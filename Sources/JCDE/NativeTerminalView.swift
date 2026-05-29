import SwiftUI
import SwiftTerm
import UIKit

// MARK: - SwiftTerm host view (one per project, owns its WebSocket)

final class JCDETerminalHostView: TerminalView, TerminalViewDelegate {
    private var wsTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    var isActiveTab: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        terminalDelegate = self
        nativeBackgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []

        let tap = UITapGestureRecognizer(target: self, action: #selector(focusSoon))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc func focusSoon() {
        guard isActiveTab, !isFirstResponder else { return }
        becomeFirstResponder()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.isActiveTab else { return }
                self.becomeFirstResponder()
            }
        }
    }

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
                    let bytes = [UInt8](data)
                    DispatchQueue.main.async { self.feed(byteArray: bytes[...]) }
                case .string(let text):
                    DispatchQueue.main.async { self.feed(text: text) }
                @unknown default:
                    break
                }
                self.receive()
            case .failure:
                break
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

// MARK: - UIKit container: holds all open tabs' terminals, only active visible.
// Single representable (no SwiftUI ZStack) so the active terminal's native
// scroll isn't intercepted by SwiftUI's gesture arena on iPadOS 26.

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

        // Remove closed tabs
        for (key, host) in hosts where !liveKeys.contains(key) {
            host.teardown()
            host.removeFromSuperview()
            hosts.removeValue(forKey: key)
        }
        // Add newly opened tabs (stay alive once created)
        for project in projects where hosts[project.key] == nil {
            let host = makeHost(project)
            addSubview(host)
            hosts[project.key] = host
        }
        // Show active on top, hide the rest — all remain connected
        for (key, host) in hosts {
            let isActive = (key == activeKey)
            host.isActiveTab = isActive
            host.isHidden = !isActive
            host.frame = bounds
            if isActive {
                bringSubviewToFront(host)
                host.focusSoon()
            }
        }
    }

    private func makeHost(_ project: Project) -> JCDETerminalHostView {
        let host = JCDETerminalHostView(frame: bounds)
        host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.connect(projectKey: project.key)
        return host
    }

    // Automates the "close/reopen the tab and it works" fix: on return to
    // foreground, rebuild the active tab's view fresh (reconnects, server
    // replays scrollback). Background tabs are left untouched.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { host.focusSoon() }
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
