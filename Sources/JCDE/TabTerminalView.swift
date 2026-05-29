import SwiftUI

struct TabTerminalView: View {
    @Binding var openProjects: [Project]
    @Binding var activeProject: Project?
    @Environment(\.dismiss) private var dismiss
    @State private var showProjectPicker = false
    @State private var focusTrigger = 0
    @State private var newSessionTrigger = 0
    @State private var showNewSessionConfirm = false
    @StateObject private var store = ProjectsStore()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                // Grid icon — back to project list (keeps tabs alive)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }

                // Tabs
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

                // Open URL for active project
                if let urlString = activeProject?.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Text("Open ↗")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "7B7BFF"))
                            .padding(.horizontal, 8)
                    }
                }

                // New session button
                Button {
                    showNewSessionConfirm = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }

                // Keyboard restore button
                Button {
                    focusTrigger += 1
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }

                // + button to add a tab
                Button {
                    showProjectPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .frame(width: 44, height: 44)
                }
            }
            .frame(height: 44)
            .background(Color(hex: "16161E"))

            Rectangle()
                .fill(Color(hex: "2A2A35"))
                .frame(height: 1)

            // Terminal views — all alive, only active visible
            ZStack {
                ForEach(openProjects) { project in
                    NativeTerminalView(
                        project: project,
                        isActive: activeProject?.key == project.key,
                        focusTrigger: activeProject?.key == project.key ? focusTrigger : 0,
                        newSessionTrigger: activeProject?.key == project.key ? newSessionTrigger : 0
                    )
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard)
        }
        .background(Color(hex: "0E0E12"))
        .preferredColorScheme(.dark)
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

    private func closeTab(_ project: Project) {
        openProjects.removeAll { $0.key == project.key }
        if activeProject?.key == project.key {
            activeProject = openProjects.last
        }
        if openProjects.isEmpty {
            dismiss()
        }
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
