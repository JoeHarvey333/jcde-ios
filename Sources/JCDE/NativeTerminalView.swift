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
        wv.scrollView.bouncesZoom = false
        let url = URL(string: "http://\(ProjectsStore.baseHost)/terminal-page/\(project.key)")!
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.isHidden = !isActive
    }
}
