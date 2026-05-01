import SwiftUI

struct DetailView: View {
    let post: ImagePost
    let isOwner: Bool
    var onDeleted: ((UUID) -> Void)?

    @Environment(UserSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var error: APIError?

    var displayUsername: String {
        post.username ?? session.user?.username ?? "unknown"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                                Color(.systemGray5)
                                    .frame(height: 300)
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            default:
                                Color(.systemGray6)
                                    .frame(height: 300)
                                    .overlay(ProgressView())
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("@\(displayUsername)")
                        .font(.headline)

                    Text("Style: \(post.prompt)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(post.createdAt, format: .dateTime.month(.wide).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                if isOwner {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Back")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this image?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(item: $error) { err in
            Alert(
                title: Text("Error"),
                message: Text(err.errorDescription ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func deletePost() {
        guard let user = session.user else { return }
        isDeleting = true
        Task {
            do {
                try await APIService.shared.deleteImage(id: post.id, userID: user.id)
                onDeleted?(post.id)
                dismiss()
            } catch let err as APIError {
                error = err
            } catch {
                self.error = .network
            }
            isDeleting = false
        }
    }
}
