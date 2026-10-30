import BasketCore
import Foundation
import UserNotifications

/// Shows web notifications as macOS notifications and routes clicks back to the right account.
@MainActor
final class NotificationBridge: NSObject {
    static let shared = NotificationBridge()

    private var onClick: ((UUID, Int) -> Void)?

    func start(onClick: @escaping (UUID, Int) -> Void) {
        self.onClick = onClick
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func post(_ notification: WebNotification, from account: Account) {
        let content = UNMutableNotificationContent()
        content.title = account.title
        content.subtitle = notification.title
        content.body = notification.body
        content.threadIdentifier = account.id.uuidString
        content.userInfo = ["accountID": account.id.uuidString, "notificationID": notification.id]
        let playSound = UserDefaults.standard.object(forKey: SettingsKeys.playSound) as? Bool ?? true
        if playSound && !notification.silent {
            content.sound = .default
        }
        // Same tag replaces the earlier notification, matching browser behaviour.
        let identifier = notification.tag.isEmpty
            ? "\(account.id.uuidString)-\(UUID().uuidString)"
            : "\(account.id.uuidString)-\(notification.tag)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    func removeAll(for accountID: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .filter { $0.request.content.threadIdentifier == accountID.uuidString }
                .map(\.request.identifier)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}

extension NotificationBridge: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let accountID = (info["accountID"] as? String).flatMap(UUID.init(uuidString:))
        let notificationID = info["notificationID"] as? Int ?? 0
        if let accountID {
            Task { @MainActor in
                NotificationBridge.shared.onClick?(accountID, notificationID)
            }
        }
        completionHandler()
    }
}
