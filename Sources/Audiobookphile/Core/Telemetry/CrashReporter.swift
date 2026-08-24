//
//  CrashReporter.swift
//  Audiobookphile
//
//  Minimal, dependency-free crash capture for iOS. Uncaught exceptions are
//  serialized to a pending report file; fatal signals are recorded with
//  async-signal-safe writes. The next app launch reports the pending crash
//  through TelemetryService. Compiles to a no-op outside iOS.
//

import Foundation

#if !SKIP && os(iOS)
import UIKit
#endif

#if !SKIP && os(iOS)
/// A fatal termination recorded by the crash handler.
public struct PendingCrashReport: Sendable {
    public let kind: String
    public let detail: String
    public let signal: Int32?
    public let stackSymbols: [String]?
}
#endif

#if !SKIP && os(iOS)
enum CrashReporter {
    static let reportFileName = "abp_crash_report.json"
    static let maxStackSymbols = 32

    private static let fatalSignals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
    static let signalNames: [Int32: String] = [
        SIGABRT: "SIGABRT",
        SIGBUS: "SIGBUS",
        SIGFPE: "SIGFPE",
        SIGILL: "SIGILL",
        SIGSEGV: "SIGSEGV",
        SIGTRAP: "SIGTRAP",
    ]

    static let reportLock = NSLock()

    static func install() {
        installExceptionHandler()
        installSignalHandlers()
    }

    // MARK: - Uncaught exceptions

    private static func installExceptionHandler() {
        NSSetUncaughtExceptionHandler(abpExceptionHandler)
    }

    // MARK: - Fatal signals

    private static func installSignalHandlers() {
        var action = sigaction()
        action.__sigaction_u.__sa_handler = abpSignalHandler
        action.sa_mask = sigset_t()
        action.sa_flags = 0
        for signalNumber in fatalSignals {
            sigaction(signalNumber, &action, nil)
        }
    }

    // MARK: - Report persistence

    /// Stored in Application Support rather than Caches: iOS purges Caches
    /// under storage pressure, which would silently destroy a retained crash
    /// report. Excluded from iCloud backups so it doesn't bloat them.
    static func reportURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Audiobookphile", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var url = directory.appendingPathComponent(reportFileName)
        try? url.setResourceValues(excluded)
        return url
    }

    /// Reads any crash report from a previous session **without** removing it.
    /// Use this on launch so an undelivered report is retained when telemetry
    /// is disabled, rather than being silently discarded.
    static func readPendingCrashReport() -> PendingCrashReport? {
        reportLock.lock()
        defer { reportLock.unlock() }
        let url = reportURL()
        guard let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return nil
        }
        let kind = json["kind"] as? String ?? "Crash"
        let name = json["name"] as? String
        let reason = json["reason"] as? String
        let detail = [name, reason].compactMap { $0 }.joined(separator: ": ")
        return PendingCrashReport(
            kind: kind,
            detail: detail.isEmpty ? kind : detail,
            signal: (json["signal"] as? NSNumber)?.int32Value,
            stackSymbols: json["stack"] as? [String]
        )
    }

    /// Removes the persisted crash report. Call only after it has been
    /// delivered to a telemetry sink, so a failed upload can be retried on the
    /// next launch instead of the report vanishing.
    static func clearPendingCrashReport() {
        reportLock.lock()
        defer { reportLock.unlock() }
        let url = reportURL()
        try? FileManager.default.removeItem(at: url)
    }

    /// Backwards-compatible read-and-delete. Prefer `readPendingCrashReport()`
    /// plus `clearPendingCrashReport()` so the report survives when no sink is
    /// configured.
    static func consumePendingCrashReport() -> PendingCrashReport? {
        guard let report = readPendingCrashReport() else { return nil }
        clearPendingCrashReport()
        return report
    }
}

// C-conformant handler functions: @convention(c) callbacks cannot capture
// context, so the payloads are built here against global-only state.

private func abpWriteReport(_ payload: [String: Any], signal: Int32?) {
    CrashReporter.reportLock.lock()
    defer { CrashReporter.reportLock.unlock() }
    let url = CrashReporter.reportURL()
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
    try? data.write(to: url, options: .atomic)
}

private func abpExceptionHandler(_ exception: NSException) {
    let symbols = Array(exception.callStackSymbols.prefix(CrashReporter.maxStackSymbols))
    let payload: [String: Any] = [
        "kind": "NSException",
        "name": exception.name.rawValue,
        "reason": exception.reason ?? "Unknown reason",
        "stack": symbols,
        "timestamp": Int(Date().timeIntervalSince1970),
    ]
    abpWriteReport(payload, signal: nil)
}

private func abpSignalHandler(_ signalNumber: Int32) {
    let payload: [String: Any] = [
        "kind": CrashReporter.signalNames[signalNumber] ?? "Signal \(signalNumber)",
        "signal": Int32(signalNumber),
        "timestamp": Int(Date().timeIntervalSince1970),
    ]
    abpWriteReport(payload, signal: signalNumber)
    // Restore the default handler and re-raise so the OS still produces
    // its native crash log (and debugger detach behaves normally).
    signal(signalNumber, SIG_DFL)
    raise(signalNumber)
}
#else
/// Compile-time placeholder so callers outside iOS stay source-compatible.
public enum CrashReporter {
    public static func install() {}
}
#endif
