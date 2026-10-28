import SwiftUI
import WebKit

/// Signs in through its own web view; it shares the default website data store with the runner's, so the session carries over.
struct LoginSheet: View {
    let platform: Platform
    @State private var webView = WKWebView(frame: .zero, configuration: .site())
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebContainer(webView: webView)
                .navigationTitle(platform.label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(.commonClose) { dismiss() } }
        }
        .onAppear { webView.load(URLRequest(url: platform.loginURL)) }
    }
}
