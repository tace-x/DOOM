import Foundation
import Testing
@testable import DoomCore

struct LaunchOptionsTests {
    @Test("argv[0] only gives false")
    func argv0OnlyGivesFalse() {
        let options = LaunchOptions(arguments: ["/path/to/DOOM"])
        #expect(options.isSmokeTest == false)
    }

    @Test("Smoke test flag present in arguments gives true")
    func smokeTestFlagPresent() {
        let options = LaunchOptions(arguments: ["/path/to/DOOM", "--doom-smoke-test"])
        #expect(options.isSmokeTest == true)
    }

    @Test("Smoke test flag only as argv[0] gives false")
    func smokeTestFlagAsArgv0() {
        let options = LaunchOptions(arguments: ["--doom-smoke-test"])
        #expect(options.isSmokeTest == false)
    }

    @Test("Unknown arguments are ignored")
    func unknownArgumentsIgnored() {
        let options = LaunchOptions(arguments: [
            "/path/to/DOOM",
            "-NSDocumentRevisionsDebugMode",
            "YES",
            "--some-other-flag",
            "--doom-smoke-test"
        ])
        #expect(options.isSmokeTest == true)

        let optionsWithoutFlag = LaunchOptions(arguments: [
            "/path/to/DOOM",
            "-NSDocumentRevisionsDebugMode",
            "YES",
            "--some-other-flag"
        ])
        #expect(optionsWithoutFlag.isSmokeTest == false)
    }
}
