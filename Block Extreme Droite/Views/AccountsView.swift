import SwiftUI

/// The selected accounts and their status on the chosen platform. Its filters only narrow what is shown here;
/// a blocking run still covers the whole selection.
struct AccountsView: View {
    let accounts: [Account]
    let platform: Platform
    let snapshot: BlockCounter.Snapshot?

    private enum Sort: CaseIterable {
        case site, blocks, followers

        var label: LocalizedStringResource {
            switch self {
            case .site: .sortSite
            case .blocks: .sortBlocks
            case .followers: .sortFollowers
            }
        }
    }

    private struct Row: Identifiable {
        let account: Account
        let profile: Profile
        let status: BlockStatus
        let blockCount: Int?
        var id: String { account.siteId }
    }

    private static let followerSteps = [10_000, 100_000, 1_000_000, 10_000_000]
    private static let blockSteps = [10, 100, 1_000, 10_000, 25_000, 50_000]

    @State private var category: String?
    @State private var minFollowers = 0
    @State private var minBlocks = 0
    @State private var sort = Sort.site
    @Environment(\.openURL) private var openURL

    private var rows: [Row] {
        let progress = ProgressStore()
        return accounts.compactMap { account in
            account.profile(on: platform).map {
                Row(account: account, profile: $0, status: progress.status($0), blockCount: snapshot?.count(for: account, on: platform))
            }
        }
    }

    private var shown: [Row] {
        let filtered = rows.filter {
            (category == nil || $0.account.category == category) &&
                ($0.profile.followers ?? 0) >= minFollowers && ($0.blockCount ?? 0) >= minBlocks
        }
        return switch sort {
        case .site: filtered
        case .blocks: filtered.sorted { ($0.blockCount ?? -1) > ($1.blockCount ?? -1) }
        case .followers: filtered.sorted { ($0.profile.followers ?? -1) > ($1.profile.followers ?? -1) }
        }
    }

    private var categories: [String] {
        Dictionary(grouping: accounts, by: \.category).sorted { $0.value.count > $1.value.count }.map(\.key)
    }

    var body: some View {
        let all = rows
        let visible = shown
        List {
            if !all.isEmpty {
                Section {
                    Text(.accountsSummary(
                        all.filter { !$0.status.isDone }.count,
                        all.filter { $0.status == .blocked || $0.status == .alreadyBlocked }.count,
                        all.filter { $0.status == .unavailable }.count
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(.accountsHint(platform.label))
                }
            }
            ForEach(visible) { row in
                Button { if let url = URL(string: row.profile.url) { openURL(url) } } label: { AccountRow(row: row) }
                    .buttonStyle(.plain)
            }
        }
        .overlay {
            if all.isEmpty {
                ContentUnavailableView(String(localized: .accountsEmpty), systemImage: "person.slash")
            } else if visible.isEmpty {
                ContentUnavailableView(String(localized: .accountsFilteredEmpty), systemImage: "line.3.horizontal.decrease")
            }
        }
        .navigationTitle(.accountsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu(.filtersTitle, systemImage: "line.3.horizontal.decrease.circle") {
                    Menu(.filtersCategory) {
                        Picker(.filtersCategory, selection: $category) {
                            Text(.filtersAllCategories).tag(String?.none)
                            ForEach(categories, id: \.self) { Text($0).tag(String?.some($0)) }
                        }
                    }
                    Menu(.filtersFollowers) {
                        Picker(.filtersFollowers, selection: $minFollowers) {
                            Text(.filtersAny).tag(0)
                            ForEach(Self.followerSteps, id: \.self) { Text(.filtersOver($0.formatted(.number.notation(.compactName)))).tag($0) }
                        }
                    }
                    Menu(.filtersBlocks) {
                        Picker(.filtersBlocks, selection: $minBlocks) {
                            Text(.filtersAny).tag(0)
                            ForEach(Self.blockSteps, id: \.self) { Text(.filtersOver($0.formatted())).tag($0) }
                        }
                    }
                    Menu(.filtersSort) {
                        Picker(.filtersSort, selection: $sort) {
                            ForEach(Sort.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                }
            }
        }
    }

    private struct AccountRow: View {
        let row: Row

        var body: some View {
            HStack(spacing: 12) {
                Avatar(name: row.account.name, url: row.account.avatarURL(on: platform))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.account.name).font(.body)
                    Text(meta).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(statusLabel).font(.caption).foregroundStyle(statusColor)
            }
        }

        private var platform: Platform {
            Platform.allCases.first { row.account.profile(on: $0) == row.profile } ?? .x
        }

        private var meta: String {
            [
                row.profile.handle.map { "@\($0)" },
                row.account.category,
                row.profile.followers.map { String(localized: .accountFollowers($0.formatted(.number.notation(.compactName)))) },
                row.blockCount.map { String(localized: .accountBlocks($0.formatted())) },
            ].compactMap { $0 }.joined(separator: " · ")
        }

        private var statusLabel: String {
            switch row.status {
            case .pending: String(localized: .statusPending)
            case .blocked: String(localized: .statusBlocked)
            case .alreadyBlocked: String(localized: .statusAlreadyBlocked)
            case .unavailable: String(localized: .statusUnavailable)
            case .failed: String(localized: .statusFailed)
            }
        }

        private var statusColor: Color {
            switch row.status {
            case .blocked, .alreadyBlocked: .green
            case .failed: .red
            default: .secondary
            }
        }
    }

    private struct Avatar: View {
        let name: String
        let url: URL?

        var body: some View {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Text(initials).font(.caption.bold()).foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            .background(.quaternary)
            .clipShape(.circle)
        }

        private var initials: String {
            name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }
    }
}
