# Nano Banana — Backend Implementation Plan

## Stack
- **Runtime**: Node.js + Express
- **Database**: PostgreSQL
- **Image Gen**: xAI `grok-imagine-image` via `/v1/images/edits`
- **Hosting**: Railway or Render
- **File Handling**: Base64 image passed directly to xAI (no S3 needed — xAI returns a hosted URL)

---

## Database Schema

### `users`
```sql
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username    TEXT UNIQUE NOT NULL,
  created_at  TIMESTAMP DEFAULT NOW()
);
```

### `images`
```sql
CREATE TABLE images (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  prompt      TEXT NOT NULL,
  image_url   TEXT NOT NULL,
  is_public   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMP DEFAULT NOW()
);
```

Relationship: `images.user_id` → `users.id` (one-to-many)

---

## API Routes

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/feed` | No | Paginated public images with author username |
| GET | `/users/:username` | No | Find or create user by username, return user_id |
| POST | `/generate` | user_id in body | Accept photo (base64) + prompt, call xAI, save result |
| DELETE | `/images/:id` | user_id in body | Delete image if owned by requesting user |

---

## Route Specs

### GET `/feed`
- Query params: `page` (default 1), `limit` (default 20)
- Joins `images` with `users` on `user_id`
- Filters `is_public = true`
- Orders by `created_at DESC`
- Returns: `[{ id, image_url, prompt, username, created_at }]`

### GET `/users/:username`
- Tries to find user by username
- If not found, inserts a new row
- Returns: `{ id, username, created_at }`

### POST `/generate`
- Body: `{ user_id, prompt, image_base64, mime_type }`
- Calls xAI `/v1/images/edits` with `grok-imagine-image`, passing `image_base64` and `prompt`
- On success, saves `{ user_id, prompt, image_url, is_public: true }` to `images` table
- Returns: `{ id, image_url, prompt, created_at }`

### DELETE `/images/:id`
- Body: `{ user_id }`
- Verifies `images.user_id = user_id` before deleting
- Returns: `{ success: true }` or 403 if not owner

---

## Implementation Steps

### Phase 1 — Project Setup
1. Init Node/Express project with `express`, `pg`, `dotenv`, `cors`
2. Create `.env` with `DATABASE_URL` and `XAI_API_KEY`
3. Write `db.js` connection pool using `pg`
4. Run migrations to create `users` and `images` tables

### Phase 2 — Routes
5. Implement `GET /feed` with pagination
6. Implement `GET /users/:username` with upsert logic
7. Implement `POST /generate` — wire up xAI call, save result
8. Implement `DELETE /images/:id` with ownership check

### Phase 3 — xAI Integration
9. Write `xai.js` helper that takes `{ prompt, image_base64, mime_type }` and calls `/v1/images/edits`
10. Handle xAI errors (rate limits, invalid image format) and return clean error messages

### Phase 4 — Deploy
11. Push to GitHub
12. Deploy to Railway, set env vars
13. Run migrations against production DB
14. Test all four routes with Postman or curl
