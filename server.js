const express = require("express");
const pool = require("./db/db")
const cors = require("cors");
require('dotenv').config()
const app = express();
app.use(express.json())
app.use(cors())

app.get("/", (req, res) => {
    res.send("Hello world");
});

app.listen(3000, () => {
    console.log("Server running on port 3000");
});

app.get("/feed", async (req, res) => {
    try {
        if (!parseInt(req.query.page)) {
            req.query.page = 1;
        }
        if (!parseInt(req.query.limit)) {
            req.query.limit = 20;
        }
        const page = parseInt(req.query.page)
        const limit = parseInt(req.query.limit)
        let offset = 0
        if (page != 1) {
            offset = (page * limit) - limit
        }
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
        res.json(imageQuery.rows)
        } catch (err) {
            console.error(err)
            res.status(500).json({ error: "Internal server error" })
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

app.post("/generate", (req, res) => {

});

app.delete("/images/:id", async (req, res) => {
    try {
        const imageID = req.params.id
        const userID = req.body
        const findImage = await pool.query(
            `SELECT *
            FROM images
            WHERE id = $1
            `, [imageID]
        )
        const imageToUserID = findImage.rows[0].user_id
        if (imageToUserID != userID.user_id) {
            res.status(403).json({ error: "Specified user is not the owner of this image!"})
        } else {
            await pool.query(
                `DELETE FROM images
                WHERE id = $1
                `, [imageID]
            )
            res.status(200).json({ success: true })
        }
    } catch (err) {
        console.error(err)
        res.status(500).json({ error: "Interal server error" })
    }
});