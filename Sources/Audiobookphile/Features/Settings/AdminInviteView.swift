//
//  AdminInviteView.swift
//  Audiobookphile
//
//  Admin-only view for inviting users via email.
//  Uses Liquid Glass aesthetics and @Observable pattern.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
@MainActor
final class AdminInviteViewModel {
    var email = ""
    var username = ""
    var selectedUserType = "user"
    var isLoading = false
    var showSuccess = false
    var showError = false
    var feedbackMessage = ""

    let userTypes = ["user", "admin"]

    var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    func sendInvite() async {
        guard isValidEmail else {
            feedbackMessage = "Please enter a valid email address."
            showError = true
            return
        }

        isLoading = true
        showSuccess = false
        showError = false

        do {
            let result = try await AudiobookphileAPI.shared.inviteUser(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.isEmpty ? nil : username.trimmingCharacters(in: .whitespacesAndNewlines),
                userType: selectedUserType
            )

            if let errorMsg = result.error, !errorMsg.isEmpty {
                feedbackMessage = errorMsg
                showError = true
            } else {
                feedbackMessage = "Invitation sent to \(email)"
                showSuccess = true
                // Reset fields
                email = ""
                username = ""
                selectedUserType = "user"
            }
        } catch {
            feedbackMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}

// MARK: - View

public struct AdminInviteView: View {
    @State private var viewModel = AdminInviteViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    headerCard

                    // Invite form
                    formSection

                    // Send button
                    sendButton

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Invite User")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.feedbackMessage)
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") { viewModel.showSuccess = false }
        } message: {
            Text(viewModel.feedbackMessage)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        SettingsSection {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.appPrimary, .appAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)

                    Image(systemName: "person.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Email Invitation")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Send an invite link to add a new member")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Form

    private var formSection: some View {
        SettingsSection(title: "Invitation Details") {
            VStack(spacing: 16) {
                // Email
                VStack(alignment: .leading, spacing: 6) {
                    Label("Email Address", systemImage: "envelope.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("user@example.com", text: $viewModel.email)
                        #if os(iOS) || SKIP
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                }

                Divider().background(Color.primary.opacity(0.1))

                // Username (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Username (Optional)", systemImage: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("johndoe", text: $viewModel.username)
                        #if os(iOS) || SKIP
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                }

                Divider().background(Color.primary.opacity(0.1))

                // User Type Picker
                VStack(alignment: .leading, spacing: 6) {
                    Label("Role", systemImage: "shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Role", selection: $viewModel.selectedUserType) {
                        ForEach(viewModel.userTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(12)
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            Task {
                await viewModel.sendInvite()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(viewModel.isLoading ? "Sending…" : "Send Invitation")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(DesignTokens.Color.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: viewModel.isValidEmail && !viewModel.isLoading
                        ? [.appPrimary, .appAccent]
                        : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: viewModel.isValidEmail ? [.white.opacity(0.4), .white.opacity(0.1)] : [.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: viewModel.isValidEmail ? .appPrimary.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(!viewModel.isValidEmail || viewModel.isLoading)
        .animation(.spring(response: 0.3), value: viewModel.isValidEmail)
    }
}
