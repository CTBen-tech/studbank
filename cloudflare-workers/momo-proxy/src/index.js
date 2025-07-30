import { v4 as uuidv4 } from "uuid";

// Helper: JSON response
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Get MoMo access token
async function getAccessToken(env) {
  const auth = btoa(`${env.MOMO_USER}:${env.MOMO_API_KEY}`);
  const res = await fetch("https://sandbox.momodeveloper.mtn.com/collection/token/", {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Ocp-Apim-Subscription-Key": env.MOMO_SUBSCRIPTION_KEY,
    },
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("Access Token Error:", text);
    return null;
  }

  const json = await res.json();
  return json.access_token;
}

// Handle /request-to-pay POST
async function handleRequestToPay(req, env) {
  const body = await req.json();
  const token = await getAccessToken(env);

  if (!token) return jsonResponse({ error: "Failed to get access token" }, 500);

  const referenceId = uuidv4();
  const payload = {
    amount: body.amount,
    currency: body.currency || "EUR",
    externalId: referenceId,
    payer: {
      partyIdType: "MSISDN",
      partyId: body.payerMobile,
    },
    payerMessage: body.payerMessage || "Payment",
    payeeNote: body.payeeNote || "StudBank Transaction",
  };

  const momoRes = await fetch("https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "X-Reference-Id": referenceId,
      "X-Target-Environment": "sandbox",
      "Ocp-Apim-Subscription-Key": env.MOMO_SUBSCRIPTION_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!momoRes.ok) {
    const text = await momoRes.text();
    console.error("MoMo Error:", text);
    return jsonResponse({ error: "MoMo API error", details: text }, momoRes.status);
  }

  return jsonResponse({ success: true, referenceId });
}

// Handle /payment-status/:referenceId GET
async function handlePaymentStatus(referenceId, env) {
  const token = await getAccessToken(env);
  if (!token) return jsonResponse({ error: "Failed to get access token" }, 500);

  const url = `https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay/${referenceId}`;
  const statusRes = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "X-Target-Environment": "sandbox",
      "Ocp-Apim-Subscription-Key": env.MOMO_SUBSCRIPTION_KEY,
    },
  });

  const text = await statusRes.text();
  let data;

  try {
    data = JSON.parse(text);
  } catch {
    return jsonResponse({ error: "Invalid JSON from MoMo API", raw: text }, 500);
  }

  return jsonResponse(data, statusRes.status);
}

// Main Worker fetch handler
export default {
  async fetch(req, env) {
    const url = new URL(req.url);

    if (req.method === "POST" && url.pathname === "/request-to-pay") {
      return await handleRequestToPay(req, env);
    }

    if (req.method === "GET" && url.pathname.startsWith("/payment-status/")) {
      const referenceId = url.pathname.split("/").pop();
      return await handlePaymentStatus(referenceId, env);
    }

    return new Response("Not Found", { status: 404 });
  },
};
