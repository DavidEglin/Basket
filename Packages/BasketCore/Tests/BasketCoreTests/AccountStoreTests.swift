import XCTest
@testable import BasketCore

final class AccountStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var store: AccountStore { AccountStore(fileURL: directory.appendingPathComponent("state.json")) }

    func testMissingFileIsEmpty() {
        XCTAssertEqual(store.load(), BasketState())
    }

    func testRoundTrip() throws {
        let slack = Account(service: .slack, name: "Work", url: Service.slack.defaultURL!)
        let custom = Account(service: .custom, name: "", url: URL(string: "https://chat.example.com")!, notificationsEnabled: false, customUserAgent: "UA")
        let state = BasketState(accounts: [slack, custom], selectedID: custom.id, pendingDataRemovals: [UUID()])
        try store.save(state)
        XCTAssertEqual(store.load(), state)
    }

    func testToleratesMissingAndUnknownFields() throws {
        let id = UUID()
        let json = """
        {"accounts":[{"id":"\(id.uuidString)","url":"https://example.com","service":"fax","future":1}]}
        """
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)

        let state = store.load()
        XCTAssertEqual(state.accounts.count, 1)
        XCTAssertEqual(state.accounts[0].id, id)
        XCTAssertEqual(state.accounts[0].service, .custom)
        XCTAssertTrue(state.accounts[0].notificationsEnabled)
        XCTAssertNil(state.selectedID)
    }

    func testCorruptFileIsMovedAside() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)

        XCTAssertEqual(store.load(), BasketState())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(leftovers.contains { $0.contains("corrupt") })
    }
}

final class AccountTests: XCTestCase {
    func testNormalizedURL() {
        XCTAssertEqual(Account.normalizedURL(from: " chat.example.com ")?.absoluteString, "https://chat.example.com")
        XCTAssertEqual(Account.normalizedURL(from: "http://intranet.local")?.absoluteString, "http://intranet.local")
        XCTAssertNil(Account.normalizedURL(from: ""))
        XCTAssertNil(Account.normalizedURL(from: "not a url"))
        XCTAssertNil(Account.normalizedURL(from: "ftp://example.com"))
        XCTAssertNil(Account.normalizedURL(from: "example"))
    }

    func testTitles() {
        let work = Account(service: .slack, name: "Work", url: Service.slack.defaultURL!)
        XCTAssertEqual(work.displayName, "Work")
        XCTAssertEqual(work.title, "Slack · Work")

        let unnamed = Account(service: .gmail, name: "", url: Service.gmail.defaultURL!)
        XCTAssertEqual(unnamed.title, "Gmail")

        let custom = Account(service: .custom, name: "", url: URL(string: "https://chat.example.com")!)
        XCTAssertEqual(custom.title, "chat.example.com")
    }
}

final class WebNotificationTests: XCTestCase {
    func testParsesShimMessage() {
        let n = WebNotification(message: ["id": 3, "title": "Alex", "body": "Lunch?", "tag": "dm-1", "silent": true])
        XCTAssertEqual(n, WebNotification(id: 3, title: "Alex", body: "Lunch?", tag: "dm-1", silent: true))
    }

    func testRequiresTitle() {
        XCTAssertNil(WebNotification(message: ["body": "x"]))
    }

    func testDownloadNaming() {
        let dir = URL(fileURLWithPath: "/tmp/downloads")
        var existing: Set<String> = ["report.pdf", "report (2).pdf"]
        let url = DownloadNaming.uniqueURL(in: dir, suggestedFilename: "report.pdf") { existing.contains($0.lastPathComponent) }
        XCTAssertEqual(url.lastPathComponent, "report (3).pdf")

        existing = []
        XCTAssertEqual(DownloadNaming.uniqueURL(in: dir, suggestedFilename: "../../etc/passwd") { _ in false }.lastPathComponent, "passwd")
        XCTAssertEqual(DownloadNaming.uniqueURL(in: dir, suggestedFilename: "") { _ in false }.lastPathComponent, "download")
        XCTAssertEqual(DownloadNaming.uniqueURL(in: dir, suggestedFilename: ".env") { _ in false }.lastPathComponent, ".env")
    }
}
