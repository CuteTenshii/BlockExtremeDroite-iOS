import Foundation

/// Keeps the merged account list in app storage; it is downloaded on first launch and on each update.
nonisolated struct AccountRepository {
    static let site = URL(string: "https://onbloquelextremedroite.fun")!
    static let projectURL = URL(string: "https://github.com/CuteTenshii/BlockExtremeDroite-iOS")!

    private let listFile = URL.applicationSupportDirectory.appending(path: "accounts.json")
    private let defaults = UserDefaults.standard
    private let updatedKey = "accounts.updatedAt"

    var lastUpdated: Date? { defaults.object(forKey: updatedKey) as? Date }

    /// Returns the saved list, downloading it first when nothing usable is saved yet.
    @concurrent func load() async throws -> [Account] {
        if let data = try? Data(contentsOf: listFile), let accounts = try? JSONDecoder().decode([Account].self, from: data) {
            return accounts
        }
        return try await refresh()
    }

    /// The saved list is only replaced once the live sources combine into a valid one.
    @concurrent func refresh() async throws -> [Account] {
        async let accounts = text("accounts.js")
        async let socials = text("socials.js")
        async let directory = try? text("api/accounts")
        async let portraits = try? text("portraits.js")
        async let followers = try? text("followers.js")
        let directoryJSON = await directory
        // Without the API there are no community entries or removals; keep a saved full list rather than replace it.
        if directoryJSON == nil && FileManager.default.fileExists(atPath: listFile.path) { throw URLError(.badServerResponse) }
        let built = try AccountDirectory.build(DirectorySources(
            accountsScript: try await accounts,
            socialsScript: try await socials,
            directoryJSON: directoryJSON ?? #"{"entries":[]}"#,
            portraitsScript: await portraits,
            followersScript: await followers
        ))
        try FileManager.default.createDirectory(at: listFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(built).write(to: listFile, options: .atomic)
        defaults.set(Date(), forKey: updatedKey)
        return built
    }

    private func text(_ path: String) async throws -> String {
        let (data, response) = try await Http.session.data(from: Self.site.appending(path: path))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return String(decoding: data, as: UTF8.self)
    }
}
