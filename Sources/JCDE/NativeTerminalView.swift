import SwiftUI
import SwiftTerm

struct NativeTerminalView: UIViewRepresentable {
    let project: Project
    var isActive: Bool = true
    var focusTrigger: Int = 0

    func makeUIView(context: Context) -> JCDETerminalHostView {
        let view = JCDETerminalHostView(frame: .zero)
        view.connect(projectKey: project.key)
        return view
    }

    func updateUIView(_ uiView: JCDETerminalHostView, context: Context) {
        uiView.isActiveTab = isActive
        if isActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                uiView.becomeFirstResponder()
            }
        }
    }
}

class JCDETerminalHostView: TerminalView, TerminalViewDelegate {
    private var wsTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    var isActiveTab: Bool = true

    private var fontSize: CGFloat {
        get { CGFloat(UserDefaults.standard.float(forKey: "termFontSize").nonZero ?? 16) }
        set { UserDefaults.standard.set(Float(newValue), forKey: "termFontSize") }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        terminalDelegate = self
        nativeBackgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(claimFocus))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.isActiveTab else { return }
                self.becomeFirstResponder()
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        } else {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }

    @objc private func appDidBecomeActive() {
        guard isActiveTab else { return }
        for delay in [0.1, 0.3, 0.6, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isActiveTab, !self.isFirstResponder else { return }
                self.becomeFirstResponder()
            }
        }
    }

    @objc func claimFocus() {
        guard isActiveTab else { return }
        if !isFirstResponder { becomeFirstResponder() }
    }

    func connect(projectKey: String) {
        let urlString = "ws://\(ProjectsStore.baseHost)/projects/\(projectKey)/terminal"
        guard let url = URL(string: urlString) else { return }
        wsSession = URLSession(configuration: .default)
        wsTask = wsSession?.webSocketTask(with: url)
        wsTask?.resume()
        receive()
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

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard g.state == .ended else { return }
        let newSize = (fontSize * g.scale).clamped(to: 10...32)
        fontSize = newSize
        font = UIFont.monospacedSystemFont(ofSize: newSize, weight: .regular)
    }

    // MARK: - TerminalViewDelegate

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

    deinit {
        wsTask?.cancel()
    }
}

private extension Float {
    var nonZero: Float? { self == 0 ? nil : self }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
