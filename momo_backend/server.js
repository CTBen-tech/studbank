require('dotenv').config(); // Load environment variables
const express = require('express');
const cors = require('cors');
const momoService = require('./services/momoService'); // Import your MoMo service

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json()); // To parse JSON request bodies
// Configure CORS for your Flutter app's origin in production
app.use(cors({
    origin: '*', // Allow all origins for development. Be specific in production: 'http://localhost:XXXX' or 'https://yourflutterapp.com'
}));

// Routes

// Health check
app.get('/', (req, res) => {
    res.send('MoMo Backend is running!');
});

// Endpoint to initiate a MoMo Request to Pay
app.post('/api/momo/request-payment', async (req, res) => {
    try {
        const { amount, currency, partyIdType, partyId, payerMessage, payeeNote } = req.body;

        // Basic validation
        if (!amount || !currency || !partyIdType || !partyId) {
            return res.status(400).json({ success: false, message: "Missing required payment fields." });
        }

        const result = await momoService.requestToPay(
            amount,
            currency,
            partyIdType,
            partyId,
            payerMessage || "Payment Request",
            payeeNote || "From my app"
        );

        res.status(202).json({ success: true, data: result }); // 202 Accepted
    } catch (error) {
        console.error("API Error - /api/momo/request-payment:", error.message);
        res.status(500).json({ success: false, message: error.message || "Internal server error" });
    }
});

// Endpoint to check transaction status
app.get('/api/momo/transaction-status/:externalId', async (req, res) => {
    try {
        const { externalId } = req.params;
        if (!externalId) {
            return res.status(400).json({ success: false, message: "Missing externalId." });
        }

        const status = await momoService.getTransactionStatus(externalId);
        res.status(200).json({ success: true, data: status });
    } catch (error) {
        console.error("API Error - /api/momo/transaction-status:", error.message);
        res.status(500).json({ success: false, message: error.message || "Internal server error" });
    }
});

// Endpoint to get account balance
app.get('/api/momo/account-balance', async (req, res) => {
    try {
        const balance = await momoService.getAccountBalance();
        res.status(200).json({ success: true, data: balance });
    } catch (error) {
        console.error("API Error - /api/momo/account-balance:", error.message);
        res.status(500).json({ success: false, message: error.message || "Internal server error" });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`MoMo Backend server running on port ${PORT}`);
});