import Foundation

public enum MenuStatusFormatter {
    public static func statusText(
        phase: AssistantController.Phase,
        isPanelVisible: Bool,
        isPrivacyModeEnabled: Bool,
        fallbackText: String
    ) -> String {
        switch phase {
        case .acquiring, .requesting:
            if isPrivacyModeEnabled {
                return "Privacy Mode: Working…"
            }
            return "Working…"
        case .succeeded:
            if !isPanelVisible {
                if isPrivacyModeEnabled {
                    return "Privacy Mode: Response ready"
                }
                return "Response ready"
            }
            return fallbackText
        default:
            return fallbackText
        }
    }
}
