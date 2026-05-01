import SwiftUI

struct ResultView: View {
    let image: UIImage
    let chipLabel: String
    let fullPrompt: String
    @Binding var selectedTab: Int
    let onDismiss: () -> Void

    @Environment(UserSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var isPublic = true
    @State private var state: LoadState = .idle
    @State private var savedToRoll = false

    enum LoadState {
        case idle
        case loading
        case loaded(ImagePost)
        case failed(APIError)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch state {
                case .idle:
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    Text("Style: \(chipLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle("Post to feed", isOn: $isPublic)
                        .padding(.horizontal)

                    Button {
                        generate()
                    } label: {
                        Text("🍌 Generate")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                case .loading:
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    Text("Style: \(chipLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView("Generating...")
                        .padding()

                case .loaded(let post):
                    AsyncImage(url: URL(string: post.imageUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fit)
                        case .failure:
                            Color(.systemGray5).overlay(Image(systemName: "photo"))
                        default:
                            ProgressView()
                        }
                    }
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Text("Style: \(chipLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        saveToRoll(post: post)
                    } label: {
                        Label(savedToRoll ? "Saved!" : "Save to Roll", systemImage: savedToRoll ? "checkmark" : "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(savedToRoll)
                    .padding(.horizontal)

                    Button {
                        NotificationCenter.default.post(name: .postCreated, object: nil)
                        onDismiss()
                        selectedTab = 0
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                case .failed(let err):
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    Text(err.errorDescription ?? "Something went wrong")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Retry") {
                        generate()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() {
        guard let user = session.user else { return }
        guard let encoded = image.encodedForUpload() else { return }

        state = .loading
        Task {
            do {
                let post = try await APIService.shared.generate(
                    userID: user.id,
                    prompt: fullPrompt,
                    imageData: encoded.data,
                    mimeType: encoded.mime,
                    isPublic: isPublic
                )
                state = .loaded(post)
            } catch let err as APIError {
                state = .failed(err)
            } catch {
                state = .failed(.network)
            }
        }
    }

    private func saveToRoll(post: ImagePost) {
        Task {
            guard let url = URL(string: post.imageUrl),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            savedToRoll = true
        }
    }
}
