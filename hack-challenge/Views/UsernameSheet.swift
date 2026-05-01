import SwiftUI

struct UsernameSheet: View {
    @Binding var isPresented: Bool
    @Environment(UserSession.self) private var session
    @State private var input = ""
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Spacer()

            Text("Enter a username\nto continue")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("username", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                submit()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
            .padding(.horizontal)

            Text("No password needed.\nWe'll find or create your account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .interactiveDismissDisabled()
    }

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            error = "Username can't be empty."
            return
        }
        guard trimmed.count <= 30 else {
            error = "Username must be 30 characters or fewer."
            return
        }
        guard trimmed.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil else {
            error = "Only letters, numbers, and underscores allowed."
            return
        }

        error = nil
        isSubmitting = true
        Task {
            do {
                try await session.login(username: trimmed)
                isPresented = false
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
