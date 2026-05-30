import Foundation

@MainActor
class ProjectsStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var error: String?

    static let baseHost = "100.97.249.32:8094"
    static let baseURL = "http://\(baseHost)"

    func load() async {
        guard let url = URL(string: "\(Self.baseURL)/projects") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reorder(keys: [String]) async {
        guard let url = URL(string: "\(Self.baseURL)/projects/reorder") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["keys": keys])
        _ = try? await URLSession.shared.data(for: req)
    }
}
