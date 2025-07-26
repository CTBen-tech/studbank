// File: momo_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class MomoService {
  static const String _baseUrl = 'https://momo-proxy.studbank.workers.dev';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const List<String> supportedCurrencies = ['UGX'];
  static final _uuid = Uuid();

  static Future<String?> getAccessToken() async {
    int retries = 3;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/getMomoToken'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['access_token'];
        }
        if (response.statusCode >= 500 && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      } catch (_) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  static Future<bool> requestToPay({
    required String amount,
    String currency = 'UGX',
    String? externalId,
    required String payerMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('Failed to obtain access token');

    // Validate mobile number
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(payerMobile)) {
      throw Exception('Invalid phone number format. Use +256 format.');
    }

    final amountValue = double.tryParse(amount);
    if (amountValue == null || amountValue < 100 || amountValue > 1000000) {
      throw Exception('Amount must be between UGX 100 and UGX 1,000,000.');
    }

    final refId = externalId ?? _uuid.v4();
    final cur = supportedCurrencies.contains(currency.toUpperCase()) ? currency.toUpperCase() : 'UGX';

    int retries = 3;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/requestToPay'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-Reference-Id': refId,
            'Ocp-Apim-Subscription-Key': '2c28040e2be54efb94a6d8d16b7ecc92', // replace this
          },
          body: jsonEncode({
            'amount': amountValue.toStringAsFixed(0),
            'currency': cur,
            'externalId': refId,
            'payer': {
              'partyIdType': 'MSISDN',
              'partyId': payerMobile,
            },
            'payerMessage': payerMessage,
            'payeeNote': payeeNote,
          }),
        );

        if (response.statusCode == 202) {
          await _saveTransaction(refId, amount, payerMobile, 'requestToPay');
          final status = await _checkTransactionStatus(refId, token);
          return status == 'SUCCESSFUL';
        } else if (response.statusCode == 409 &&
                   response.body.contains('RESOURCE_ALREADY_EXIST') &&
                   attempt < retries) {
          // regenerate referenceId and retry
          print('Duplicated reference ID, retrying...');
          await Future.delayed(Duration(seconds: attempt * 2));
          return await requestToPay(
            amount: amount,
            currency: currency,
            externalId: _uuid.v4(), // new id
            payerMobile: payerMobile,
            payerMessage: payerMessage,
            payeeNote: payeeNote,
          );
        }
        throw Exception('Request to Pay failed: ${response.statusCode}, ${response.body}');
      } catch (e) {
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        } else {
          throw Exception('Request to Pay error: $e');
        }
      }
    }
    return false;
  }

  static Future<bool> transfer({
    required String amount,
    String currency = 'UGX',
    String? externalId,
    required String payeeMobile,
    required String payerMessage,
    required String payeeNote,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('Failed to obtain access token');

    if (!RegExp(r'^\+\d{10,15}$').hasMatch(payeeMobile)) {
      throw Exception('Invalid phone number format. Use +256 format.');
    }

    final amountValue = double.tryParse(amount);
    if (amountValue == null || amountValue < 100 || amountValue > 1000000) {
      throw Exception('Amount must be between UGX 100 and UGX 1,000,000.');
    }

    final refId = externalId ?? _uuid.v4();
    final cur = supportedCurrencies.contains(currency.toUpperCase()) ? currency.toUpperCase() : 'UGX';

    int retries = 3;
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/transfer'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-Reference-Id': refId,
            'Ocp-Apim-Subscription-Key': 'YOUR_SUBSCRIPTION_KEY', // replace this
          },
          body: jsonEncode({
            'amount': amountValue.toStringAsFixed(0),
            'currency': cur,
            'externalId': refId,
            'payee': {
              'partyIdType': 'MSISDN',
              'partyId': payeeMobile,
            },
            'payerMessage': payerMessage,
            'payeeNote': payeeNote,
          }),
        );

        if (response.statusCode == 202) {
          await _saveTransaction(refId, amount, payeeMobile, 'transfer');
          final status = await _checkTransactionStatus(refId, token, isDisbursement: true);
          return status == 'SUCCESSFUL';
        }
        throw Exception('Transfer failed: ${response.statusCode}, ${response.body}');
      } catch (e) {
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        } else {
          throw Exception('Transfer error: $e');
        }
      }
    }
    return false;
  }

  static Future<String?> _checkTransactionStatus(String externalId, String token, {bool isDisbursement = false}) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/checkTransactionStatus?externalId=$externalId&accessToken=$token&isDisbursement=$isDisbursement'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];
          if (status == 'SUCCESSFUL' || status == 'FAILED') {
            return status;
          }
        }
        await Future.delayed(const Duration(seconds: 5));
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
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
