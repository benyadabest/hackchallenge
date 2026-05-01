import SwiftUI

struct FeedView: View {
    @Environment(UserSession.self) private var session
    @State private var posts: [ImagePost] = []
    @State private var page = 1
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var error: APIError?
    @State private var initialLoadDone = false
    @State private var selectedFilter = "For you"

    private let filters = ["For you", "Following", "Trending", "Recent"]

    private var displayPosts: [ImagePost] {
        if posts.isEmpty {
            return ImagePost.stockPosts
        }
        return ImagePost.stockPosts + posts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { filter in
                                FilterChip(
                                    label: filter,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    MasonryGrid(posts: displayPosts) { post in
                        selectedPost = post
                    }
                    .padding(.horizontal, 8)

                    if isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .navigationTitle("nano banana")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedPost) { post in
                let isOwner = post.username == session.user?.username
                DetailView(post: post, isOwner: isOwner) { deletedID in
                    posts.removeAll { $0.id == deletedID }
                }
            }
            .refreshable {
                await refresh()
            }
            .task {
                if !initialLoadDone {
                    await refresh()
                }
            }
            .alert(item: $error) { err in
                Alert(
                    title: Text("Error"),
                    message: Text(err.errorDescription ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .postCreated)) { _ in
                Task { await refresh() }
            }
        }
    }

    @State private var selectedPost: ImagePost?

    private func refresh() async {
        page = 1
        hasMore = true
        do {
            let results = try await APIService.shared.fetchFeed(page: 1)
            posts = results
            hasMore = results.count >= 20
            page = 2
        } catch let err as APIError {
            error = err
        } catch {}
        initialLoadDone = true
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let results = try await APIService.shared.fetchFeed(page: page)
                posts.append(contentsOf: results)
                hasMore = results.count >= 20
                page += 1
            } catch let err as APIError {
                error = err
            } catch {}
            isLoadingMore = false
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(.label) : Color(.systemGray6))
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
