import Foundation

/// A notification a web app tried to show, as forwarded by the injected Notification shim.
public struct WebNotification: Equatable, Sendable {
    /// The shim's id for the JS Notification object, used to fire its onclick.
    public var id: Int
    public var title: String
    public var body: String
    /// Notifications with the same tag replace each other.
    public var tag: String
    public var silent: Bool

    public init(id: Int, title: String, body: String = "", tag: String = "", silent: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.tag = tag
        self.silent = silent
    }

    /// Parses the message body posted by the shim.
    public init?(message: [String: Any]) {
        guard let title = message["title"] as? String else { return nil }
        self.title = title
        id = (message["id"] as? Int) ?? (message["id"] as? Double).map { Int($0) } ?? 0
        body = message["body"] as? String ?? ""
        tag = message["tag"] as? String ?? ""
        silent = message["silent"] as? Bool ?? false
    }
}

public enum DownloadNaming {
    /// A file URL in `directory` that doesn't exist yet: "report.pdf", then "report (2).pdf", ...
    public static func uniqueURL(in directory: URL, suggestedFilename: String, exists: (URL) -> Bool) -> URL {
        var name = suggestedFilename.split(separator: "/").last.map(String.init) ?? ""
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." { name = "download" }

        let base: String
        let ext: String
        if let dot = name.lastIndex(of: "."), dot != name.startIndex {
            base = String(name[..<dot])
            ext = String(name[dot...])
        } else {
            base = name
            ext = ""
        }

        var candidate = directory.appendingPathComponent(name)
        var n = 2
        while exists(candidate) {
            candidate = directory.appendingPathComponent("\(base) (\(n))\(ext)")
            n += 1
        }
        return candidate
    }
}
