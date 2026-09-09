//
//  TelemetryComponent.swift
//  Audiobookphile
//
//  A dedicated, testable component for Sentry and telemetry operations.
//  Compatible with Swift 6.3 and Skip — compiles for iOS (SentrySDK via
//  TelemetryService) and Android (Skip transpilation via the envelope
//  transport in TelemetryService).
//
//  Single source of truth for telemetry call-sites that want an injectable
//  wrapper instead of touching `TelemetryService.shared` directly.
//  Reuses `SentryLevel` from TelemetryService.swift — no redefinitions.
//

import Foundation
import Observation

/// Injectable wrapper around `TelemetryService` for Sentry operations.
/// Exposes the capture API plus lifecycle helpers with an observable
/// configuration state for Settings/Diagnostics UI.
@Observable
@MainActor
public final class TelemetryComponent {
    private let telemetryService: TelemetryService

    /// Whether Sentry is currently configured (DSN present and valid).
    public var isSentryConfigured: Bool {
        telemetryService.isConfigured
    }

    /// Whether crash reporting is enabled (user opt-out respected).
    public var isCrashReportingEnabled: Bool {
        telemetryService.isEnabled
    }

    /// Shared-instance convenience for production call-sites.
    public static let shared = TelemetryComponent(telemetryService: TelemetryService.shared)

    /// Creates a component around the given service (inject a double in tests).
    /// - Parameter telemetryService: The telemetry service to wrap.
    public init(telemetryService: TelemetryService = TelemetryService.shared) {
        self.telemetryService = telemetryService
    }

    // MARK: - Capture API

    /// Reports a caught error with optional fingerprint tags.
    public func captureError(_ error: Error, tags: [String: String] = [:]) {
        telemetryService.captureError(error, tags: tags)
    }

    /// Reports a free-form message at the given severity.
    public func captureMessage(_ message: String, level: SentryLevel = .info, tags: [String: String] = [:]) {
        telemetryService.captureMessage(message, level: level, tags: tags)
    }

    /// Captures a breadcrumb for Sentry debugging (sequence of events
    /// leading up to a crash or error).
    public func captureBreadcrumb(_ message: String, level: SentryLevel = .info, tags: [String: String] = [:]) {
        telemetryService.captureBreadcrumb(message, level: level, tags: tags)
    }

    // MARK: - Lifecycle

    /// Parses the Sentry DSN and flushes events queued in previous sessions.
    /// Idempotent — safe to call more than once.
    public func configure() {
        telemetryService.configure()
    }

    /// Forwards a pending crash report from a previous session to Sentry
    /// when configured, otherwise retains it locally for Crash Diagnostics.
    public func handlePendingCrashReport() {
        telemetryService.handlePendingCrashReport()
    }

    /// Re-uploads envelopes that failed in a previous session.
    public func flushPendingEvents() {
        telemetryService.flushPendingEvents()
    }
}
