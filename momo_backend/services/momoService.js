const axios = require('axios');
const { v4: uuidv4 } = require('uuid');

class MoMoService {
    constructor() {
        this.collectionSubscriptionKey = process.env.MOMO_COLLECTION_SUBSCRIPTION_KEY;
        this.apiUserUuid = process.env.MOMO_API_USER_UUID;
        this.apiUserSecret = process.env.MOMO_API_USER_SECRET;
        this.baseUrl = process.env.MOMO_BASE_URL;
        this.targetEnvironment = process.env.MOMO_TARGET_ENVIRONMENT;

        this.accessToken = null;
        this.tokenExpiryTime = 0; // Unix timestamp in seconds

        if (!this.collectionSubscriptionKey || !this.apiUserUuid || !this.apiUserSecret) {
            console.error("MoMo credentials missing. Please set environment variables.");
            throw new Error("MoMo API credentials not configured.");
        }
    }

    async _generateAccessToken() {
        const authString = `${this.apiUserUuid}:${this.apiUserSecret}`;
        const encodedAuth = Buffer.from(authString).toString('base64');

        const headers = {
            "Authorization": `Basic ${encodedAuth}`,
            "Content-Type": "application/x-www-form-urlencoded",
            "Ocp-Apim-Subscription-Key": this.collectionSubscriptionKey // This is needed for token endpoint
        };
        const data = "grant_type=client_credentials";

        try {
            console.log("Attempting to generate new MoMo access token...");
            const response = await axios.post(`${this.baseUrl}/oauth2/token`, data, { headers });
            const tokenData = response.data;

            this.accessToken = tokenData.access_token;
            const expiresIn = tokenData.expires_in || 3600;
            // Set expiry time a bit before actual expiry for a buffer (e.g., 5 minutes before)
            this.tokenExpiryTime = Math.floor(Date.now() / 1000) + expiresIn - 300;

            console.log(`MoMo access token generated. Expires in ${expiresIn} seconds.`);
            return true;
        } catch (error) {
            console.error("Error generating MoMo access token:", error.response ? error.response.data : error.message);
            this.accessToken = null;
            this.tokenExpiryTime = 0;
            return false;
        }
    }

    async _getValidAccessToken() {
        if (!this.accessToken || Math.floor(Date.now() / 1000) >= this.tokenExpiryTime) {
            console.log("Access token missing or expired, generating new one...");
            const success = await this._generateAccessToken();
            if (!success) {
                throw new Error("Failed to obtain MoMo access token.");
            }
        }
        return this.accessToken;
    }

    async requestToPay(amount, currency, partyIdType, partyId, payerMessage, payeeNote) {
        try {
            const token = await this._getValidAccessToken(); // Ensures fresh token

            // Use the provided externalId or generate a new one
            const externalId = uuidv4(); // Unique ID for this specific transaction

            const headers = {
                "Authorization": `Bearer ${token}`,
                "X-Target-Environment": this.targetEnvironment,
                "Ocp-Apim-Subscription-Key": this.collectionSubscriptionKey,
                "Content-Type": "application/json",
                "X-Reference-Id": externalId
            };

            const payload = {
                amount: String(amount),
                currency: currency,
                externalId: externalId,
                payer: {
                    partyIdType: partyIdType,
                    partyId: partyId
                },
                payerMessage: payerMessage,
                payeeNote: payeeNote
            };

            console.log(`Sending Request to Pay for ${partyId} (External ID: ${externalId})`);
            const response = await axios.post(
                `${this.baseUrl}/collection/v1_0/requesttopay`,
                payload,
                { headers }
            );

            console.log(`MoMo Request to Pay Accepted. Status Code: ${response.status}`);
            return {
                status: "PENDING_ACCEPTANCE",
                externalId: externalId,
                message: "Payment request sent successfully. Check transaction status later."
            };
        } catch (error) {
            console.error("Error in Request to Pay:", error.response ? JSON.stringify(error.response.data) : error.message);
            throw new Error(`Failed to initiate payment: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
        }
    }

    async getTransactionStatus(externalId) {
        try {
            const token = await this._getValidAccessToken();

            const headers = {
                "Authorization": `Bearer ${token}`,
                "X-Target-Environment": this.targetEnvironment,
                "Ocp-Apim-Subscription-Key": this.collectionSubscriptionKey
            };

            console.log(`Checking transaction status for External ID: ${externalId}`);
            const response = await axios.get(
                `${this.baseUrl}/collection/v1_0/requesttopay/${externalId}`,
                { headers }
            );

            console.log(`Transaction Status for ${externalId}:`, response.data);
            return response.data;
        } catch (error) {
            console.error("Error getting transaction status:", error.response ? JSON.stringify(error.response.data) : error.message);
            throw new Error(`Failed to get transaction status: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
        }
    }

    async getAccountBalance() {
        try {
            const token = await this._getValidAccessToken();

            const headers = {
                "Authorization": `Bearer ${token}`,
                "X-Target-Environment": this.targetEnvironment,
                "Ocp-Apim-Subscription-Key": this.collectionSubscriptionKey
            };

            console.log("Fetching account balance...");
            const response = await axios.get(
                `${this.baseUrl}/collection/v1_0/account/balance`,
                { headers }
            );

            console.log("Account Balance:", response.data);
            return response.data;
        } catch (error) {
            console.error("Error getting account balance:", error.response ? JSON.stringify(error.response.data) : error.message);
            throw new Error(`Failed to get account balance: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
        }
    }
}

module.exports = new MoMoService(); // Export an instance