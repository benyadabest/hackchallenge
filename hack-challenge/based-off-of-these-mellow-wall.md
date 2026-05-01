# Nano Banana — iOS Implementation Plan

> **Audience**: this plan is intended to be executed in **Xcode / iOS-only context** (the iOS session does not have access to the backend repo). All backend file references are removed from the implementation phases. The "Backend API Reference" section below is the complete contract — treat it as the source of truth for what the API will return.

## Context

The Nano Banana iOS app generates AI-edited photos from a captured photo + a chosen style prompt, displays a public feed of generated images, and lets users delete their own posts.

A Node/Express backend exposing the API contract below is being maintained in a **separate repo and a separate session**. The iOS work in this plan assumes the prerequisite backend changes (listed below) have been completed in that other session before iOS implementation begins. The iOS plan only consumes the documented API; it never modifies backend code.

Two preexisting docs in the project guide UI layout and screen architecture: `nano-banana-frontend.md` (architecture) and `ui.md` (per-screen layouts). Both remain authoritative for layout/structure; this plan supersedes them where they diverged from what's actually being built (notably ProfileView's data source and ResultView's `is_public` flow — both reconciled below).

## Decisions locked in

| Decision | Choice |
|---|---|
| Backend gaps (is_public, per-user images) | Backend session will add both before iOS starts. iOS plan assumes contract below. |
| Backend host during iOS development | iOS Simulator → `http://localhost:3000`. Add `NSAllowsLocalNetworking` ATS exception. No deploy needed. |

---

## Backend Prerequisites

> **For the backend session, NOT this iOS session.** These changes must land in the backend repo before iOS implementation starts. Listed here only so the iOS plan can reference the post-change API contract.

1. **`POST /generate` accepts `is_public`** — destructure from body, default `true`, coerce to bool, pass into the `INSERT` instead of literal `true`.
2. **New `GET /users/:user_id/images?viewer_id=&page=&limit=`** — returns `[{ id, image_url, prompt, is_public, created_at }]`. If `viewer_id` matches `user_id`, include private posts; otherwise public only. Pagination matches `/feed` shape (`page` default 1, `limit` default 30).
3. **Use `process.env.PORT` in `app.listen`** — `app.listen(process.env.PORT || 3000, ...)`. Trivial fix, removes a deploy blocker later.
4. **Server runs locally on port 3000** during iOS dev, with the Postgres DB seeded via the existing schema.

iOS verification depends on (1) and (2) being present.

---

## Backend API Reference (contract iOS will consume)

All routes are JSON in/out. Base URL during dev: `http://localhost:3000`.

### `GET /feed?page=1&limit=20`
Public images, newest first. No auth.
```json
[
  { "id": "uuid", "image_url": "https://...", "prompt": "string",
    "username": "string", "created_at": "2026-04-26T19:28:00.000Z" }
]
```

### `GET /users/:username`
Find-or-create. Returns the user record (the `id` field IS the user_id — there is no separate `user_id`).
```json
{ "id": "uuid", "username": "string", "created_at": "2026-04-26T..." }
```

### `GET /users/:user_id/images?viewer_id=<uuid>&page=1&limit=30`
Per-user images. Owner (when `viewer_id == user_id`) sees public + private; others see public only. No `username` field — caller already knows it.
```json
[
  { "id": "uuid", "image_url": "https://...", "prompt": "string",
    "is_public": true, "created_at": "2026-04-26T..." }
]
```

### `POST /generate`
Body:
```json
{ "user_id": "uuid", "prompt": "string", "image_base64": "string",
  "mime_type": "image/jpeg", "is_public": true }
```
Returns 201:
```json
{ "id": "uuid", "image_url": "https://...", "prompt": "string", "created_at": "..." }
```
Errors: 400 (validation, mime type), 413 (>10MB base64), 429 (xAI rate limit), 502 (xAI down).

### `DELETE /images/:id`
Body: `{ "user_id": "uuid" }`. Returns `{ "success": true }` if owner, 403 if not, 404 if missing.

---

## iOS Project Structure

Existing scaffold: `hack-challenge.xcodeproj`, with `hack_challengeApp.swift` (`@main`) and `ContentView.swift` (placeholder "Hello, world!"). Bundle ID `bs.hack-challenge`, deployment target iOS 26.4, Swift 5.0, no SPM dependencies.

Add the following groups inside the `hack-challenge/` source folder:

```
hack-challenge/
├── hack_challengeApp.swift          [modify: inject UserSession, render RootTabView]
├── ContentView.swift                 [REPLACE: becomes RootTabView]
├── Models/
│   ├── ImagePost.swift              [new]
│   └── User.swift                   [new]
├── Services/
│   ├── APIService.swift             [new]
│   └── UserSession.swift            [new]
├── Views/
│   ├── FeedView.swift               [new]
│   ├── CameraView.swift             [new]
│   ├── GenerateView.swift           [new]
│   ├── ResultView.swift             [new]
│   ├── DetailView.swift             [new]
│   ├── ProfileView.swift            [new]
│   └── UsernameSheet.swift          [new]
└── Components/
    ├── ImageCard.swift              [new]
    ├── PromptChip.swift             [new]
    └── ImageGrid.swift              [new]
```

`ContentView.swift` gets repurposed: rename the struct to `RootTabView` and replace its body with a `TabView { FeedView(); CameraTabView(); ProfileView() }`. Update `WindowGroup` in `hack_challengeApp.swift` to render `RootTabView()`.

### Info.plist additions

Add via Xcode → target → **Info** tab → **Custom iOS Target Properties**:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
<key>NSCameraUsageDescription</key>
<string>Capture a photo to transform with AI.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save your generated images to your photo library.</string>
```

`NSAllowsLocalNetworking` permits cleartext HTTP to localhost without globally disabling ATS — narrower and safer than `NSAllowsArbitraryLoads`.

---

## Phase 1 — Models + Networking

### Models

**`Models/ImagePost.swift`** (covers both feed and per-user-images responses with optional fields):
```swift
struct ImagePost: Identifiable, Codable, Hashable {
    let id: UUID
    let imageUrl: String
    let prompt: String
    let username: String?      // present from /feed, nil from /users/:id/images
    let isPublic: Bool?        // present from /users/:id/images, nil from /feed
    let createdAt: Date
}
```

**`Models/User.swift`**:
```swift
struct User: Codable, Hashable {
    let id: UUID
    let username: String
    let createdAt: Date
}
```

The `id` field on `User` IS the user_id. Do not invent a separate `user_id` property — the API doesn't return one.

### `Services/APIService.swift`

- Final class with a static `shared` singleton. Marked `@MainActor` is fine for simplicity; methods are `async throws`.
- `private let baseURL = URL(string: "http://localhost:3000")!`
- Shared `JSONDecoder` configured with:
  - `keyDecodingStrategy = .convertFromSnakeCase` (maps `image_url` → `imageUrl`, `is_public` → `isPublic`, etc.)
  - `dateDecodingStrategy = .iso8601`
- Methods:
  - `fetchFeed(page: Int = 1, limit: Int = 20) async throws -> [ImagePost]`
  - `findOrCreateUser(username: String) async throws -> User`
  - `fetchUserImages(userID: UUID, viewerID: UUID?, page: Int = 1, limit: Int = 30) async throws -> [ImagePost]`
  - `generate(userID: UUID, prompt: String, imageData: Data, mimeType: String, isPublic: Bool) async throws -> ImagePost` (encodes `imageData` as base64 internally)
  - `deleteImage(id: UUID, userID: UUID) async throws`
- Typed errors for view-layer rendering:
  ```swift
  enum APIError: LocalizedError {
      case http(status: Int, message: String?)
      case network
      case decoding
      case payloadTooLarge
      case rateLimited
      var errorDescription: String? { ... }
  }
  ```
  Map status codes from the contract: 400/403/404 → `.http`, 413 → `.payloadTooLarge`, 429 → `.rateLimited`, ≥500 → `.http`, URLSession errors → `.network`, `JSONDecoder` errors → `.decoding`.

### `Services/UserSession.swift`

- `@MainActor final class UserSession: ObservableObject`. Inject at app root via `.environmentObject`.
- `@Published var user: User?` — derived `var isLoggedIn: Bool { user != nil }`.
- Persists to `UserDefaults` keys: `nb.user.id`, `nb.user.username`, `nb.user.createdAt`.
- `init()` loads from UserDefaults; if all three keys present and valid, restores `user`.
- `func login(username: String) async throws` — calls `APIService.shared.findOrCreateUser`, stores result, sets `user`.
- `func logout()` — clears the three UserDefaults keys, sets `user = nil`.

### Image encoding helper

Used in Phase 3 (Generate flow). Backend caps base64 at ~10 MB.

```swift
extension UIImage {
    func encodedForUpload(maxEdge: CGFloat = 1024, quality: CGFloat = 0.8)
        -> (base64: String, mime: String)?
    {
        // 1. Compute resize ratio so longest edge ≤ maxEdge, preserving aspect.
        // 2. Render scaled UIImage via UIGraphicsImageRenderer.
        // 3. jpegData(compressionQuality: quality) → Data.
        // 4. data.base64EncodedString() → String.
        // 5. return (base64, "image/jpeg").
    }
}
```

---

## Phase 2 — Feed (no auth required)

- **`Components/ImageCard.swift`**: `AsyncImage(url:)` with placeholder + failure states; `@username` and prompt caption beneath. Card style per `ui.md` Section 1.
- **`Views/FeedView.swift`**:
  - State: `@State var posts: [ImagePost] = []`, `@State var page = 1`, `@State var isLoadingMore = false`, `@State var hasMore = true`, `@State var error: APIError?`.
  - `NavigationStack` wrapping `ScrollView` + `LazyVStack` of `ImageCard`s.
  - Tap pushes `DetailView` via `.navigationDestination(for: ImagePost.self)`.
  - `.refreshable { ... }` resets `page = 1`, reloads.
  - Infinite scroll: when the last `ImageCard` appears (`.onAppear` on the last item in the array), if `hasMore && !isLoadingMore`, fetch `page + 1`.
  - Bottom: small spinner while loading more, "no more posts" when `!hasMore`.
  - Error rendered via `.alert(item: $error)`.

---

## Phase 3 — Camera + Generate flow

### Important architectural decision: where the API call happens

The original frontend doc had GenerateView call `POST /generate`, then ResultView showed the result with a "Post to feed" toggle. But the toggle has to map to `is_public` in the request — which means it must be set **before** the call. So the flow is:

1. **GenerateView** collects inputs only (photo + selected chip) — does NOT call the API.
2. Tapping "🍌 Generate" navigates to **ResultView** in a "loading" state with the inputs.
3. **ResultView** has the `is_public` toggle and a "Save" / "Generate" button. The button is what calls `POST /generate` with the toggle's value, then renders the result.

This avoids needing a `PATCH` route or any backend-side mutation after the fact.

### Components and views

- **`Views/CameraView.swift`**: `UIViewControllerRepresentable` wrapping `UIImagePickerController`.
  - `sourceType = .camera` on device.
  - **Simulator fallback**: `#if targetEnvironment(simulator)` use `.photoLibrary` (sim has no camera). Gate this so device builds always use camera.
  - Coordinator implements `UIImagePickerControllerDelegate` + `UINavigationControllerDelegate`. On `didFinishPickingMediaWithInfo`, sets `@Binding var capturedImage: UIImage?` and dismisses.
- **`CameraTabView.swift`** (lives in `Views/` even if not in original tree): the camera tab's container.
  - State: `@State var capturedImage: UIImage?`
  - If `capturedImage == nil`: present `CameraView` via `.fullScreenCover`.
  - When set: push `GenerateView(image: capturedImage!)` via NavigationStack.
- **`Components/PromptChip.swift`**: rounded pill button. Props: `label: String`, `isSelected: Bool`, `onTap: () -> Void`. Selected state has filled background, unselected has outline.
- **`Views/GenerateView.swift`**:
  - Layout per `ui.md` Section 4.
  - Thumbnail of the captured photo at top.
  - Horizontal `ScrollView` of `PromptChip` for the 6 presets:
    - "Politician", "Cornellian", "Anime", "Oil Painting", "Astronaut", "Noir"
  - Each chip label maps to a fuller prompt string:
    ```swift
    static let promptMap: [String: String] = [
        "Politician": "Re-imagine this person as a 1960s political portrait, formal suit, oil-painted background",
        "Cornellian": "Re-imagine this person in Cornell University attire, autumn campus background, school colors",
        "Anime":      "Re-imagine this photo in anime style, vibrant colors, soft cel shading",
        "Oil Painting": "Render this photo as a classical oil painting, visible brushstrokes, dramatic lighting",
        "Astronaut":  "Re-imagine this person as a NASA astronaut in a spacesuit, Earth visible in background",
        "Noir":       "Render this photo in 1940s film noir style, high contrast black and white, dramatic shadows"
    ]
    ```
  - Single-select chip state: `@State var selectedChip: String?`.
  - "🍌 Generate" button: disabled until `selectedChip != nil`. On tap, navigate to `ResultView(image: capturedImage, chipLabel: selectedChip!, fullPrompt: promptMap[selectedChip!]!)`.

- **`Views/ResultView.swift`**:
  - Receives the captured `UIImage`, the chip label (for display), and the full prompt.
  - State machine:
    - `.idle` (initial — but actually we move straight to `.loading` on appear since the user clicked Generate)
    - `.loading` (calling `/generate`, show spinner per `ui.md` "Loading State")
    - `.loaded(ImagePost)` (show full image, "Style: \(chip)", Save-to-Roll, Post-to-feed toggle, Save button)
    - `.failed(APIError)` (show error banner, retry button)
  - On `.onAppear`, kick off `Task { try await generate() }`. The first call uses `isPublic: true` by default.
  - **Wait — `is_public` toggle problem**: If we call `/generate` on appear with a default value, then the user toggles, we'd need a PATCH. Alternative flow that respects the toggle:
    - On appear, render the inputs (photo + chip) but DON'T call the API.
    - Show a "Generate" CTA button instead of automatic loading.
    - User picks `is_public` toggle state, taps Generate → API call with that value.
    - Result renders below; "Save" pops back to Feed/Profile.
  - This is cleaner and matches user mental model. Adopt this version.
  - "Save to Camera Roll" button: `UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)`. Requires `NSPhotoLibraryAddUsageDescription` (set in Phase 1 Info.plist).
  - On Save: pop back to Feed tab via `@Environment(\.dismiss)` and a `NavigationStack` path binding, or by toggling a tab-selection state.

- Loading state UI per `ui.md` Section 4 ("Generate View — Loading State"): chips remain visible but disabled, button replaced by spinner.

### Camera flow auth gate

The Camera tab requires login (per existing frontend doc). If `!session.isLoggedIn`, present `UsernameSheet` as `.sheet` over `CameraTabView`. Sheet dismisses on successful login; tab content becomes interactive.

---

## Phase 4 — Profile + Detail

- **`Components/ImageGrid.swift`**: `LazyVGrid(columns: 3 GridItem(.flexible(), spacing: 4))`. Square thumbnails: `AsyncImage` clipped via `.aspectRatio(1, contentMode: .fill).frame(maxWidth: .infinity).clipped()`.
- **`Views/ProfileView.swift`**:
  - Reads `@EnvironmentObject session: UserSession`.
  - If `!session.isLoggedIn`: empty placeholder + auto-present `UsernameSheet`.
  - Header: `@\(session.user!.username)`, `\(posts.count) images`.
  - Body: `ImageGrid(posts: posts)` inside `NavigationStack`.
  - Calls `APIService.fetchUserImages(userID: session.user!.id, viewerID: session.user!.id)` so private posts come back.
  - `.refreshable` reloads page 1.
  - Tap thumbnail → push `DetailView`.
- **`Views/DetailView.swift`**:
  - Receives an `ImagePost`.
  - Layout per `ui.md` Section 6.
  - Full image, `@username` (or session.username if `username` is nil — for posts loaded from `/users/:id/images`), "Style: \(prompt)" (or just prompt text), formatted date.
  - Date format: `Date.formatted(date: .long, time: .omitted)` → "April 26, 2026" style.
  - **Ownership detection**: a post is owned by the viewer if it came from `/users/:user_id/images` while logged in OR if `post.username == session.user?.username`. Pass an explicit `isOwner: Bool` into DetailView from the parent (FeedView passes `false`/computed; ProfileView passes `true`) to avoid ambiguity.
  - If `isOwner`, show the 🗑 Delete button. Tap → `Alert` confirmation → `APIService.deleteImage(id: post.id, userID: session.user!.id)`.
  - Use a `var onDeleted: (UUID) -> Void` callback so the parent (Profile or Feed) can remove the post from its list and pop back.

---

## Phase 5 — Auth gate (`UsernameSheet`)

- **`Views/UsernameSheet.swift`**:
  - `@Binding var isPresented: Bool`, `@EnvironmentObject session: UserSession`.
  - State: `@State var input = ""`, `@State var isSubmitting = false`, `@State var error: String?`.
  - Layout per `ui.md` Section 2: drag handle, instruction text, `TextField("@username", text: $input)` with `.autocapitalization(.never)`, `.disableAutocorrection(true)`, leading "@" prefix shown but not part of `input`.
  - Validation before submit: trim whitespace; reject empty; length 1-30; regex `^[a-zA-Z0-9_]+$`. Show inline error if invalid.
  - "Continue" button: `Task { try await session.login(username: trimmed); isPresented = false }`.
  - On error, show inline message; do not dismiss.
  - Help text per `ui.md`: "No password needed. We'll find or create your account."

### Where the sheet is presented

- **Feed tab**: never presented (no auth required).
- **Camera tab**: presented if `!session.isLoggedIn` on tab appear.
- **Profile tab**: presented if `!session.isLoggedIn` on tab appear.

---

## Phase 6 — Polish

- **Loading skeletons**: gray rounded rectangle placeholder in `ImageCard` while `AsyncImage.phase` is `.empty`.
- **Empty states**:
  - FeedView (zero posts): "No posts yet — be the first to generate one."
  - ProfileView (zero posts): "Your generated images will appear here."
- **Error UX**: `.alert(item:)` driven by `@State var error: APIError?` on every screen that calls the API. Use `error.errorDescription` for the message body.
- **Accessibility**:
  - `accessibilityLabel(post.prompt)` on `ImageCard`.
  - `accessibilityHint("Double-tap to view detail")` on cards/thumbnails.
  - Chip selection state announced via `accessibilityValue`.
- **Pull-to-refresh** on Feed and Profile via `.refreshable`.

---

## Files to create/modify (iOS only)

**Modify:**
- `ContentView.swift` — replace placeholder body with `RootTabView` (TabView with Feed / Camera / Profile tabs).
- `hack_challengeApp.swift` — instantiate `UserSession`, inject via `.environmentObject`, render `RootTabView`.
- Project Info → ATS exception, camera + photo permission strings.

**Create:** all files listed in the project structure tree (Models/, Services/, Views/, Components/).

---

## Verification

> Prerequisite: backend session has completed all four items in "Backend Prerequisites" and the server is running on `localhost:3000` against a Postgres DB seeded with the schema. If iOS build fails to reach the backend, halt and confirm with the backend session before proceeding.

Smoke test, executed in iOS Simulator (iPhone 15 or later, iOS 26.x). Each step is a checkpoint — don't move on if it fails:

1. **Build + launch**: app cold-starts into a `TabView` with three tabs (Feed, Camera, Profile). No console errors.
2. **Feed tab**: shows empty state ("No posts yet"). Pull to refresh — no error alert.
3. **Profile tab**: prompts `UsernameSheet`. Enter `test1` → tap Continue → sheet dismisses, profile shows `@test1`, `0 images`.
4. **Force-quit + relaunch**: still on `@test1` (UserSession restored from UserDefaults).
5. **Camera tab**: pick a photo from sim library (sim has no camera). Photo lands on `GenerateView`.
6. Tap "Anime" chip → it shows selected state. Tap "🍌 Generate" → navigates to `ResultView`.
7. On `ResultView`, ensure "Post to feed" toggle is OFF, tap "Generate". Loading state shows. Result image appears. Tap "Save".
8. Pops back. **Profile** tab: image appears in 3-column grid. **Feed** tab: image does NOT appear (private).
9. Tap image in Profile → `DetailView` shows full image, `@test1`, prompt, date, AND a 🗑 Delete button.
10. Tap Delete → confirmation alert → confirm → returns to Profile, image is gone.
11. Repeat step 7 with toggle ON → image appears in BOTH Feed and Profile.
12. Switch to a different user (logout via long-press on header → Logout, or temporarily expose a logout button for testing). Log in as `test2`. Open Feed. Tap `test1`'s public image → `DetailView` shows NO Delete button.
13. **Save to Roll** button on a result → "Saved" feedback (image appears in sim's Photos app).

### Pass criteria

- All 13 checkpoints pass.
- No Xcode warnings for force unwraps in production paths (use guards/`if let`).
- No crashes on cold launch / tab switching / rapid pull-to-refresh.
- Network errors render readable alerts, never silent failures.

---

## Out of scope (intentionally)

Tracked separately, not blocking:
- Image caching beyond `AsyncImage`'s default URLCache.
- Offline support / queue-on-reconnect.
- Multi-user account switching UX (logout button is testing-only).
- Deep linking, share sheets, push notifications.
- Backend deploy (iOS dev runs against localhost only).
