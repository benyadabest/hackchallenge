import SwiftUI

struct GenerateView: View {
    let image: UIImage
    @Binding var selectedTab: Int
    let onDismiss: () -> Void

    @Environment(UserSession.self) private var session
    @State private var selectedChip: String?
    @State private var navigateToResult = false

    static let chipLabels = ["Politician", "Cornellian", "Anime", "Oil Painting", "Astronaut", "Noir"]

    static let promptMap: [String: String] = [
        "Politician": "Re-imagine this person as a 1960s political portrait, formal suit, oil-painted background",
        "Cornellian": "Re-imagine this person in Cornell University attire, autumn campus background, school colors",
        "Anime": "Re-imagine this photo in anime style, vibrant colors, soft cel shading",
        "Oil Painting": "Render this photo as a classical oil painting, visible brushstrokes, dramatic lighting",
        "Astronaut": "Re-imagine this person as a NASA astronaut in a spacesuit, Earth visible in background",
        "Noir": "Render this photo in 1940s film noir style, high contrast black and white, dramatic shadows"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Text("Choose a style")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Self.chipLabels, id: \.self) { label in
                            PromptChip(label: label, isSelected: selectedChip == label) {
                                selectedChip = label
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                NavigationLink(
                    destination: ResultView(
                        image: image,
                        chipLabel: selectedChip ?? "",
                        fullPrompt: Self.promptMap[selectedChip ?? ""] ?? "",
                        selectedTab: $selectedTab,
                        onDismiss: onDismiss
                    ),
                    isActive: $navigateToResult
                ) {
                    EmptyView()
                }

                Button {
                    navigateToResult = true
                } label: {
                    Text("🍌 Generate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedChip == nil)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Your Photo")
        .navigationBarTitleDisplayMode(.inline)
    }
}
