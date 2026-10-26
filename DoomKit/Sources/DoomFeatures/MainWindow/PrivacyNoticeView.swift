import SwiftUI

public struct PrivacyNoticeView: View {
    public let onUnderstand: () -> Void
    public let onDismiss: () -> Void

    public init(onUnderstand: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onUnderstand = onUnderstand
        self.onDismiss = onDismiss
    }

    public static let noticeVersion = 1

    public static let noticeBullets: [String] = [
        "When you press Fn ⌃ ⌥, DOOM reads the text you selected and sends it, with a fixed instruction, to Google's Gemini API using your API key. Nothing is sent at any other time.",
        "DOOM doesn't send the app name, page address, window title or anything else from your screen.",
        "DOOM asks Google not to store the request (store = false). Google's own terms still apply. With an unpaid (free-tier) key, Google may use what you send to improve its products and human reviewers may read it. Don't select sensitive or personal information when using a free-tier key. Paid-tier content isn't used to improve Google's products.",
        "DOOM keeps your selection and the answer only in memory and discards them when you close the panel. DOOM doesn't keep history or logs of your text.",
        "To detect Fn ⌃ ⌥, macOS lets DOOM observe keyboard events. DOOM only looks at the modifier keys and never records what you type.",
        "Cancelling stops DOOM from waiting, but can't recall text that was already sent."
    ]

    public var body: some View {
        ZStack {
            DoomTheme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: DoomTheme.Spacing.m) {
                Text("How DOOM handles your text")
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)

                ScrollView {
                    VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
                        ForEach(Self.noticeBullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: DoomTheme.Spacing.xs) {
                                Text("•")
                                    .foregroundStyle(DoomTheme.accentText)
                                Text(bullet)
                                    .font(.body)
                                    .foregroundStyle(DoomTheme.textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(.vertical, DoomTheme.Spacing.xxs)
                }
                .frame(maxHeight: 380)

                HStack {
                    Spacer()

                    Button(action: onDismiss) {
                        Text("Not Now")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(DoomTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(DoomTheme.control)
                            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)

                    Button(action: onUnderstand) {
                        Text("I Understand")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(DoomTheme.primaryButtonText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(DoomTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(DoomTheme.Spacing.l)
        }
        .frame(width: 480, height: 440)
        .preferredColorScheme(.dark)
    }
}
