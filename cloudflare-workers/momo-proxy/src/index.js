export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Ocp-Apim-Subscription-Key, X-Reference-Id, X-Target-Environment',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      const validateFields = (body, fields) => {
        for (const field of fields) {
          if (!body[field]) throw new Error(`Missing required field: ${field}`);
        }
      };

      const generateUUID = () => {
        return crypto.randomUUID(); // Available in Cloudflare Workers
      };

      if (path === '/getMomoToken') {
        if (!env.MOMO_API_USER_ID || !env.MOMO_API_KEY || !env.MOMO_SUBSCRIPTION_KEY) {
          throw new Error('Missing environment variables');
        }

        const response = await fetch('https://sandbox.momodeveloper.mtn.com/collection/token/', {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${env.MOMO_API_USER_ID}:${env.MOMO_API_KEY}`)}`,
            'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
            'Content-Type': 'application/json',
          },
        });

        if (!response.ok) {
          const errorText = await response.text();
          throw new Error(`Token error: ${response.status} ${errorText}`);
        }

        const data = await response.json();
        return new Response(JSON.stringify(data), { status: 200, headers: corsHeaders });
      }

      if (path === '/requestToPay') {
        const body = await request.json();
        validateFields(body, ['amount', 'currency', 'payerMobile', 'accessToken']);

        const externalId = body.externalId || generateUUID();

        const response = await fetch('https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${body.accessToken}`,
            'X-Reference-Id': externalId,
            'X-Target-Environment': 'sandbox',
            'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: body.amount,
            currency: body.currency,
            externalId: externalId,
            payer: { partyIdType: 'MSISDN', partyId: body.payerMobile.replace('+', '') },
            payerMessage: body.payerMessage || '',
            payeeNote: body.payeeNote || '',
          }),
        });

        if (!response.ok) {
          const errorText = await response.text();
          throw new Error(`Request to Pay failed: ${response.status} ${errorText}`);
        }

        return new Response(JSON.stringify({ status: 'initiated', externalId }), { status: 200, headers: corsHeaders });
      }

      return new Response('Not found', { status: 404, headers: corsHeaders });

    } catch (error) {
      console.error('Worker Error:', error.message, error.stack);
      return new Response(JSON.stringify({ error: 'Server error', message: error.message }), {
        status: 500,
        headers: corsHeaders
      });
    }
  }
};
