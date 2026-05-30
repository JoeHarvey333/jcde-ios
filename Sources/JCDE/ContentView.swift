import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectsStore()
    @State private var openProjects: [Project] = []
    @State private var activeProject: Project?

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    // Drag state
    @State private var draggingKey: String? = nil
    @State private var dragLocation: CGPoint = .zero
    @GestureState private var longPressActive = false

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
                                    .opacity(draggingKey == project.key ? 0.3 : 1.0)
                                    .scaleEffect(draggingKey == project.key ? 0.95 : 1.0)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: CardFrameKey.self,
                                                value: [project.key: geo.frame(in: .global)]
                                            )
                                        }
                                    )
                                    .onTapGesture {
                                        if draggingKey == nil { open(project) }
                                    }
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.4)
                                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                                            .onChanged { value in
                                                switch value {
                                                case .second(true, let drag):
                                                    if draggingKey == nil { draggingKey = project.key }
                                                    if let drag = drag {
                                                        dragLocation = drag.location
                                                    }
                                                default:
                                                    break
                                                }
                                            }
                                            .onEnded { _ in
                                                if draggingKey != nil {
                                                    let keys = store.projects.map { $0.key }
                                                    Task { await store.reorder(keys: keys) }
                                                    draggingKey = nil
                                                }
                                            }
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .onPreferenceChange(CardFrameKey.self) { frames in
                            guard let key = draggingKey else { return }
                            let loc = dragLocation
                            // Find which card the drag is over (not the dragged card)
                            if let target = frames.first(where: { $0.key != key && $0.value.contains(loc) }) {
                                guard let fromIdx = store.projects.firstIndex(where: { $0.key == key }),
                                      let toIdx = store.projects.firstIndex(where: { $0.key == target.key }) else { return }
                                if fromIdx != toIdx {
                                    withAnimation(.interactiveSpring()) {
                                        store.projects.move(fromOffsets: IndexSet(integer: fromIdx),
                                                            toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("JCDE")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "555560"))
                        }
                    }
                    .background(Color(hex: "0E0E12"))
                }
            }
        }
        .task { await store.load() }
    }

    private func open(_ project: Project) {
        if !openProjects.contains(where: { $0.key == project.key }) {
            openProjects.append(project)
        }
        activeProject = project
    }
}

private struct CardFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
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
