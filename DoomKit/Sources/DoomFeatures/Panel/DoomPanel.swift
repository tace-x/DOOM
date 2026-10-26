#if canImport(AppKit)
import AppKit

public final class DoomPanel: NSPanel {
    public var wasMovedByUser: Bool = false

    public override var canBecomeKey: Bool {
        true
    }

    public override var canBecomeMain: Bool {
        false
    }

    public override func mouseDragged(with event: NSEvent) {
        wasMovedByUser = true
        super.mouseDragged(with: event)
    }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.setAccessibilityLabel("DOOM response panel")
    }
}
#endif
