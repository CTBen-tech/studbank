import '../services/firestore_service.dart';

class PaymentController {
  final FirestoreService _firestoreService = FirestoreService();

  /// Processes a payment by updating user balance and saving the transaction.
  Future<void> makePayment({
    required String userId,
    required double amount,
    required String transactionId,
    required String status,
    required DateTime timestamp,
    String? payerMobile, // optional
  }) async {
    // Update user balance
    await _firestoreService.updateUserBalance(userId, amount);

    // Save transaction details
    await _firestoreService.saveTransaction(
      userId: userId,
      amount: amount.toString(),
      transactionId: transactionId,
      status: status,
      timestamp: timestamp,
      //payerMobile: payerMobile,
    );
  }
}
