import Foundation

/// A messaging service Basket knows how to host. `custom` covers any other web app.
public enum Service: String, Codable, CaseIterable, Identifiable, Sendable {
    case slack
    case teams
    case gmail
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .slack: "Slack"
        case .teams: "Teams"
        case .gmail: "Gmail"
        case .custom: "Web App"
        }
    }

    public var defaultURL: URL? {
        switch self {
        case .slack: URL(string: "https://app.slack.com/client")
        case .teams: URL(string: "https://teams.microsoft.com/v2/")
        case .gmail: URL(string: "https://mail.google.com/mail/u/0/")
        case .custom: nil
        }
    }

    /// SF Symbol shown in the sidebar.
    public var symbolName: String {
        switch self {
        case .slack: "number"
        case .teams: "person.2.fill"
        case .gmail: "envelope.fill"
        case .custom: "globe"
        }
    }

    /// Domains (and their subdomains) that belong to the app itself. Links to them stay in Basket.
    public var homeDomains: [String] {
        switch self {
        case .slack: ["slack.com"]
        case .teams: ["teams.microsoft.com", "teams.cloud.microsoft", "teams.live.com"]
        case .gmail: ["mail.google.com"]
        case .custom: []
        }
    }

    /// Sign-in domains that must stay inside the account's isolated session.
    public var authDomains: [String] {
        let specific: [String] = switch self {
        case .teams: ["login.microsoft.com", "login.windows.net"]
        case .slack, .gmail, .custom: []
        }
        return specific + Service.commonAuthDomains
    }

    public static let commonAuthDomains = [
        "accounts.google.com",
        "login.microsoftonline.com",
        "login.live.com",
        "appleid.apple.com",
    ]
}
