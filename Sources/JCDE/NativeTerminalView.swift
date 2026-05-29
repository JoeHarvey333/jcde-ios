import SwiftUI
import WebKit

struct NativeTerminalView: UIViewRepresentable {
    let project: Project
    var isActive: Bool = true

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = true
        wv.backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        wv.scrollView.bounces = false
        // Cache-bust so WKWebView always fetches latest page from server
        let ts = Int(Date().timeIntervalSince1970)
        let url = URL(string: "http://\(ProjectsStore.baseHost)/projects/\(project.key)/terminal-native?v=\(ts)")!
        wv.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.isHidden = !isActive
    }
}
