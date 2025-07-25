// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\lib\pages\dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:studbank/services/momo_service.dart';
import '../services/auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize user data via AuthService
    if (user != null) {
      AuthService.initializeUser(user!).catchError((e) {
        print('Error initializing user: $e');
        setState(() {
          _errorMessage = 'Error loading user data: $e';
        });
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addFunds() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting deposit (attempt $attempt/$retries)...');
        final amount = _amountController.text;
        final phone = _phoneController.text;
        final externalId = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';

        final success = await MomoService.requestToPay(
          amount: amount,
          currency: 'UGX',
          externalId: externalId,
          payerMobile: phone,
          payerMessage: 'Deposit to StudBank',
          payeeNote: 'Deposit for ${user!.email}',
        );

        if (success) {
          final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
          await userDoc.update({
            'balance': FieldValue.increment(double.parse(amount)),
          });
          await userDoc.collection('transactions').add({
            'type': 'deposit',
            'amount': double.parse(amount),
            'timestamp': FieldValue.serverTimestamp(),
            'externalId': externalId,
            'status': 'SUCCESSFUL',
          });
          setState(() {
            _errorMessage = 'Deposit successful!';
          });
          _amountController.clear();
          _phoneController.clear();
        } else {
          setState(() {
            _errorMessage = 'Deposit failed. Please try again.';
          });
        }
        break;
      } catch (e) {
        print('Deposit error (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        setState(() {
          _errorMessage = 'Error: $e';
        });
        break;
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _withdrawFunds() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        print('Attempting withdrawal (attempt $attempt/$retries)...');
        final amount = _amountController.text;
        final phone = _phoneController.text;
        final externalId = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
        final docSnapshot = await userDoc.get();
        final currentBalance = docSnapshot.data()?['balance']?.toDouble() ?? 0.0;
        final withdrawAmount = double.parse(amount);

        if (withdrawAmount > currentBalance) {
          setState(() {
            _errorMessage = 'Insufficient balance';
          });
          return;
        }

        final success = await MomoService.transfer(
          amount: amount,
          currency: 'UGX',
          externalId: externalId,
          payeeMobile: phone,
          payerMessage: 'Withdrawal from StudBank',
          payeeNote: 'Withdrawal for ${user!.email}',
        );

        if (success) {
          await userDoc.update({
            'balance': FieldValue.increment(-withdrawAmount),
          });
          await userDoc.collection('transactions').add({
            'type': 'withdrawal',
            'amount': withdrawAmount,
            'timestamp': FieldValue.serverTimestamp(),
            'externalId': externalId,
            'status': 'SUCCESSFUL',
          });
          setState(() {
            _errorMessage = 'Withdrawal successful!';
          });
          _amountController.clear();
          _phoneController.clear();
        } else {
          setState(() {
            _errorMessage = 'Withdrawal failed. Please try again.';
          });
        }
        break;
      } catch (e) {
        print('Withdrawal error (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          attempt++;
          continue;
        }
        setState(() {
          _errorMessage = 'Error: $e';
        });
        break;
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2), // Match login/signup
      appBar: AppBar(
        title: const Text('StudBank Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Firestore error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final balance = data['balance']?.toDouble() ?? 0.0;
          final name = data['name'] ?? 'User';
          final uid = data['uid'] ?? 'N/A';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Account ID: $uid',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Balance: UGX ${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('amount'), // Fix webhint
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount (UGX)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.money, color: Colors.blue),
                        filled: true,
                        fillColor: Colors.white,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('phone'), // Fix webhint
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number (e.g., +256123456789)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                        filled: true,
                        fillColor: Colors.white,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        if (!RegExp(r'^\+256[0-9]{9}$').hasMatch(value)) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ElevatedButton(
                                    onPressed: _addFunds,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: const Text(
                                      'Add Funds',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ElevatedButton(
                                    onPressed: _withdrawFunds,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: const Text(
                                      'Withdraw Funds',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: _errorMessage!.contains('successful') ? Colors.green : Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}