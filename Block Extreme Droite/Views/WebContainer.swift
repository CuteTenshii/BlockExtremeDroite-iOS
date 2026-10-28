import SwiftUI
import WebKit

struct WebContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

extension WKWebViewConfiguration {
    private static let hideBackButtons = #"""
    (() => {
      const style = document.createElement('style');
      style.textContent = [
        '[data-testid="app-bar-back"]',
        ...['back', 'go back', 'retour', 'précédent', 'revenir en arrière'].map(l => `[aria-label="${l}" i]`),
      ].join(',') + '{display:none !important}';
      document.documentElement.appendChild(style);
    })();
    """#

    /// The configuration for every web view of the app: the default data store, so sessions are shared, and the sites' own back arrows hidden.
    static func site() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.addUserScript(
            WKUserScript(source: hideBackButtons, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        return configuration
    }
}
