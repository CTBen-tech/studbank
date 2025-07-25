// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\lib\services\momo_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class MomoService {
  static const String _baseUrl = 'https://momo-proxy.studbank.workers.dev';

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
    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting requestToPay (attempt $attempt/$retries)...');
        final response = await http.post(
          Uri.parse('$_baseUrl/requestToPay'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'amount': amount,
            'currency': currency,
            'externalId': externalId,
            'payerMobile': payerMobile,
            'payerMessage': payerMessage,
            'payeeNote': payeeNote,
            'accessToken': token,
          }),
        );
        print('Request to Pay response: ${response.statusCode}, ${response.body}');
        if (response.statusCode == 202) {
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
    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting transfer (attempt $attempt/$retries)...');
        final response = await http.post(
          Uri.parse('$_baseUrl/transfer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'amount': amount,
            'currency': currency,
            'externalId': externalId,
            'payeeMobile': payeeMobile,
            'payerMessage': payerMessage,
            'payeeNote': payeeNote,
            'accessToken': token,
          }),
        );
        print('Transfer response: ${response.statusCode}, ${response.body}');
        if (response.statusCode == 202) {
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
          headers: {'Content-Type': 'application/json'},
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
}