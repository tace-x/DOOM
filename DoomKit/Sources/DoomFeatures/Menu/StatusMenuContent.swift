import SwiftUI

public struct StatusMenuContent: View {
    public let statusText: String
    public let isPanelVisible: Bool
    public let canAskSelection: Bool
    public let onAskSelection: () -> Void
    public let onTogglePanel: () -> Void
    public let onOpenMainWindow: () -> Void
    public let onQuit: () -> Void

    public init(
        statusText: String,
        isPanelVisible: Bool,
        canAskSelection: Bool = false,
        onAskSelection: @escaping () -> Void = {},
        onTogglePanel: @escaping () -> Void = {},
        onOpenMainWindow: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.statusText = statusText
        self.isPanelVisible = isPanelVisible
        self.canAskSelection = canAskSelection
        self.onAskSelection = onAskSelection
        self.onTogglePanel = onTogglePanel
        self.onOpenMainWindow = onOpenMainWindow
        self.onQuit = onQuit
    }

    public var body: some View {
        Group {
            // Status line (disabled item)
            Button(statusText) {}
                .disabled(true)

            Divider()

            Button("Ask DOOM About Selection") {
                onAskSelection()
            }
            .disabled(!canAskSelection)

            Button(isPanelVisible ? "Hide Panel" : "Show Panel") {
                onTogglePanel()
            }

            Divider()

            Button("Open DOOM…") {
                onOpenMainWindow()
            }

            Button("Quit DOOM") {
                onQuit()
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
