import AppKit
import BasketCore
import Observation
import WebKit

enum SettingsKeys {
    static let showDockBadge = "showDockBadge"
    static let playSound = "playSound"
}

/// The app's state: accounts, which one is showing, and unread badges.
@MainActor
@Observable
final class AppModel {
    private(set) var accounts: [Account] = []
    var selectedID: UUID? {
        didSet {
            guard selectedID != oldValue else { return }
            save()
            onSelectionChange?()
        }
    }
    private(set) var badges: [UUID: Badge] = [:]

    // Sheet and alert state
    var isAddingAccount = false
    var editingAccount: Account?
    var accountPendingRemoval: Account?

    @ObservationIgnored var onSelectionChange: (() -> Void)?
    @ObservationIgnored private var sessions: [UUID: AccountSession] = [:]
    @ObservationIgnored private var pendingDataRemovals: [UUID] = []
    private let store = AccountStore(fileURL: AccountStore.defaultFileURL())
    @ObservationIgnored private var isRestoring = true

    init() {
        let state = store.load()
        accounts = state.accounts
        pendingDataRemovals = state.pendingDataRemovals
        let restored = state.selectedID.flatMap { id in state.accounts.first { $0.id == id }?.id }
        selectedID = restored ?? state.accounts.first?.id
        isRestoring = false
    }

    /// Creates a live web view for every account and cleans up data from removed accounts.
    func start() {
        for account in accounts {
            makeSession(for: account)
        }
        purgeRemovedAccountData()
    }

    var selectedAccount: Account? {
        accounts.first { $0.id == selectedID }
    }

    /// Sessions in sidebar order. Reads `accounts`, so views using it update when accounts change.
    var orderedSessions: [AccountSession] {
        accounts.compactMap { sessions[$0.id] }
    }

    func session(for id: UUID) -> AccountSession? {
        sessions[id]
    }

    // MARK: - Editing accounts

    func addAccount(_ account: Account) {
        accounts.append(account)
        makeSession(for: account)
        selectedID = account.id
        save()
    }

    func updateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        sessions[account.id]?.apply(account)
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool, for id: UUID) {
        guard var account = accounts.first(where: { $0.id == id }) else { return }
        account.notificationsEnabled = enabled
        updateAccount(account)
    }

    func moveAccounts(from source: IndexSet, to destination: Int) {
        accounts.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Removes the account, signs it out and deletes its cookies and storage.
    func removeAccount(_ id: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts.remove(at: index)
        badges[id] = nil
        sessions.removeValue(forKey: id)?.tearDown()
        NotificationBridge.shared.removeAll(for: id)
        if selectedID == id {
            selectedID = accounts.isEmpty ? nil : accounts[min(index, accounts.count - 1)].id
        }
        pendingDataRemovals.append(id)
        save()
        updateDockBadge()
        // The web view may take a moment to release the data store, so wait before deleting it.
        // Anything that still fails is retried at the next launch.
        Task {
            try? await Task.sleep(for: .seconds(2))
            purgeRemovedAccountData()
        }
    }

    // MARK: - Navigation

    func select(index: Int) {
        guard accounts.indices.contains(index) else { return }
        selectedID = accounts[index].id
    }

    func selectNext(_ offset: Int) {
        guard !accounts.isEmpty else { return }
        let current = accounts.firstIndex { $0.id == selectedID } ?? 0
        let next = (current + offset + accounts.count) % accounts.count
        selectedID = accounts[next].id
    }

    func reloadSelected() {
        guard let selectedID else { return }
        sessions[selectedID]?.reload()
    }

    func reload(_ id: UUID) {
        sessions[id]?.reload()
    }

    func handleNotificationClick(accountID: UUID, notificationID: Int) {
        guard accounts.contains(where: { $0.id == accountID }) else { return }
        selectedID = accountID
        sessions[accountID]?.notificationClicked(notificationID)
    }

    // MARK: - Badges

    func updateDockBadge() {
        let show = UserDefaults.standard.object(forKey: SettingsKeys.showDockBadge) as? Bool ?? true
        NSApp.dockTile.badgeLabel = show ? Badge.total(badges.values).label : nil
    }

    // MARK: - Private

    private func makeSession(for account: Account) {
        let id = account.id
        let session = AccountSession(account: account)
        session.onBadgeChange = { [weak self] badge in
            self?.badges[id] = badge
            self?.updateDockBadge()
        }
        session.onNotification = { [weak self] notification in
            guard let account = self?.accounts.first(where: { $0.id == id }), account.notificationsEnabled else { return }
            NotificationBridge.shared.post(notification, from: account)
        }
        sessions[id] = session
        session.loadHome()
    }

    private func purgeRemovedAccountData() {
        let ids = pendingDataRemovals
        guard !ids.isEmpty else { return }
        Task {
            for id in ids where sessions[id] == nil {
                do {
                    try await WKWebsiteDataStore.remove(forIdentifier: id)
                    pendingDataRemovals.removeAll { $0 == id }
                } catch {
                    // Still in use; the next launch will try again.
                }
            }
            save()
        }
    }

    private func save() {
        guard !isRestoring else { return }
        let state = BasketState(accounts: accounts, selectedID: selectedID, pendingDataRemovals: pendingDataRemovals)
        do {
            try store.save(state)
        } catch {
            NSLog("Basket: failed to save state: \(error)")
        }
    }
}
