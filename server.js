const express = require("express");
require('dotenv').config()
const pool = require("./db/db")
const { generateImageEdit, XaiApiError } = require("./xai");
const cors = require("cors");
const app = express();
app.use(express.json({ limit: "12mb" }))
app.use(cors())

const ALLOWED_MIME_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);
const MAX_IMAGE_BASE64_LENGTH = 10 * 1024 * 1024;

app.get("/", (req, res) => {
    res.send("Hello world");
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

app.get("/feed", async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
        const offset = (page - 1) * limit;
        const imageQuery = await pool.query(
            `SELECT images.id, images.image_url, images.prompt, users.username, images.created_at
            FROM images
            JOIN users ON images.user_id = users.id
            WHERE is_public = true
            ORDER BY created_at DESC
            LIMIT $1
            OFFSET $2
            `, [limit, offset]
        );
        res.json(imageQuery.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: "Internal server error" });
    }
});

app.get("/users/:username", async (req, res) => {
    try {
        const username = req.params.username
        const usernameQuery = await pool.query(
            `SELECT *
            FROM users
            WHERE username = $1
            `, [username]
        )
        if (usernameQuery.rows.length === 0) {
            await pool.query(
                `INSERT INTO users(username)
                VALUES($1)
                `, [username]
            )
            const usernameInsertQuery = await pool.query(
                `SELECT *
                FROM users
                WHERE username = $1
                `, [username]
            )
            res.json(usernameInsertQuery.rows[0])
        } else {
            res.json(usernameQuery.rows[0])
        }
    } catch (err) {
        console.error(err)
        res.status(500).json({ error: "Internal server error" })
    }
});

app.post("/generate", async (req, res) => {
    try {
        const { user_id, prompt, image_base64, mime_type, is_public } = req.body;
        if (!user_id || !prompt || !image_base64 || !mime_type) {
            return res.status(400).json({ error: "Missing required fields: user_id, prompt, image_base64, mime_type" });
        }

        let isPublic = true;
        if (is_public !== undefined) {
            if (typeof is_public !== "boolean") {
                return res.status(400).json({ error: "is_public must be a boolean" });
            }
            isPublic = is_public;
        }

        if (!ALLOWED_MIME_TYPES.has(mime_type)) {
            return res.status(400).json({ error: "Invalid mime_type. Allowed: image/png, image/jpeg, image/webp" });
        }

        if (image_base64.length > MAX_IMAGE_BASE64_LENGTH) {
            return res.status(413).json({ error: "image_base64 payload too large" });
        }

        const imageUrl = await generateImageEdit({ prompt, image_base64, mime_type });

        const insertQuery = await pool.query(
            `INSERT INTO images (user_id, prompt, image_url, is_public)
            VALUES ($1, $2, $3, $4)
            RETURNING id, image_url, prompt, created_at
            `,
            [user_id, prompt, imageUrl, isPublic]
        );

        return res.status(201).json(insertQuery.rows[0]);
    } catch (err) {
        if (err instanceof XaiApiError) {
            return res.status(err.statusCode).json({ error: err.message });
        }
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
});

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

app.get("/users/:user_id/images", async (req, res) => {
    try {
        const userID = req.params.user_id;
        const viewerID = req.query.viewer_id;

        if (!UUID_RE.test(userID)) {
            return res.status(400).json({ error: "Invalid user_id format" });
        }
        if (viewerID !== undefined && !UUID_RE.test(viewerID)) {
            return res.status(400).json({ error: "Invalid viewer_id format" });
        }

        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 30));
        const offset = (page - 1) * limit;

        const result = await pool.query(
            `SELECT id, image_url, prompt, is_public, created_at
            FROM images
            WHERE user_id = $1
              AND (is_public = true OR user_id = $2)
            ORDER BY created_at DESC
            LIMIT $3 OFFSET $4
            `,
            [userID, viewerID || null, limit, offset]
        );

        return res.json(result.rows);
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
});

app.delete("/images/:id", async (req, res) => {
    try {
        const imageID = req.params.id
        const { user_id } = req.body

        if (!user_id) {
            return res.status(400).json({ error: "Missing required field: user_id" })
        }

        const findImage = await pool.query(
            `SELECT *
            FROM images
            WHERE id = $1
            `, [imageID]
        )

        if (findImage.rows.length === 0) {
            return res.status(404).json({ error: "Image not found" })
        }

        const imageToUserID = findImage.rows[0].user_id
        if (imageToUserID != user_id) {
            return res.status(403).json({ error: "Specified user is not the owner of this image!"})
        } else {
            await pool.query(
                `DELETE FROM images
                WHERE id = $1
                `, [imageID]
            )
            return res.status(200).json({ success: true })
        }
    } catch (err) {
        console.error(err)
        return res.status(500).json({ error: "Internal server error" })
    }
});

app.use((err, req, res, next) => {
    if (err?.type === "entity.too.large") {
        return res.status(413).json({ error: "Request body too large" });
    }
    return next(err);
});