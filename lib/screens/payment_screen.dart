import 'package:flutter/material.dart';
import '../controllers/payment_controller.dart';

class PaymentScreen extends StatefulWidget {
  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  final PaymentController _paymentController = PaymentController();
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);

    try {
      // Sample data (replace with real user/form input)
      String userId = 'testUser123';
      double amount = 5000.0;
      String transactionId = 'TX1234567890';
      String status = 'success';
      DateTime timestamp = DateTime.now();
      String? payerMobile = '0777000000'; // optional

      await _paymentController.makePayment(
        userId: userId,
        amount: amount,
        transactionId: transactionId,
        status: status,
        timestamp: timestamp,
        payerMobile: payerMobile,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment processed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Make Payment')),
      body: Center(
        child: _isProcessing
            ? CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _handlePayment,
                child: Text('Pay Now'),
              ),
      ),
    );
  }
}
