const express = require('express');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors()); // Allow all origins or configure allowed origins

const PORT = process.env.PORT || 5000;

// Route to get MoMo token
app.get('/api/get-momo-token', async (req, res) => {
    try {
        const user = process.env.MOMO_USER_ID;
        const apiKey = process.env.MOMO_API_KEY;

        const response = await axios.post(
            'https://sandbox.momodeveloper.mtn.com/collection/token/',
            {},
            {
                headers: {
                    Authorization: 'Basic ' + Buffer.from(`${user}:${apiKey}`).toString('base64'),
                    'Ocp-Apim-Subscription-Key': process.env.MOMO_SUBSCRIPTION_KEY
                }
            }
        );

        res.json({
            access_token: response.data.access_token,
            expires_in: response.data.expires_in,
            token_type: response.data.token_type
        });
    } catch (error) {
        console.error('Error fetching MoMo token:', error.response?.data || error.message);
        res.status(500).json({ error: 'Failed to get MoMo token' });
    }
});

app.listen(PORT, () => {
    console.log(`MoMo backend server running on port ${PORT}`);
});
