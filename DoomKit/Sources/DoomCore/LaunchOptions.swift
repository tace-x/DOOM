import Foundation

public struct LaunchOptions: Equatable, Sendable {
    public static let smokeTestFlag = "--doom-smoke-test"
    public static let diagnoseFlag = "--doom-diagnose"

    public let isSmokeTest: Bool
    public let isDiagnose: Bool

    public init(arguments: [String]) {
        guard arguments.count > 1 else {
            self.isSmokeTest = false
            self.isDiagnose = false
            return
        }
        let rest = arguments.dropFirst()
        self.isSmokeTest = rest.contains(Self.smokeTestFlag)
        self.isDiagnose = rest.contains(Self.diagnoseFlag)
    }
}
