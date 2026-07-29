import SwiftUI
#if os(iOS) && !SKIP
import UIKit
#endif

public struct TwoFactorSettingsView: View {
    @State private var mode: Mode = .idle
    @State private var secret: String = ""
    @State private var uri: String = ""
    @State private var verificationCode: String = ""
    @State private var disableCode: String = ""
    @State private var is2faEnabled: Bool = false
    @State private var isLoading: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var copied: Bool = false

    enum Mode {
        case idle
        case enrolling
        case disabling
    }

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerCard

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else if mode == .enrolling {
                        enrollmentCard
                    } else if mode == .disabling {
                        disablingCard
                    } else {
                        statusCard
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Two-Factor Auth")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStatus()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: is2faEnabled ? "shield.fill" : "shield.slash")
                .font(.system(size: 40))
                .foregroundStyle(is2faEnabled ? Color.green : Color.orange)
                .padding()
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )

            Text(is2faEnabled ? "Two-Factor Authentication is ON" : "Two-Factor Authentication is OFF")
                .font(.headline.bold())
                .foregroundStyle(.white)

            Text("Protect your account by requiring a 6-digit Time-based One-Time Password (TOTP) from an authenticator app when signing in.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            if is2faEnabled {
                Button {
                    withAnimation { mode = .disabling }
                } label: {
                    Text("Disable 2FA...")
                        .font(.headline)
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Button {
                    Task { await startEnrollment() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text("Set Up 2FA")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.9))
            }
        }
    }

    private var enrollmentCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("1. Add Secret Key to Authenticator")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Copy the secret key below and add it to your authenticator app (such as 1Password, Authy, or Google Authenticator):")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            HStack {
                Text(secret)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    #if os(iOS) && !SKIP
                    UIPasteboard.general.string = secret
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                    withAnimation { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                        .foregroundStyle(copied ? .green : .white)
                        .padding(8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Divider().background(Color.white.opacity(0.2))

            Text("2. Verify 6-Digit Code")
                .font(.headline)
                .foregroundStyle(.white)

            TextField("000000", text: $verificationCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS) || SKIP
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: verificationCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 6 {
                        verificationCode = String(filtered.prefix(6))
                    } else {
                        verificationCode = filtered
                    }
                    errorMessage = nil
                }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.9))
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation {
                        mode = .idle
                        verificationCode = ""
                        errorMessage = nil
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await confirmEnrollment() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text("Activate 2FA")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(verificationCode.count == 6 ? Color.green : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(verificationCode.count != 6 || isSubmitting)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var disablingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter a 6-digit code from your authenticator to disable 2FA:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            TextField("000000", text: $disableCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS) || SKIP
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: disableCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 6 {
                        disableCode = String(filtered.prefix(6))
                    } else {
                        disableCode = filtered
                    }
                    errorMessage = nil
                }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.9))
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    withAnimation {
                        mode = .idle
                        disableCode = ""
                        errorMessage = nil
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await confirmDisable() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text("Disable")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(disableCode.count == 6 ? Color.red : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(disableCode.count != 6 || isSubmitting)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func loadStatus() async {
        isLoading = true
        do {
            let user = try await AudiobookphileAPI.shared.getCurrentUserProfile()
            is2faEnabled = user.id.isEmpty ? false : is2faEnabled // Default to false unless check returns true
        } catch {
            print("[TwoFactorSettings] Failed to check status: \(error)")
        }
        isLoading = false
    }

    private func startEnrollment() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.enroll2FA()
            if let secret = res.secret {
                self.secret = secret
                self.uri = res.uri ?? ""
                self.mode = .enrolling
            } else if let err = res.error {
                self.errorMessage = err
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func confirmEnrollment() async {
        guard verificationCode.count == 6 else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.verify2FA(code: verificationCode)
            if res.success == true {
                is2faEnabled = true
                mode = .idle
                verificationCode = ""
            } else {
                errorMessage = res.error ?? "Invalid code"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func confirmDisable() async {
        guard disableCode.count == 6 else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let res = try await AudiobookphileAPI.shared.disable2FA(code: disableCode)
            if res.success == true {
                is2faEnabled = false
                mode = .idle
                disableCode = ""
            } else {
                errorMessage = res.error ?? "Invalid code"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
