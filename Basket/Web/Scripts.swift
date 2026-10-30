import Foundation

/// JavaScript injected into every account's pages.
enum Scripts {
    static let notifyHandler = "basketNotify"
    static let badgeHandler = "basketBadge"

    /// Replaces `window.Notification` (and service-worker notifications) with a version that always
    /// has permission and forwards each notification to Basket, which shows it natively.
    static let notificationShim = """
    (function () {
      if (window.__basketShim) return;
      window.__basketShim = true;
      const handlers = window.webkit && window.webkit.messageHandlers;
      const handler = handlers && handlers.\(notifyHandler);
      if (!handler) return;

      const live = new Map();
      let nextId = 1;

      class BasketNotification extends EventTarget {
        constructor(title, options) {
          super();
          options = options || {};
          this.title = String(title);
          this.body = options.body ? String(options.body) : '';
          this.tag = options.tag ? String(options.tag) : '';
          this.icon = options.icon || '';
          this.data = options.data;
          this.silent = !!options.silent;
          this.onclick = null;
          this.onclose = null;
          this.onshow = null;
          this.onerror = null;
          this._id = nextId++;
          live.set(this._id, this);
          if (live.size > 200) live.delete(live.keys().next().value);
          handler.postMessage({ type: 'show', id: this._id, title: this.title, body: this.body, tag: this.tag, silent: this.silent });
          setTimeout(() => this._fire('show'), 0);
        }
        close() {
          // Deliberately not removed from Notification Center: apps often auto-close after a few
          // seconds, which is exactly how messages get missed.
          live.delete(this._id);
          this._fire('close');
        }
        _fire(name) {
          const event = new Event(name);
          const fn = this['on' + name];
          if (typeof fn === 'function') { try { fn.call(this, event); } catch (e) {} }
          this.dispatchEvent(event);
        }
        static get permission() { return 'granted'; }
        static get maxActions() { return 0; }
        static requestPermission(callback) {
          if (typeof callback === 'function') callback('granted');
          return Promise.resolve('granted');
        }
      }

      window.Notification = BasketNotification;
      window.__basketNotificationClicked = function (id) {
        const n = live.get(id);
        if (n) n._fire('click');
      };

      if (window.ServiceWorkerRegistration && ServiceWorkerRegistration.prototype.showNotification) {
        ServiceWorkerRegistration.prototype.showNotification = function (title, options) {
          new BasketNotification(title, options);
          return Promise.resolve();
        };
      }

      if (navigator.permissions && navigator.permissions.query) {
        const query = navigator.permissions.query.bind(navigator.permissions);
        navigator.permissions.query = function (descriptor) {
          if (descriptor && descriptor.name === 'notifications') {
            return Promise.resolve({ state: 'granted', status: 'granted', onchange: null,
              addEventListener() {}, removeEventListener() {} });
          }
          return query(descriptor);
        };
      }
    })();
    """

    /// Gmail only: polls the inbox Atom feed (same origin, so it uses this account's cookies) and
    /// posts it back for an unread count that doesn't depend on which page is open.
    static let gmailBadge = """
    (function () {
      if (window.top !== window || window.__basketPollBadge) return;
      if (!location.pathname.startsWith('/mail/')) return;
      const handler = window.webkit.messageHandlers.\(badgeHandler);
      const match = location.pathname.match(/^\\/mail\\/u\\/(\\d+)\\//);
      const feed = '/mail/u/' + (match ? match[1] : '0') + '/feed/atom';
      window.__basketPollBadge = async function () {
        try {
          const response = await fetch(feed, { credentials: 'include', cache: 'no-store' });
          if (response.ok) handler.postMessage({ feed: await response.text() });
        } catch (e) {}
      };
      window.__basketPollBadge();
      setInterval(window.__basketPollBadge, 60000);
    })();
    """

    static func notificationClicked(_ id: Int) -> String {
        "window.__basketNotificationClicked && window.__basketNotificationClicked(\(id));"
    }

    static let pollBadge = "window.__basketPollBadge && window.__basketPollBadge();"
}

enum WebDefaults {
    /// Appended to WebKit's user agent so services see a normal Safari. Without the "Version/… Safari/…"
    /// suffix, Slack and Teams treat WKWebView as an unsupported browser.
    static var applicationNameForUserAgent: String {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let safari = switch major {
        case ..<15: "17.6"
        case 15: "18.6"
        default: "\(major).0"
        }
        return "Version/\(safari) Safari/605.1.15"
    }
}
