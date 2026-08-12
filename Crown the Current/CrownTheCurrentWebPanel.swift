import SwiftUI
import WebKit

struct CrownTheCurrentWebPanel: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black

        webView.scrollView.backgroundColor = .black

        // The branch presenting this runs dark so the status bar glyphs turn white; pin

        // the page itself back to light so that trait never reaches the site.

        webView.overrideUserInterfaceStyle = .light
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
