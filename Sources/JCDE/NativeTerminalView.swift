import SwiftUI
import WebKit

/// A UIKit-managed container that holds one live WKWebView per open project.
/// All web views stay alive and connected (sessions keep streaming); only the
/// active one is visible and frontmost. Because SwiftUI sees a single view —
/// not a ZStack of competing representables — touch/scroll routing is clean on
/// iPadOS 26.
final class TerminalHostContainer: UIView {
    private var webViews: [String: WKWebView] = [:]

    func sync(projects: [Project], activeKey: String?) {
        let liveKeys = Set(projects.map { $0.key })

        // Tear down web views for projects that were closed
        for (key, wv) in webViews where !liveKeys.contains(key) {
            wv.removeFromSuperview()
            webViews.removeValue(forKey: key)
        }

        // Create a web view for any newly opened project (loads once, stays alive)
        for project in projects where webViews[project.key] == nil {
            let wv = makeWebView(for: project)
            addSubview(wv)
            webViews[project.key] = wv
        }

        // Show the active one on top, hide the rest — all remain connected
        for (key, wv) in webViews {
            let isActive = (key == activeKey)
            wv.isHidden = !isActive
            wv.frame = bounds
            if isActive { bringSubviewToFront(wv) }
        }
    }

    private func makeWebView(for project: Project) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: bounds, configuration: config)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.isOpaque = true
        wv.backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        wv.scrollView.isScrollEnabled = false   // JS (xterm.js) owns scrolling
        wv.scrollView.bounces = false
        var comps = URLComponents(string: "http://\(ProjectsStore.baseHost)/terminal-native.html")!
        let shortHost = project.host.map { ".\($0.split(separator: ".").last ?? "92")" } ?? ".92"
        comps.queryItems = [
            URLQueryItem(name: "key", value: project.key),
            URLQueryItem(name: "name", value: project.name),
            URLQueryItem(name: "host", value: shortHost),
        ]
        wv.load(URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData))
        return wv
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for wv in webViews.values { wv.frame = bounds }
    }
}

struct TerminalContainer: UIViewRepresentable {
    let projects: [Project]
    let activeKey: String?

    func makeUIView(context: Context) -> TerminalHostContainer {
        let c = TerminalHostContainer()
        c.backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        c.sync(projects: projects, activeKey: activeKey)
        return c
    }

    func updateUIView(_ uiView: TerminalHostContainer, context: Context) {
        uiView.sync(projects: projects, activeKey: activeKey)
    }
}
