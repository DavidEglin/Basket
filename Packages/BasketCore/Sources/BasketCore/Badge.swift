import Foundation

/// Unread state for an account.
public enum Badge: Equatable, Sendable {
    case none
    /// Something is unread but the app doesn't say how much (e.g. Slack's "*" title prefix).
    case dot
    case count(Int)

    /// Combines every account's badge into one for the Dock icon.
    public static func total(_ badges: some Sequence<Badge>) -> Badge {
        var sum = 0
        var anyDot = false
        for badge in badges {
            switch badge {
            case .none: break
            case .dot: anyDot = true
            case .count(let n): sum += n
            }
        }
        if sum > 0 { return .count(sum) }
        return anyDot ? .dot : .none
    }

    public var label: String? {
        switch self {
        case .none: nil
        case .dot: "•"
        case .count(let n): n > 99 ? "99+" : "\(n)"
        }
    }
}

/// Reads unread counts from page titles, e.g. "Inbox (12) - me@gmail.com - Gmail" or "(3) Chat | Microsoft Teams".
public enum BadgeParser {
    public static func badge(fromTitle title: String, service: Service) -> Badge {
        if let count = firstParenthesizedNumber(in: title) {
            return count > 0 ? .count(count) : .none
        }
        if service == .slack {
            // Slack marks unread channels with "*" and mentions with "!" at the start of the title.
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("*") || trimmed.hasPrefix("!") { return .dot }
        }
        return .none
    }

    private static let countPattern = try! NSRegularExpression(pattern: #"\((\d[\d,]*)\)"#)

    static func firstParenthesizedNumber(in title: String) -> Int? {
        let range = NSRange(title.startIndex..., in: title)
        guard let match = countPattern.firstMatch(in: title, range: range),
              let digits = Range(match.range(at: 1), in: title)
        else { return nil }
        return Int(title[digits].replacingOccurrences(of: ",", with: ""))
    }
}

/// Gmail's Atom feed (/mail/u/0/feed/atom) gives an inbox unread count that doesn't depend on
/// which page is open, unlike the title, which only shows the count on the inbox view.
public enum GmailFeed {
    public static func unreadCount(in xml: String) -> Int? {
        guard let start = xml.range(of: "<fullcount>"),
              let end = xml.range(of: "</fullcount>", range: start.upperBound..<xml.endIndex)
        else { return nil }
        return Int(xml[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
