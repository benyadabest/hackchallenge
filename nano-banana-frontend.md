# Nano Banana — iOS Frontend Implementation Plan

## Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Networking**: URLSession
- **Camera**: UIImagePickerController (via UIViewControllerRepresentable)
- **Local Storage**: UserDefaults (store username + user_id)
- **Min Target**: iOS 16+

---

## App Structure

```
NanaBanana/
├── App/
│   └── NanaBananaApp.swift
├── Models/
│   ├── ImagePost.swift
│   └── User.swift
├── Services/
│   ├── APIService.swift
│   └── UserSession.swift
├── Views/
│   ├── FeedView.swift
│   ├── CameraView.swift
│   ├── GenerateView.swift
│   ├── ResultView.swift
│   ├── DetailView.swift
│   ├── ProfileView.swift
│   └── UsernameSheet.swift
└── Components/
    ├── ImageCard.swift
    ├── PromptChip.swift
    └── ImageGrid.swift
```

---

## Screens & Navigation

```
TabView
├── Tab 1: Feed
│   └── FeedView
│       └── → DetailView (push)
├── Tab 2: Generate
│   ├── UsernameSheet (if not logged in)
│   └── CameraView
│       └── → GenerateView (push, passes captured photo)
│           └── → ResultView (push, passes generated image)
└── Tab 3: Profile
    ├── UsernameSheet (if not logged in)
    └── ProfileView
        └── → DetailView (push)
```

---

## Models

### `ImagePost`
```swift
struct ImagePost: Identifiable, Codable {
    let id: UUID
    let imageUrl: String
    let prompt: String
    let username: String
    let createdAt: Date
}
```

### `User`
```swift
struct User: Codable {
    let id: UUID
    let username: String
}
```

---

## Services

### `UserSession`
- Wraps `UserDefaults`
- Stores/retrieves `username` and `user_id`
- `var isLoggedIn: Bool`
- `func login(username:)` — calls `GET /users/:username`, saves result
- `func logout()` — clears UserDefaults

### `APIService`
- `func fetchFeed(page:) async throws -> [ImagePost]`
- `func findOrCreateUser(username:) async throws -> User`
- `func generate(userID:, prompt:, imageData:) async throws -> ImagePost`
- `func deleteImage(id:, userID:) async throws`

---

## Screen Specs

### FeedView
- `ScrollView` + `LazyVStack` of `ImageCard` components
- Loads first page on appear, infinite scroll on bottom reach
- Pull-to-refresh via `.refreshable`
- Tapping a card pushes `DetailView`
- No auth required

### CameraView
- Full-screen live camera using `UIImagePickerController`
- Capture button at bottom center
- On capture, pushes `GenerateView` with the photo

### GenerateView
- Shows thumbnail of captured photo
- Horizontal `ScrollView` of `PromptChip` components
  - Preset prompts: "Politician", "Cornellian", "Anime", "Oil Painting", "Astronaut", "Noir"
- One chip selected at a time
- "Generate" button triggers `POST /generate`
- Loading spinner while waiting on API
- On success, pushes `ResultView`

### ResultView
- Full-size generated image
- Shows original prompt chip label
- "Post to Feed" toggle (maps to `is_public`)
- "Save to Camera Roll" button
- "Save" button — confirms post, pops back to Feed tab

### DetailView
- Full-size image
- Prompt text + username + date
- If `user_id` matches session, show delete button
- Delete triggers confirmation alert then `DELETE /images/:id`
- On delete success, pops view and removes from parent list

### ProfileView
- Username header + image count
- `LazyVGrid` (3 columns) of user's images
- Tapping pushes `DetailView`
- Pull-to-refresh

### UsernameSheet
- Presented as `.sheet` over Generate or Profile tab if not logged in
- Single `TextField` for username input
- "Continue" button calls `GET /users/:username` and saves to `UserSession`
- Dismisses on success

---

## Implementation Steps

### Phase 1 — Project Setup
1. Create SwiftUI project, set deployment target to iOS 16
2. Set up `TabView` with Feed, Generate, Profile tabs
3. Scaffold all view files with placeholder `Text` views
4. Implement `UserSession` with `UserDefaults` read/write

### Phase 2 — Networking
5. Implement `APIService` with all four methods using `URLSession` async/await
6. Add `Codable` models with `JSONDecoder` snake_case key strategy
7. Test each endpoint against the live backend

### Phase 3 — Feed
8. Build `ImageCard` component (AsyncImage + prompt caption + username)
9. Wire `FeedView` to `APIService.fetchFeed`
10. Add pull-to-refresh and basic pagination

### Phase 4 — Camera + Generate Flow
11. Wrap `UIImagePickerController` in `UIViewControllerRepresentable` for `CameraView`
12. Build `PromptChip` component with selection state
13. Build `GenerateView` — photo thumbnail, chip carousel, generate button
14. Wire generate button to `APIService.generate` with loading state
15. Build `ResultView` with post/save actions

### Phase 5 — Profile + Detail
16. Build `ImageGrid` component for `ProfileView`
17. Wire `ProfileView` to fetch user's images from `/feed?user_id=`
18. Build `DetailView` with conditional delete button
19. Wire delete to `APIService.deleteImage` with alert confirmation

### Phase 6 — Auth Gate
20. Build `UsernameSheet` and wire to `UserSession.login`
21. Add auth gate logic to Generate and Profile tabs
22. Test full login flow from cold launch

### Phase 7 — Polish
23. Add loading skeletons for image cards
24. Add empty state views (no images yet, not logged in)
25. Handle network errors with user-facing alerts
26. Test on physical device for camera functionality
