import SwiftUI
import SwiftTerm
import UIKit

// MARK: - Terminal Host View
// VANILLA SwiftTerm — add NOTHING to it. SwiftTerm sets up its own gesture
// recognizers (single-tap → becomeFirstResponder for keyboard, pan → scroll,
// double/triple-tap → selection). Adding our own tap gesture or a separate
// KeyboardProxy steals first-responder status and BREAKS SwiftTerm's native
// scroll. The first working version touched nothing — so neither do we.

final class JCDETerminalHostView: TerminalView, TerminalViewDelegate {
    private var wsTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    var isActiveTab: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        terminalDelegate = self
        nativeBackgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    }

    required init?(coder: NSCoder) { fatalError() }

    func connect(projectKey: String) {
        let urlString = "ws://\(ProjectsStore.baseHost)/projects/\(projectKey)/terminal"
        guard let url = URL(string: urlString) else { return }
        wsSession = URLSession(configuration: .default)
        wsTask = wsSession?.webSocketTask(with: url)
        wsTask?.resume()
        receive()
    }

    func teardown() {
        wsTask?.cancel()
        wsTask = nil
    }

    private func receive() {
        wsTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .data(let data):
                    DispatchQueue.main.async { self.feed(byteArray: [UInt8](data)[...]) }
                case .string(let text):
                    DispatchQueue.main.async { self.feed(text: text) }
                @unknown default: break
                }
                self.receive()
            case .failure: break
            }
        }
    }

    // MARK: TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        wsTask?.send(.data(Data(data))) { _ in }
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        guard let json = try? JSONSerialization.data(withJSONObject: ["type": "resize", "cols": newCols, "rows": newRows]) else { return }
        var frame = Data([0x00])
        frame.append(json)
        wsTask?.send(.data(frame)) { _ in }
    }

    func scrolled(source: TerminalView, position: Double) {}
    func setTerminalTitle(source: TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    func bell(source: TerminalView) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    func clipboardCopy(source: TerminalView, content: Data) {}

    deinit { wsTask?.cancel() }
}

// MARK: - UIKit container: all open tabs live at once, only active visible.
// Hosts vanilla SwiftTerm views as subviews and toggles isHidden — it adds NO
// gestures to the terminals, so their native scroll/keyboard stay intact.

final class TerminalHostContainer: UIView {
    private var hosts: [String: JCDETerminalHostView] = [:]
    private var projects: [Project] = []
    private var activeKey: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appForeground),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    func sync(projects: [Project], activeKey: String?) {
        self.projects = projects
        self.activeKey = activeKey
        let liveKeys = Set(projects.map { $0.key })

        for (key, host) in hosts where !liveKeys.contains(key) {
            host.teardown()
            host.removeFromSuperview()
            hosts.removeValue(forKey: key)
        }
        for project in projects where hosts[project.key] == nil {
            let host = makeHost(project)
            addSubview(host)
            hosts[project.key] = host
        }
        for (key, host) in hosts {
            let isActive = (key == activeKey)
            host.isActiveTab = isActive
            host.isHidden = !isActive
            host.frame = bounds
            if isActive { bringSubviewToFront(host) }
        }
    }

    private func makeHost(_ project: Project) -> JCDETerminalHostView {
        let host = JCDETerminalHostView(frame: bounds)
        host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.connect(projectKey: project.key)
        return host
    }

    // Pop-back-in fix: rebuild the active tab fresh on foreground (automates the
    // "close/reopen the tab" trick). Server replays scrollback on reconnect.
    @objc private func appForeground() {
        guard let key = activeKey,
              let old = hosts[key],
              let project = projects.first(where: { $0.key == key }) else { return }
        old.teardown()
        old.removeFromSuperview()
        hosts.removeValue(forKey: key)

        let host = makeHost(project)
        host.isActiveTab = true
        host.frame = bounds
        addSubview(host)
        bringSubviewToFront(host)
        hosts[key] = host
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for host in hosts.values { host.frame = bounds }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

struct TerminalContainer: UIViewRepresentable {
    let projects: [Project]
    let activeKey: String?

    func makeUIView(context: Context) -> TerminalHostContainer {
        let c = TerminalHostContainer(frame: .zero)
        c.backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        c.sync(projects: projects, activeKey: activeKey)
        return c
    }

    func updateUIView(_ uiView: TerminalHostContainer, context: Context) {
        uiView.sync(projects: projects, activeKey: activeKey)
    }
}
