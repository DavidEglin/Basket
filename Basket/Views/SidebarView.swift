import BasketCore
import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            List(selection: $model.selectedID) {
                ForEach(model.accounts) { account in
                    AccountRow(account: account, badge: model.badges[account.id] ?? .none)
                        .contextMenu { contextMenu(for: account) }
                }
                .onMove { model.moveAccounts(from: $0, to: $1) }
            }
            .listStyle(.sidebar)

            Divider()
            Button {
                model.isAddingAccount = true
            } label: {
                Label("Add Account", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func contextMenu(for account: Account) -> some View {
        Button("Reload") { model.reload(account.id) }
        Button("Edit…") { model.editingAccount = account }
        Button(account.notificationsEnabled ? "Mute Notifications" : "Unmute Notifications") {
            model.setNotificationsEnabled(!account.notificationsEnabled, for: account.id)
        }
        Divider()
        Button("Remove…", role: .destructive) { model.accountPendingRemoval = account }
    }
}

struct AccountRow: View {
    let account: Account
    let badge: Badge

    var body: some View {
        HStack(spacing: 10) {
            ServiceIcon(service: account.service, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.displayName)
                    .lineLimit(1)
                Text(account.service == .custom ? (account.url.host() ?? "") : account.service.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !account.notificationsEnabled {
                Image(systemName: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Notifications muted")
            }
            BadgeView(badge: badge)
        }
        .padding(.vertical, 3)
    }
}

struct BadgeView: View {
    let badge: Badge

    var body: some View {
        switch badge {
        case .none:
            EmptyView()
        case .dot:
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        case .count:
            Text(badge.label ?? "")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(.red))
        }
    }
}

struct ServiceIcon: View {
    let service: Service
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(service.tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: service.symbolName)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

extension Service {
    var tint: Color {
        switch self {
        case .slack: Color(red: 0.29, green: 0.08, blue: 0.29)
        case .teams: Color(red: 0.31, green: 0.35, blue: 0.79)
        case .gmail: Color(red: 0.92, green: 0.26, blue: 0.21)
        case .custom: Color.gray
        }
    }
}
