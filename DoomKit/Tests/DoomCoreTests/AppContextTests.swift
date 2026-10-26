import Foundation
import Testing
@testable import DoomCore

struct AppContextTests {
    @Test("Valid dictionary and arguments give loaded configuration, no issue, and parsed options")
    func validDictionaryWithSmokeFlag() {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "1"
        ]
        let args = ["/path/to/DOOM", "--doom-smoke-test"]
        let context = AppContext.make(infoDictionary: dict, arguments: args)

        #expect(context.configuration.displayName == "DOOM")
        #expect(context.configuration.bundleIdentifier == "com.tace.doom")
        #expect(context.configuration.version == "0.1.0")
        #expect(context.configuration.build == "1")
        #expect(context.configurationIssue == nil)
        #expect(context.launchOptions.isSmokeTest == true)
    }

    @Test("Empty dictionary substitutes fallback configuration and records issue without crashing")
    func emptyDictionaryUsesFallback() {
        let context = AppContext.make(infoDictionary: [:], arguments: ["/path/to/DOOM"])

        #expect(context.configuration == AppConfiguration.fallback)
        #expect(context.configurationIssue != nil)
        #expect(context.configurationIssue == ConfigurationError.missingValue(key: "CFBundleDisplayName"))
        #expect(context.launchOptions.isSmokeTest == false)
    }

    @Test("make is deterministic: identical inputs yield equal results")
    func makeIsDeterministic() {
        let dict: [String: Any] = [
            "CFBundleDisplayName": "DOOM Deterministic",
            "CFBundleIdentifier": "com.tace.doom",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "100"
        ]
        let args = ["DOOM", "--doom-smoke-test", "-flag"]
        let first = AppContext.make(infoDictionary: dict, arguments: args)
        let second = AppContext.make(infoDictionary: dict, arguments: args)

        #expect(first.configuration == second.configuration)
        #expect(first.configurationIssue == second.configurationIssue)
        #expect(first.launchOptions == second.launchOptions)
    }
}
