import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                pacingSection
                keepAliveSection
                Section {
                    Toggle(.settingsShowBrowser, isOn: $model.settings.showBrowser)
                } header: {
                    Text(.settingsDebug)
                } footer: {
                    Text(.settingsShowBrowserFooter)
                }
            }
            .navigationTitle(.tabSettings)
        }
    }

    private var keepAliveSection: some View {
        Section {
            Toggle(.settingsKeepAlive, isOn: $model.settings.keepAlive)
                .disabled(model.runner.keeper.isDenied)
                .onChange(of: model.settings.keepAlive) { _, isOn in
                    if isOn { model.runner.keeper.requestAuthorization() }
                }
                .onChange(of: model.runner.keeper.isDenied, initial: true) { _, isDenied in
                    if isDenied { model.settings.keepAlive = false }
                }
            if model.runner.keeper.isDenied {
                Button(.settingsOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        } footer: {
            if model.runner.keeper.isDenied {
                Text(.settingsKeepAliveDenied)
            } else {
                Text(.settingsKeepAliveFooter)
            }
        }
        .disabled(model.runner.isRunning)
    }

    private var pacingSection: some View {
        Section {
            Stepper(.pacingMin(model.settings.minDelay), value: $model.settings.minDelay, in: SettingsStore.delayRange)
            Stepper(.pacingMax(model.settings.maxDelay), value: $model.settings.maxDelay, in: model.settings.minDelay...SettingsStore.delayRange.upperBound)
            Toggle(.pacingUnlimited, isOn: $model.settings.unlimited)
            if !model.settings.unlimited {
                Stepper(.pacingCap(model.settings.sessionCap), value: $model.settings.sessionCap, in: SettingsStore.capRange, step: 5)
            }
        } header: {
            Text(.pacingTitle)
        } footer: {
            Text(.pacingFooter)
        }
        .disabled(model.runner.isRunning)
    }
}
