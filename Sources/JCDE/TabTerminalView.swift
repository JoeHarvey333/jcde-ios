import SwiftUI

struct TabTerminalView: View {
    @Binding var openProjects: [Project]
    @Binding var activeProject: Project?
    @Environment(\.dismiss) private var dismiss
    @State private var showProjectPicker = false
    @State private var newSessionTrigger = 0
    @State private var showNewSessionConfirm = false
    @State private var focusTrigger = 0
    @State private var showTapToType = false
    @State private var didBackground = false
    @State private var sendBytesAction: ((Data) -> Void)? = nil
    @State private var focusAction: (() -> Void)? = nil
    @StateObject private var store = ProjectsStore()

    let controlKeys: [(String, [UInt8])] = [
        ("◀", [0x1b, 0x5b, 0x44]),
        ("▶", [0x1b, 0x5b, 0x43]),
        ("▲", [0x1b, 0x5b, 0x41]),
        ("▼", [0x1b, 0x5b, 0x42]),
        ("Esc", [0x1b]),
        ("Tab", [0x09]),
        ("^C", [0x03]),
        ("^A", [0x01]),
        ("^E", [0x05]),
        ("^B", [0x02]),
        ("^D", [0x04]),
        ("^L", [0x0c]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar — sits below status bar
            HStack(spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(openProjects) { project in
                            TabButton(
                                project: project,
                                isActive: activeProject?.key == project.key,
                                onSelect: { activeProject = project },
                                onClose: { closeTab(project) }
                            )
                        }
                    }
                }

                if let urlString = activeProject?.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Text("Open ↗")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "7B7BFF"))
                            .padding(.horizontal, 8)
                    }
                }

                Button { showNewSessionConfirm = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }

                Button { showProjectPicker = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }
            }
            .frame(height: 44)
            .background(Color(hex: "16161E"))
            .padding(.top, safeAreaTop)

            Rectangle().fill(Color(hex: "2A2A35")).frame(height: 1)

            // Terminal views
            ZStack {
                ForEach(openProjects) { project in
                    NativeTerminalView(
                        project: project,
                        isActive: activeProject?.key == project.key,
                        newSessionTrigger: activeProject?.key == project.key ? newSessionTrigger : 0,
                        focusTrigger: activeProject?.key == project.key ? focusTrigger : 0,
                        sendBytesAction: $sendBytesAction,
                        focusAction: $focusAction
                    )
                }

                // Tap-to-type overlay — only after returning from background
                if showTapToType {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showTapToType = false
                            focusAction?()
                        }
                        .overlay(
                            Text("Tap to type")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "7B7BFF").opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "22222A").opacity(0.9))
                                .cornerRadius(10)
                                .padding(.bottom, 60),
                            alignment: .bottom
                        )
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)

            // Control bar — always visible, not attached to keyboard
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(controlKeys, id: \.0) { key in
                            Button {
                                sendBytesAction?(Data(key.1))
                            } label: {
                                Text(key.0)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color(hex: "B0B0FF"))
                                    .frame(height: 32)
                                    .padding(.horizontal, 10)
                                    .background(Color(hex: "1E1E28"))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "33333D"), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 44)
                // Safe area spacer below control bar (above home indicator)
                Color(hex: "16161E").frame(height: safeAreaBottom)
            }
            .background(Color(hex: "16161E"))
        }
        .background(Color(hex: "0E0E12"))
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .sheet(isPresented: $showProjectPicker) {
            ProjectPickerSheet(projects: store.projects, openKeys: Set(openProjects.map { $0.key })) { project in
                if !openProjects.contains(where: { $0.key == project.key }) {
                    openProjects.append(project)
                }
                activeProject = project
                showProjectPicker = false
            }
        }
        .task { await store.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            didBackground = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if didBackground {
                didBackground = false
                showTapToType = true
            }
        }
        .confirmationDialog(
            "Start a new Claude session for \(activeProject?.name ?? "this project")?",
            isPresented: $showNewSessionConfirm,
            titleVisibility: .visible
        ) {
            Button("New Session", role: .destructive) { newSessionTrigger += 1 }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current session and context will be cleared. Chat history is preserved.")
        }
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    private func closeTab(_ project: Project) {
        openProjects.removeAll { $0.key == project.key }
        if activeProject?.key == project.key {
            activeProject = openProjects.last
        }
        if openProjects.isEmpty { dismiss() }
    }
}

struct ProjectPickerSheet: View {
    let projects: [Project]
    let openKeys: Set<String>
    let onSelect: (Project) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(projects) { project in
                Button {
                    onSelect(project)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: project.color))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .foregroundColor(.white)
                        Spacer()
                        if openKeys.contains(project.key) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(hex: "7B7BFF"))
                                .font(.system(size: 12))
                        }
                    }
                }
                .listRowBackground(Color(hex: "22222A"))
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "0E0E12"))
            .navigationTitle("Open Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "7B7BFF"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TabButton: View {
    let project: Project
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 7, height: 7)
            Text(project.name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .white : Color(hex: "666670"))
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "555560"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(isActive ? Color(hex: "22222A") : Color.clear)
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(Color(hex: project.color))
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
