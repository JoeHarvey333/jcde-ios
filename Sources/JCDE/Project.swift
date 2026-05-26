import Foundation

struct Project: Codable, Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let color: String
    let host: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case key, name, color, host, url
    }
}
