import UIKit

struct ImagePost: Identifiable, Codable, Hashable {
    let id: UUID
    let imageUrl: String
    let prompt: String
    let username: String?
    let isPublic: Bool?
    let createdAt: Date

    var localImage: UIImage? = nil

    enum CodingKeys: String, CodingKey {
        case id, imageUrl, prompt, username, isPublic, createdAt
    }

    static func == (lhs: ImagePost, rhs: ImagePost) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let stockPosts: [ImagePost] = {
        let items: [(asset: String, prompt: String, username: String)] = [
            ("stock-wrestler", "Wrestling champion portrait", "athlete_pro"),
            ("stock-astronaut", "Astronaut in a cosmic galaxy", "space_art"),
            ("stock-soccer", "Soccer star on the pitch", "goal_scorer"),
            ("stock-jedi", "Jedi knight with lightsaber", "jedi_fan"),
        ]

        return items.enumerated().map { index, item in
            ImagePost(
                id: UUID(),
                imageUrl: "",
                prompt: item.prompt,
                username: item.username,
                isPublic: true,
                createdAt: Date().addingTimeInterval(TimeInterval(-index * 3600)),
                localImage: UIImage(named: item.asset)
            )
        }
    }()
}
