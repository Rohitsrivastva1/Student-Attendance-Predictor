//
//  RedeemInviteView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct RedeemInviteView: View {
    @ObservedObject private var referral = ReferralService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Got a friend’s code?")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Enter it to unlock \(ReferralConfiguration.grantDays) days of all Pro features. Ads stay on. Your friend gets the same.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))

                    TextField("ABC123", text: $referral.redeemCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .onChange(of: referral.redeemCodeInput) { _, newValue in
                            let normalized = CrockfordBase32.normalize(newValue)
                            if normalized != newValue {
                                referral.redeemCodeInput = String(normalized.prefix(6))
                            } else if newValue.count > 6 {
                                referral.redeemCodeInput = String(newValue.prefix(6))
                            }
                        }

                    if referral.hasAlreadyRedeemed {
                        Text("This install already unlocked an invite. One redeem per device.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BrandColor.colorAccentPrimary.opacity(0.9))
                    } else if let error = referral.lastError {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BrandColor.colorMissed)
                    }

                    Button {
                        Task { await referral.redeemEnteredCode() }
                    } label: {
                        HStack {
                            if referral.isBusy {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text(
                                referral.hasAlreadyRedeemed
                                    ? "Already unlocked"
                                    : (referral.isBusy ? "Unlocking…" : "Unlock \(ReferralConfiguration.grantDays) days")
                            )
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black.opacity(referral.canSubmitRedeem || referral.isBusy ? 0.9 : 0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandColor.colorAccentPrimary.opacity(referral.canSubmitRedeem || referral.isBusy ? 1 : 0.45))
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(referral.isBusy || referral.canSubmitRedeem == false)

                    Text("One redeem per install. Skip planner, forecast, unlimited subjects, and exports unlock for a week. Ads keep running until you buy Pro.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(20)
            }
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle("Redeem invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        referral.lastError = nil
                        dismiss()
                    }
                }
            }
            .onAppear {
                referral.prefillRedeemFromClipboardIfNeeded()
            }
        }
        .preferredColorScheme(.dark)
    }
}
