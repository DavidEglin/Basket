import Foundation

public enum LinkDecision: Equatable, Sendable {
    /// Load it where it is.
    case allow
    /// Open an in-app window that shares the account's session (sign-in flows, app pop-outs).
    case popup
    /// Hand it to the default browser.
    case external
    /// Drop it (e.g. a page silently trying to launch a desktop app via msteams://).
    case cancel
}

/// Decides where a navigation should happen, so that the messaging app stays in Basket
/// and everything else opens in the user's normal browser.
public struct LinkPolicy: Sendable {
    public let homeDomains: [String]
    public let authDomains: [String]

    public init(homeDomains: [String], authDomains: [String]) {
        self.homeDomains = homeDomains.map { $0.lowercased() }
        self.authDomains = authDomains.map { $0.lowercased() }
    }

    public init(account: Account) {
        var home = account.service.homeDomains
        if let host = account.url.host?.lowercased() {
            home.append(account.service == .custom ? Self.siteDomain(of: host) : host)
        }
        self.init(homeDomains: home, authDomains: account.service.authDomains)
    }

    public func isHome(_ host: String) -> Bool { Self.matches(host, homeDomains) }
    public func isAuth(_ host: String) -> Bool { Self.matches(host, authDomains) }

    /// Navigation inside an existing view.
    public func decideNavigation(to url: URL, isMainFrame: Bool, isUserClick: Bool) -> LinkDecision {
        guard let scheme = url.scheme?.lowercased() else { return .allow }
        if Self.internalSchemes.contains(scheme) { return .allow }
        guard scheme == "http" || scheme == "https" else {
            return isUserClick ? .external : .cancel
        }
        // Redirects and scripted navigation are allowed anywhere, so corporate SSO (Okta, ADFS...) works.
        guard isMainFrame, isUserClick, let host = url.host?.lowercased() else { return .allow }
        return isHome(host) || isAuth(host) ? .allow : .external
    }

    /// A page asking for a new window (target=_blank, window.open).
    public func decideNewWindow(to url: URL?) -> LinkDecision {
        guard let url, let scheme = url.scheme?.lowercased(), scheme != "about" else {
            // Blank windows are usually filled in by script; the popup decides once it navigates.
            return .popup
        }
        guard scheme == "http" || scheme == "https" else {
            return Self.internalSchemes.contains(scheme) ? .popup : .external
        }
        guard let host = url.host?.lowercased() else { return .popup }
        return isHome(host) || isAuth(host) ? .popup : .external
    }

    /// The first real page a popup loads. After that the popup is trusted.
    public func decidePopupNavigation(to url: URL) -> LinkDecision {
        decideNewWindow(to: url) == .popup ? .allow : .external
    }

    static let internalSchemes: Set<String> = ["about", "blob", "data", "javascript"]

    static func matches(_ host: String, _ domains: [String]) -> Bool {
        let host = host.lowercased()
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// "app.example.com" -> "example.com", "portal.example.com.au" -> "example.com.au".
    static func siteDomain(of host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return host }
        let secondLevel: Set<String> = ["com", "net", "org", "gov", "edu", "co", "ac", "asn", "id"]
        let usesSecondLevel = labels[labels.count - 1].count == 2 && secondLevel.contains(labels[labels.count - 2])
        return labels.suffix(usesSecondLevel ? 3 : 2).joined(separator: ".")
    }
}
