# Swift & iOS Notes

## UserDefaults: Persistent Storage in iOS

When building iOS apps, you'll often want to store small pieces of data so they persist even after the app is closed. That's where `UserDefaults` comes in.

`UserDefaults` is a built-in iOS storage system that works as a simple key–value store: you save a value (like a `Bool`, `String`, or array) under a specific key, and later retrieve it using that same key. It's designed for small pieces of persistent data that should stick around between app launches. A common example is storing user preferences, like whether dark mode is enabled, where you might save a Boolean under a key like `"isDarkMode"` and read it back when the app starts to restore the user's settings.

### Example: Storing Bookmarks

Let's say you have a struct (e.g., an item, article, or model), and you want users to be able to "bookmark" them.

Instead of storing the entire struct, a common approach is to store identifiers (IDs). For simplicity, we'll use strings like:

```
"id1", "id2", "id3"
```

So your bookmarks will just be an array of strings:

```swift
[String]
```

### Saving Bookmarks

To save an array of bookmark IDs:

```swift
let bookmarks = ["id1", "id2", "id3"]
UserDefaults.standard.set(bookmarks, forKey: "bookmarks") // "bookmarks" is the key
```

### Loading Bookmarks

To retrieve them later:

```swift
let bookmarks = UserDefaults.standard.stringArray(forKey: "bookmarks") ?? [] // optional value
```

If nothing has been saved yet, this safely defaults to an empty array.

### Adding a Bookmark

```swift
var bookmarks = UserDefaults.standard.stringArray(forKey: "bookmarks") ?? []

if !bookmarks.contains("id1") {
    bookmarks.append("id1")
    UserDefaults.standard.set(bookmarks, forKey: "bookmarks")
}
```

### Removing a Bookmark

```swift
var bookmarks = UserDefaults.standard.stringArray(forKey: "bookmarks") ?? []
bookmarks.removeAll { $0 == "id1" }
UserDefaults.standard.set(bookmarks, forKey: "bookmarks")
```

### Key Idea

You don't store the full struct in `UserDefaults`. Instead, you:

- Store lightweight identifiers (like `"id1"`)
- Use those IDs to match against your actual data when displaying bookmarked items

### When to Use UserDefaults

**Use it when:**

- Data is small
- You just need simple persistence
- You don't need complex relationships

**Avoid it for:**

- Large datasets
- Storing full models
- Anything requiring secure storage (only use for preferences or things that don't hold real importance. E.g., no passwords)

If something isn't saving/loading correctly, double-check your key names and make sure you're calling `set` after modifying the array.

---

## Multiple Initializers in Swift Structs

In Swift, a struct can have multiple initializers, and each one is used in a different situation.

For this assignment, your `Recipe` struct should have two:

### 1. Default Initializer (for Dummy Data)

This is the one you use when you are manually creating recipes (for testing, previews, etc.).

In this case:

- You already have clean data
- You just pass values in and store them

### 2. Decoding Initializer (for Networking)

When you fetch data from an API, Swift doesn't use your normal initializer. Instead, it uses this one:

```swift
init(from decoder: Decoder) throws {
    // The decoder is the object Swift gives us to read incoming JSON data

    // Create a container that maps JSON keys to our CodingKeys enum
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Try to decode the "id" field as a String (it might be missing, so we use decodeIfPresent)
    if let idString = try container.decodeIfPresent(String.self, forKey: .id) {

        // Convert the String (from the API) into a UUID (what our struct expects)
        self.id = UUID(uuidString: idString)
    } else {
        // If the API didn't provide an id, set it to nil
        self.id = nil
    }

    // Decode "description" from JSON and assign it to our struct
    self.description = try container.decode(String.self, forKey: .description)

    // Decode "difficulty" from JSON
    self.difficulty = try container.decode(String.self, forKey: .difficulty)

    // Decode "imageUrl" from JSON
    self.imageUrl = try container.decode(String.self, forKey: .imageUrl)

    // Decode "name" from JSON
    self.name = try container.decode(String.self, forKey: .name)

    // Decode "rating" from JSON as a Float
    self.rating = try container.decode(Float.self, forKey: .rating)
}
```

### What This Initializer Is Doing

This initializer is called automatically when decoding JSON.

In this example, it's especially useful because:

- The API gives you `id` as a `String`
- Your struct wants `id` as a `UUID`

So here:

```swift
let idString = try container.decodeIfPresent(String.self, forKey: .id)
self.id = UUID(uuidString: idString)
```

You are transforming the data into the format your app expects.

Everything else:

```swift
self.name = try container.decode(String.self, forKey: .name)
```

is just normal decoding.

### Why You Need Both

- When you create a recipe yourself → Swift uses your default initializer
- When data comes from the network → Swift uses `init(from:)`

They solve two different problems:

- **Default init** → store data
- **Decoding init** → convert + store data

### Key Idea

Having multiple initializers lets your struct handle different sources of data cleanly — manual data vs API data — without mixing the logic together.

If you're confused, remember: you never call `init(from:)` yourself, Swift does it for you during decoding.
