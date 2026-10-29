import AppKit
import SwiftUI
import DoomCore
import DoomFeatures

@MainActor
func inspectPanel() {
    let controller = PanelController()
    controller.setPrivacyMode(true)
    controller.show()
    guard let panel = controller.panel else {
        print("Panel is nil!")
        return
    }
    print("DoomPanel:")
    print("  windowNumber: \(panel.windowNumber)")
    print("  sharingType: \(panel.sharingType.rawValue) (0=none, 1=readOnly, 2=readWrite)")
    print("  level: \(panel.level.rawValue)")
    print("  isOpaque: \(panel.isOpaque)")
    print("  backgroundColor: \(String(describing: panel.backgroundColor))")
    print("  childWindows count: \(panel.childWindows?.count ?? 0)")
    if let children = panel.childWindows {
        for (i, c) in children.enumerated() {
            print("    child [\(i)]: windowNumber=\(c.windowNumber), sharingType=\(c.sharingType.rawValue)")
        }
    }
    print("  parentWindow: \(String(describing: panel.parent))")
    print("  contentView: \(String(describing: panel.contentView))")
    print("  subviews count: \(panel.contentView?.subviews.count ?? 0)")

    print("\nAll NSApp.windows:")
    for (i, w) in NSApp.windows.enumerated() {
        print("  [\(i)]: '\(w.title)', class=\(type(of: w)), windowNumber=\(w.windowNumber), sharingType=\(w.sharingType.rawValue), isVisible=\(w.isVisible)")
    }
}

MainActor.assumeIsolated {
    inspectPanel()
}
