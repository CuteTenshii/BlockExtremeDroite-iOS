import Foundation

/// The site's collective block counter (`/api/counts`). Reports are queued on disk first so a block
/// made offline is still counted later; the server dedupes on profile + device id.
actor BlockCounter {
    static let shared = BlockCounter()

    struct Snapshot: Sendable {
        let total: Int
        let counts: [String: Int]

        func count(for account: Account, on platform: Platform) -> Int? {
            counts[BlockCounter.key(account.siteId, platform)]
        }
    }

    private let url = AccountRepository.site.appending(path: "api/counts")
    private let defaults = UserDefaults.standard
    private let queueKey = "counter.queue"
    private let deviceKey = "counter.deviceId"
    private var flushing = false

    static func key(_ siteId: String, _ platform: Platform) -> String { "\(platform.rawValue):\(siteId)" }

    /// Random UUID, the only identifier the site receives, matching what its own page sends.
    private var deviceID: String {
        if let id = defaults.string(forKey: deviceKey) { return id }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: deviceKey)
        return id
    }

    private var pending: [String] {
        get { defaults.stringArray(forKey: queueKey) ?? [] }
        set { defaults.set(newValue, forKey: queueKey) }
    }

    func fetch() async throws -> Snapshot {
        let (data, _) = try await Http.session.data(from: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let counts = object["counts"] as? [String: Int],
              let total = object["total"] as? Int
        else { throw URLError(.cannotParseResponse) }
        return Snapshot(total: total, counts: counts)
    }

    func report(_ account: Account, on platform: Platform) async {
        let key = Self.key(account.siteId, platform)
        if !pending.contains(key) { pending.append(key) }
        await flush()
    }

    /// Sends queued reports; stops at the first failure and keeps the rest for later.
    func flush() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        for key in pending {
            guard await send(key) else { break }
            pending.removeAll { $0 == key }
        }
    }

    private func send(_ key: String) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["account_id": key, "device_id": deviceID, "blocked": true])
        guard let (data, _) = try? await Http.session.data(for: request),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["ok"] as? Bool == true
    }
}
