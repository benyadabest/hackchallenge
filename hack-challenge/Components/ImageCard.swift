import SwiftUI

struct ImageCard: View {
    let post: ImagePost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let localImage = post.localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: URL(string: post.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            ZStack {
                                Color(.systemGray5)
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                        default:
                            Color(.systemGray6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            if let username = post.username {
                Text("@\(username)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(post.prompt)
    }
}
