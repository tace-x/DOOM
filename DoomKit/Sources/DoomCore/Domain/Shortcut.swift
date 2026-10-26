import Foundation

public enum ActivationOrigin: Equatable, Sendable {
    case chord
    case menu
}

public enum ShortcutEvent: Equatable, Sendable {
    case activate(origin: ActivationOrigin)
    case togglePanel
}

public enum ActivationShortcutState: Equatable, Sendable {
    case active
    case needsAccessibility
    case unverified
}

public typealias ActivationStatus = ActivationShortcutState

public enum PanelShortcutState: Equatable, Sendable {
    case available
    case unavailable(status: Int32)

    public static var active: PanelShortcutState { .available }
}

public typealias PanelToggleStatus = PanelShortcutState

public struct ShortcutStatus: Equatable, Sendable {
    public let activation: ActivationShortcutState
    public let panelToggle: PanelShortcutState

    public init(activation: ActivationShortcutState, panelToggle: PanelShortcutState) {
        self.activation = activation
        self.panelToggle = panelToggle
    }
}

