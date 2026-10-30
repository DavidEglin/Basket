import AppKit
import SwiftUI

/// Hosts every account's web view at once and shows only the selected one, so switching accounts is
/// instant and never reloads a page.
struct WebContainerView: NSViewRepresentable {
    let sessions: [AccountSession]
    let selectedID: UUID?

    final class Coordinator {
        var lastSelectedID: UUID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ container: NSView, context: Context) {
        let wanted = Set(sessions.map { ObjectIdentifier($0.webView) })
        for subview in container.subviews where !wanted.contains(ObjectIdentifier(subview)) {
            subview.removeFromSuperview()
        }

        for session in sessions {
            let webView = session.webView
            if webView.superview !== container {
                webView.removeFromSuperview()
                webView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    webView.topAnchor.constraint(equalTo: container.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
            webView.isHidden = session.accountID != selectedID
        }

        if context.coordinator.lastSelectedID != selectedID {
            context.coordinator.lastSelectedID = selectedID
            if let selected = sessions.first(where: { $0.accountID == selectedID }) {
                // Give the page keyboard focus once SwiftUI has finished updating.
                DispatchQueue.main.async {
                    selected.webView.window?.makeFirstResponder(selected.webView)
                }
            }
        }
    }
}
