import Foundation

/// Everything Basket remembers between launches.
public struct BasketState: Codable, Equatable, Sendable {
    public var accounts: [Account]
    public var selectedID: UUID?
    /// Accounts whose website data still needs deleting (it can't be removed while a web view is using it).
    public var pendingDataRemovals: [UUID]

    public init(accounts: [Account] = [], selectedID: UUID? = nil, pendingDataRemovals: [UUID] = []) {
        self.accounts = accounts
        self.selectedID = selectedID
        self.pendingDataRemovals = pendingDataRemovals
    }

    private enum CodingKeys: String, CodingKey {
        case accounts, selectedID, pendingDataRemovals
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try c.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        selectedID = try c.decodeIfPresent(UUID.self, forKey: .selectedID)
        pendingDataRemovals = try c.decodeIfPresent([UUID].self, forKey: .pendingDataRemovals) ?? []
    }
}

/// Reads and writes `BasketState` as JSON.
public struct AccountStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// ~/Library/Application Support/Basket/state.json (inside the sandbox container when sandboxed).
    public static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent("Basket", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    /// Returns an empty state if there's no file yet. An unreadable file is moved aside rather than
    /// overwritten, so a bad write never silently loses the user's accounts.
    public func load() -> BasketState {
        guard let data = try? Data(contentsOf: fileURL) else { return BasketState() }
        do {
            return try JSONDecoder().decode(BasketState.self, from: data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return BasketState()
        }
    }

    public func save(_ state: BasketState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }
}
