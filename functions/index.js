const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const base64 = require("base-64");

admin.initializeApp();
const app = express();
app.use(cors({ origin: true }));

// Load your secrets securely from environment config
const momoApiUserId = functions.config().momo.apiuserid;
const momoApiKey = functions.config().momo.apikey;
const momoSubscriptionKey = functions.config().momo.subscriptionkey;
const momoBaseUrl = functions.config().momo.baseurl;
const momoTokenEndpoint = functions.config().momo.tokenendpoint;

app.get("/get-momo-token", async (req, res) => {
  const authHeader = base64.encode(`${momoApiUserId}:${momoApiKey}`);

  try {
    const response = await fetch(`${momoBaseUrl}${momoTokenEndpoint}`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${authHeader}`,
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": momoSubscriptionKey
      },
      body: JSON.stringify({})
    });

    if (response.status === 200) {
      const data = await response.json();
      res.json({ access_token: data.access_token });
    } else {
      const text = await response.text();
      console.error(`Token request failed: ${response.status} ${text}`);
      res.status(500).json({ error: `Failed to fetch token: ${text}` });
    }
  } catch (error) {
    console.error("Error fetching MoMo token:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

exports.api = functions.https.onRequest(app);
