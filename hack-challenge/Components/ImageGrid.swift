import SwiftUI

struct ImageGrid: View {
    let posts: [ImagePost]
    let onTap: (ImagePost) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(posts) { post in
                AsyncImage(url: URL(string: post.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color(.systemGray5)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            )
                    default:
                        Color(.systemGray6)
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .onTapGesture { onTap(post) }
                .accessibilityLabel(post.prompt)
                .accessibilityHint("Double-tap to view detail")
            }
        }
    }
}
