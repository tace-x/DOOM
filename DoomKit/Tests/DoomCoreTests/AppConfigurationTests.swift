import Foundation
import Testing
@testable import DoomCore

struct AppConfigurationTests {
    @Test("Valid dictionary loads all four fields exactly")
    func validDictionary() throws {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM Assistant",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        let config = try AppConfiguration.load(from: dict)
        #expect(config.displayName == "DOOM Assistant")
        #expect(config.bundleIdentifier == "com.tace.doom")
        #expect(config.version == "0.1.0")
        #expect(config.build == "1")
    }

    @Test("CFBundleName is used when CFBundleDisplayName is absent")
    func fallbackToCFBundleName() throws {
        let dict: [String: Any] = [
            "CFBundleName": "DOOMFallback",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        let config = try AppConfiguration.load(from: dict)
        #expect(config.displayName == "DOOMFallback")
    }

    @Test("Whitespace is trimmed on all fields")
    func whitespaceTrimmed() throws {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "  DOOM Assistant  \n",
            "CFBundleIdentifier": "  com.tace.doom \t",
            "CFBundleShortVersionString": " 0.1.0 \n",
            "CFBundleVersion": " 42 \r\n"
        ]
        let config = try AppConfiguration.load(from: dict)
        #expect(config.displayName == "DOOM Assistant")
        #expect(config.bundleIdentifier == "com.tace.doom")
        #expect(config.version == "0.1.0")
        #expect(config.build == "42")
    }

    @Test("Missing required keys return missingValue error", arguments: [
        "CFBundleIdentifier",
        "CFBundleShortVersionString",
        "CFBundleVersion"
    ])
    func missingRequiredKeys(key: String) {
        var dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        dict.removeValue(forKey: key)

        #expect(throws: ConfigurationError.missingValue(key: key)) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Both name keys missing returns missingValue for CFBundleDisplayName")
    func missingNameKeys() {
        let dict: [String: Any] = [
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        #expect(throws: ConfigurationError.missingValue(key: "CFBundleDisplayName")) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Non-string value counts as missing")
    func nonStringValueCountsAsMissing() {
        let dict: [String: Any] = [
            "CFBundleDisplayName": 12345,
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        #expect(throws: ConfigurationError.missingValue(key: "CFBundleDisplayName")) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Invalid bundle identifiers return notReverseDNS", arguments: [
        "doom",
        "com..doom",
        "com.doom.",
        "com.do om"
    ])
    func invalidBundleIdentifiers(bundleID: String) {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": bundleID,
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        #expect(throws: ConfigurationError.invalidValue(key: "CFBundleIdentifier", reason: .notReverseDNS)) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Invalid version strings return notVersionFormat", arguments: [
        "1.2.3.4",
        "v1",
        "1.x"
    ])
    func invalidVersions(version: String) {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "1"
        ]
        #expect(throws: ConfigurationError.invalidValue(key: "CFBundleShortVersionString", reason: .notVersionFormat)) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Valid version strings are accepted", arguments: [
        "1",
        "0.1",
        "10.20.30"
    ])
    func validVersions(version: String) throws {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "1"
        ]
        let config = try AppConfiguration.load(from: dict)
        #expect(config.version == version)
    }

    @Test("Empty version after trimming counts as missing")
    func emptyVersionCountsAsMissing() {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "   \n",
            "CFBundleVersion": "1"
        ]
        #expect(throws: ConfigurationError.missingValue(key: "CFBundleShortVersionString")) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Invalid build numbers return notBuildFormat", arguments: [
        "1.2.3.4",
        "v1",
        "1.x"
    ])
    func invalidBuildNumbers(build: String) {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": build
        ]
        #expect(throws: ConfigurationError.invalidValue(key: "CFBundleVersion", reason: .notBuildFormat)) {
            try AppConfiguration.load(from: dict)
        }
    }

    @Test("Valid build numbers are accepted", arguments: [
        "1",
        "0.1",
        "10.20.30"
    ])
    func validBuildNumbers(build: String) throws {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": build
        ]
        let config = try AppConfiguration.load(from: dict)
        #expect(config.build == build)
    }

    @Test("Empty build number after trimming counts as missing")
    func emptyBuildNumberCountsAsMissing() {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "  \t"
        ]
        #expect(throws: ConfigurationError.missingValue(key: "CFBundleVersion")) {
            try AppConfiguration.load(from: dict)
        }
    }
}
