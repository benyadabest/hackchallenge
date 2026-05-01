# Nano Banana

AI photo style transfer for iOS. Pick a photo, choose a style, and xAI's `grok-imagine-image` model returns a re-imagined version. Keep posts private or share them to a public feed.

## User flow

### 1. Pick a photo

Open the **Camera** tab and select a photo from your library (or capture live on device).

![Photo picker](docs/screenshots/01-photo-picker.png)

### 2. Choose a style

The photo loads into the Generate screen with horizontally-scrolling style chips: Cornellian, Anime, Oil Painting, Astronaut, Politician, Noir. Pick one and tap Generate.

![Generate screen](docs/screenshots/02-generate.png)

### 3. Wait while xAI generates

The backend forwards your photo + a style-specific prompt to xAI's `grok-imagine-image` endpoint at `/v1/images/edits`. A spinner shows while the model runs (~5 seconds end-to-end).

![Generating screen](docs/screenshots/03-generating.png)

### 4. See the result

The styled image replaces the spinner. Tap **Save to Roll** to keep a local copy, or **Done** to finish.

![Result screen](docs/screenshots/04-result.png)

### 5. Manage your profile

The **Profile** tab shows every image you've generated — public and private — in a grid. Logout clears your session.

![Profile screen](docs/screenshots/05-profile.png)

### 6. Browse the public feed

The **Feed** tab surfaces other users' public posts with For you / Following / Trending / Recent filters.

![Feed screen](docs/screenshots/06-feed.png)

## Tech stack

| Layer | Tools |
|---|---|
| iOS | SwiftUI, URLSession, UIImagePickerController |
| Backend | Node.js, Express 5, PostgreSQL, dotenv |
| AI | xAI `grok-imagine-image` via `/v1/images/edits` |
| Local infra | Docker (Postgres) |

## Local setup

Backend:

```bash
cd hack-challenge
npm install
cp .env.example .env   # fill in DATABASE_URL, XAI_API_KEY

# Postgres in Docker
docker run -d --name nb-pg \
  -e POSTGRES_PASSWORD=dev \
  -e POSTGRES_DB=nanobanana \
  -p 5432:5432 postgres:16

# apply schema (once Postgres is healthy)
docker exec -i nb-pg psql -U postgres -d nanobanana < db/schema.sql

# run the server (PORT=3001 by default per .env.example)
node server.js
```

iOS: open `hack-challenge.xcodeproj` in Xcode, build, run on the iOS Simulator. Confirm `APIService.baseURL` matches the backend port (`http://localhost:3001`).

## API

| Method | Path | Description |
|---|---|---|
| GET | `/feed?page=&limit=` | Paginated public images joined with username |
| GET | `/users/:username` | Find or create user, returns `{ id, username, created_at }` |
| GET | `/users/:user_id/images?viewer_id=` | A user's images. Owner sees public + private; others see public only |
| POST | `/generate` | Body: `{ user_id, prompt, image_base64, mime_type, is_public }` → xAI image edit |
| DELETE | `/images/:id` | Body: `{ user_id }`. Owner only; 403 otherwise |
