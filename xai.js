class XaiApiError extends Error {
    constructor(statusCode, message) {
        super(message);
        this.name = "XaiApiError";
        this.statusCode = statusCode;
    }
}

function getImageUrlFromXaiResponse(payload) {
    return payload?.data?.[0]?.url || payload?.data?.[0]?.image_url || payload?.image_url || null;
}

function mapXaiError(statusCode, payload) {
    const upstreamMessage = payload?.error?.message;

    if (statusCode === 429) {
        return new XaiApiError(429, "xAI rate limit hit, try again shortly");
    }
    if (statusCode === 400) {
        return new XaiApiError(400, upstreamMessage || "Invalid image or request format");
    }
    if (statusCode === 401 || statusCode === 403) {
        return new XaiApiError(statusCode, "xAI authentication failed; check XAI_API_KEY");
    }
    if (statusCode >= 500) {
        return new XaiApiError(502, "xAI service is temporarily unavailable");
    }

    return new XaiApiError(statusCode || 502, upstreamMessage || "xAI image generation failed");
}

async function generateImageEdit({ prompt, image_base64, mime_type }) {
    if (!process.env.XAI_API_KEY) {
        throw new XaiApiError(500, "Missing XAI_API_KEY environment variable");
    }

    let xaiRes;
    try {
        xaiRes = await fetch("https://api.x.ai/v1/images/edits", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${process.env.XAI_API_KEY}`
            },
            body: JSON.stringify({
                model: "grok-imagine-image",
                prompt,
                image_base64,
                mime_type
            })
        });
    } catch (_) {
        throw new XaiApiError(502, "Unable to reach xAI service");
    }

    let payload = null;
    try {
        payload = await xaiRes.json();
    } catch (_) {
        payload = null;
    }

    if (!xaiRes.ok) {
        throw mapXaiError(xaiRes.status, payload);
    }

    const imageUrl = getImageUrlFromXaiResponse(payload);
    if (!imageUrl) {
        throw new XaiApiError(502, "xAI response did not include an image URL");
    }

    return imageUrl;
}

module.exports = { generateImageEdit, XaiApiError };
