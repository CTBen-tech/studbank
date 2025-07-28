import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

// --- Helper: Phone number formatter ---
String _formatPhoneNumberForMomo(String phoneNumber) {
  String cleanedNumber = phoneNumber.trim();

  // Remove leading '+' if present
  if (cleanedNumber.startsWith('+')) {
    cleanedNumber = cleanedNumber.substring(1);
  }

  // Remove spaces and hyphens
  cleanedNumber = cleanedNumber.replaceAll(' ', '').replaceAll('-', '');

  // Remove Uganda's country code (256) if it makes the number too long
  // MoMo usually expects numbers without country code for MSISDN type
  // This logic assumes a 9-digit number after removing 256. Adjust if needed.
  if (cleanedNumber.startsWith('256') && cleanedNumber.length > 9) { // Example: 256771234567 -> 771234567
    cleanedNumber = cleanedNumber.substring(3);
  }

  return cleanedNumber;
}

class MomoService {
  static const String _baseUrl = 'https://momo-proxy.studbank.workers.dev';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // UPDATED: Include EUR as a supported currency for sandbox testing
  static const List<String> supportedCurrencies = ['UGX', 'EUR'];
  static final _uuid = Uuid();

  static Future<String?> getAccessToken() async {
    int retries = 3;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/getMomoToken'),
          headers: {'Content-Type': 'application/json'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('MomoService: Access token received.');
          return data['access_token'];
        }
        final errorBody = jsonDecode(response.body);
        debugPrint('Token Error ${response.statusCode}: ${errorBody['message']}');
        throw Exception('Token error: ${errorBody['message']}');
      } catch (e) {
        debugPrint('Token fetch error (Attempt $attempt): $e');
        if (attempt < retries) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  static Future<bool> requestToPay({
    required String amount,
    // UPDATED: Default currency to 'EUR' for sandbox testing
    String currency = 'EUR',
    String? externalId,
    required String payerMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    debugPrint('requestToPay: Raw phone: $payerMobile');

    final formattedPayerMobile = _formatPhoneNumberForMomo(payerMobile);
    debugPrint('requestToPay: Formatted phone: $formattedPayerMobile');

    final token = await getAccessToken();
    if (token == null) throw Exception('Failed to obtain access token');

    final amountValue = double.tryParse(amount);
    // Adjust amount validation based on EUR for sandbox if needed,
    // but typically MoMo's sandbox accepts various amounts.
    if (amountValue == null || amountValue < 1 || amountValue > 1000000) { // Using a broader range for EUR
      throw Exception('Amount must be a valid number and within reasonable limits.');
    }

    final refId = externalId ?? _uuid.v4();
    // UPDATED: Ensure currency is 'EUR' if it's explicitly 'UGX' or unsupported
    final cur = supportedCurrencies.contains(currency.toUpperCase())
        ? currency.toUpperCase()
        : 'EUR'; // Fallback to EUR if provided currency is not in supported list

    final payload = {
      'amount': amountValue.toStringAsFixed(0),
      'currency': cur,
      'externalId': refId, // Worker will use this as X-Reference-Id
      'payer': {
        'partyIdType': 'MSISDN',
        'partyId': formattedPayerMobile,
      },
      'payerMessage': payerMessage,
      'payeeNote': payeeNote,
      'accessToken': token, // Access token is passed to the Worker
    };

    int retries = 3;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/requestToPay'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        // MoMo API usually responds with 202 Accepted for successful initiation
        if (response.statusCode == 202) {
          debugPrint('RequestToPay: Accepted (202), refId: $refId');
          await _saveTransaction(refId, amount, payerMobile, 'requestToPay');
          final status = await _checkTransactionStatus(refId, token);
          return status == 'SUCCESSFUL';
        }

        // If MoMo returns an error, decode and throw
        final errorBody = jsonDecode(response.body);
        final message = errorBody['message'] ?? 'Unknown error message from MoMo API.';
        final error = errorBody['error'] ?? 'Request failed on MoMo API side.';
        debugPrint('RequestToPay error ${response.statusCode}: $message');

        throw Exception('$error: $message');
      } catch (e) {
        debugPrint('RequestToPay error (Attempt $attempt): $e');
        if (attempt < retries) await Future.delayed(const Duration(seconds: 2));
        if (attempt == retries) rethrow; // Re-throw the last error after all retries
      }
    }

    return false; // Should not be reached if rethrow is used
  }

  static Future<bool> transfer({
    required String amount,
    // UPDATED: Default currency to 'EUR' for sandbox testing
    String currency = 'EUR',
    String? externalId,
    required String payeeMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    debugPrint('transfer: Raw phone: $payeeMobile');

    final formattedPayeeMobile = _formatPhoneNumberForMomo(payeeMobile);
    debugPrint('transfer: Formatted phone: $formattedPayeeMobile');

    final token = await getAccessToken();
    if (token == null) throw Exception('Failed to obtain access token');

    final amountValue = double.tryParse(amount);
    if (amountValue == null || amountValue < 1 || amountValue > 1000000) { // Using a broader range for EUR
      throw Exception('Amount must be a valid number and within reasonable limits.');
    }

    final refId = externalId ?? _uuid.v4();
    // UPDATED: Ensure currency is 'EUR' if it's explicitly 'UGX' or unsupported
    final cur = supportedCurrencies.contains(currency.toUpperCase())
        ? currency.toUpperCase()
        : 'EUR'; // Fallback to EUR if provided currency is not in supported list

    final payload = {
      'amount': amountValue.toStringAsFixed(0),
      'currency': cur,
      'externalId': refId,
      'payee': {
        'partyIdType': 'MSISDN',
        'partyId': formattedPayeeMobile,
      },
      'payerMessage': payerMessage,
      'payeeNote': payeeNote,
      'accessToken': token,
    };

    int retries = 3;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/transfer'),
          headers: {
            'Content-Type': 'application/json',
            // Note: X-Reference-Id and Ocp-Apim-Subscription-Key are
            // handled by your Cloudflare Worker for transfer endpoint as well.
            // If the Worker is not proxying these, you might need them here.
            // Based on your Worker code, it should be handling these for transfer too.
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 202) {
          debugPrint('Transfer: Accepted (202), refId: $refId');
          await _saveTransaction(refId, amount, payeeMobile, 'transfer');
          final status = await _checkTransactionStatus(refId, token, isDisbursement: true);
          return status == 'SUCCESSFUL';
        }

        final errorBody = jsonDecode(response.body);
        final message = errorBody['message'] ?? 'Unknown error message from MoMo API.';
        final error = errorBody['error'] ?? 'Transfer failed on MoMo API side.';
        debugPrint('Transfer error ${response.statusCode}: $message');

        throw Exception('$error: $message');
      } catch (e) {
        debugPrint('Transfer error (Attempt $attempt): $e');
        if (attempt < retries) await Future.delayed(const Duration(seconds: 2));
        if (attempt == retries) rethrow;
      }
    }

    return false;
  }

  static Future<String?> _checkTransactionStatus(String externalId, String token,
      {bool isDisbursement = false}) async {
    debugPrint('Checking transaction status: $externalId (isDisbursement: $isDisbursement)');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Your Worker handles the headers for this request,
        // just needs externalId, accessToken, and isDisbursement flag.
        final response = await http.get(
          Uri.parse(
              '$_baseUrl/checkTransactionStatus?externalId=$externalId&accessToken=$token&isDisbursement=$isDisbursement'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          debugPrint('Transaction status: $status');
          if (status == 'SUCCESSFUL' || status == 'FAILED') return status;
        }

        // If not yet successful/failed, wait and retry
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Status check error (Attempt $attempt): $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return 'FAILED'; // If after retries, status is not definitive
  }

  static Future<void> _saveTransaction(String externalId, String amount, String mobile, String type) async {
    debugPrint('Saving transaction: $externalId | $type | $mobile');
    await _firestore.collection('transactions').doc(externalId).set({
      'externalId': externalId,
      'amount': amount,
      'mobile': mobile,
      'type': type,
      'status': 'initiated', // Initial status, will be updated by webhook or polling
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}