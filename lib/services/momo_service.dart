// lib/services/momo_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../api_constants.dart';

class MomoService {
  /// Generate OAuth token for MoMo API
  static Future<String?> getAccessToken() async {
    final String basicAuth = base64Encode(
      utf8.encode('${ApiConstants.apiUserId}:${ApiConstants.apiKey}'),
    );

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tokenEndpoint}'),
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/json',
          'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
        },
        body: jsonEncode({}), // Required even if empty for some endpoints
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        print('✅ MoMo Access Token retrieved successfully.');
        return token;
      } else {
        print('❌ Failed to get token: ${response.statusCode} | ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception while getting token: $e');
      return null;
    }
  }

  /// Request to Pay (Collections - Add Funds)
  static Future<bool> requestToPay({
    required String amount,
    required String currency,
    required String externalId,
    required String payerMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) {
      print('❌ Cannot proceed with requestToPay, token is null.');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.collectionsEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Reference-Id': externalId,
          'X-Target-Environment': ApiConstants.targetEnvironment,
          'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'externalId': externalId,
          'payer': {
            'partyIdType': 'MSISDN',
            'partyId': payerMobile.replaceAll('+', ''),
          },
          'payerMessage': payerMessage,
          'payeeNote': payeeNote,
        }),
      );

      if (response.statusCode == 202) {
        print('✅ RequestToPay initiated successfully.');
        final status = await _checkTransactionStatus(externalId, token);
        return status == 'SUCCESSFUL';
      } else {
        print('❌ RequestToPay failed: ${response.statusCode} | ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception in requestToPay: $e');
      return false;
    }
  }

  /// Transfer (Disbursements - Withdraw Funds)
  static Future<bool> transfer({
    required String amount,
    required String currency,
    required String externalId,
    required String payeeMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) {
      print('❌ Cannot proceed with transfer, token is null.');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.disbursementsEndpoint}'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Reference-Id': externalId,
          'X-Target-Environment': ApiConstants.targetEnvironment,
          'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'externalId': externalId,
          'payee': {
            'partyIdType': 'MSISDN',
            'partyId': payeeMobile.replaceAll('+', ''),
          },
          'payerMessage': payerMessage,
          'payeeNote': payeeNote,
        }),
      );

      if (response.statusCode == 202) {
        print('✅ Transfer initiated successfully.');
        final status = await _checkTransactionStatus(
          externalId,
          token,
          isDisbursement: true,
        );
        return status == 'SUCCESSFUL';
      } else {
        print('❌ Transfer failed: ${response.statusCode} | ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Exception in transfer: $e');
      return false;
    }
  }

  /// Check transaction status (polls up to 3 times)
  static Future<String?> _checkTransactionStatus(
    String externalId,
    String token, {
    bool isDisbursement = false,
  }) async {
    final endpoint = isDisbursement
        ? '${ApiConstants.baseUrl}${ApiConstants.disbursementsEndpoint}/$externalId'
        : '${ApiConstants.baseUrl}${ApiConstants.collectionsEndpoint}/$externalId';

    try {
      for (int attempt = 1; attempt <= 3; attempt++) {
        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'X-Target-Environment': ApiConstants.targetEnvironment,
            'Ocp-Apim-Subscription-Key': ApiConstants.subscriptionKey,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          print('ℹ️ Attempt $attempt: Transaction status for $externalId -> $status');
          if (status == 'SUCCESSFUL' || status == 'FAILED') {
            return status;
          }
        } else {
          print('❌ Status check failed: ${response.statusCode} | ${response.body}');
        }
        await Future.delayed(const Duration(seconds: 5));
      }
      print('⚠️ Transaction status still pending after retries for $externalId.');
      return null;
    } catch (e) {
      print('❌ Exception while checking transaction status: $e');
      return null;
    }
  }
}
