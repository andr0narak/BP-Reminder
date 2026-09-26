import Combine
import SwiftUI
import WebKit

/// Holds the WKWebView and exposes navigation state to SwiftUI.
final class BrowserModel: ObservableObject {
    static let homeURL = URL(string: "https://www.google.com")!

    let webView: WKWebView
    @Published var addressText = ""
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var isLoading = false

    private var observers: [NSKeyValueObservation] = []

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true

        observers = [
            webView.observe(\.url, options: .new) { [weak self] view, _ in
                DispatchQueue.main.async { self?.addressText = view.url?.absoluteString ?? "" }
            },
            webView.observe(\.canGoBack, options: .new) { [weak self] view, _ in
                DispatchQueue.main.async { self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: .new) { [weak self] view, _ in
                DispatchQueue.main.async { self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.estimatedProgress, options: .new) { [weak self] view, _ in
                DispatchQueue.main.async { self?.progress = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: .new) { [weak self] view, _ in
                DispatchQueue.main.async { self?.isLoading = view.isLoading }
            },
        ]

        webView.load(URLRequest(url: Self.homeURL))
    }

    /// Loads a URL, or runs a Google search when the text doesn't look like one.
    func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url: URL?
        if trimmed.contains("://") {
            url = URL(string: trimmed)
        } else if trimmed.contains("."), !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)")
        } else {
            var components = URLComponents(string: "https://www.google.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            url = components.url
        }
        if let url { webView.load(URLRequest(url: url)) }
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reloadOrStop() { isLoading ? webView.stopLoading() : webView.reload() }
}

struct BrowserView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
