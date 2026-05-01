import SwiftUI

@main
struct hack_challengeApp: App {
    @State private var session = UserSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(session)
        }
    }
}
