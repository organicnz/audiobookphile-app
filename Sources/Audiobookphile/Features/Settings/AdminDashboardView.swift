//
//  AdminDashboardView.swift
//  Audiobookphile
//
//  Bleeding-edge Admin Dashboard for mobile with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

public struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) private var appState

    public init() {}

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Quick Navigation Back Banner
                    navigationBanner

                    // Live Server Status Badge
                    statusBanner

                    // Admin Actions Grid
                    actionsSection

                    // System Telemetry Overview
                    telemetrySection

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Admin Dashboard")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    appState.navigation.selectedTab = 0
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Library")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.appPrimary)
            }

            ToolbarItem(placement: trailingPlacement) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Color.appPrimary)
            }
        }
    }

    // MARK: - Navigation Banner

    private var navigationBanner: some View {
        Button {
            appState.navigation.selectedTab = 0
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.appPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Return to Library")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Switch back to your active bookshelf")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "books.vertical")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.3), Color.appPrimary.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            )
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "shield.righthalf.filled")
                        .font(.title3)
                        .foregroundStyle(Color.orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("SERVER CONTROLLER")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.orange)

                    Spacer()

                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2), in: Capsule())
                }

                Text("Root / Administrator")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        SettingsSection(title: "USER MANAGEMENT & INVITES") {
            VStack(spacing: 0) {
                NavigationLink {
                    AdminInviteView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Invite New Member")
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))

                            Text("Send tokenized invitation by email")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.caption)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: - Telemetry Section

    private var telemetrySection: some View {
        SettingsSection(title: "SERVER TELEMETRY") {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "server.rack",
                    title: "Active Status",
                    value: "Online"
                ) {}

                SettingsRow(
                    icon: "network",
                    title: "Connection Mode",
                    value: "Supabase Native Edge"
                ) {}

                SettingsRow(
                    icon: "lock.shield",
                    title: "2FA Policy",
                    value: "Backend Authoritative"
                ) {}
            }
        }
    }
}
