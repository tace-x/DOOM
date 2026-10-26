import Foundation

public struct AppConfiguration: Equatable, Sendable {
    public let displayName: String
    public let bundleIdentifier: String
    public let version: String
    public let build: String

    public init(displayName: String, bundleIdentifier: String, version: String, build: String) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
    }

    public static let fallback = AppConfiguration(
        displayName: "DOOM",
        bundleIdentifier: "local.doom.unbundled",
        version: "0.0.0",
        build: "0"
    )

    public enum Key: String, Sendable {
        case displayName = "CFBundleDisplayName"
        case bundleName = "CFBundleName"
        case bundleIdentifier = "CFBundleIdentifier"
        case version = "CFBundleShortVersionString"
        case build = "CFBundleVersion"
    }

    public static func load(from info: [String: Any]) throws(ConfigurationError) -> AppConfiguration {
        // 1. Display name
        let rawDisplayName = (info[Key.displayName.rawValue] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBundleName = (info[Key.bundleName.rawValue] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedName: String
        if let rawDisplayName, !rawDisplayName.isEmpty {
            resolvedName = rawDisplayName
        } else if let rawBundleName, !rawBundleName.isEmpty {
            resolvedName = rawBundleName
        } else {
            throw .missingValue(key: Key.displayName.rawValue)
        }

        // 2. CFBundleIdentifier
        guard let rawBundleID = info[Key.bundleIdentifier.rawValue] as? String else {
            throw .missingValue(key: Key.bundleIdentifier.rawValue)
        }
        let trimmedBundleID = rawBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBundleID.isEmpty {
            throw .missingValue(key: Key.bundleIdentifier.rawValue)
        }
        let reverseDNSRegex = /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/
        guard trimmedBundleID.wholeMatch(of: reverseDNSRegex) != nil else {
            throw .invalidValue(key: Key.bundleIdentifier.rawValue, reason: .notReverseDNS)
        }

        // 3. CFBundleShortVersionString
        guard let rawVersion = info[Key.version.rawValue] as? String else {
            throw .missingValue(key: Key.version.rawValue)
        }
        let trimmedVersion = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedVersion.isEmpty {
            throw .missingValue(key: Key.version.rawValue)
        }
        let versionRegex = /^[0-9]+(\.[0-9]+){0,2}$/
        guard trimmedVersion.wholeMatch(of: versionRegex) != nil else {
            throw .invalidValue(key: Key.version.rawValue, reason: .notVersionFormat)
        }

        // 4. CFBundleVersion
        guard let rawBuild = info[Key.build.rawValue] as? String else {
            throw .missingValue(key: Key.build.rawValue)
        }
        let trimmedBuild = rawBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBuild.isEmpty {
            throw .missingValue(key: Key.build.rawValue)
        }
        guard trimmedBuild.wholeMatch(of: versionRegex) != nil else {
            throw .invalidValue(key: Key.build.rawValue, reason: .notBuildFormat)
        }

        return AppConfiguration(
            displayName: resolvedName,
            bundleIdentifier: trimmedBundleID,
            version: trimmedVersion,
            build: trimmedBuild
        )
    }
}
