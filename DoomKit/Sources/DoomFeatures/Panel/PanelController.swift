#if canImport(AppKit)
import AppKit
import SwiftUI

@MainActor
@Observable
public final class PanelController {
    public private(set) var panel: DoomPanel?
    @ObservationIgnored private var hostingView: NSHostingView<PanelView>?
    public private(set) var isVisible: Bool = false
    public private(set) var visibility: LocalOverlayVisibility = .hiddenByUser
    @ObservationIgnored private var userOrigin: CGPoint?

    public var state: PanelContentState = .empty

    public var onCancelHandler: (() -> Void)?
    public var onCloseHandler: (() -> Void)?
    public var onCopyHandler: (() -> Void)?
    public var onRetryHandler: (() -> Void)?
    public var onOpenSettingsHandler: (() -> Void)?
    public var onReviewPrivacyHandler: (() -> Void)?
    public var onPrivacyModeChange: ((Bool) -> Void)?

    public private(set) var isPrivacyModeEnabled: Bool = false
    public private(set) var hideLocallyFallbackEnabled: Bool = false

    public let assistant: AssistantController?

    public init(assistant: AssistantController? = nil) {
        self.assistant = assistant
        if let assistant = assistant {
            self.state = PanelContentState(from: assistant.phase)
            bindToAssistant(assistant)
        }
    }

    public func setPrivacyMode(_ enabled: Bool) {
        guard self.isPrivacyModeEnabled != enabled else { return }
        self.isPrivacyModeEnabled = enabled
        applyExclusionConfiguration()
        if enabled && hideLocallyFallbackEnabled && isVisible {
            hide()
        }
        onPrivacyModeChange?(enabled)
    }

    public func setHideLocallyFallback(_ enabled: Bool) {
        guard self.hideLocallyFallbackEnabled != enabled else { return }
        self.hideLocallyFallbackEnabled = enabled
        if enabled && isPrivacyModeEnabled && isVisible {
            hide()
        }
    }

    public func applyExclusionConfiguration() {
        guard let p = panel else { return }
        let targetSharingType: NSWindow.SharingType = isPrivacyModeEnabled ? .none : .readOnly
        if p.sharingType != targetSharingType {
            p.sharingType = targetSharingType
        }
    }

    public func currentExclusionConfiguration() -> CaptureExclusionConfiguration {
        guard let p = panel else {
            return CaptureExclusionConfiguration(windowRecords: [])
        }
        let isNone = p.sharingType == .none
        return CaptureExclusionConfiguration(windowRecords: [
            WindowExclusionRecord(
                windowIdentifier: "DoomPanel",
                isExclusionConfigured: isNone,
                configurationDescription: isNone ? "none" : "readOnly"
            )
        ])
    }

    public func recreatePanel() {
        let wasVisible = isVisible
        let savedFrame = panel?.frame
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        if wasVisible {
            let p = ensurePanelCreated()
            if let frame = savedFrame {
                p.setFrame(frame, display: true)
            }
            applyExclusionConfiguration()
            p.orderFrontRegardless()
            self.isVisible = true
            self.visibility = .visibleInteractive
        }
    }

    private func bindToAssistant(_ assistant: AssistantController) {
        assistant.onPhaseChange = { [weak self] newPhase in
            guard let self = self else { return }
            self.updateState(PanelContentState(from: newPhase))
            switch newPhase {
            case .succeeded, .failed:
                if !self.hideLocallyFallbackEnabled && !self.isVisible {
                    self.show(deliberateUserAction: false)
                }
            case .acquiring, .requesting, .idle:
                break
            }
        }
        assistant.onShowRequested = { [weak self] in
            guard let self = self else { return }
            self.show(deliberateUserAction: false)
        }
    }

    private func ensurePanelCreated() -> DoomPanel {
        let targetSharingType: NSWindow.SharingType = isPrivacyModeEnabled ? .none : .readOnly
        if let existing = panel {
            existing.sharingType = targetSharingType
            return existing
        }

        let defaultFrame = PanelGeometry.frame(
            contentHeight: PanelGeometry.minHeight,
            visibleFrame: currentScreenVisibleFrame()
        )

        let newPanel = DoomPanel(contentRect: defaultFrame, sharingType: targetSharingType)
        newPanel.sharingType = targetSharingType
        newPanel.onCancelOrClose = { [weak self] in
            guard let self = self else { return }
            if self.assistant?.isBusy == true {
                self.handleCancel()
            } else {
                self.handleClose()
            }
        }
        self.panel = newPanel

        let rootView = PanelView(
            state: self.state,
            privacyStatusLine: (isPrivacyModeEnabled && !hideLocallyFallbackEnabled) ? "Exclusion requested; not confirmed for your sharing method. It may appear on your shared screen." : nil,
            onChooseFallback: { [weak self] in
                self?.setHideLocallyFallback(true)
            },
            onClose: { [weak self] in self?.handleClose() },
            onCancel: { [weak self] in self?.handleCancel() },
            onCopy: { [weak self] in
                self?.assistant?.copyResponse()
                self?.onCopyHandler?()
            },
            onRetry: { [weak self] in
                self?.assistant?.retry()
                self?.onRetryHandler?()
            },
            onOpenSettings: { [weak self] in self?.onOpenSettingsHandler?() },
            onReviewPrivacy: { [weak self] in self?.onReviewPrivacyHandler?() }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]
        newPanel.contentView = hosting
        self.hostingView = hosting

        applyExclusionConfiguration()
        return newPanel
    }

    public func updateState(_ newState: PanelContentState) {
        self.state = newState
        updateHostingView()

        // VoiceOver announcements per UI_SPECIFICATION.md §8
        switch newState {
        case .acquiring:
            postAccessibilityAnnouncement("Reading selection")
        case .requesting:
            postAccessibilityAnnouncement("Asking Gemini")
        case .succeeded:
            postAccessibilityAnnouncement("Response ready")
        case .failed(let presentation, _):
            postAccessibilityAnnouncement(presentation.title)
        case .empty:
            break
        }
    }

    private func updateHostingView() {
        let rootView = PanelView(
            state: self.state,
            privacyStatusLine: (isPrivacyModeEnabled && !hideLocallyFallbackEnabled) ? "Exclusion requested; not confirmed for your sharing method. It may appear on your shared screen." : nil,
            onChooseFallback: { [weak self] in
                self?.setHideLocallyFallback(true)
            },
            onClose: { [weak self] in self?.handleClose() },
            onCancel: { [weak self] in self?.handleCancel() },
            onCopy: { [weak self] in
                self?.assistant?.copyResponse()
                self?.onCopyHandler?()
            },
            onRetry: { [weak self] in
                self?.assistant?.retry()
                self?.onRetryHandler?()
            },
            onOpenSettings: { [weak self] in self?.onOpenSettingsHandler?() },
            onReviewPrivacy: { [weak self] in self?.onReviewPrivacyHandler?() }
        )
        hostingView?.rootView = rootView

        if isPrivacyModeEnabled && hideLocallyFallbackEnabled {
            if isVisible {
                hide()
            }
            return
        }

        // If panel is already visible, adjust frame height anchored to top edge
        if isVisible, let p = panel {
            hostingView?.layoutSubtreeIfNeeded()
            let fittingHeight = hostingView?.fittingSize.height ?? PanelGeometry.minHeight
            let currentVisible = currentScreenVisibleFrame()
            let newFrame = PanelGeometry.frame(
                contentHeight: fittingHeight,
                visibleFrame: currentVisible,
                userOrigin: userOrigin ?? p.frame.origin
            )
            p.setFrame(newFrame, display: true, animate: false)
        }
        applyExclusionConfiguration()
    }

    public func show(deliberateUserAction: Bool = false) {
        if isPrivacyModeEnabled && hideLocallyFallbackEnabled && !deliberateUserAction {
            // While Privacy Mode is enabled with explicit hide fallback, auto-show is suppressed
            return
        }

        let p = ensurePanelCreated()
        applyExclusionConfiguration()

        // Calculate fitting height and target frame
        hostingView?.layoutSubtreeIfNeeded()
        let fittingHeight = hostingView?.fittingSize.height ?? PanelGeometry.minHeight
        let screenFrame = currentScreenVisibleFrame()
        let targetFrame = PanelGeometry.frame(
            contentHeight: fittingHeight,
            visibleFrame: screenFrame,
            userOrigin: userOrigin
        )

        p.setFrame(targetFrame, display: true)

        // Non-activating show: never steals focus, never makes key
        p.orderFrontRegardless()
        self.isVisible = true
        self.visibility = .visibleInteractive
    }

    public func hide() {
        guard let p = panel, isVisible else { return }
        // Save origin if dragged by user
        if p.wasMovedByUser {
            self.userOrigin = p.frame.origin
        }
        p.orderOut(nil)
        self.isVisible = false
        self.visibility = (isPrivacyModeEnabled && hideLocallyFallbackEnabled) ? .hiddenByLocalFallback : .hiddenByUser
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show(deliberateUserAction: true)
        }
    }

    public func runSelfTest(osVersion: String = "macOS") async -> VerificationStatus {
        let p = ensurePanelCreated()
        applyExclusionConfiguration()
        guard p.sharingType == .none else {
            return .selfTestFailed(api: "WindowServer", osVersion: osVersion)
        }
        return .selfTestPassed(api: "WindowServer", osVersion: osVersion)
    }

    private func handleClose() {
        hide()
        onCloseHandler?()
    }

    private func handleCancel() {
        hide()
        assistant?.cancel()
        onCancelHandler?()
    }

    private func currentScreenVisibleFrame() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        let pointerScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        return (pointerScreen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func postAccessibilityAnnouncement(_ announcement: String) {
        guard let p = panel else { return }
        NSAccessibility.post(
            element: p,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}
#endif
