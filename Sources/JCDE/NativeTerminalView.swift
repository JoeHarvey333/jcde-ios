import SwiftUI
import SwiftTerm
import UIKit

struct NativeTerminalView: UIViewRepresentable {
    let project: Project
    var isActive: Bool = true
    var newSessionTrigger: Int = 0

    func makeUIView(context: Context) -> JCDETerminalHostView {
        let view = JCDETerminalHostView(frame: .zero)
        view.connect(projectKey: project.key)
        return view
    }

    func updateUIView(_ uiView: JCDETerminalHostView, context: Context) {
        let coord = context.coordinator

        uiView.isHidden = !isActive
        uiView.isActiveTab = isActive

        if newSessionTrigger != coord.lastNewSessionTrigger {
            coord.lastNewSessionTrigger = newSessionTrigger
            uiView.newSession()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {
        var lastNewSessionTrigger = 0
    }
}

// MARK: - Control Key Bar

class TerminalControlBar: UIView {
    var onKey: ((Data) -> Void)?

    private let keys: [(String, Data)] = [
        ("◀", Data([0x1b, 0x5b, 0x44])),
        ("▶", Data([0x1b, 0x5b, 0x43])),
        ("▲", Data([0x1b, 0x5b, 0x41])),
        ("▼", Data([0x1b, 0x5b, 0x42])),
        ("Esc", Data([0x1b])),
        ("Tab", Data([0x09])),
        ("^C",  Data([0x03])),
        ("^A",  Data([0x01])),
        ("^E",  Data([0x05])),
        ("^B",  Data([0x02])),
        ("^D",  Data([0x04])),
        ("^L",  Data([0x0c])),
    ]

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        backgroundColor = UIColor(red: 0.086, green: 0.086, blue: 0.11, alpha: 1)

        let scroll = UIScrollView(frame: bounds)
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.showsHorizontalScrollIndicator = false
        addSubview(scroll)

        var x: CGFloat = 8
        for (label, data) in keys {
            let btn = UIButton(type: .system)
            btn.setTitle(label, for: .normal)
            btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            btn.setTitleColor(UIColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 1), for: .normal)
            btn.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1)
            btn.layer.cornerRadius = 6
            let w = max(44, (btn.intrinsicContentSize.width + 20))
            btn.frame = CGRect(x: x, y: 6, width: w, height: 32)
            let capture = data
            btn.addAction(UIAction { [weak self] _ in self?.onKey?(capture) }, for: .touchUpInside)
            scroll.addSubview(btn)
            x += w + 8
        }
        scroll.contentSize = CGSize(width: x, height: 44)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Keyboard Proxy

class KeyboardProxy: UITextField, UITextFieldDelegate {
    var onBytes: ((Data) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        alpha = 0.011  // invisible but within bounds so becomeFirstResponder works
        delegate = self
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
        keyboardType = .asciiCapable
        returnKeyType = .default
    }

    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeFirstResponder: Bool { true }
    override var hasText: Bool { true } // ensures backspace is always delivered

    func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty {
            onBytes?(Data([0x7f])) // backspace
        } else {
            onBytes?(string.data(using: .utf8) ?? Data())
        }
        return false
    }

    func textFieldShouldReturn(_ tf: UITextField) -> Bool {
        onBytes?(Data([0x0d]))
        return false
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }
            switch key.keyCode {
            case .keyboardDeleteOrBackspace:
                onBytes?(Data([0x7f]))
                return
            case .keyboardReturnOrEnter:
                onBytes?(Data([0x0d]))
                return
            case .keyboardTab:
                onBytes?(Data([0x09]))
                return
            case .keyboardEscape:
                onBytes?(Data([0x1b]))
                return
            default:
                break
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

// MARK: - Terminal Host View

class JCDETerminalHostView: TerminalView, TerminalViewDelegate {
    private var wsTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    var isActiveTab: Bool = true
    private var projectKey: String?

    private let keyProxy = KeyboardProxy()
    private let controlBar = TerminalControlBar()

    override init(frame: CGRect) {
        super.init(frame: frame)
        terminalDelegate = self
        nativeBackgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        font = UIFont.monospacedSystemFont(ofSize: 18, weight: .regular)

        // Proxy keyboard setup
        controlBar.onKey = { [weak self] data in self?.sendBytes(data) }
        keyProxy.onBytes = { [weak self] data in self?.sendBytes(data) }
        keyProxy.inputAccessoryView = controlBar
        addSubview(keyProxy)

        let tap = UITapGestureRecognizer(target: self, action: #selector(focusKeyboard))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    // Prevent iOS from scrolling the terminal when keyProxy becomes first responder
    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        guard rect != keyProxy.frame else { return }
        super.scrollRectToVisible(rect, animated: animated)
    }

    @objc func focusKeyboard() {
        keyProxy.becomeFirstResponder()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.isActiveTab else { return }
                self.focusKeyboard()
            }
            NotificationCenter.default.addObserver(self, selector: #selector(onAppForeground),
                name: UIApplication.didBecomeActiveNotification, object: nil)
        } else {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }

    @objc private func onAppForeground() {
        guard isActiveTab else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.isActiveTab else { return }
            _ = self.keyProxy.becomeFirstResponder()
        }
    }

    func connect(projectKey: String) {
        self.projectKey = projectKey
        let urlString = "ws://\(ProjectsStore.baseHost)/projects/\(projectKey)/terminal"
        guard let url = URL(string: urlString) else { return }
        wsSession = URLSession(configuration: .default)
        wsTask = wsSession?.webSocketTask(with: url)
        wsTask?.resume()
        receive()
    }

    func newSession() {
        wsTask?.cancel()
        wsTask = nil
        guard let key = projectKey,
              let url = URL(string: "http://\(ProjectsStore.baseHost)/projects/\(key)/terminal") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.async { self?.connect(projectKey: key) }
        }.resume()
        feed(text: "\r\n\u{1b}[2m[starting new session…]\u{1b}[0m\r\n")
    }

    private func sendBytes(_ data: Data) {
        wsTask?.send(.data(data)) { _ in }
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
                @unknown default: break
                }
                self.receive()
            case .failure: break
            }
        }
    }

    // MARK: - TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        // SwiftTerm toolbar keys (arrows etc.) still come through here
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
        NotificationCenter.default.removeObserver(self)
    }
}

