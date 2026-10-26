#if canImport(AppKit)
import AppKit
import SwiftUI

@MainActor
@Observable
public final class PanelController {
    public private(set) var panel: DoomPanel?
    @ObservationIgnored private var hostingView: NSHostingView<PanelView>?
    public private(set) var isVisible: Bool = false
    @ObservationIgnored private var userOrigin: CGPoint?

    public var state: PanelContentState = .empty

    public var onCancelHandler: (() -> Void)?
    public var onCloseHandler: (() -> Void)?
    public var onCopyHandler: (() -> Void)?
    public var onRetryHandler: (() -> Void)?
    public var onOpenSettingsHandler: (() -> Void)?
    public var onReviewPrivacyHandler: (() -> Void)?

    public init() {
        // Created on demand or at setup
    }

    private func ensurePanelCreated() -> DoomPanel {
        if let existing = panel {
            return existing
        }

        let defaultFrame = PanelGeometry.frame(
            contentHeight: PanelGeometry.minHeight,
            visibleFrame: currentScreenVisibleFrame()
        )

        let newPanel = DoomPanel(contentRect: defaultFrame)
        self.panel = newPanel

        let rootView = PanelView(
            state: self.state,
            onClose: { [weak self] in self?.handleClose() },
            onCancel: { [weak self] in self?.handleCancel() },
            onCopy: { [weak self] in self?.onCopyHandler?() },
            onRetry: { [weak self] in self?.onRetryHandler?() },
            onOpenSettings: { [weak self] in self?.onOpenSettingsHandler?() },
            onReviewPrivacy: { [weak self] in self?.onReviewPrivacyHandler?() }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]
        newPanel.contentView = hosting
        self.hostingView = hosting

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
            onClose: { [weak self] in self?.handleClose() },
            onCancel: { [weak self] in self?.handleCancel() },
            onCopy: { [weak self] in self?.onCopyHandler?() },
            onRetry: { [weak self] in self?.onRetryHandler?() },
            onOpenSettings: { [weak self] in self?.onOpenSettingsHandler?() },
            onReviewPrivacy: { [weak self] in self?.onReviewPrivacyHandler?() }
        )
        hostingView?.rootView = rootView

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
    }

    public func show() {
        let p = ensurePanelCreated()

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
    }

    public func hide() {
        guard let p = panel, isVisible else { return }
        // Save origin if dragged by user
        if p.wasMovedByUser {
            self.userOrigin = p.frame.origin
        }
        p.orderOut(nil)
        self.isVisible = false
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func handleClose() {
        hide()
        onCloseHandler?()
    }

    private func handleCancel() {
        hide()
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
