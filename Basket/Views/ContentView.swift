import BasketCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 230)
            Divider()
            if model.accounts.isEmpty {
                ContentUnavailableView {
                    Label("Nothing in your Basket yet", systemImage: "tray")
                } description: {
                    Text("Add Slack, Teams, Gmail or any other web app. Each account gets its own separate sign-in.")
                } actions: {
                    Button("Add Account") { model.isAddingAccount = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WebContainerView(sessions: model.orderedSessions, selectedID: model.selectedID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $model.isAddingAccount) {
            AccountEditor(mode: .add)
                .environment(model)
        }
        .sheet(item: $model.editingAccount) { account in
            AccountEditor(mode: .edit(account))
                .environment(model)
        }
        .alert(
            "Remove \(model.accountPendingRemoval?.title ?? "account")?",
            isPresented: Binding(
                get: { model.accountPendingRemoval != nil },
                set: { if !$0 { model.accountPendingRemoval = nil } }
            ),
            presenting: model.accountPendingRemoval
        ) { account in
            Button("Remove", role: .destructive) { model.removeAccount(account.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This signs the account out of Basket and deletes its saved data.")
        }
    }
}
