import SwiftUI
import WebKit

enum StopReason {
    case user, finished, capReached, loggedOut, tooManyFailures
}

/// Drives a platform's website in a web view signed in with the user's own session: opens each profile, then
/// clicks its menu, Block and the confirmation. Page state is read by an injected script and checked on a short poll.
@MainActor @Observable
final class BlockRunner: NSObject, WKHTTPCookieStoreObserver, WKNavigationDelegate {
    private(set) var isRunning = false
    private(set) var current: String?
    private(set) var blocked = 0
    private(set) var lastStop: StopReason?
    private(set) var lastBlocked = 0
    /// The current step and the controls the page script found, shown while a run is going.
    private(set) var diagnostics = ""
    /// Platforms whose website session cookie is present, kept current while the user signs in or out.
    private(set) var loggedIn: Set<Platform> = []
    /// False until the first cookie read returns, which waits on WebKit's networking process starting.
    private(set) var loginsLoaded = false

    let webView: WKWebView
    private let progress = ProgressStore()
    let keeper = BackgroundKeeper()
    private let liveActivity = LiveActivityController()
    private var task: Task<Void, Never>?
    private var requested: URL?

    private enum Step { case profile, menu, confirm, verify }
    private enum Outcome { case status(BlockStatus), loggedOut, cancelled }

    private static let poll = Duration.milliseconds(400)
    private static let maxConsecutiveFailures = 3

    override init() {
        let configuration = WKWebViewConfiguration()
        let script = WKUserScript(source: Self.script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        webView.layer.cornerRadius = 16
        webView.layer.masksToBounds = true
        super.init()
        webView.navigationDelegate = self
        configuration.websiteDataStore.httpCookieStore.add(self)
        Task { await refreshLogins() }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let url = navigationAction.request.url
        guard let scheme = url?.scheme?.lowercased(), scheme == "http" || scheme == "https" || scheme == "about" else {
            diagnostics = "blocked redirect to \(url?.absoluteString ?? "?") (from \(webView.url?.absoluteString ?? "\(requested?.absoluteString ?? "?")"))"
            return .cancel
        }
        diagnostics = "navigate \(url?.absoluteString ?? "?")"
        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        let status = (navigationResponse.response as? HTTPURLResponse)?.statusCode ?? 0
        diagnostics = "response \(status) \(navigationResponse.response.mimeType ?? "?") \(navigationResponse.response.url?.absoluteString ?? "")"
        return .allow
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        diagnostics = "load failed [\(nsError.domain) \(nsError.code)] \(nsError.localizedDescription) | requested \(requested?.absoluteString ?? "none") | now \(webView.url?.absoluteString ?? "none")"
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        diagnostics = "web process terminated"
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in await refreshLogins() }
    }

    private func refreshLogins() async {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        loggedIn = Set(Platform.allCases.filter { platform in
            guard let session = platform.sessionCookie else { return false }
            return cookies.contains { $0.name == session.name && $0.domain.hasSuffix(session.domain) && !$0.value.isEmpty }
        })
        loginsLoaded = true
    }

    /// Accounts already blocked, unavailable or without a profile on the platform are skipped.
    func start(platform: Platform, accounts: [Account], pacing: Pacing, keepAlive: Bool) {
        guard !isRunning, platform.webSpec != nil else { return }
        let queue = accounts.filter { account in
            account.profile(on: platform).map { !progress.status($0).isDone } ?? false
        }
        guard !queue.isEmpty else { return }
        isRunning = true
        if keepAlive {
            keeper.start()
            liveActivity.start(platform: platform, cap: pacing.sessionCap)
        }
        blocked = 0
        current = nil
        lastStop = nil
        UIApplication.shared.isIdleTimerDisabled = true
        task = Task { [self] in
            let reason = await run(platform, queue, pacing)
            isRunning = false
            keeper.stop()
            liveActivity.end(blocked: blocked)
            current = nil
            lastStop = reason
            lastBlocked = blocked
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func stop() { task?.cancel() }

    private func run(_ platform: Platform, _ queue: [Account], _ pacing: Pacing) async -> StopReason {
        var failures = 0
        for (index, account) in queue.enumerated() {
            if let cap = pacing.sessionCap, blocked >= cap { return .capReached }
            guard let profile = account.profile(on: platform), let url = URL(string: profile.url) else { continue }
            current = account.label(on: platform)
            liveActivity.update(current: current, blocked: blocked)
            requested = url
            webView.load(URLRequest(url: url))

            let status: BlockStatus
            switch await process(platform, profile) {
            case .cancelled: return .user
            case .loggedOut: return .loggedOut
            case .status(let result): status = result
            }
            progress.set(profile, status)
            if status == .blocked || status == .alreadyBlocked { await BlockCounter.shared.report(account, on: platform) }
            if status == .blocked {
                blocked += 1
                liveActivity.update(current: current, blocked: blocked)
            }
            failures = status == .failed ? failures + 1 : 0
            if failures >= Self.maxConsecutiveFailures { return .tooManyFailures }
            if let cap = pacing.sessionCap, blocked >= cap { return .capReached }
            if index == queue.count - 1 { break }

            let pause = status == .blocked
                ? Duration.seconds(Int.random(in: pacing.minDelay...max(pacing.minDelay, pacing.maxDelay)))
                : .milliseconds(min(300, pacing.maxDelay * 1000))
            if (try? await Task.sleep(for: pause)) == nil { return .user }
        }
        return .finished
    }

    private func process(_ platform: Platform, _ profile: Profile) async -> Outcome {
        guard let spec = platform.webSpec else { return .status(.failed) }
        let dictionary = spec.dictionary(for: profile)
        let clock = ContinuousClock()
        var step = Step.profile
        var stepStart = clock.now
        var deadline = stepStart + .seconds(15)
        var confirmRetried = false

        func enter(_ next: Step, timeout: Duration) {
            step = next
            stepStart = clock.now
            deadline = stepStart + timeout
        }

        while true {
            if (try? await Task.sleep(for: Self.poll)) == nil { return .cancelled }
            let now = clock.now
            let elapsed = now - stepStart
            guard let page = await call(dictionary) as? [String: Bool] else {
                if !diagnostics.hasPrefix("load failed") { diagnostics = "\(step) probe failed (\(webView.url?.absoluteString ?? "no url"))" }
                if now > deadline { return .status(.failed) }
                continue
            }
            let seen = { (key: String) in page[key] == true }
            diagnostics = "\(step) " + page.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value ? "✓" : "✗")" }.joined(separator: " ")

            switch step {
            case .profile:
                let shown = seen("shows")
                if shown && seen("blocked") { return .status(.alreadyBlocked) }
                if shown && seen("overflow") {
                    await call(dictionary, "overflow")
                    enter(.menu, timeout: .seconds(6))
                } else if seen("unavailable") && (shown || elapsed > .seconds(5)) {
                    return .status(.unavailable)
                } else if seen("gate") {
                    await call(dictionary, "gate")
                } else if !shown && elapsed > .seconds(5) && seen("loggedOut") {
                    return .loggedOut
                } else if now > deadline {
                    return .status(.failed)
                }
            case .menu:
                if seen("block") {
                    await call(dictionary, "block")
                    enter(.confirm, timeout: .seconds(6))
                } else if seen("unblock") {
                    return .status(.alreadyBlocked)
                } else if now > deadline {
                    return .status(.failed)
                }
            case .confirm:
                if seen("confirm") {
                    await call(dictionary, "confirm", "lowest")
                    enter(.verify, timeout: .seconds(8))
                } else if seen("blocked") {
                    return .status(.blocked)
                } else if now > deadline {
                    return .status(.failed)
                }
            case .verify:
                if seen("blocked") {
                    return .status(.blocked)
                } else if seen("confirm") && !confirmRetried && elapsed > .seconds(2) {
                    confirmRetried = true
                    await call(dictionary, "confirm", "lowest")
                } else if now > deadline {
                    return .status(.failed)
                }
            }
        }
    }

    @discardableResult
    private func call(_ spec: [String: Any], _ key: String? = nil, _ mode: String = "first") async -> Any? {
        let body = key == nil ? "return window.__bed?.probe(spec)" : "return window.__bed?.click(spec, key, mode)"
        return try? await webView.callAsyncJavaScript(
            body, arguments: ["spec": spec, "key": key ?? "", "mode": mode], contentWorld: .page
        )
    }

    private static let script = #"""
    window.__bed = (() => {
      const norm = s => (s || '').replace(/[\s\u00a0\u202f]+/g, ' ').trim().toLowerCase().replace(/\u2019/g, "'");
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
      };
      const labelsOf = el => [norm(el.getAttribute('aria-label')), norm(el.innerText), norm(el.querySelector('svg[aria-label]')?.getAttribute('aria-label'))];
      const controls = 'a,button,[role=button],[role=menuitem],[role=link],[role=option]';
      const find = (target, mode) => {
        let hits = target.selectors.flatMap(sel => [...document.querySelectorAll(sel)]).filter(visible);
        if (!hits.length && target.labels.length) {
          hits = [...document.querySelectorAll(controls)].filter(el => visible(el) && labelsOf(el).some(l => target.labels.includes(l)));
        }
        if (!hits.length) return null;
        return mode === 'lowest'
          ? hits.reduce((a, b) => b.getBoundingClientRect().bottom > a.getBoundingClientRect().bottom ? b : a)
          : hits[0];
      };
      const targets = ['overflow', 'block', 'confirm', 'unblock', 'gate'];
      return {
        probe(spec) {
          const text = norm(document.body?.innerText);
          const result = {
            shows: new RegExp(spec.marker).test(text),
            blocked: !!find(spec.blockedProfile),
            unavailable: spec.unavailable.some(t => text.includes(t)),
            loggedOut: !!find(spec.loggedOut),
          };
          for (const key of targets) result[key] = !!find(spec[key]);
          return result;
        },
        click(spec, key, mode) {
          const el = find(spec[key], mode);
          el?.click();
          return !!el;
        },
      };
    })();
    """#
}
