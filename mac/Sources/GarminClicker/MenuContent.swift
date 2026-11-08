import ClickerCore
import SwiftUI

struct MenuContent: View {
    @Bindable var model: AppModel

    var body: some View {
        let l = model.l10n

        Text(model.statusTitle)
        if let paired = model.pairedWatch {
            Text(l("menu.paired", paired.name))
        }

        Divider()

        if model.isPairingMode {
            Button(l("menu.stopPairing")) { model.stopPairing() }
        } else {
            Button(l("menu.pairWatch")) { model.startPairing() }
        }
        Button(l("menu.forgetWatch")) { model.forgetWatch() }
            .disabled(model.pairedWatch == nil)
        if model.pairedWatch != nil {
            Toggle(l("menu.broadcast"), isOn: $model.isBroadcastEnabled)
        }

        Divider()

        Picker(l("menu.keys"), selection: $model.keyScheme) {
            ForEach(KeyScheme.allCases) { Text(l($0.titleKey)).tag($0) }
        }
        Picker(l("menu.language"), selection: $model.language) {
            ForEach(AppLanguage.allCases) { Text(l($0.titleKey)).tag($0) }
        }
        Toggle(l("menu.launchAtLogin"), isOn: $model.launchAtLogin)
        if !model.canPostEvents {
            Button(l("menu.grantPermission")) { model.requestInputPermission() }
        }

        Divider()

        Button(l("menu.quit")) { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct MenuBarIcon: View {
    let model: AppModel

    var body: some View {
        Image(systemName: model.status.symbolName)
    }
}
