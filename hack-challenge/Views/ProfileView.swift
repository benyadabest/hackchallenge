import SwiftUI

struct ProfileView: View {
    @Environment(UserSession.self) private var session
    @State private var posts: [ImagePost] = []
    @State private var error: APIError?
    @State private var showLogin = false
    @State private var initialLoadDone = false

    var body: some View {
        NavigationStack {
            Group {
                if !session.isLoggedIn {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Log in to see your profile")
                            .foregroundStyle(.secondary)
                    }
                    .onAppear { showLogin = true }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(session.user!.username)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("\(posts.count) images")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            if posts.isEmpty && initialLoadDone {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("Your generated images will appear here.")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                ImageGrid(posts: posts) { post in
                                    selectedPost = post
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await loadPosts()
                    }
                    .task {
                        if !initialLoadDone {
                            await loadPosts()
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedPost) { post in
                DetailView(post: post, isOwner: true) { deletedID in
                    posts.removeAll { $0.id == deletedID }
                }
            }
            .toolbar {
                if session.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Logout") {
                            session.logout()
                            posts = []
                            initialLoadDone = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            UsernameSheet(isPresented: $showLogin)
                .environment(session)
                .onDisappear {
                    if session.isLoggedIn {
                        Task { await loadPosts() }
                    }
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
            Task { await loadPosts() }
        }
    }

    @State private var selectedPost: ImagePost?

    private func loadPosts() async {
        guard let user = session.user else { return }
        do {
            posts = try await APIService.shared.fetchUserImages(userID: user.id, viewerID: user.id)
        } catch let err as APIError {
            error = err
        } catch {}
        initialLoadDone = true
    }
}
