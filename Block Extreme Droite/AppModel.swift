import SwiftUI

/// State shared by every tab: the loaded list, the user's settings and the blocking runner.
@MainActor @Observable
final class AppModel {
    var settings = SettingsStore()
    let runner = BlockRunner()
    private(set) var accounts: [Account] = []
    private(set) var snapshot: BlockCounter.Snapshot?
    private(set) var loading = false
    private(set) var error: String?
    /// The network whose login page is open in the sign-in sheet.
    var loginPlatform: Platform?

    let repository = AccountRepository()
    let progress = ProgressStore()

    var selected: [Account] { settings.select(accounts) }

    var remaining: Int { pendingCount(settings.platform) }

    var categories: [String] {
        Set(accounts.filter { $0.profile(on: settings.platform) != nil }.map(\.category)).sorted()
    }

    private var onPlatform: [Account] { accounts.filter { $0.profile(on: settings.platform) != nil } }

    func count(of source: AccountSource) -> Int { onPlatform.filter { $0.source == source }.count }

    /// Follows the selected sources, as the category chips do on Android.
    func count(of category: String) -> Int {
        onPlatform.filter { !settings.excludedSources.contains($0.source) && $0.category == category }.count
    }

    func pendingCount(_ platform: Platform) -> Int {
        settings.select(accounts, on: platform).filter { account in
            account.profile(on: platform).map { !progress.status($0).isDone } ?? false
        }.count
    }

    func reload(refresh: Bool) async {
        loading = true
        error = nil
        do {
            accounts = refresh ? try await repository.refresh() : try await repository.load()
            snapshot = try? await BlockCounter.shared.fetch()
            await BlockCounter.shared.flush()
        } catch {
            self.error = String(localized: .listUnavailable(error.localizedDescription))
        }
        loading = false
    }
}
