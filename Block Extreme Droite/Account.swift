import Foundation

nonisolated enum AccountSource: String, Codable, CaseIterable {
    case curated, community

    var label: String { self == .curated ? String(localized: .sourceCurated) : String(localized: .sourceCommunity) }
}

nonisolated struct Account: Codable, Identifiable {
    /// The site's record key (`id`, else the handle, lowercased), used by its block counter.
    let siteId: String
    let name: String
    let category: String
    let reason: String
    let source: AccountSource
    /// The site's hand-picked photo (`portraits.js`), nil for accounts it has none for.
    let portraitURL: String?
    /// Keyed by `Platform.rawValue`; only platforms with a usable profile link are present.
    let profiles: [String: Profile]

    var id: String { siteId }

    func profile(on platform: Platform) -> Profile? { profiles[platform.rawValue] }

    /// The site's portrait when it picked one, else the platform's profile picture through the site's `/avatar` proxy.
    func avatarURL(on platform: Platform) -> URL? {
        if let portraitURL { return URL(string: portraitURL) }
        guard let profile = profile(on: platform) else { return nil }
        var components = URLComponents(url: AccountRepository.site.appending(path: "avatar"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "net", value: platform.rawValue), URLQueryItem(name: "u", value: profile.url)]
        return components?.url
    }

    func label(on platform: Platform) -> String {
        profile(on: platform)?.handle.map { "@\($0)" } ?? name
    }
}

nonisolated struct DirectorySources {
    let accountsScript: String
    let socialsScript: String
    let directoryJSON: String
    var portraitsScript: String?
    var followersScript: String?
}

nonisolated enum DirectoryError: Error {
    case malformed(String)
}

nonisolated enum AccountDirectory {
    static let knownCategories: Set<String> = ["RN", "Reconquête", "Politiques", "Partis & mouvements", "Médias", "Influenceurs", "Groupes", "Autres"]
    private static let fallbackCategory = "Autres"

    private final class Record {
        let key: String, name: String, category: String, reason: String, source: AccountSource
        var links: [(Platform, String)] = []

        init(key: String, name: String, category: String, reason: String, source: AccountSource) {
            self.key = key; self.name = name; self.category = category; self.reason = reason; self.source = source
        }

        func setLink(_ platform: Platform, _ link: String) {
            if let index = links.firstIndex(where: { $0.0 == platform }) { links[index].1 = link } else { links.append((platform, link)) }
        }

        func link(_ platform: Platform) -> String? { links.first { $0.0 == platform }?.1 }
    }

    /// Rebuilds the site's list: curated accounts and their `socials.js` links, then directory additions and link
    /// updates. Records sharing a profile on any platform are one person: the first record keeps its key and
    /// details, each platform takes the first usable link, and a removal of any record drops the whole group.
    static func build(_ sources: DirectorySources) throws -> [Account] {
        let curated = try literal(sources.accountsScript, open: "[", close: "]") as? [[String: Any]] ?? []
        let socials = try literal(sources.socialsScript, open: "{", close: "}") as? [String: [String: Any]] ?? [:]
        let portraits = sources.portraitsScript.flatMap { try? literal($0, open: "{", close: "}") } as? [String: [String: Any]] ?? [:]
        let followers = sources.followersScript.flatMap { try? literal($0, open: "{", close: "}") } as? [String: [String: Any]] ?? [:]
        guard let directory = try JSONSerialization.jsonObject(with: Data(sources.directoryJSON.utf8)) as? [String: Any],
              let entries = directory["entries"] as? [[String: Any]]
        else { throw DirectoryError.malformed("directory") }
        if directory["stale"] as? Bool == true { throw DirectoryError.malformed("Directory snapshot is stale") }

        var records: [Record] = []
        var byKey: [String: Record] = [:]
        for account in curated {
            let handle = account["handle"] as? String ?? ""
            let key = ((account["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? handle).lowercased()
            guard !key.isEmpty, byKey[key] == nil else { continue }
            let record = Record(
                key: key,
                name: account["name"] as? String ?? "",
                category: account["category"] as? String ?? "",
                reason: account["reason"] as? String ?? "",
                source: .curated
            )
            if !handle.trimmingCharacters(in: .whitespaces).isEmpty {
                record.setLink(.x, "https://x.com/\(handle.trimmingCharacters(in: .whitespaces))")
            }
            for (platformID, value) in socials[key] ?? [:] {
                if let platform = Platform(rawValue: platformID), let link = value as? String { record.setLink(platform, link) }
            }
            records.append(record)
            byKey[key] = record
        }

        var removed: Set<String> = []
        for entry in entries {
            let type = entry["type"] as? String ?? ""
            let targetID = (entry["target_id"] as? String)?.lowercased()
            if type == "removal" {
                if let targetID { removed.insert(targetID) }
                continue
            }
            let key = (type == "new" ? (entry["id"] as? String)?.lowercased() : targetID) ?? ""
            guard !key.isEmpty else { continue }
            let record: Record
            if let existing = byKey[key] {
                record = existing
            } else if type == "new" {
                let category = entry["category"] as? String ?? ""
                record = Record(
                    key: key,
                    name: entry["name"] as? String ?? "",
                    category: knownCategories.contains(category) ? category : fallbackCategory,
                    reason: entry["reason"] as? String ?? "",
                    source: .community
                )
                records.append(record)
                byKey[key] = record
            } else {
                continue
            }
            if let platform = (entry["platform"] as? String).flatMap(Platform.init(rawValue:)),
               let link = entry["profile_url"] as? String, !link.trimmingCharacters(in: .whitespaces).isEmpty {
                record.setLink(platform, link)
            }
        }

        var accounts: [Account] = []
        for group in identityGroups(records) where !group.contains(where: { removed.contains($0.key) }) {
            var profiles: [String: Profile] = [:]
            for platform in Platform.allCases {
                guard var profile = group.lazy.compactMap({ $0.link(platform).flatMap(platform.profile(link:)) }).first else { continue }
                if let count = followers[profile.identity]?["count"] as? Int, count >= 0 { profile.followers = count }
                profiles[platform.rawValue] = profile
            }
            guard let first = group.first, !profiles.isEmpty else { continue }
            let fallbackName = profiles.values.lazy.compactMap(\.handle).first ?? first.key
            let name = first.name.trimmingCharacters(in: .whitespacesAndNewlines)
            accounts.append(Account(
                siteId: first.key,
                name: name.isEmpty ? fallbackName : name,
                category: first.category.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: first.reason.trimmingCharacters(in: .whitespacesAndNewlines),
                source: first.source,
                portraitURL: (portraits[first.key]?["url"] as? String)?.trimmingCharacters(in: .whitespaces).nilIfNotHTTPS,
                profiles: profiles
            ))
        }
        guard !accounts.isEmpty else { throw DirectoryError.malformed("Account list is empty") }
        return accounts
    }

    /// Unites records that link the same profile; groups and their members keep the records' order.
    private static func identityGroups(_ records: [Record]) -> [[Record]] {
        var parents = Array(records.indices)
        func find(_ index: Int) -> Int {
            var i = index
            while parents[i] != i {
                parents[i] = parents[parents[i]]
                i = parents[i]
            }
            return i
        }
        var seen: [String: Int] = [:]
        for (index, record) in records.enumerated() {
            for (platform, link) in record.links {
                guard let identity = platform.profile(link: link)?.identity else { continue }
                guard let other = seen[identity] else { seen[identity] = index; continue }
                let (a, b) = (find(index), find(other))
                if a != b { parents[max(a, b)] = min(a, b) }
            }
        }
        var groups: [Int: [Record]] = [:]
        var order: [Int] = []
        for index in records.indices {
            let root = find(index)
            if groups[root] == nil { order.append(root) }
            groups[root, default: []].append(records[index])
        }
        return order.compactMap { groups[$0] }
    }

    /// Parses the JSON literal in a `const name = [...];` or `{...}` script, skipping any leading comments.
    private static func literal(_ script: String, open: Character, close: Character) throws -> Any {
        guard let equals = script.firstIndex(of: "="),
              let start = script[equals...].firstIndex(of: open),
              let end = script.lastIndex(of: close), start < end
        else { throw DirectoryError.malformed("No JSON literal found") }
        return try JSONSerialization.jsonObject(with: Data(script[start...end].utf8))
    }
}

private nonisolated extension String {
    var nilIfNotHTTPS: String? { hasPrefix("https://") ? self : nil }
}
