const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");
const base64 = require("base-64");
const fetch = require("node-fetch");

admin.initializeApp();
const app = express();
app.use(cors({ origin: true }));

// Load secrets from Firebase config
const momoApiUserId = functions.config().momo.apiuserid;
const momoApiKey = functions.config().momo.apikey;
const momoSubscriptionKey = functions.config().momo.subscriptionkey;
const momoBaseUrl = functions.config().momo.baseurl;
const momoTokenEndpoint = functions.config().momo.tokenendpoint;

app.get("/get-momo-token", async (req, res) => {
  const authHeader = base64.encode(`${momoApiUserId}:${momoApiKey}`);

  try {
    const response = await fetch(
      `${momoBaseUrl}${momoTokenEndpoint}`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${authHeader}`,
          "Content-Type": "application/json",
          "Ocp-Apim-Subscription-Key": momoSubscriptionKey,
        },
        body: JSON.stringify({}),
      }
    );

    if (response.ok) {
      const data = await response.json();
      res.json({ access_token: data.access_token });
    } else {
      const errorText = await response.text();
      console.error(
        `Token request failed: ${response.status} ${errorText}`
      );
      res.status(500).json({
        error: `Failed to fetch token: ${errorText}`,
      });
    }
  } catch (error) {
    console.error("Error fetching MoMo token:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

// ✅ v1-compatible export (Spark plan safe)
exports.api = functions.https.onRequest(app);
