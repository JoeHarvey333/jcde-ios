import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectsStore()
    @State private var openProjects: [Project] = []
    @State private var activeProject: Project?
    @State private var reordering = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Group {
            if activeProject != nil {
                // Plain view swap — NOT a modal. Avoids fullScreenCover's gesture
                // layer, which iPadOS 26 uses to intercept the terminal's scroll.
                TabTerminalView(openProjects: $openProjects, activeProject: $activeProject)
            } else {
                NavigationStack {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.projects) { project in
                                ProjectCard(project: project)
                                    .opacity(reordering ? 0.85 : 1.0)
                                    .overlay(alignment: .topTrailing) {
                                        if reordering {
                                            Image(systemName: "line.3.horizontal")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "555560"))
                                                .padding(10)
                                        }
                                    }
                                    .onTapGesture {
                                        if !reordering { open(project) }
                                    }
                                    .gesture(reordering ? dragGesture(for: project) : nil)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .scrollDisabled(reordering)
                    .navigationTitle("JCDE")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            if reordering {
                                Button("Done") {
                                    let keys = store.projects.map { $0.key }
                                    Task { await store.reorder(keys: keys) }
                                    reordering = false
                                }
                                .foregroundColor(Color(hex: "7B7BFF"))
                            } else {
                                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "555560"))
                            }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            if !reordering {
                                Button {
                                    reordering = true
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(hex: "555560"))
                                }
                            }
                        }
                    }
                    .background(Color(hex: "0E0E12"))
                }
            }
        }
        .task { await store.load() }
    }

    private func dragGesture(for project: Project) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard let fromIdx = store.projects.firstIndex(where: { $0.key == project.key }) else { return }
                // Find card under drag location using simple index estimation
                let x = value.location.x
                let col = x < UIScreen.main.bounds.width / 2 ? 0 : 1
                let cardHeight: CGFloat = 114 // 90 minHeight + 12 spacing + padding
                let gridTop: CGFloat = 140
                let row = max(0, Int((value.location.y - gridTop) / cardHeight))
                let toIdx = min(row * 2 + col, store.projects.count - 1)
                if toIdx != fromIdx {
                    withAnimation(.interactiveSpring()) {
                        store.projects.move(fromOffsets: IndexSet(integer: fromIdx),
                                            toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
                    }
                }
            }
    }

    private func open(_ project: Project) {
        if !openProjects.contains(where: { $0.key == project.key }) {
            openProjects.append(project)
        }
        activeProject = project
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 10, height: 10)

            Text(project.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(project.host.map { ".\($0.split(separator: ".").last ?? "92")" } ?? ".92")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "888896"))

                Spacer()

                if let urlString = project.url, let url = URL(string: urlString) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Text("Open ↗")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "7B7BFF"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "7B7BFF").opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .background(Color(hex: "22222A"))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "33333D"), lineWidth: 1))
        .cornerRadius(16)
    }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}
