import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    private var isPreview: Bool { model.runner.isRunning && model.settings.showBrowser }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            browser
            TabView {
                Tab(.tabBlock, systemImage: "hand.raised.fill") { BlockView(model: model) }
                Tab(.accountsTitle, systemImage: "person.3.fill") {
                    NavigationStack {
                        AccountsView(accounts: model.selected, platform: model.settings.platform, snapshot: model.snapshot)
                    }
                }
                Tab(.tabSettings, systemImage: "gearshape.fill") { SettingsView(model: model) }
            }
        }
        .sheet(item: $model.loginPlatform) { LoginSheet(platform: $0) }
        .task {
            await LiveActivityController.endStale()
            await model.reload(refresh: false)
        }
    }

    /// The runner's web view, always in the window so the run keeps going across tabs. It keeps one fixed size and
    /// position so its layout never changes: behind the tabs normally, above them as a corner preview during a run.
    private var browser: some View {
        WebContainer(webView: model.runner.webView)
            .frame(width: 360, height: 300)
            .padding(.trailing, 12)
            .padding(.bottom, 100)
            .allowsHitTesting(false)
            .zIndex(isPreview ? 1 : 0)
    }
}

#Preview {
    ContentView()
}
