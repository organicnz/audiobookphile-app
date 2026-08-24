//
//  CrashDiagnosticsView.swift
//  Audiobookphile
//
//  Self-serve crash diagnostics. Reads the on-device report written by
//  CrashReporter so the last crash is visible in-app (including TestFlight /
//  Xcode Cloud builds) without depending on App Store Connect or Sentry.
//
//  Compatible with Swift 6.3 and Skip.
//

#if !SKIP && os(iOS)
import SwiftUI
import Observation

public struct CrashDiagnosticsView: View {
    @State private var report: PendingCrashReport?
    @State private var sentryConfigured: Bool = false
    @State private var sentryEnabled: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection

                if let report = report {
                    crashSection(report)
                } else {
                    ContentUnavailableView(
                        "No crash recorded",
                        systemImage: "checkmark.shield",
                        description: Text("The previous session did not terminate unexpectedly.")
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle("Crash Diagnostics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { refresh() }
    }

    // MARK: - Telemetry status

    private var statusSection: some View {
        SettingsSection(title: "Telemetry Pipeline") {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: sentryConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(sentryConfigured ? Color.appSuccess : Color.appError)
                    Text("Sentry (Xcode Cloud SENTRY_DSN)")
                    Spacer()
                    Text(sentryConfigured ? "Configured" : "Not configured")
                        .foregroundStyle(.secondary)
                }
                .padding(12)

                HStack {
                    Image(systemName: sentryEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(sentryEnabled ? Color.appSuccess : Color.appError)
                    Text("Crash reporting enabled")
                    Spacer()
                    Text(sentryEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
                .padding(12)

                Text("If Sentry is not configured, crashes are retained on-device and shown here after a relaunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Last crash

    private func crashSection(_ report: PendingCrashReport) -> some View {
        SettingsSection(title: "Last Crash") {
            VStack(alignment: .leading, spacing: 12) {
                row(label: "Kind", value: report.kind)
                row(label: "Detail", value: report.detail)
                if let signal = report.signal {
                    let name = CrashReporter.signalNames[signal] ?? "Signal \(signal)"
                    row(label: "Signal", value: name)
                }

                if let symbols = report.stackSymbols, !symbols.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stack Trace").font(.caption).foregroundStyle(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(symbols.enumerated()), id: \.offset) { _, sym in
                                    Text(sym)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(DesignTokens.Color.foreground)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 320)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                HStack {
                    Button("Copy Report") {
                        var text = "\(report.kind): \(report.detail)"
                        if let signal = report.signal { text += "\nSignal: \(signal)" }
                        if let symbols = report.stackSymbols {
                            text += "\n\n" + symbols.joined(separator: "\n")
                        }
                        UIPasteboard.general.string = text
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appPrimary)

                    Spacer()

                    Button("Clear") {
                        CrashReporter.clearPendingCrashReport()
                        refresh()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(12)
            }
        }
    }

    private func row(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Color.foreground)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func refresh() {
        report = CrashReporter.readPendingCrashReport()
        sentryConfigured = TelemetryService.shared.isConfigured
        sentryEnabled = TelemetryService.shared.isEnabled
    }
}
#endif
