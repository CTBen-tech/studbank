import 'dart:convert';
import 'package:http/http.dart' as http;
import '/api_constants.dart';

class MomoService {
  // Generate OAuth token
  static Future<String?> getAccessToken() async {
    final String basicAuth = base64Encode(utf8.encode('${ApiConstants.apiUserId}:${ApiConstants.apiKey}'));
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tokenEndpoint}'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/json',
          'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        print('Token request failed: ${response.statusCode}, ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error generating token: $e');
      return null;
    }
  }

  // Request to Pay (Collections - Add Funds)
  static Future<bool> requestToPay({
    required String amount,
    required String currency,
    required String externalId,
    required String payerMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.collectionsEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Reference-Id': externalId,
          'X-Target-Environment': 'sandbox',
          'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'externalId': externalId,
          'payer': {'partyIdType': 'MSISDN', 'partyId': payerMobile},
          'payerMessage': payerMessage,
          'payeeNote': payeeNote,
        }),
      );

      if (response.statusCode == 202) {
        print('Request to Pay initiated: ${response.body}');
        return true;
      } else {
        print('Request to Pay failed: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in Request to Pay: $e');
      return false;
    }
  }

  // Transfer (Disbursements - Withdraw)
  static Future<bool> transfer({
    required String amount,
    required String currency,
    required String externalId,
    required String payeeMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.disbursementsEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Reference-Id': externalId,
          'X-Target-Environment': 'sandbox',
          'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'externalId': externalId,
          'payee': {'partyIdType': 'MSISDN', 'partyId': payeeMobile},
          'payerMessage': payerMessage,
          'payeeNote': payeeNote,
        }),
      );

      if (response.statusCode == 202) {
        print('Transfer initiated: ${response.body}');
        return true;
      } else {
        print('Transfer failed: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error in Transfer: $e');
      return false;
    }
  }
}