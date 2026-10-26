import Foundation
#if canImport(AppKit)
import AppKit
#endif

public struct ModifierSnapshot: Sendable, Equatable {
    public let function: Bool
    public let control: Bool
    public let option: Bool
    public let command: Bool
    public let shift: Bool

    public init(
        function: Bool = false,
        control: Bool = false,
        option: Bool = false,
        command: Bool = false,
        shift: Bool = false
    ) {
        self.function = function
        self.control = control
        self.option = option
        self.command = command
        self.shift = shift
    }

    #if canImport(AppKit)
    public init(flags: NSEvent.ModifierFlags) {
        self.function = flags.contains(.function)
        self.control = flags.contains(.control)
        self.option = flags.contains(.option)
        self.command = flags.contains(.command)
        self.shift = flags.contains(.shift)
    }
    #endif

    public var isChordSubset: Bool {
        function && control && option
    }

    public var hasExcluded: Bool {
        command || shift
    }

    public var hasAnyChord: Bool {
        function || control || option
    }

    public var hasAnyRelevant: Bool {
        function || control || option || command || shift
    }
}

public struct ChordRecognizer: Sendable {
    public enum State: Sendable, Equatable {
        case idle
        case armed(t0: TimeInterval)
        case cancelled
    }

    public enum EventKind: Sendable, Equatable {
        case flagsChanged(ModifierSnapshot)
        case keyDown
    }

    public private(set) var state: State = .idle
    public static let maxHoldDuration: TimeInterval = 2.0

    public init() {}

    public mutating func handle(event: EventKind, timestamp: TimeInterval) -> Bool {
        switch state {
        case .idle:
            switch event {
            case .flagsChanged(let snapshot):
                if snapshot.isChordSubset && !snapshot.hasExcluded {
                    state = .armed(t0: timestamp)
                }
            case .keyDown:
                break
            }
            return false

        case .armed(let t0):
            switch event {
            case .keyDown:
                state = .cancelled
                return false

            case .flagsChanged(let snapshot):
                if snapshot.hasExcluded {
                    state = .cancelled
                    return false
                }

                if !snapshot.hasAnyChord {
                    // All three chord keys released
                    let elapsed = timestamp - t0
                    state = .idle
                    if elapsed <= Self.maxHoldDuration && elapsed >= 0 {
                        return true
                    }
                    return false
                }

                // Partial release or re-press of an F key while others remain down: stay armed
                return false
            }

        case .cancelled:
            switch event {
            case .keyDown:
                break
            case .flagsChanged(let snapshot):
                if !snapshot.hasAnyRelevant {
                    state = .idle
                }
            }
            return false
        }
    }

    public mutating func reset() {
        state = .idle
    }
}
