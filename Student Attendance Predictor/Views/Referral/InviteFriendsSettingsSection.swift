//
//  InviteFriendsSettingsSection.swift
//  Student Attendance Predictor
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct InviteFriendsSettingsSection: View {
    @ObservedObject private var referral = ReferralService.shared
    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private let mint = BrandColor.colorAccentPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            codeCard
            statsRow
            actionButtons
        }
        .padding(.vertical, 6)
        .task {
            await referral.ensureInviteCode()
            await referral.claimReferralRewards()
        }
        .onChange(of: didCopy) { _, copied in
            guard copied else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                didCopy = false
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(mint.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: "gift.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(mint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Invite friends")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("You both get 7 days of all Pro features")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("7 days")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(mint))
        }
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR INVITE CODE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            HStack(alignment: .center, spacing: 12) {
                if let code = referral.inviteCode {
                    Button(action: copyCode) {
                        Text(spaced(code))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(mint)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Your invite code \(code)")
                    .accessibilityHint("Copies the code")
                } else if referral.isBusy {
                    ProgressView()
                        .tint(mint)
                    Text("Getting your code…")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                } else {
                    Button("Get my code") {
                        Task { await referral.ensureInviteCode() }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .buttonStyle(.borderless)
                    Spacer(minLength: 8)
                }

                Button(action: copyCode) {
                    Text(didCopy ? "Copied" : "Copy")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(didCopy ? mint : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(didCopy ? mint.opacity(0.18) : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.borderless)
                .disabled(referral.inviteCode == nil)
            }

            Text(
                didCopy
                    ? "Code copied. Paste it in chat."
                    : (ReferralConfiguration.inviteSystemShareEnabled
                        ? "This is your code. Share it with a friend."
                        : "Copy your code and paste it in WhatsApp / chat.")
            )
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if let error = referral.lastError, referral.inviteCode == nil {
                Text(error)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(BrandColor.colorMissed)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            inviteStat(value: "\(referral.friendsJoined)", label: referral.friendsJoined == 1 ? "joined" : "joined")
            inviteStat(value: "\(referral.adFreeDaysEarned)", label: "days earned")
            if entitlements.isPro == false,
               let remaining = entitlements.remaining(until: entitlements.inviteTrialUntil) {
                inviteStat(value: remaining, label: "trial left")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if ReferralConfiguration.inviteSystemShareEnabled {
                Button {
                    Task {
                        await referral.ensureInviteCode()
                        shareInvite()
                    }
                } label: {
                    Text("Share")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule(style: .continuous).fill(mint))
                }
                .buttonStyle(.borderless)
                .disabled(referral.inviteCode == nil && referral.isBusy == false)
            }

            Button {
                // Settings is already a sheet — dismiss it first so Home can present Redeem.
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    referral.presentRedeem(source: "settings")
                }
            } label: {
                Text(referral.hasAlreadyRedeemed ? "Invite used" : "I have a code")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(referral.hasAlreadyRedeemed ? 0.45 : 0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                    )
            }
            .buttonStyle(.borderless)
            .disabled(referral.hasAlreadyRedeemed)
        }
    }

    private func copyCode() {
        Task {
            if referral.inviteCode == nil {
                await referral.ensureInviteCode()
            }
            guard referral.copyInviteCode() else { return }
            didCopy = true
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
    }

    private func spaced(_ code: String) -> String {
        code.map(String.init).joined(separator: "  ")
    }

    private func inviteStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shareInvite() {
        guard let line = referral.shareInviteLine() else { return }
        AnalyticsService.shared.log(.inviteLinkShared)
        #if canImport(UIKit)
        let activity = UIActivityViewController(activityItems: [line], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else {
            return
        }
        var presenter = root
        while let shown = presenter.presentedViewController {
            presenter = shown
        }
        presenter.present(activity, animated: true)
        #endif
    }
}

#if canImport(UIKit)
private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: \.isKeyWindow) ?? windows.first
    }
}
#endif
