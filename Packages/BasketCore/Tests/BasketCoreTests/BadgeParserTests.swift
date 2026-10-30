import XCTest
@testable import BasketCore

final class BadgeParserTests: XCTestCase {
    func testGmailInboxTitle() {
        XCTAssertEqual(BadgeParser.badge(fromTitle: "Inbox (12) - me@gmail.com - Gmail", service: .gmail), .count(12))
    }

    func testThousandsSeparator() {
        XCTAssertEqual(BadgeParser.badge(fromTitle: "Inbox (1,234) - me@gmail.com - Gmail", service: .gmail), .count(1234))
    }

    func testTeamsTitle() {
        XCTAssertEqual(BadgeParser.badge(fromTitle: "(3) Chat | Dave | Microsoft Teams", service: .teams), .count(3))
    }

    func testSlackUnreadPrefixes() {
        XCTAssertEqual(BadgeParser.badge(fromTitle: "* general (Channel) - Acme - Slack", service: .slack), .dot)
        XCTAssertEqual(BadgeParser.badge(fromTitle: "! general (Channel) - Acme - Slack", service: .slack), .dot)
        XCTAssertEqual(BadgeParser.badge(fromTitle: "general (Channel) - Acme - Slack", service: .slack), .none)
    }

    func testStarPrefixOnlyMeansUnreadForSlack() {
        XCTAssertEqual(BadgeParser.badge(fromTitle: "* Something", service: .custom), .none)
    }

    func testNoCount() {
        XCTAssertEqual(BadgeParser.badge(fromTitle: "Sent Mail - me@gmail.com - Gmail", service: .gmail), .none)
        XCTAssertEqual(BadgeParser.badge(fromTitle: "Inbox (0)", service: .custom), .none)
    }

    func testTotal() {
        XCTAssertEqual(Badge.total([.count(2), .dot, .none, .count(5)]), .count(7))
        XCTAssertEqual(Badge.total([.dot, .none]), .dot)
        XCTAssertEqual(Badge.total([Badge]()), .none)
    }

    func testLabel() {
        XCTAssertNil(Badge.none.label)
        XCTAssertEqual(Badge.dot.label, "•")
        XCTAssertEqual(Badge.count(7).label, "7")
        XCTAssertEqual(Badge.count(250).label, "99+")
    }

    func testGmailFeed() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?><feed version="0.3" xmlns="http://purl.org/atom/ns#">
        <title>Gmail - Inbox for me@gmail.com</title><fullcount>4</fullcount><entry></entry></feed>
        """
        XCTAssertEqual(GmailFeed.unreadCount(in: xml), 4)
        XCTAssertNil(GmailFeed.unreadCount(in: "<html>Sign in</html>"))
    }
}
