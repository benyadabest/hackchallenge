import Foundation

struct User: Codable, Hashable {
    let id: UUID
    let username: String
    let createdAt: Date
}
