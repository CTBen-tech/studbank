// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\lib\services\momo_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class MomoService {
  static const String _baseUrl = 'https://momo-proxy.studbank.workers.dev';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String?> getAccessToken() async {
    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting to get MoMo token (attempt $attempt/$retries)...');
        final response = await http.post(
          Uri.parse('$_baseUrl/getMomoToken'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        );
        print('Token response: ${response.statusCode}, ${response.body}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['access_token'] != null) {
            print('Token received: ${data['access_token']}');
            return data['access_token'];
          }
          print('No access_token in response: ${response.body}');
          return null;
        }
        print('Token request failed: ${response.statusCode}, ${response.body}');
        if (response.statusCode >= 500 && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        return null;
      } catch (e) {
        print('Error generating token (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        return null;
      }
    }
    return null;
  }

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
      print('No access token for requestToPay');
      throw Exception('Failed to obtain access token');
    }

    // Validate inputs
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(payerMobile)) {
      throw Exception('Invalid phone number format. Use a valid number with country code (e.g., +256712345678).');
    }
    final amountValue = double.tryParse(amount);
    if (amountValue == null || amountValue < 100 || amountValue > 1000000) {
      throw Exception('Amount must be between UGX 100 and UGX 1,000,000.');
    }

    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting requestToPay (attempt $attempt/$retries)...');
        final response = await http.post(
          Uri.parse('$_baseUrl/requestToPay'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-Reference-Id': externalId,
            'Ocp-Apim-Subscription-Key': 'YOUR_SUBSCRIPTION_KEY', // Replace with actual key
          },
          body: jsonEncode({
            'amount': amountValue.toStringAsFixed(0), // MoMo expects integer amounts
            'currency': currency,
            'externalId': externalId,
            'payer': {
              'partyIdType': 'MSISDN',
              'partyId': payerMobile,
            },
            'payerMessage': payerMessage,
            'payeeNote': payeeNote,
          }),
        );
        print('Request to Pay response: ${response.statusCode}, ${response.body}');
        if (response.statusCode == 202) {
          await _saveTransaction(externalId, amount, payerMobile, 'requestToPay');
          final status = await _checkTransactionStatus(externalId, token);
          return status == 'SUCCESSFUL';
        }
        if (response.statusCode >= 500 && attempt < retries) {
          print('Server error, retrying: ${response.statusCode}');
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        throw Exception('Request to Pay failed: ${response.statusCode}, ${response.body}');
      } catch (e) {
        print('Request to Pay error (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        throw Exception('Request to Pay failed: $e');
      }
    }
    return false;
  }

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
      print('No access token for transfer');
      throw Exception('Failed to obtain access token');
    }

    // Validate inputs
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(payeeMobile)) {
      throw Exception('Invalid phone number format. Use a valid number with country code (e.g., +256712345678).');
    }
    final amountValue = double.tryParse(amount);
    if (amountValue == null || amountValue < 100 || amountValue > 1000000) {
      throw Exception('Amount must be between UGX 100 and UGX 1,000,000.');
    }

    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting transfer (attempt $attempt/$retries)...');
        final response = await http.post(
          Uri.parse('$_baseUrl/transfer'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-Reference-Id': externalId,
            'Ocp-Apim-Subscription-Key': 'YOUR_SUBSCRIPTION_KEY', // Replace with actual key
          },
          body: jsonEncode({
            'amount': amountValue.toStringAsFixed(0), // MoMo expects integer amounts
            'currency': currency,
            'externalId': externalId,
            'payee': {
              'partyIdType': 'MSISDN',
              'partyId': payeeMobile,
            },
            'payerMessage': payerMessage,
            'payeeNote': payeeNote,
          }),
        );
        print('Transfer response: ${response.statusCode}, ${response.body}');
        if (response.statusCode == 202) {
          await _saveTransaction(externalId, amount, payeeMobile, 'transfer');
          final status = await _checkTransactionStatus(externalId, token, isDisbursement: true);
          return status == 'SUCCESSFUL';
        }
        if (response.statusCode >= 500 && attempt < retries) {
          print('Server error, retrying: ${response.statusCode}');
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        throw Exception('Transfer failed: ${response.statusCode}, ${response.body}');
      } catch (e) {
        print('Transfer error (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        throw Exception('Transfer failed: $e');
      }
    }
    return false;
  }

  static Future<String?> _checkTransactionStatus(String externalId, String token, {bool isDisbursement = false}) async {
    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Checking transaction status (attempt $attempt/$retries)...');
        final response = await http.get(
          Uri.parse('$_baseUrl/checkTransactionStatus?externalId=$externalId&accessToken=$token&isDisbursement=$isDisbursement'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        print('Status check response: ${response.statusCode}, ${response.body}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          if (status == 'SUCCESSFUL' || status == 'FAILED') {
            return status;
          }
        }
        if (response.statusCode >= 500 && attempt < retries) {
          print('Server error, retrying status check: ${response.statusCode}');
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        await Future.delayed(const Duration(seconds: 5));
        attempt++;
      } catch (e) {
        print('Error checking transaction status (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        return 'FAILED';
      }
    }
    print('Transaction status pending after retries: $externalId');
    return 'FAILED';
  }

  static Future<void> _saveTransaction(String externalId, String amount, String mobile, String type) async {
    await _firestore.collection('transactions').doc(externalId).set({
      'externalId': externalId,
      'amount': amount,
      'mobile': mobile,
      'type': type,
      'status': 'initiated',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}