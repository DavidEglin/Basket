import AppKit
import BasketCore
import WebKit

/// One account's live web view, with its own isolated cookies and storage. Sessions are created at
/// launch and kept alive while Basket runs, so badges and notifications work for every account,
/// not just the one on screen.
@MainActor
final class AccountSession: NSObject {
    let accountID: UUID
    private(set) var account: Account
    let webView: WKWebView
    private(set) var badge: Badge = .none

    var onBadgeChange: ((Badge) -> Void)?
    var onNotification: ((WebNotification) -> Void)?

    private var policy: LinkPolicy
    private var titleObservation: NSKeyValueObservation?
    private var popups: [PopupWindow] = []
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    init(account: Account) {
        self.accountID = account.id
        self.account = account
        self.policy = LinkPolicy(account: account)

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        config.applicationNameForUserAgent = WebDefaults.applicationNameForUserAgent
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.isElementFullscreenEnabled = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let scripts = config.userContentController
        scripts.addUserScript(WKUserScript(source: Scripts.notificationShim, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        if account.service == .gmail {
            scripts.addUserScript(WKUserScript(source: Scripts.gmailBadge, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = account.customUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true

        super.init()

        // The content controller retains its handlers, so go through a weak proxy to avoid a cycle.
        let proxy = WeakScriptMessageHandler(self)
        scripts.add(proxy, name: Scripts.notifyHandler)
        scripts.add(proxy, name: Scripts.badgeHandler)

        webView.navigationDelegate = self
        webView.uiDelegate = self
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.titleDidChange() }
        }
    }

    func loadHome() {
        webView.load(URLRequest(url: account.url))
    }

    func reload() {
        if webView.url == nil { loadHome() } else { webView.reload() }
    }

    /// Applies edits made in the account editor.
    func apply(_ updated: Account) {
        let urlChanged = updated.url != account.url
        let agentChanged = updated.customUserAgent != account.customUserAgent
        account = updated
        policy = LinkPolicy(account: updated)
        if agentChanged { webView.customUserAgent = updated.customUserAgent }
        if urlChanged { loadHome() } else if agentChanged { webView.reload() }
    }

    func notificationClicked(_ notificationID: Int) {
        webView.evaluateJavaScript(Scripts.notificationClicked(notificationID), completionHandler: nil)
    }

    /// Releases everything so the account's website data store can be deleted.
    func tearDown() {
        titleObservation?.invalidate()
        titleObservation = nil
        webView.stopLoading()
        let scripts = webView.configuration.userContentController
        scripts.removeAllScriptMessageHandlers()
        scripts.removeAllUserScripts()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        popups.forEach { $0.close() }
        popups.removeAll()
    }

    private func titleDidChange() {
        if account.service == .gmail {
            // A title change usually means the inbox changed; refresh from the feed right away.
            webView.evaluateJavaScript(Scripts.pollBadge, completionHandler: nil)
            return
        }
        setBadge(BadgeParser.badge(fromTitle: webView.title ?? "", service: account.service))
    }

    private func setBadge(_ newBadge: Badge) {
        guard newBadge != badge else { return }
        badge = newBadge
        onBadgeChange?(newBadge)
    }

    private func present(_ alert: NSAlert, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = webView.window, !webView.isHidden, window.isVisible {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}

// MARK: - Messages from injected scripts

extension AccountSession: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        switch message.name {
        case Scripts.notifyHandler:
            if let notification = WebNotification(message: body) {
                onNotification?(notification)
            }
        case Scripts.badgeHandler:
            if let feed = body["feed"] as? String, let count = GmailFeed.unreadCount(in: feed) {
                setBadge(count > 0 ? .count(count) : .none)
            }
        default:
            break
        }
    }
}

// MARK: - Navigation

extension AccountSession: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        // No target frame means a new window; createWebViewWith makes that call.
        guard let url = navigationAction.request.url, let frame = navigationAction.targetFrame else {
            decisionHandler(.allow)
            return
        }
        let decision = policy.decideNavigation(
            to: url,
            isMainFrame: frame.isMainFrame,
            isUserClick: navigationAction.navigationType == .linkActivated
        )
        switch decision {
        case .allow, .popup:
            decisionHandler(.allow)
        case .external:
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        case .cancel:
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")
        let isAttachment = disposition?.lowercased().hasPrefix("attachment") ?? false
        if isAttachment || (navigationResponse.isForMainFrame && !navigationResponse.canShowMIMEType) {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }
}

// MARK: - Windows, panels and permissions

extension AccountSession: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let url = navigationAction.request.url
        switch policy.decideNewWindow(to: url) {
        case .popup:
            let popup = PopupWindow(configuration: configuration, policy: policy, features: windowFeatures, title: account.title)
            popup.webView.customUserAgent = webView.customUserAgent
            popup.onClose = { [weak self] closed in self?.popups.removeAll { $0 === closed } }
            popups.append(popup)
            popup.show()
            return popup.webView
        case .external:
            if let url { NSWorkspace.shared.open(url) }
            return nil
        case .allow:
            webView.load(navigationAction.request)
            return nil
        case .cancel:
            return nil
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        if let window = webView.window {
            panel.beginSheetModal(for: window) { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        } else {
            completionHandler(panel.runModal() == .OK ? panel.urls : nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(policy.isHome(origin.host) ? .grant : .prompt)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = account.title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        present(alert) { _ in completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = account.title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = account.title
        alert.informativeText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }
}

// MARK: - Downloads

extension AccountSession: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = DownloadNaming.uniqueURL(in: downloads, suggestedFilename: suggestedFilename) {
            FileManager.default.fileExists(atPath: $0.path)
        }
        downloadDestinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        // Bounces the Downloads stack in the Dock, like Safari does.
        DistributedNotificationCenter.default().post(name: .init("com.apple.DownloadFileFinished"), object: destination.path)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
    }
}

/// Forwards script messages without retaining the real handler.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
