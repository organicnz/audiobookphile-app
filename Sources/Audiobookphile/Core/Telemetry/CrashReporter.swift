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
    private static let signalNames: [Int32: String] = [
        SIGABRT: "SIGABRT",
        SIGBUS: "SIGBUS",
        SIGFPE: "SIGFPE",
        SIGILL: "SIGILL",
        SIGSEGV: "SIGSEGV",
        SIGTRAP: "SIGTRAP",
    ]

    private static let reportLock = NSLock()

    static func install() {
        installExceptionHandler()
        installSignalHandlers()
    }

    // MARK: - Uncaught exceptions

    private static func installExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let symbols = Array(exception.callStackSymbols.prefix(maxStackSymbols))
            let payload: [String: Any] = [
                "kind": "NSException",
                "name": exception.name.rawValue,
                "reason": exception.reason ?? "Unknown reason",
                "stack": symbols,
                "timestamp": Int(Date().timeIntervalSince1970),
            ]
            writeReport(payload, signal: nil)
        }
    }

    // MARK: - Fatal signals

    private static func installSignalHandlers() {
        var action = sigaction()
        action.__sigaction_u.__sa_sigaction = { signalNumber, _, _ in
            let payload: [String: Any] = [
                "kind": signalNames[signalNumber] ?? "Signal \(signalNumber)",
                "signal": Int32(signalNumber),
                "timestamp": Int(Date().timeIntervalSince1970),
            ]
            writeReport(payload, signal: signalNumber)
            // Restore the default handler and re-raise so the OS still produces
            // its native crash log (and debugger detach behaves normally).
            signal(signalNumber, SIG_DFL)
            raise(signalNumber)
        }
        action.sa_mask = sigset_t()
        action.sa_flags = SA_SIGINFO | SA_NODEFER
        for signalNumber in fatalSignals {
            sigaction(signalNumber, &action, nil)
        }
    }

    // MARK: - Report persistence

    private static func reportURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent(reportFileName)
    }

    private static func writeReport(_ payload: [String: Any], signal: Int32?) {
        reportLock.lock()
        defer { reportLock.unlock() }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
        try? data.write(to: reportURL(), options: .atomic)
    }

    /// Reads and deletes any crash report from a previous session.
    static func consumePendingCrashReport() -> PendingCrashReport? {
        reportLock.lock()
        defer { reportLock.unlock() }
        let url = reportURL()
        guard let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
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
}
#else
/// Compile-time placeholder so callers outside iOS stay source-compatible.
public enum CrashReporter {
    public static func install() {}
}
#endif
