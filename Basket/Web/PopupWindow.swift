import AppKit
import BasketCore
import WebKit

/// A window opened by a page (sign-in, Teams pop-out, …). It uses the configuration WebKit hands us,
/// so it shares the account's isolated session.
@MainActor
final class PopupWindow: NSObject {
    let webView: WKWebView
    var onClose: ((PopupWindow) -> Void)?

    private let window: NSWindow
    private let policy: LinkPolicy
    /// Once the popup has shown a trusted page, later navigations (SSO redirects) are allowed anywhere.
    private var hasLoadedTrustedPage = false

    init(configuration: WKWebViewConfiguration, policy: LinkPolicy, features: WKWindowFeatures, title: String) {
        self.policy = policy
        webView = WKWebView(frame: .zero, configuration: configuration)
        let width = features.width?.doubleValue ?? 520
        let height = features.height?.doubleValue ?? 700
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = title
        window.contentView = webView
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        window.delegate = self
        window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    private var isBlank: Bool {
        webView.url == nil || webView.url?.absoluteString == "about:blank"
    }
}

extension PopupWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        webView.stopLoading()
        onClose?(self)
    }
}

extension PopupWindow: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard !hasLoadedTrustedPage,
              let url = navigationAction.request.url,
              navigationAction.targetFrame?.isMainFrame ?? true
        else {
            decisionHandler(.allow)
            return
        }
        if policy.decidePopupNavigation(to: url) == .external {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            // A blank window that only existed to open an outside link has nothing left to show.
            if isBlank { DispatchQueue.main.async { self.close() } }
            return
        }
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            hasLoadedTrustedPage = true
        }
        decisionHandler(.allow)
    }
}

extension PopupWindow: WKUIDelegate {
    func webViewDidClose(_ webView: WKWebView) {
        close()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }
}
