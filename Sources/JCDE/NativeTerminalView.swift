import SwiftUI
import SwiftTerm

struct NativeTerminalView: UIViewRepresentable {
    let project: Project

    func makeUIView(context: Context) -> JCDETerminalHostView {
        let view = JCDETerminalHostView(frame: .zero)
        view.connect(projectKey: project.key)
        return view
    }

    func updateUIView(_ uiView: JCDETerminalHostView, context: Context) {}
}

class JCDETerminalHostView: SwiftTerm.TerminalView, SwiftTerm.TerminalViewDelegate {
    private var wsTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?

    override init(frame: CGRect) {
        super.init(frame: frame)
        terminalDelegate = self
        nativeBackgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.071, alpha: 1)
        font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
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

    private func receive() {
        wsTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .data(let data):
                    DispatchQueue.main.async { self.feed(byteArray: [UInt8](data)) }
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

    // MARK: - TerminalViewDelegate

    func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        wsTask?.send(.data(Data(data))) { _ in }
    }

    func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        guard let json = try? JSONSerialization.data(withJSONObject: ["type": "resize", "cols": newCols, "rows": newRows]) else { return }
        var frame = Data([0x00])
        frame.append(json)
        wsTask?.send(.data(frame)) { _ in }
    }

    func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
    func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
    func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}
    func bell(source: SwiftTerm.TerminalView) {}
    func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    func clip(source: SwiftTerm.TerminalView, content: Data) {}

    deinit {
        wsTask?.cancel()
    }
}
