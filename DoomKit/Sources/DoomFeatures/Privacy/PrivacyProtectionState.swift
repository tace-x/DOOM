import Foundation

public enum LocalOverlayVisibility: String, Equatable, Sendable {
    case visibleInteractive
    case hiddenByUser
    case hiddenByLocalFallback
}

public enum SharingContext: String, CaseIterable, Sendable, Identifiable {
    case entireScreen = "Entire screen"
    case singleWindow = "A single window"
    case separateDisplay = "Separate display"
    case notSure = "Not sure"

    public var id: String { rawValue }
}

public struct WindowExclusionRecord: Equatable, Sendable {
    public let windowIdentifier: String
    public let isExclusionConfigured: Bool
    public let configurationDescription: String

    public init(windowIdentifier: String, isExclusionConfigured: Bool, configurationDescription: String = "") {
        self.windowIdentifier = windowIdentifier
        self.isExclusionConfigured = isExclusionConfigured
        self.configurationDescription = configurationDescription
    }
}

public struct CaptureExclusionConfiguration: Equatable, Sendable {
    public var windowRecords: [WindowExclusionRecord]

    public var allWindowsConfigured: Bool {
        !windowRecords.isEmpty && windowRecords.allSatisfy { $0.isExclusionConfigured }
    }

    public init(windowRecords: [WindowExclusionRecord] = []) {
        self.windowRecords = windowRecords
    }
}

public enum FallbackMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case none = "None"
    case localHideWhileSharing = "Hide overlay locally while sharing"
    case shareDifferentWindow = "Share a single application window instead"
    case separateDisplay = "Move DOOM to an unshared display"

    public var id: String { rawValue }
}

public struct UserConfirmationRecord: Equatable, Sendable {
    public let method: String
    public let osBuild: String
    public let browserVersion: String
    public let date: String

    public init(method: String, osBuild: String, browserVersion: String, date: String) {
        self.method = method
        self.osBuild = osBuild
        self.browserVersion = browserVersion
        self.date = date
    }

    public func isValid(currentOS: String?, currentBrowser: String?) -> Bool {
        if let currentOS = currentOS, currentOS != self.osBuild {
            return false
        }
        if let currentBrowser = currentBrowser, currentBrowser != self.browserVersion {
            return false
        }
        return true
    }
}

public enum SelfTestResult: Equatable, Sendable {
    case passed(api: String, osBuild: String)
    case failed(api: String, osBuild: String)
}

public enum VerificationStatus: Equatable, Sendable {
    case notVerified
    case selfTestPassed(api: String, osVersion: String)
    case selfTestFailed(api: String, osVersion: String)
    case unavailable(reason: String)
}

public enum ProtectionStatus: Equatable, Sendable {
    case notRequested
    case requestedUnverified(method: String)
    case knownNotEffective(method: String, evidence: String)
    case selfTestPassed(api: String, osBuild: String)
    case selfTestFailed(api: String, osBuild: String)
    case userConfirmed(method: String, osBuild: String, browserVersion: String, date: String)
    case unavailable(reason: String)
}

public struct PrivacyProtectionState: Equatable, Sendable {
    public var requested: Bool
    public var exclusionConfiguration: CaptureExclusionConfiguration
    public var sharingContext: SharingContext
    public var fallbackMode: FallbackMode
    public var userConfirmationRecord: UserConfirmationRecord?
    public var selfTestResult: SelfTestResult?

    public init(
        requested: Bool = false,
        windowExclusionApplied: Bool = false,
        exclusionConfiguration: CaptureExclusionConfiguration? = nil,
        sharingContext: SharingContext = .notSure,
        verification: VerificationStatus = .notVerified,
        hideLocallyFallbackEnabled: Bool = false,
        fallbackMode: FallbackMode = .none,
        userConfirmationRecord: UserConfirmationRecord? = nil,
        selfTestResult: SelfTestResult? = nil
    ) {
        self.requested = requested
        if let config = exclusionConfiguration {
            self.exclusionConfiguration = config
        } else if windowExclusionApplied {
            self.exclusionConfiguration = CaptureExclusionConfiguration(windowRecords: [
                WindowExclusionRecord(windowIdentifier: "DoomPanel", isExclusionConfigured: true, configurationDescription: "none")
            ])
        } else {
            self.exclusionConfiguration = CaptureExclusionConfiguration(windowRecords: [])
        }
        self.sharingContext = sharingContext
        if fallbackMode != .none {
            self.fallbackMode = fallbackMode
        } else {
            self.fallbackMode = hideLocallyFallbackEnabled ? .localHideWhileSharing : .none
        }
        self.userConfirmationRecord = userConfirmationRecord
        if let test = selfTestResult {
            self.selfTestResult = test
        } else {
            switch verification {
            case .selfTestPassed(let api, let osVersion):
                self.selfTestResult = .passed(api: api, osBuild: osVersion)
            case .selfTestFailed(let api, let osVersion):
                self.selfTestResult = .failed(api: api, osBuild: osVersion)
            case .notVerified, .unavailable:
                self.selfTestResult = nil
            }
        }
    }

    public var windowExclusionApplied: Bool {
        get { exclusionConfiguration.allWindowsConfigured }
        set {
            if newValue {
                exclusionConfiguration = CaptureExclusionConfiguration(windowRecords: [
                    WindowExclusionRecord(windowIdentifier: "DoomPanel", isExclusionConfigured: true, configurationDescription: "none")
                ])
            } else {
                exclusionConfiguration = CaptureExclusionConfiguration(windowRecords: [])
            }
        }
    }

    public var hideLocallyFallbackEnabled: Bool {
        get { fallbackMode == .localHideWhileSharing }
        set { fallbackMode = newValue ? .localHideWhileSharing : .none }
    }

    public var verification: VerificationStatus {
        get {
            guard let test = selfTestResult else { return .notVerified }
            switch test {
            case .passed(let api, let osBuild):
                return .selfTestPassed(api: api, osVersion: osBuild)
            case .failed(let api, let osBuild):
                return .selfTestFailed(api: api, osVersion: osBuild)
            }
        }
        set {
            switch newValue {
            case .selfTestPassed(let api, let osVersion):
                self.selfTestResult = .passed(api: api, osBuild: osVersion)
            case .selfTestFailed(let api, let osVersion):
                self.selfTestResult = .failed(api: api, osBuild: osVersion)
            case .notVerified, .unavailable:
                self.selfTestResult = nil
            }
        }
    }

    public func computeProtectionStatus(currentOSBuild: String? = nil, currentBrowserVersion: String? = nil) -> ProtectionStatus {
        guard requested else {
            return .notRequested
        }
        guard exclusionConfiguration.allWindowsConfigured else {
            return .unavailable(reason: "Exclusion setting not configured on all overlay windows")
        }

        // Check user confirmation first, if recorded and still valid for current OS build and browser version
        if let confirmed = userConfirmationRecord {
            if confirmed.isValid(currentOS: currentOSBuild, currentBrowser: currentBrowserVersion) {
                return .userConfirmed(
                    method: confirmed.method,
                    osBuild: confirmed.osBuild,
                    browserVersion: confirmed.browserVersion,
                    date: confirmed.date
                )
            }
        }

        // Static capability table lookup based on empirical evidence
        switch sharingContext {
        case .entireScreen:
            // OBSERVED: Google Meet in Chrome on macOS 27 composites the full display framebuffer,
            // bypassing window exclusion.
            return .knownNotEffective(
                method: "Entire screen (Chrome / Google Meet)",
                evidence: "macOS display capture composites display framebuffer on macOS 27, bypassing window exclusion."
            )
        case .notSure:
            return .requestedUnverified(method: "Unspecified sharing method")
        case .singleWindow:
            if let test = selfTestResult {
                switch test {
                case .passed(let api, let osBuild):
                    return .selfTestPassed(api: api, osBuild: osBuild)
                case .failed(let api, let osBuild):
                    return .selfTestFailed(api: api, osBuild: osBuild)
                }
            }
            return .requestedUnverified(method: "A single window")
        case .separateDisplay:
            return .requestedUnverified(method: "Separate display")
        }
    }

    public var protectionStatus: ProtectionStatus {
        computeProtectionStatus()
    }

    public var statusDescription: String {
        guard requested else {
            return "Privacy Mode is off."
        }
        guard exclusionConfiguration.allWindowsConfigured else {
            return "Exclusion requested, but window property is not applied."
        }

        switch protectionStatus {
        case .notRequested:
            return "Privacy Mode is off."
        case .knownNotEffective:
            return "Exclusion requested, but not effective for entire-screen sharing in Google Meet/Chrome on macOS 27. DOOM may appear on your shared screen. To keep DOOM private, share a single window or enable the local-hide fallback."
        case .requestedUnverified(let method):
            return "Exclusion requested; not confirmed for \(method). It may appear on your shared screen."
        case .selfTestPassed(let api, let osBuild):
            return "Exclusion requested. Local self-test passed under \(api) on macOS \(osBuild), but does not verify third-party WebRTC capture."
        case .selfTestFailed(let api, let osBuild):
            return "Exclusion setting failed under \(api) on macOS \(osBuild). It may appear on your shared screen."
        case .userConfirmed(let method, let osBuild, let browserVersion, _):
            return "User confirmed excluded for \(method) on macOS \(osBuild) with Chrome \(browserVersion)."
        case .unavailable(let reason):
            return "Exclusion unavailable: \(reason)."
        }
    }

    public var overlayStatusLine: String? {
        guard requested && fallbackMode != .localHideWhileSharing else { return nil }
        switch protectionStatus {
        case .knownNotEffective:
            return "Exclusion requested; not confirmed for your sharing method. It may appear on your shared screen."
        case .requestedUnverified:
            return "Exclusion requested; not confirmed for your sharing method. It may appear on your shared screen."
        case .selfTestFailed:
            return "Exclusion setting failed. It may appear on your shared screen."
        default:
            return nil
        }
    }

    public var isVerifiedProtected: Bool {
        guard requested && exclusionConfiguration.allWindowsConfigured else { return false }
        switch protectionStatus {
        case .userConfirmed:
            return true
        case .knownNotEffective, .requestedUnverified, .notRequested, .unavailable, .selfTestFailed, .selfTestPassed:
            return false
        }
    }
}
