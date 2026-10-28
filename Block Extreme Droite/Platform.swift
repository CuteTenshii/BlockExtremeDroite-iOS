import Foundation

nonisolated enum Platform: String, CaseIterable, Codable, Identifiable {
    case x, instagram, facebook, tiktok, youtube

    var id: String { rawValue }

    var label: String {
        switch self {
        case .x: "X"
        case .instagram: "Instagram"
        case .facebook: "Facebook"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        }
    }

    private var hosts: Set<String> {
        switch self {
        case .x: ["x.com", "twitter.com"]
        case .instagram: ["instagram.com"]
        case .facebook: ["facebook.com"]
        case .tiktok: ["tiktok.com"]
        case .youtube: ["youtube.com"]
        }
    }

    var loginURL: URL {
        switch self {
        case .x: URL(string: "https://x.com/i/flow/login")!
        case .instagram: URL(string: "https://www.instagram.com/accounts/login/")!
        case .facebook: URL(string: "https://m.facebook.com/login/")!
        case .tiktok: URL(string: "https://www.tiktok.com/login")!
        case .youtube: URL(string: "https://accounts.google.com/ServiceLogin?service=youtube")!
        }
    }

    /// Reads a direct profile link the way the site's `identityForLink` does, so two records linking the same
    /// profile get the same `Profile.identity`. Search pages, posts and other non-profile links give nil.
    func profile(link: String) -> Profile? {
        guard let components = URLComponents(string: link.trimmingCharacters(in: .whitespaces)),
              components.scheme?.lowercased() == "https",
              let rawHost = components.host?.lowercased()
        else { return nil }
        let host = rawHost.replacing(Self.hostPrefix, with: "")
        guard hosts.contains(host) else { return nil }
        var originalPath = components.path
        while originalPath.hasSuffix("/") { originalPath.removeLast() }
        let path = originalPath.lowercased()

        switch self {
        case .x:
            var handle = String(originalPath.dropFirst())
            if handle.hasPrefix("@") { handle.removeFirst() }
            guard handle.wholeMatch(of: Self.xHandle) != nil, !Self.xReserved.contains(handle.lowercased()) else { return nil }
            return Profile(identity: identity(handle.lowercased()), url: "https://x.com/\(handle)", handle: handle)
        case .instagram:
            let username = String(path.dropFirst())
            guard username.wholeMatch(of: Self.instagramUsername) != nil, !Self.instagramReserved.contains(username) else { return nil }
            return Profile(identity: identity(username), url: "https://www.instagram.com/\(username)/", handle: username)
        case .tiktok:
            guard path.hasPrefix("/@") else { return nil }
            let username = String(path.dropFirst(2))
            guard username.wholeMatch(of: Self.tiktokUsername) != nil else { return nil }
            return Profile(identity: identity("@\(username)"), url: "https://www.tiktok.com/@\(username)", handle: username)
        case .youtube:
            if originalPath.wholeMatch(of: Self.youtubeHandle) != nil {
                return Profile(identity: identity(String(path.dropFirst())), url: "https://www.youtube.com\(originalPath)", handle: String(originalPath.dropFirst(2)))
            }
            if originalPath.wholeMatch(of: Self.youtubeChannel) != nil {
                return Profile(identity: identity(String(originalPath.dropFirst())), url: "https://www.youtube.com\(originalPath)", handle: nil)
            }
            return nil
        case .facebook:
            let numericID: String?
            if path == "/profile.php" {
                guard let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
                      id.wholeMatch(of: Self.digits) != nil else { return nil }
                numericID = id
            } else {
                numericID = path.wholeMatch(of: Self.facebookNumeric).map { String($0.1) }
            }
            if let numericID {
                return Profile(identity: "\(rawValue):id:\(numericID)", url: "https://www.facebook.com/profile.php?id=\(numericID)", handle: nil)
            }
            if path.wholeMatch(of: Self.facebookName) != nil {
                return Profile(identity: identity(String(path.dropFirst())), url: "https://www.facebook.com\(path)", handle: nil)
            }
            return nil
        }
    }

    private func identity(_ path: String) -> String { "\(rawValue):/\(path)" }

    private static let hostPrefix = #/^(www|m|mobile|fr-fr)\./#
    private static let digits = #/\d+/#
    private static let xHandle = #/[A-Za-z0-9_]{1,15}/#
    private static let xReserved: Set<String> = ["home", "explore", "search", "i", "intent", "hashtag", "settings", "messages", "notifications"]
    private static let instagramUsername = #/[a-z0-9._]{1,30}/#
    private static let instagramReserved: Set<String> = ["p", "reel", "reels", "stories", "explore", "accounts", "direct"]
    private static let tiktokUsername = #/[a-z0-9._]{2,24}/#
    private static let youtubeHandle = #/\/@[A-Za-z0-9._-]{3,30}/#
    private static let youtubeChannel = #/\/channel\/UC[A-Za-z0-9_-]{22}/#
    private static let facebookNumeric = #/\/(?:pages|people)\/[a-z0-9._%-]+\/(\d+)/#
    private static let facebookName = #/\/(?:[a-z0-9._-]{3,100}|p\/[a-z0-9._-]{3,100})/#
}

nonisolated struct Profile: Codable, Hashable {
    /// The site's key for this profile (`instagram:/marine_lepen`), shared by every record that links it.
    let identity: String
    let url: String
    /// The name shown with an `@`; nil when the link only gives a page name or a numeric id.
    let handle: String?
    var followers: Int?
}
