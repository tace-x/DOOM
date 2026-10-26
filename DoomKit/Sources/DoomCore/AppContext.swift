import Foundation

public struct AppContext: Sendable {
    public let configuration: AppConfiguration
    public let configurationIssue: ConfigurationError?
    public let launchOptions: LaunchOptions

    public init(
        configuration: AppConfiguration,
        configurationIssue: ConfigurationError? = nil,
        launchOptions: LaunchOptions
    ) {
        self.configuration = configuration
        self.configurationIssue = configurationIssue
        self.launchOptions = launchOptions
    }

    public static func make(infoDictionary: [String: Any], arguments: [String]) -> AppContext {
        let options = LaunchOptions(arguments: arguments)
        do {
            let config = try AppConfiguration.load(from: infoDictionary)
            return AppContext(
                configuration: config,
                configurationIssue: nil,
                launchOptions: options
            )
        } catch {
            return AppContext(
                configuration: .fallback,
                configurationIssue: error,
                launchOptions: options
            )
        }
    }
}
