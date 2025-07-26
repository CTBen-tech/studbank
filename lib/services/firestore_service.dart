import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updateUserBalance(String userId, double amount) async {
    final userRef = _db.collection('users').doc(userId);
    await userRef.set({'balance': 0}, SetOptions(merge: true)); // Ensure doc exists

    await userRef.update({
      'balance': FieldValue.increment(amount),
    });
  }

  Future<void> addTransaction(String userId, Map<String, dynamic> txData) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add(txData);
  }

  /// ✅ Alias for compatibility with `payment_controller.dart`
  Future<void> saveTransaction({
    required String userId,
    required String amount,
    required String transactionId,
    required String status,
    required DateTime timestamp,
  }) async {
    final txData = {
      'amount': amount,
      'transactionId': transactionId,
      'status': status,
      'timestamp': timestamp,
    };

    await addTransaction(userId, txData);
  }
}
