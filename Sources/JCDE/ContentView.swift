import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectsStore()
    @State private var openProjects: [Project] = []
    @State private var activeProject: Project?

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.projects) { project in
                        ProjectCard(project: project)
                            .onTapGesture { open(project) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
            .fullScreenCover(isPresented: Binding(
                get: { activeProject != nil },
                set: { if !$0 { activeProject = nil } }
            )) {
                TabTerminalView(openProjects: $openProjects, activeProject: $activeProject)
            }
        }
        .task { await store.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.makeKeyAndVisible()
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

                if project.url != nil {
                    Text("Open ↗")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "7B7BFF"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "7B7BFF").opacity(0.12))
                        .cornerRadius(6)
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
