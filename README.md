# Basket

A native macOS home for your messaging web apps: Slack, Teams, Gmail, and anything else with a web address. Every account lives in Basket's sidebar, separate from your browser tabs.

- **One sidebar, many accounts.** Each account runs in its own isolated session, so several Teams or Gmail accounts never fight over cookies.
- **Layout that survives restarts.** Account order, the selected account and the window frame are saved. Basket can also open at login.
- **Unread badges.** Each account shows a count in the sidebar, and the total shows on the Dock icon.
- **Native notifications.** Web notifications become macOS notifications ("Slack · Work"), and clicking one jumps to that account. They stay in Notification Center even if the web app closes them.
- **Links go to your browser.** Links outside the app open in your default browser (Chrome). Sign-in pop-ups stay in Basket.
- **Always running.** Closing the window keeps Basket running so notifications keep arriving. Quit with ⌘Q.

## Building on the Mac

Requirements: macOS 14 or later, Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate        # creates Basket.xcodeproj (+ Supporting/Info.plist and entitlements)
open Basket.xcodeproj
```

Choose the **Basket** scheme and run it (⌘R). Signing defaults to "Sign to Run Locally". You can set your own team under *Signing & Capabilities* instead.

Run `xcodegen generate` again whenever files are added or removed. The project file is generated, so it isn't committed.

For "Open at login" to work reliably, copy the built app to `/Applications`. To do that, use *Product → Archive* or copy it from the build products folder.

### Tests

The core logic has no AppKit or WebKit dependencies and is tested with SwiftPM:

```sh
cd Packages/BasketCore
swift test
```

## Layout

| Path | What it holds |
| --- | --- |
| `Packages/BasketCore` | Pure logic: account model, JSON store, badge parsing, link policy, notification parsing |
| `Basket/AppModel.swift` | App state: accounts, selection, badges, Dock badge |
| `Basket/AppDelegate.swift` | The main window (closing hides it), plus app lifecycle |
| `Basket/Web/AccountSession.swift` | Each account's web view and its isolated data store, navigation, downloads and panels |
| `Basket/Web/Scripts.swift` | Injected JS: the Notification shim and Gmail's unread feed poller |
| `Basket/Web/NotificationBridge.swift` | Web notification → macOS notification, and click → account |
| `Basket/Views/` | SwiftUI sidebar, account editor, settings |

State is saved to `~/Library/Containers/au.com.yaxley.Basket/Data/Library/Application Support/Basket/state.json`.

## Shortcuts

| Keys | Action |
| --- | --- |
| ⌘1–⌘9 | Jump to an account |
| ⇧⌘] / ⇧⌘[ | Next / previous account |
| ⌘R | Reload the current account |
| ⇧⌘E | Edit the current account |
| ⌘N | Add an account |
| ⌘0 | Show the Basket window |

Drag accounts in the sidebar to reorder them. Right-click an account to reload, edit, mute or remove it.

## Known limits

- **Teams calls.** Teams supports Safari, so chat works. Calls inside an embedded web view may be limited.
- **Unsupported browser messages.** If a site says your browser isn't supported, set a user agent under *Edit Account → Advanced*.
- **Notification clicks.** These fire the page's `onclick` for notifications created in the page. Clicks on service-worker notifications only switch to the account.
