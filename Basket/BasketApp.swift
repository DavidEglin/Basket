import SwiftUI

@main
struct BasketApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The main window is managed by AppDelegate; this scene only supplies Settings and menus.
        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }
        .commands {
            BasketCommands(model: appDelegate.model, showWindow: { appDelegate.showMainWindow() })
        }
    }
}

struct BasketCommands: Commands {
    let model: AppModel
    let showWindow: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Account…") {
                showWindow()
                model.isAddingAccount = true
            }
            .keyboardShortcut("n")
        }

        CommandGroup(before: .windowList) {
            Button("Basket") { showWindow() }
                .keyboardShortcut("0")
            Divider()
        }

        CommandMenu("Account") {
            Button("Reload") { model.reloadSelected() }
                .keyboardShortcut("r")
                .disabled(model.selectedID == nil)
            Button("Edit Account…") {
                showWindow()
                model.editingAccount = model.selectedAccount
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(model.selectedID == nil)
            Divider()
            Button("Next Account") { model.selectNext(1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Previous Account") { model.selectNext(-1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Divider()
            ForEach(Array(model.accounts.prefix(9).enumerated()), id: \.element.id) { index, account in
                Button(account.title) {
                    showWindow()
                    model.select(index: index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
    }
}
