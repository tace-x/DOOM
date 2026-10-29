import SwiftUI
import DoomCore
import DoomFeatures

@main
struct DOOMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("DOOM", id: "main") {
            MainWindowView(model: appDelegate.mainWindowModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 640)

        MenuBarExtra {
            StatusMenuContent(
                statusText: appDelegate.menuStatusText,
                isPanelVisible: appDelegate.isPanelVisible,
                isPrivacyModeEnabled: appDelegate.panelController.isPrivacyModeEnabled,
                canAskSelection: false,
                onAskSelection: { appDelegate.handleAskSelection() },
                onTogglePanel: { appDelegate.togglePanel() },
                onOpenMainWindow: {
                    openWindow(id: "main")
                    appDelegate.openMainWindow()
                },
                onQuit: { appDelegate.quit() }
            )
            .task {
                appDelegate.openWindowAction = { [openWindow] in
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
        } label: {
            Image(systemName: "hexagon")
                .accessibilityLabel("DOOM")
        }
    }
}
