import XCTest
@testable import BasketCore

final class LinkPolicyTests: XCTestCase {
    private let gmail = LinkPolicy(account: Account(service: .gmail, name: "Personal", url: URL(string: "https://mail.google.com/mail/u/0/")!))
    private let teams = LinkPolicy(account: Account(service: .teams, name: "Work", url: URL(string: "https://teams.microsoft.com/v2/")!))

    private func url(_ s: String) -> URL { URL(string: s)! }

    func testClickWithinAppStays() {
        XCTAssertEqual(gmail.decideNavigation(to: url("https://mail.google.com/mail/u/0/#inbox"), isMainFrame: true, isUserClick: true), .allow)
    }

    func testClickToOtherSiteGoesToBrowser() {
        XCTAssertEqual(gmail.decideNavigation(to: url("https://drive.google.com/file/1"), isMainFrame: true, isUserClick: true), .external)
    }

    func testRedirectsAreAllowedAnywhere() {
        // e.g. corporate SSO bouncing through Okta
        XCTAssertEqual(teams.decideNavigation(to: url("https://acme.okta.com/login"), isMainFrame: true, isUserClick: false), .allow)
    }

    func testSignInStaysInApp() {
        XCTAssertEqual(teams.decideNavigation(to: url("https://login.microsoftonline.com/common"), isMainFrame: true, isUserClick: true), .allow)
    }

    func testCustomSchemes() {
        XCTAssertEqual(teams.decideNavigation(to: url("msteams:/l/chat"), isMainFrame: false, isUserClick: false), .cancel)
        XCTAssertEqual(gmail.decideNavigation(to: url("mailto:someone@example.com"), isMainFrame: true, isUserClick: true), .external)
        XCTAssertEqual(gmail.decideNavigation(to: url("blob:https://mail.google.com/123"), isMainFrame: true, isUserClick: true), .allow)
    }

    func testNewWindows() {
        XCTAssertEqual(gmail.decideNewWindow(to: nil), .popup)
        XCTAssertEqual(gmail.decideNewWindow(to: url("about:blank")), .popup)
        XCTAssertEqual(gmail.decideNewWindow(to: url("https://accounts.google.com/signin")), .popup)
        XCTAssertEqual(gmail.decideNewWindow(to: url("https://www.google.com/url?q=https://example.com")), .external)
        XCTAssertEqual(teams.decideNewWindow(to: url("https://teams.microsoft.com/v2/meeting")), .popup)
    }

    func testPopupNavigation() {
        XCTAssertEqual(gmail.decidePopupNavigation(to: url("https://accounts.google.com/o/oauth2")), .allow)
        XCTAssertEqual(gmail.decidePopupNavigation(to: url("https://example.com")), .external)
    }

    func testCustomAccountUsesSiteDomain() {
        let policy = LinkPolicy(account: Account(service: .custom, name: "", url: URL(string: "https://app.example.com.au/inbox")!))
        XCTAssertTrue(policy.isHome("login.example.com.au"))
        XCTAssertFalse(policy.isHome("example.com"))
    }

    func testSiteDomain() {
        XCTAssertEqual(LinkPolicy.siteDomain(of: "app.example.com"), "example.com")
        XCTAssertEqual(LinkPolicy.siteDomain(of: "portal.example.com.au"), "example.com.au")
        XCTAssertEqual(LinkPolicy.siteDomain(of: "example.com"), "example.com")
    }

    func testDomainMatchingNeedsDotBoundary() {
        XCTAssertFalse(LinkPolicy.matches("notslack.com", ["slack.com"]))
        XCTAssertTrue(LinkPolicy.matches("acme.slack.com", ["slack.com"]))
    }
}
