import Foundation

@MainActor
class ProjectsStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var error: String?

    static let baseURL = "http://100.97.249.32:8094"

    func load() async {
        guard let url = URL(string: "\(Self.baseURL)/projects") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
