import Foundation

nonisolated enum Http {
    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "BlockExtremeDroite/\(version) (iOS \(os.majorVersion).\(os.minorVersion); +\(AccountRepository.projectURL.absoluteString))"
    }()

    /// Every request to the site goes through this session so it carries the app's user agent.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent, "X-BF": "1"]
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()
}
