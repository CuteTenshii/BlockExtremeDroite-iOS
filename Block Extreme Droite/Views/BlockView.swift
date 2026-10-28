import SwiftUI

struct BlockView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                platformSection
                listSection
                runSection
            }
            .navigationTitle("Block Extreme Droite")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: AccountRepository.projectURL) { Image(.gitHub) }
                        .accessibilityLabel(Text(.mainRepository))
                }
            }
        }
    }

    @ViewBuilder private var platformSection: some View {
        Section {
            Picker(.mainNetwork, selection: $model.settings.platform) {
                ForEach(Platform.allCases.filter { $0.webSpec != nil }) { platform in
                    Text("\(platform.label) (\(model.pendingCount(platform)))").tag(platform)
                }
            }
            .pickerStyle(.menu)
            .disabled(model.runner.isRunning)
        }
        Section {
            if model.settings.connectionsExpanded {
                ForEach(Platform.allCases.filter { $0.webSpec != nil }) { platform in
                    LabeledContent(platform.label) { connectionStatus(platform) }
                }
            }
        } header: {
            CollapsibleHeader(title: .mainConnections, isExpanded: $model.settings.connectionsExpanded)
        } footer: {
            if model.settings.connectionsExpanded { Text(.mainLoginFooter) }
        }
    }

    @ViewBuilder private func connectionStatus(_ platform: Platform) -> some View {
        if model.runner.loginsLoaded {
            connectionButton(platform)
        } else {
            ProgressView()
        }
    }

    private func connectionButton(_ platform: Platform) -> some View {
        let loggedIn = model.runner.loggedIn.contains(platform)
        return Button { model.loginPlatform = platform } label: {
            HStack(spacing: 6) {
                Image(systemName: loggedIn ? "checkmark.circle.fill" : "person.crop.circle")
                Text(loggedIn ? .mainLoggedIn : .mainLogin)
            }
        }
        .buttonStyle(.bordered)
        .tint(loggedIn ? .green : .accentColor)
        .allowsHitTesting(!loggedIn)
        .animation(nil, value: loggedIn)
    }

    private var listSection: some View {
        Section {
            if model.settings.listExpanded { listContent }
        } header: {
            CollapsibleHeader(title: .listTitle, isExpanded: $model.settings.listExpanded)
        }
    }

    @ViewBuilder private var listContent: some View {
        if model.loading {
            ProgressView()
        } else {
            LabeledContent(.listRemaining, value: String(localized: .listRemainingValue(model.remaining, model.selected.count)))
            if let total = model.snapshot?.total {
                LabeledContent(.listCollective, value: total.formatted())
            }
            if let date = model.repository.lastUpdated {
                LabeledContent(.listUpdated, value: date.formatted(date: .abbreviated, time: .shortened))
            }
        }
        if let error = model.error { Text(error).foregroundStyle(.red) }
        Button(.listUpdate, systemImage: "arrow.clockwise") { Task { await model.reload(refresh: true) } }
            .disabled(model.loading || model.runner.isRunning)
        ForEach(AccountSource.allCases, id: \.self) { source in
            Toggle("\(source.label) (\(model.count(of: source)))" as String, isOn: included(\.excludedSources, source))
        }
        DisclosureGroup(.listCategories) {
            ForEach(model.categories, id: \.self) { category in
                Toggle("\(category) (\(model.count(of: category)))" as String, isOn: included(\.excludedCategories, category))
            }
        }
        Button(.listReset, role: .destructive) { model.progress.clear(model.settings.platform) }
            .disabled(model.runner.isRunning)
    }

    private var runSection: some View {
        Section {
            if model.runner.isRunning {
                LabeledContent(.runInProgress, value: model.runner.current ?? "…")
                LabeledContent(.runBlocked, value: "\(model.runner.blocked)")
                Text(model.runner.diagnostics).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                Button(.runStop, role: .destructive) { model.runner.stop() }
            } else {
                Button(.runStart, systemImage: "hand.raised.fill") {
                    model.runner.start(platform: model.settings.platform, accounts: model.selected, pacing: model.settings.pacing, keepAlive: model.settings.keepAlive)
                }
                .disabled(model.remaining == 0 || !model.runner.loggedIn.contains(model.settings.platform))
                if let reason = model.runner.lastStop { Text(message(reason)).foregroundStyle(.secondary) }
            }
        } footer: {
            Text(.runFooter)
        }
    }

    private func included<T: Hashable>(_ excluded: ReferenceWritableKeyPath<SettingsStore, Set<T>>, _ value: T) -> Binding<Bool> {
        Binding(
            get: { !model.settings[keyPath: excluded].contains(value) },
            set: { isIncluded in
                if isIncluded { model.settings[keyPath: excluded].remove(value) } else { model.settings[keyPath: excluded].insert(value) }
            }
        )
    }

    private func message(_ reason: StopReason) -> String {
        let count = String(localized: .runCount(model.runner.lastBlocked))
        return switch reason {
        case .user: String(localized: .runStopped(count))
        case .finished: String(localized: .runDone(count))
        case .capReached: String(localized: .runCapReached(count))
        case .loggedOut: String(localized: .runLoggedOut(model.settings.platform.label))
        case .tooManyFailures: String(localized: .runTooManyFailures(count))
        }
    }
}

private struct CollapsibleHeader: View {
    let title: LocalizedStringResource
    @Binding var isExpanded: Bool

    var body: some View {
        Button { withAnimation { isExpanded.toggle() } } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.down").rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
    }
}
