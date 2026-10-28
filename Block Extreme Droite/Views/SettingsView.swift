import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                pacingSection
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
