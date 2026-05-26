import SwiftUI

struct ContentView: View {
    @StateObject private var store = ProjectsStore()
    @State private var selected: Project?

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.projects) { project in
                        ProjectCard(project: project)
                            .onTapGesture { selected = project }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("JCDE")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(hex: "0E0E12"))
            .fullScreenCover(item: $selected) { project in
                TerminalView(project: project)
            }
        }
        .task { await store.load() }
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
