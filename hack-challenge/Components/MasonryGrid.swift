import SwiftUI

struct MasonryGrid: View {
    let posts: [ImagePost]
    let onTap: (ImagePost) -> Void

    private var leftColumn: [ImagePost] {
        posts.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
    }

    private var rightColumn: [ImagePost] {
        posts.enumerated().compactMap { $0.offset % 2 == 1 ? $0.element : nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            LazyVStack(spacing: 8) {
                ForEach(leftColumn) { post in
                    MasonryCell(post: post)
                        .onTapGesture { onTap(post) }
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(rightColumn) { post in
                    MasonryCell(post: post)
                        .onTapGesture { onTap(post) }
                }
            }
        }
    }
}

private struct MasonryCell: View {
    let post: ImagePost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let localImage = post.localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    AsyncImage(url: URL(string: post.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                                .frame(height: 150)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                )
                        default:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .frame(height: 150)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
