//
//  TelemetryService.swift
//  Audiobookphile
//
//  Portable, dependency-free crash and error reporting client that speaks the
//  Sentry envelope protocol over plain URLSession. It compiles unchanged for
//  iOS and Android (via Skip transpilation), so every platform reports to the
//  same error tracker as the web app.
//
//  The service is a no-op unless a Sentry DSN is present in the build
//  configuration (Skip.env → SENTRY_DSN → Info.plist "SentryDSN").
//

import Foundation

/// Severity of a reported message, matching the Sentry level vocabulary.
public enum SentryLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
    case fatal
}

/// Parsed Sentry DSN (`https://<publicKey>@o<org>.ingest.sentry.io/<project>` or self-hosted equivalents).
struct SentryDSN: Sendable, Equatable {
    let scheme: String
    let host: String
    let publicKey: String
    let projectID: String

    /// The ingest endpoint for envelope uploads.
    var envelopeURL: URL? {
        URL(string: "\(scheme)://\(host)/api/\(projectID)/envelope/")
    }

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let schemeRange = trimmed.range(of: "://") else { return nil }
        let scheme = String(trimmed[trimmed.startIndex..<schemeRange.lowerBound])
        let remainder = String(trimmed[schemeRange.upperBound...])
        guard let atRange = remainder.range(of: "@") else { return nil }
        let publicKey = String(remainder[remainder.startIndex..<atRange.lowerBound])
        let hostAndProject = String(remainder[atRange.upperBound...])
        let host: String
        let projectID: String
        if let slash = hostAndProject.lastIndex(of: "/") {
            host = String(hostAndProject[hostAndProject.startIndex..<slash])
            projectID = String(hostAndProject[hostAndProject.index(after: slash)...])
        } else {
            host = hostAndProject
            projectID = ""
        }
        guard !publicKey.isEmpty, !host.isEmpty, !projectID.isEmpty else { return nil }
        self.scheme = scheme
        self.host = host
        self.publicKey = publicKey
        self.projectID = projectID
    }
}

/// Sends crash and error events to Sentry. Thread-safe after `configure()` has
/// been called once during app launch; the parsed configuration is immutable
/// from then on and pending events live in `UserDefaults`, which is safe to
/// touch from any thread.
public final class TelemetryService: @unchecked Sendable {
    public static let shared = TelemetryService()

    private static let sdkName = "audiobookphile-telemetry"
    private static let sdkVersion = "1.0.0"
    private static let pendingQueueKey = "abp_pending_sentry_events"
    private static let maxPendingEvents = 10
    private static let enabledKey = "abp_crash_reporting_enabled"

    private struct Config: Sendable {
        let dsn: SentryDSN
        let release: String
        let environment: String
        let deviceID: String
    }

    private var config: Config?

    private init() {}

    /// Whether crash/error reporting is active for this build.
    public var isConfigured: Bool {
        config != nil
    }

    /// User-controlled opt-out. Off by default only when the user explicitly
    /// disabled it in Settings; stored per install in UserDefaults.
    public var isEnabled: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: TelemetryService.enabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: TelemetryService.enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: TelemetryService.enabledKey)
            logger.debug("TelemetryService: crash reporting \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Lifecycle

    /// Parses the Sentry DSN from the environment and flushes any events that
    /// failed to upload in previous sessions. Safe to call more than once.
    public func configure() {
        guard config == nil else { return }
        guard let dsn = SentryDSN(string: EnvironmentConfig.sentryDSN) else {
            logger.debug("TelemetryService: no valid Sentry DSN; reporting disabled")
            return
        }
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif
        config = Config(
            dsn: dsn,
            release: "audiobookphile-app@\(version)+\(build)",
            environment: environment,
            deviceID: deviceInstallID()
        )
        logger.debug("TelemetryService: configured for \(dsn.host) (\(environment))")
        flushPendingEvents()
    }

    /// Reads a crash report written by the crash handler (if any) from a
    /// previous session, mirrors it to the system log, and forwards it to
    /// Sentry when telemetry is configured. The on-disk report is only removed
    /// after a successful hand-off, so it survives when telemetry is disabled.
    public func handlePendingCrashReport() {
        #if !SKIP && os(iOS)
        guard let report = CrashReporter.readPendingCrashReport() else { return }

        // Mirror the crash to the system log so it is visible in the Xcode
        // console on the next launch — even when Sentry is not configured.
        logger.error("CrashReporter: previous session terminated by \(report.kind): \(report.detail)")
        if let signal = report.signal {
            logger.error("CrashReporter: signal \(signal)")
        }
        if let symbols = report.stackSymbols {
            for symbol in symbols {
                logger.error("CrashReporter: \(symbol)")
            }
        }

        guard config != nil, isEnabled else {
            // No telemetry sink available: retain the on-disk report so it can
            // be inspected (e.g. via device logs) instead of being discarded.
            logger.error("CrashReporter: report retained locally (telemetry not configured)")
            return
        }

        var extra: [String: Any] = ["signal": report.signal ?? -1]
        if let symbols = report.stackSymbols {
            extra["stack_symbols"] = symbols
        }
        captureEvent(
            level: .fatal,
            message: "App terminated by \(report.kind)",
            type: report.kind,
            value: report.detail,
            extra: extra
        )
        CrashReporter.clearPendingCrashReport()
        #else
        // Android crash capture is handled by the platform at a later stage.
        #endif
    }

    // MARK: - Capture API

    /// Reports a caught error with an optional fingerprint tag.
    public func captureError(_ error: Error, tags: [String: String] = [:]) {
        let nsError = error as NSError
        captureEvent(
            level: .error,
            message: nsError.localizedDescription,
            type: "\(type(of: error))",
            value: nsError.localizedDescription,
            domain: nsError.domain,
            code: nsError.code,
            tags: tags
        )
    }

    /// Reports a free-form message at the given severity.
    public func captureMessage(_ message: String, level: SentryLevel = .info, tags: [String: String] = [:]) {
        captureEvent(level: level, message: message, type: nil, value: nil, tags: tags)
    }

    /// Reports an unhandled fatal condition (used by the crash reporter).
    func captureEvent(
        level: SentryLevel,
        message: String,
        type: String?,
        value: String?,
        domain: String? = nil,
        code: Int? = nil,
        extra: [String: Any]? = nil,
        tags: [String: String] = [:]
    ) {
        guard let config else { return }
        guard isEnabled else { return }

        var event: [String: Any] = [
            "event_id": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            "timestamp": iso8601Timestamp(Date()),
            "platform": "native",
            "sdk": [
                "name": TelemetryService.sdkName,
                "version": TelemetryService.sdkVersion,
            ],
            "release": config.release,
            "environment": config.environment,
            "level": level.rawValue,
            "message": ["formatted": message],
        ]
        if let type, let value {
            event["exception"] = [
                "values": [
                    [
                        "type": type,
                        "value": value,
                        "mechanism": ["type": "generated", "handled": false],
                    ]
                ]
            ]
        }
        var mergedTags = tags
        mergedTags["device_id"] = config.deviceID
        event["tags"] = mergedTags
        if let extra {
            event["extra"] = extra
        }
        if let domain {
            event["extra"] = mergeExtra(event["extra"] as? [String: Any], ["error_domain": domain])
        }
        if let code {
            event["extra"] = mergeExtra(event["extra"] as? [String: Any], ["error_code": code])
        }
        enqueue(event)
    }

    // MARK: - Transport

    private func enqueue(_ event: [String: Any]) {
        guard let config else { return }
        let envelope = buildEnvelope(event: event, dsn: config.dsn)
        guard !envelope.isEmpty else {
            logger.error("TelemetryService: failed to serialize event")
            return
        }
        let eventID = event["event_id"] as? String ?? ""
        let envelopeData = Data(envelope.utf8)
        Task {
            await upload(envelopeData: envelopeData, eventID: eventID, config: config)
        }
    }

    private func buildEnvelope(event: [String: Any], dsn: SentryDSN) -> String {
        let header: [String: Any] = [
            "event_id": event["event_id"] ?? "",
            "sent_at": iso8601Timestamp(Date()),
            "dsn": "\(dsn.scheme)://\(dsn.publicKey)@\(dsn.host)/\(dsn.projectID)",
            "sdk": [
                "name": TelemetryService.sdkName,
                "version": TelemetryService.sdkVersion,
            ],
        ]
        guard let eventJSON = jsonData(event), let headerJSON = jsonData(header) else {
            return ""
        }
        let eventText = String(data: eventJSON, encoding: .utf8) ?? ""
        let headerText = String(data: headerJSON, encoding: .utf8) ?? ""
        let itemHeader: [String: Any] = [
            "type": "event",
            "content_type": "application/json",
            "length": eventText.utf8.count,
        ]
        let itemHeaderText = String(data: jsonData(itemHeader) ?? Data(), encoding: .utf8) ?? ""
        return headerText + "\n" + itemHeaderText + "\n" + eventText
    }

    private func upload(envelopeData: Data, eventID: String, config: Config) async {
        guard let url = config.dsn.envelopeURL else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = envelopeData
        request.setValue("application/x-sentry-envelope", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Sentry sentry_version=7, sentry_client=\(TelemetryService.sdkName)/\(TelemetryService.sdkVersion), sentry_key=\(config.dsn.publicKey)",
            forHTTPHeaderField: "X-Sentry-Auth"
        )
        request.timeoutInterval = 15
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                persistForRetry(eventID: eventID, envelope: envelopeData)
                logger.error("TelemetryService: upload failed with status \(http.statusCode)")
            }
        } catch {
            persistForRetry(eventID: eventID, envelope: envelopeData)
            logger.debug("TelemetryService: upload failed (\(error.localizedDescription)); queued for retry")
        }
    }

    /// Persists a failed envelope for the next launch. The queue is capped so a
    /// broken network can never grow it without bound.
    private func persistForRetry(eventID: String, envelope: Data) {
        let defaults = UserDefaults.standard
        var pending = defaults.stringArray(forKey: TelemetryService.pendingQueueKey) ?? []
        pending.append(envelope.base64EncodedString())
        while pending.count > TelemetryService.maxPendingEvents {
            pending.removeFirst()
        }
        defaults.set(pending, forKey: TelemetryService.pendingQueueKey)
        logger.debug("TelemetryService: queued event \(eventID) for retry (\(pending.count) pending)")
    }

    /// Re-uploads envelopes that failed in a previous session.
    public func flushPendingEvents() {
        let defaults = UserDefaults.standard
        let pending = defaults.stringArray(forKey: TelemetryService.pendingQueueKey) ?? []
        guard !pending.isEmpty, let config else { return }
        defaults.removeObject(forKey: TelemetryService.pendingQueueKey)
        for entry in pending {
            guard let data = Data(base64Encoded: entry) else { continue }
            let eventID = UUID().uuidString
            Task {
                await upload(envelopeData: data, eventID: eventID, config: config)
            }
        }
        if !pending.isEmpty {
            logger.debug("TelemetryService: re-uploading \(pending.count) pending event(s)")
        }
    }

    // MARK: - Helpers

    private func jsonData(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [])
    }

    private func mergeExtra(_ base: [String: Any]?, _ additions: [String: Any]) -> [String: Any] {
        var merged = base ?? [:]
        for (key, value) in additions {
            merged[key] = value
        }
        return merged
    }

    private func iso8601Timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// A salted, anonymous installation identifier. Never an email or device
    /// serial — it only correlates events belonging to the same install.
    private func deviceInstallID() -> String {
        let key = "abp_install_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}
