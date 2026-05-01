import SwiftUI

extension Notification.Name {
    static let postCreated = Notification.Name("postCreated")
}

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "house")
                }
                .tag(0)

            CameraTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(2)
        }
    }
}

#Preview {
    RootTabView()
        .environment(UserSession())
}
