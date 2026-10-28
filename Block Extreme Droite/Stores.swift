import Foundation

nonisolated enum BlockStatus: String {
    case pending, blocked, alreadyBlocked, unavailable, failed

    /// Failed accounts stay in the queue: retrying is safe because already-blocked profiles are detected.
    var isDone: Bool { self == .blocked || self == .alreadyBlocked || self == .unavailable }
}

/// Keyed on `Profile.identity`, so a profile listed under two records is only processed once.
struct ProgressStore {
    private let defaults = UserDefaults(suiteName: "progress")!

    func status(_ profile: Profile) -> BlockStatus {
        defaults.string(forKey: profile.identity).flatMap(BlockStatus.init(rawValue:)) ?? .pending
    }

    func set(_ profile: Profile, _ status: BlockStatus) {
        defaults.set(status.rawValue, forKey: profile.identity)
    }

    func clear(_ platform: Platform) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("\(platform.rawValue):") {
            defaults.removeObject(forKey: key)
        }
    }
}

/// `sessionCap` is nil when a session runs through the whole queue.
struct Pacing {
    var minDelay: Int
    var maxDelay: Int
    var sessionCap: Int?
}

@MainActor @Observable
final class SettingsStore {
    static let capRange = 5...200
    static let delayRange = 0...60

    var platform: Platform { didSet { defaults.set(platform.rawValue, forKey: "platform") } }
    var minDelay: Int { didSet { defaults.set(minDelay, forKey: "delayMin"); maxDelay = max(maxDelay, minDelay) } }
    var maxDelay: Int { didSet { defaults.set(maxDelay, forKey: "delayMax") } }
    var sessionCap: Int { didSet { defaults.set(sessionCap, forKey: "cap") } }
    var unlimited: Bool { didSet { defaults.set(unlimited, forKey: "unlimited") } }
    /// Stored as exclusions so categories added to the list later start out selected.
    var connectionsExpanded: Bool { didSet { defaults.set(connectionsExpanded, forKey: "connectionsExpanded") } }
    var listExpanded: Bool { didSet { defaults.set(listExpanded, forKey: "listExpanded") } }
    var showBrowser: Bool { didSet { defaults.set(showBrowser, forKey: "showBrowser") } }
    /// Stored as exclusions so categories added to the list later start out selected.
    var excludedCategories: Set<String> { didSet { defaults.set(Array(excludedCategories), forKey: "excludedCategories") } }
    var excludedSources: Set<AccountSource> { didSet { defaults.set(excludedSources.map(\.rawValue), forKey: "excludedSources") } }

    private let defaults = UserDefaults.standard

    init() {
        platform = defaults.string(forKey: "platform").flatMap(Platform.init(rawValue:)) ?? .x
        minDelay = defaults.object(forKey: "delayMin") as? Int ?? 6
        maxDelay = defaults.object(forKey: "delayMax") as? Int ?? 12
        sessionCap = defaults.object(forKey: "cap") as? Int ?? 30
        unlimited = defaults.bool(forKey: "unlimited")
        connectionsExpanded = defaults.object(forKey: "connectionsExpanded") as? Bool ?? true
        listExpanded = defaults.object(forKey: "listExpanded") as? Bool ?? true
        showBrowser = defaults.bool(forKey: "showBrowser")
        excludedCategories = Set(defaults.stringArray(forKey: "excludedCategories") ?? [])
        excludedSources = Set((defaults.stringArray(forKey: "excludedSources") ?? []).compactMap(AccountSource.init(rawValue:)))
    }

    var pacing: Pacing { Pacing(minDelay: minDelay, maxDelay: maxDelay, sessionCap: unlimited ? nil : sessionCap) }

    /// The accounts listed on the current platform, less the excluded sources and categories.
    func select(_ accounts: [Account], on platform: Platform? = nil) -> [Account] {
        let platform = platform ?? self.platform
        return accounts.filter {
            $0.profile(on: platform) != nil && !excludedSources.contains($0.source) && !excludedCategories.contains($0.category)
        }
    }
}
