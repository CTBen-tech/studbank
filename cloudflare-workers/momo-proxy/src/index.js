// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\cloudflare-workers\momo-proxy\src\index.js
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
      if (path === '/getMomoToken') {
        console.log('Fetching MoMo token...');
        console.log('API User ID:', env.MOMO_API_USER_ID || 'Undefined');
        console.log('API Key:', env.MOMO_API_KEY ? 'Set' : 'Undefined');
        console.log('Subscription Key:', env.MOMO_SUBSCRIPTION_KEY ? 'Set' : 'Undefined');
        if (!env.MOMO_API_USER_ID || !env.MOMO_API_KEY || !env.MOMO_SUBSCRIPTION_KEY) {
          throw new Error('Missing environment variables: Check MOMO_API_USER_ID, MOMO_API_KEY, MOMO_SUBSCRIPTION_KEY');
        }
        const response = await fetch('https://sandbox.momodeveloper.mtn.com/collection/token/', {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${env.MOMO_API_USER_ID}:${env.MOMO_API_KEY}`)}`,
            'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({}),
        });
        console.log('MoMo API response status:', response.status);
        if (!response.ok) {
          const errorText = await response.text();
          throw new Error(`MoMo API error: ${response.status} ${errorText}`);
        }
        const data = await response.json();
        console.log('MoMo API response data:', JSON.stringify(data));
        return new Response(JSON.stringify(data), { status: response.status, headers: corsHeaders });
      }

      if (path === '/requestToPay') {
        const { amount, currency, externalId, payerMobile, payerMessage, payeeNote, accessToken } = await request.json();
        console.log('Request to Pay:', { amount, currency, externalId, payerMobile });
        if (!env.MOMO_SUBSCRIPTION_KEY) {
          throw new Error('Missing MOMO_SUBSCRIPTION_KEY');
        }
        const response = await fetch('https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'X-Reference-Id': externalId,
            'X-Target-Environment': 'sandbox',
            'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount,
            currency,
            externalId,
            payer: { partyIdType: 'MSISDN', partyId: payerMobile.replace('+', '') },
            payerMessage,
            payeeNote,
          }),
        });
        console.log('Request to Pay response status:', response.status);
        return new Response(JSON.stringify({ status: 'initiated' }), { status: response.status, headers: corsHeaders });
      }

      if (path === '/transfer') {
        const { amount, currency, externalId, payeeMobile, payerMessage, payeeNote, accessToken } = await request.json();
        console.log('Transfer:', { amount, currency, externalId, payeeMobile });
        if (!env.MOMO_SUBSCRIPTION_KEY) {
          throw new Error('Missing MOMO_SUBSCRIPTION_KEY');
        }
        const response = await fetch('https://sandbox.momodeveloper.mtn.com/disbursement/v1_0/transfer', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'X-Reference-Id': externalId,
            'X-Target-Environment': 'sandbox',
            'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount,
            currency,
            externalId,
            payee: { partyIdType: 'MSISDN', partyId: payeeMobile.replace('+', '') },
            payerMessage,
            payeeNote,
          }),
        });
        console.log('Transfer response status:', response.status);
        return new Response(JSON.stringify({ status: 'initiated' }), { status: response.status, headers: corsHeaders });
      }

      if (path === '/checkTransactionStatus') {
        const { externalId, accessToken, isDisbursement } = url.searchParams;
        console.log('Check Transaction Status:', { externalId, isDisbursement });
        if (!env.MOMO_SUBSCRIPTION_KEY) {
          throw new Error('Missing MOMO_SUBSCRIPTION_KEY');
        }
        const endpoint = isDisbursement === 'true'
          ? `https://sandbox.momodeveloper.mtn.com/disbursement/v1_0/transfer/${externalId}`
          : `https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay/${externalId}`;
        const response = await fetch(endpoint, {
          method: 'GET',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'X-Target-Environment': 'sandbox',
            'Ocp-Apim-Subscription-Key': env.MOMO_SUBSCRIPTION_KEY,
          },
        });
        console.log('Check Transaction Status response status:', response.status);
        const data = await response.json();
        console.log('Check Transaction Status response data:', JSON.stringify(data));
        return new Response(JSON.stringify(data), { status: response.status, headers: corsHeaders });
      }

      return new Response('Not found', { status: 404, headers: corsHeaders });
    } catch (error) {
      console.error('Error in path', path, ':', error.message, error.stack);
      return new Response(JSON.stringify({ error: 'Server error', message: error.message }), { status: 500, headers: corsHeaders });
    }
  }
};