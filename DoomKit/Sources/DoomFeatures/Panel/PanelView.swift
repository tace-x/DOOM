import SwiftUI
import DoomCore

public enum PanelContentState: Equatable, Sendable {
    case empty
    case acquiring
    case requesting(appName: String, characterCount: Int, isTakingLonger: Bool)
    case succeeded(text: String, isTruncated: Bool, restoreSkipped: Bool)
    case failed(presentation: MessagePresentation, cooldownSeconds: Int?)
}

@MainActor
public struct PanelView: View {
    public let state: PanelContentState
    public let onClose: () -> Void
    public let onCancel: () -> Void
    public let onCopy: () -> Void
    public let onRetry: () -> Void
    public let onOpenSettings: () -> Void
    public let onReviewPrivacy: () -> Void

    @State private var isCopied: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        state: PanelContentState,
        onClose: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onCopy: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onReviewPrivacy: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onClose = onClose
        self.onCancel = onCancel
        self.onCopy = onCopy
        self.onRetry = onRetry
        self.onOpenSettings = onOpenSettings
        self.onReviewPrivacy = onReviewPrivacy
    }

    public var body: some View {
        ZStack {
            // Background surface gradient
            DoomTheme.panelBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header (32 pt height)
                headerView
                    .frame(height: 32)
                    .padding(.horizontal, DoomTheme.Spacing.m)

                // Hairline divider
                Rectangle()
                    .fill(DoomTheme.steel.opacity(0.6))
                    .frame(height: 1)

                // Content
                contentView
                    .padding(DoomTheme.Spacing.m)

                // Footer (if actions exist)
                if hasFooter {
                    Rectangle()
                        .fill(DoomTheme.steel.opacity(0.6))
                        .frame(height: 1)

                    footerView
                        .padding(.horizontal, DoomTheme.Spacing.m)
                        .padding(.vertical, DoomTheme.Spacing.s)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DoomTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DoomTheme.cardRadius)
                .stroke(DoomTheme.steel.opacity(0.6), lineWidth: 1)
        )
        // Brushed metal inner top highlight
        .overlay(
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 1)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.cardRadius))
        )
        .frame(width: PanelGeometry.defaultWidth)
        .preferredColorScheme(.dark)
        .onKeyPress(.escape) {
            handleEscape()
            return .handled
        }
    }

    private var headerView: some View {
        HStack {
            Text("DOOM")
                .font(.system(size: 12, weight: .heavy, design: .default))
                .tracking(3.0)
                .foregroundStyle(DoomTheme.metal)

            Spacer()

            Button(action: handleCloseButton) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DoomTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isBusy ? "Cancel" : "Close")
        }
    }

    private var isBusy: Bool {
        switch state {
        case .acquiring, .requesting:
            return true
        default:
            return false
        }
    }

    private var hasFooter: Bool {
        switch state {
        case .empty:
            return false
        case .acquiring, .requesting, .succeeded, .failed:
            return true
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .empty:
            emptyContentView

        case .acquiring:
            acquiringContentView

        case .requesting(let appName, let characterCount, let isTakingLonger):
            requestingContentView(appName: appName, characterCount: characterCount, isTakingLonger: isTakingLonger)

        case .succeeded(let text, _, _):
            ScrollView {
                ResponsePresentationView(text: text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 80, maxHeight: 400)

        case .failed(let presentation, let cooldownSeconds):
            failedContentView(presentation: presentation, cooldownSeconds: cooldownSeconds)
        }
    }

    private var emptyContentView: some View {
        VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
            Text("Select text in any app, then press")
                .font(.system(.body))
                .foregroundStyle(DoomTheme.textPrimary)

            HStack(spacing: DoomTheme.Spacing.xs) {
                keycapView("fn")
                keycapView("⌃")
                keycapView("⌥")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DoomTheme.Spacing.s)
    }

    private func keycapView(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(DoomTheme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DoomTheme.control)
            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DoomTheme.controlRadius)
                    .stroke(DoomTheme.steel.opacity(0.5), lineWidth: 1)
            )
    }

    private var acquiringContentView: some View {
        VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
            Text(MessageCatalog.Notices.readingSelection)
                .font(.headline)
                .foregroundStyle(DoomTheme.textPrimary)

            progressBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DoomTheme.Spacing.s)
    }

    private func requestingContentView(appName: String, characterCount: Int, isTakingLonger: Bool) -> some View {
        VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
            Text(MessageCatalog.Notices.askingGemini)
                .font(.headline)
                .foregroundStyle(DoomTheme.textPrimary)

            Text(MessageCatalog.Notices.fromAppAndCount(app: appName, count: characterCount))
                .font(.subheadline)
                .foregroundStyle(DoomTheme.textSecondary)

            progressBar

            if isTakingLonger {
                Text(MessageCatalog.Notices.takingLonger)
                    .font(.footnote)
                    .foregroundStyle(DoomTheme.textSecondary)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DoomTheme.Spacing.s)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(DoomTheme.control)
                .frame(height: 2)

            if reduceMotion {
                Rectangle()
                    .fill(DoomTheme.accent)
                    .frame(width: 80, height: 2)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(DoomTheme.accent)
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }
        }
        .frame(height: 2)
    }

    private func failedContentView(presentation: MessagePresentation, cooldownSeconds: Int?) -> some View {
        VStack(alignment: .leading, spacing: DoomTheme.Spacing.s) {
            HStack(spacing: DoomTheme.Spacing.xs) {
                Image(systemName: presentation.isWarning ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(presentation.isWarning ? DoomTheme.warning : DoomTheme.error)
                    .font(.headline)

                Text(presentation.title)
                    .font(.headline)
                    .foregroundStyle(DoomTheme.textPrimary)
            }

            Text(presentation.message)
                .font(.body)
                .foregroundStyle(DoomTheme.textSecondary)
                .lineSpacing(2)

            if let cooldown = cooldownSeconds, cooldown > 0 {
                Text("Retry in \(cooldown) s")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(DoomTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footerView: some View {
        switch state {
        case .empty:
            EmptyView()

        case .acquiring, .requesting:
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(DoomTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(DoomTheme.control)
                        .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")
            }

        case .succeeded(_, let isTruncated, let restoreSkipped):
            HStack(alignment: .center) {
                if isTruncated {
                    Text(MessageCatalog.Notices.incompleteResponse)
                        .font(.footnote)
                        .foregroundStyle(DoomTheme.textTertiary)
                } else if restoreSkipped {
                    Text(MessageCatalog.Notices.restoreSkipped)
                        .font(.footnote)
                        .foregroundStyle(DoomTheme.textTertiary)
                }

                Spacer()

                HStack(spacing: DoomTheme.Spacing.xs) {
                    Button(action: handleCopyAction) {
                        Text(isCopied ? MessageCatalog.Notices.copied : "Copy")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(DoomTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(DoomTheme.control)
                            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy response")

                    Button(action: onClose) {
                        Text("Close")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(DoomTheme.primaryButtonText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(DoomTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

        case .failed(let presentation, let cooldownSeconds):
            HStack {
                Spacer()
                HStack(spacing: DoomTheme.Spacing.xs) {
                    ForEach(presentation.actions, id: \.self) { action in
                        actionButton(for: action, cooldownSeconds: cooldownSeconds)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(for action: PanelAction, cooldownSeconds: Int?) -> some View {
        switch action {
        case .close:
            Button(action: onClose) {
                Text(action.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(DoomTheme.primaryButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(DoomTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
            }
            .buttonStyle(.plain)

        case .retry:
            let isCoolingDown = (cooldownSeconds ?? 0) > 0
            Button(action: onRetry) {
                Text(isCoolingDown ? "Retry in \(cooldownSeconds ?? 0) s" : "Retry")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(isCoolingDown ? DoomTheme.textTertiary : DoomTheme.primaryButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(isCoolingDown ? DoomTheme.control : DoomTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
            }
            .buttonStyle(.plain)
            .disabled(isCoolingDown)

        case .openSettings:
            Button(action: onOpenSettings) {
                Text(action.title)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(DoomTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(DoomTheme.control)
                    .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
            }
            .buttonStyle(.plain)

        case .reviewPrivacy:
            Button(action: onReviewPrivacy) {
                Text(action.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(DoomTheme.primaryButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(DoomTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
            }
            .buttonStyle(.plain)

        case .grantAccess:
            Button(action: onOpenSettings) {
                Text(action.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(DoomTheme.primaryButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(DoomTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DoomTheme.controlRadius))
            }
            .buttonStyle(.plain)
        }
    }

    private func handleCloseButton() {
        if isBusy {
            onCancel()
        } else {
            onClose()
        }
    }

    private func handleEscape() {
        if isBusy {
            onCancel()
        } else {
            onClose()
        }
    }

    private func handleCopyAction() {
        #if canImport(AppKit)
        if case .succeeded(let text, _, _) = state {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
        #endif
        onCopy()
        isCopied = true
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            isCopied = false
        }
    }
}
