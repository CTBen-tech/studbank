export default {
    async fetch(request, env) {
        // Define CORS headers for cross-origin requests
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*', // IMPORTANT: For production, change '*' to your actual Flutter web app's domain (e.g., 'https://your-app.com')
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', // Methods your Worker supports
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, Ocp-Apim-Subscription-Key, X-Reference-Id, X-Target-Environment', // Headers your client is allowed to send
            'Access-Control-Max-Age': '86400', // Cache preflight response for 24 hours
        };

        // Handle OPTIONS requests (CORS preflight)
        if (request.method === 'OPTIONS') {
            return new Response(null, { status: 204, headers: corsHeaders });
        }

        const url = new URL(request.url);
        const path = url.pathname;

        try {
            // Helper function to validate fields in the request body
            // IMPORTANT: Removed 'payerMobile' as Flutter sends 'payer' object
            const validateFields = (body, fields) => {
                for (const field of fields) {
                    // Special handling for nested payer.partyId
                    if (field === 'payer.partyId') {
                        if (!body.payer || !body.payer.partyId) {
                            throw new Error(`Missing required field: payer.partyId`);
                        }
                    } else if (!body[field]) {
                        throw new Error(`Missing required field: ${field}`);
                    }
                }
            };

            // Helper function to generate UUID (if not provided by client)
            const generateUUID = () => {
                return crypto.randomUUID(); // Available in Cloudflare Workers
            };

            // --- /getMomoToken Endpoint ---
            if (path === '/getMomoToken') {
                if (!env.MOMO_API_USER_ID || !env.MOMO_API_KEY || !env.MOMO_SUBSCRIPTION_KEY || !env.MOMO_BASE_URL) {
                    throw new Error('Missing environment variables for token endpoint');
                }

                console.log('Proxy: Fetching MoMo Access Token...');

                const response = await fetch(`${env.MOMO_BASE_URL}/collection/token/`, {
                    method: 'POST',
                    headers: {
                        Authorization: `Basic ${btoa(`${env.MOMO_API_USER_ID}:${env.MOMO_API_KEY}`)}`,
                        'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
                        'Content-Type': 'application/json',
                    },
                    // MoMo token endpoint typically expects no body or an empty one for 'client_credentials'
                    // If your setup specifically requires 'grant_type', uncomment:
                    // body: JSON.stringify({ grant_type: 'client_credentials' }),
                });

                const data = await response.json(); // Always read the body for debugging

                if (!response.ok) {
                    console.error(`Proxy: MoMo Token API Error (Status: ${response.status}): ${JSON.stringify(data)}`);
                    // Pass through MoMo's actual error status and body
                    return new Response(JSON.stringify(data), { status: response.status, headers: { "Content-Type": "application/json", ...corsHeaders } });
                }

                console.log('Proxy: MoMo Access Token received:', JSON.stringify(data));
                return new Response(JSON.stringify(data), { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } });
            }

            // --- /requestToPay Endpoint ---
            if (path === '/requestToPay') {
                const body = await request.json();
                console.log("Proxy: Received requestToPay body from Flutter:", JSON.stringify(body));

                // Validate essential fields. 'payer' is an object, so check for 'payer.partyId'
                validateFields(body, ['amount', 'currency', 'payer.partyId', 'accessToken']);

                // Use externalId provided by Flutter, or generate one if not present
                const externalId = body.externalId || generateUUID();

                if (!env.MOMO_COLLECTION_API_KEY || !env.MOMO_BASE_URL) {
                    throw new Error('Missing environment variables for requestToPay endpoint');
                }

                // Construct the payload for MoMo API
                const momoPayload = {
                    amount: String(body.amount), // Ensure amount is a string as MoMo expects
                    currency: body.currency,
                    externalId: externalId,
                    payer: {
                        // CRITICAL: Use partyIdType and partyId directly from Flutter's 'payer' object
                        partyIdType: body.payer.partyIdType, 
                        partyId: body.payer.partyId // Already formatted by Flutter (e.g., "467331234")
                    },
                    payerMessage: body.payerMessage || '',
                    payeeNote: body.payeeNote || '',
                };

                // CRITICAL LOG: This shows the exact JSON sent to MoMo. Check your Cloudflare logs!
                console.log("Proxy: MoMo API Request Payload (Request to Pay):", JSON.stringify(momoPayload));

                const response = await fetch(`${env.MOMO_BASE_URL}/collection/v1_0/requesttopay`, {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${body.accessToken}`,
                        'X-Reference-Id': externalId,
                        'X-Target-Environment': 'sandbox',
                        'Ocp-Apim-Subscription-Key': env.MOMO_COLLECTION_API_KEY, // Use the specific Collection API key
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(momoPayload),
                });

                const result = await response.text(); // Read raw text to catch all responses
                console.log(`Proxy: MoMo Request to Pay API responded (Status: ${response.status}): ${result}`);

                if (!response.ok) {
                    // MoMo API returned an error (e.g., 400 Bad Request, 401 Unauthorized, etc.)
                    // Pass the error directly from MoMo to your Flutter app
                    return new Response(JSON.stringify({
                        error: `MoMo API Error: ${response.status}`,
                        message: result, // MoMo's error message
                        externalId: externalId
                    }), { status: response.status, headers: { "Content-Type": "application/json", ...corsHeaders } });
                }

                // Successful response from MoMo (typically 202 Accepted)
                return new Response(JSON.stringify({ status: 'initiated', externalId, momoResponse: result }), { status: response.status, headers: { "Content-Type": "application/json", ...corsHeaders } });
            }

            // --- Default Fallback ---
            return new Response('Not found', { status: 404, headers: corsHeaders });

        } catch (error) {
            // General error handling for any uncaught exceptions in the Worker
            console.error('Worker Error:', error.message, error.stack);
            return new Response(JSON.stringify({ error: 'Server error', message: error.message }), {
                status: 500,
                headers: corsHeaders
            });
        }
    }
};