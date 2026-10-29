#if canImport(AppKit)
import AppKit

public final class DoomPanel: NSPanel {
    public var wasMovedByUser: Bool = false
    public var onCancelOrClose: (() -> Void)?

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

    public override func cancelOperation(_ sender: Any?) {
        if let onCancelOrClose = onCancelOrClose {
            onCancelOrClose()
        } else {
            super.cancelOperation(sender)
        }
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle ⌘W when panel is key (UI_SPECIFICATION.md §3.7)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            if let onCancelOrClose = onCancelOrClose {
                onCancelOrClose()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    public init(contentRect: NSRect, sharingType: NSWindow.SharingType = .readOnly) {
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
        self.sharingType = sharingType
        self.setAccessibilityLabel("DOOM response panel")
    }

    public override var sharingType: NSWindow.SharingType {
        get {
            super.sharingType
        }
        set {
            if super.sharingType != newValue {
                super.sharingType = newValue
            }
        }
    }
}
#endif
