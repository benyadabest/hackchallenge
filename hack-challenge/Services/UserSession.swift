import SwiftUI
import Observation

@MainActor
@Observable
final class UserSession {
    var user: User?

    var isLoggedIn: Bool { user != nil }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let id = "nb.user.id"
        static let username = "nb.user.username"
        static let createdAt = "nb.user.createdAt"
    }

    init() {
        guard let idString = defaults.string(forKey: Keys.id),
              let id = UUID(uuidString: idString),
              let username = defaults.string(forKey: Keys.username),
              let createdAtString = defaults.string(forKey: Keys.createdAt),
              let createdAt = ISO8601DateFormatter().date(from: createdAtString)
        else { return }

        self.user = User(id: id, username: username, createdAt: createdAt)
    }

    func login(username: String) async throws {
        let user = try await APIService.shared.findOrCreateUser(username: username)
        self.user = user
        persist(user)
    }

    func logout() {
        defaults.removeObject(forKey: Keys.id)
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.createdAt)
        user = nil
    }

    private func persist(_ user: User) {
        defaults.set(user.id.uuidString, forKey: Keys.id)
        defaults.set(user.username, forKey: Keys.username)
        defaults.set(ISO8601DateFormatter().string(from: user.createdAt), forKey: Keys.createdAt)
    }
}
