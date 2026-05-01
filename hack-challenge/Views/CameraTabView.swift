import SwiftUI

struct CameraTabView: View {
    @Binding var selectedTab: Int
    @Environment(UserSession.self) private var session
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            if let image = capturedImage {
                GenerateView(image: image, selectedTab: $selectedTab, onDismiss: {
                    capturedImage = nil
                })
            } else {
                VStack {
                    Text("Tap the camera tab to take a photo")
                        .foregroundStyle(.secondary)
                }
                .onAppear {
                    if session.isLoggedIn {
                        showCamera = true
                    } else {
                        showLogin = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showLogin) {
            UsernameSheet(isPresented: $showLogin)
                .environment(session)
                .onDisappear {
                    if session.isLoggedIn {
                        showCamera = true
                    }
                }
        }
    }
}
