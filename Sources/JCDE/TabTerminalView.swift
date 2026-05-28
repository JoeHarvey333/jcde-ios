import SwiftUI

struct TabTerminalView: View {
    @Binding var openProjects: [Project]
    @Binding var activeProject: Project?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16))
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
            }
            .frame(height: 44)
            .background(Color(hex: "16161E"))

            Rectangle()
                .fill(Color(hex: "2A2A35"))
                .frame(height: 1)

            // Terminal views — all alive, only active visible
            ZStack {
                ForEach(openProjects) { project in
                    NativeTerminalView(project: project, isActive: activeProject?.key == project.key)
                        .opacity(activeProject?.key == project.key ? 1 : 0)
                        .allowsHitTesting(activeProject?.key == project.key)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(Color(hex: "0E0E12"))
        .preferredColorScheme(.dark)
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
