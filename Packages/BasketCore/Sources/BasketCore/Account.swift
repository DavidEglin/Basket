import Foundation

/// One signed-in web app, e.g. "Slack · Work". Each account has its own isolated browser session.
public struct Account: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var service: Service
    public var name: String
    public var url: URL
    public var notificationsEnabled: Bool
    /// Overrides the default Safari user agent, for services that reject WebKit.
    public var customUserAgent: String?

    public init(
        id: UUID = UUID(),
        service: Service,
        name: String,
        url: URL,
        notificationsEnabled: Bool = true,
        customUserAgent: String? = nil
    ) {
        self.id = id
        self.service = service
        self.name = name
        self.url = url
        self.notificationsEnabled = notificationsEnabled
        self.customUserAgent = customUserAgent
    }

    /// Short name for the sidebar, e.g. "Work".
    public var displayName: String {
        if !name.isEmpty { return name }
        if service == .custom { return url.host ?? url.absoluteString }
        return service.displayName
    }

    /// Full name for menus and notifications, e.g. "Slack · Work".
    public var title: String {
        if service == .custom || name.isEmpty { return displayName }
        return "\(service.displayName) · \(name)"
    }

    /// Turns what the user typed into a web URL, adding https:// when no scheme was given.
    public static func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") || host == "localhost"
        else { return nil }
        return url
    }

    private enum CodingKeys: String, CodingKey {
        case id, service, name, url, notificationsEnabled, customUserAgent
    }

    // Tolerant decoding so a newer or older state file never wipes the user's accounts.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        url = try c.decode(URL.self, forKey: .url)
        let rawService = try c.decodeIfPresent(String.self, forKey: .service) ?? ""
        service = Service(rawValue: rawService) ?? .custom
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        customUserAgent = try c.decodeIfPresent(String.self, forKey: .customUserAgent)
    }
}
