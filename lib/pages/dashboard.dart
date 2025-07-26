// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\lib\pages\dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:studbank/services/momo_service.dart';
import '../services/auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState(); // Public state class
}

class DashboardPageState extends State<DashboardPage> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  final User? user = FirebaseAuth.instance.currentUser;
  String _selectedPhoneNumber = ''; // Store complete phone number with country code

  @override
  void initState() {
    super.initState();
    if (user != null) {
      AuthService.initializeUser(user!).catchError((e) {
        debugPrint('Error initializing user: $e');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load user data. Please try logging out and back in.';
        });
      });
    } else {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No user logged in. Please log in to continue.';
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
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No user logged in. Please log in to continue.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int retries = 3;
    int attempt = 1;
    bool completed = false;
    while (attempt <= retries && !completed) {
      try {
        debugPrint('Attempting deposit (attempt $attempt/$retries)...');
        final amount = _amountController.text;
        final phone = _selectedPhoneNumber;
        final externalId = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';

        final success = await MomoService.requestToPay(
          amount: amount,
          currency: 'UGX',
          externalId: externalId,
          payerMobile: phone,
          payerMessage: 'Deposit to StudBank',
          payeeNote: 'Deposit for ${user!.email}',
        );

        if (!mounted) return;
        if (success) {
          final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final snapshot = await transaction.get(userDoc);
            if (!snapshot.exists) throw Exception('User document not found');
            transaction.update(userDoc, {
              'balance': FieldValue.increment(double.parse(amount)),
            });
            transaction.set(
              userDoc.collection('transactions').doc(),
              {
                'type': 'deposit',
                'amount': double.parse(amount),
                'timestamp': FieldValue.serverTimestamp(),
                'externalId': externalId,
                'status': 'SUCCESSFUL',
              },
            );
          });
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Deposit successful!';
            _amountController.clear();
            _phoneController.clear();
          });
        } else {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Deposit failed. Please verify your phone number and try again.';
          });
        }
        completed = true;
      } catch (e) {
        debugPrint('Deposit error (attempt $attempt/$retries): $e');
        String errorMessage = 'Error processing deposit. Please try again.';
        if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
          if (attempt < retries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            attempt++;
            continue;
          }
        } else if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. Contact support for assistance.';
        }
        if (!mounted) return;
        setState(() {
          _errorMessage = errorMessage;
        });
        completed = true;
      }
    }
    if (mounted && !completed) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawFunds() async {
    if (!_formKey.currentState!.validate()) return;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No user logged in. Please log in to continue.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    int retries = 3;
    int attempt = 1;
    bool completed = false;
    while (attempt <= retries && !completed) {
      try {
        debugPrint('Attempting withdrawal (attempt $attempt/$retries)...');
        final amount = _amountController.text;
        final phone = _selectedPhoneNumber;
        final externalId = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);

        final success = await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userDoc);
          if (!snapshot.exists) throw Exception('User document not found');
          final currentBalance = snapshot.data()?['balance']?.toDouble() ?? 0.0;
          final withdrawAmount = double.parse(amount);

          if (withdrawAmount > currentBalance) {
            if (!mounted) return false;
            setState(() {
              _errorMessage = 'Insufficient balance. Please add funds or reduce the amount.';
            });
            return false;
          }

          final momoSuccess = await MomoService.transfer(
            amount: amount,
            currency: 'UGX',
            externalId: externalId,
            payeeMobile: phone,
            payerMessage: 'Withdrawal from StudBank',
            payeeNote: 'Withdrawal for ${user!.email}',
          );

          if (momoSuccess) {
            transaction.update(userDoc, {
              'balance': FieldValue.increment(-withdrawAmount),
            });
            transaction.set(
              userDoc.collection('transactions').doc(),
              {
                'type': 'withdrawal',
                'amount': withdrawAmount,
                'timestamp': FieldValue.serverTimestamp(),
                'externalId': externalId,
                'status': 'SUCCESSFUL',
              },
            );
            return true;
          }
          return false;
        });

        if (!mounted) return;
        if (success) {
          setState(() {
            _errorMessage = 'Withdrawal successful!';
            _amountController.clear();
            _phoneController.clear();
          });
        } else if (_errorMessage == null) {
          setState(() {
            _errorMessage = 'Withdrawal failed. Please verify your phone number and try again.';
          });
        }
        completed = true;
      } catch (e) {
        debugPrint('Withdrawal error (attempt $attempt/$retries): $e');
        String errorMessage = 'Error processing withdrawal. Please try again.';
        if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
          if (attempt < retries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            attempt++;
            continue;
          }
        } else if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied. Contact support for assistance.';
        }
        if (!mounted) return;
        setState(() {
          _errorMessage = errorMessage;
        });
        completed = true;
      }
    }
    if (mounted && !completed) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        title: const Text('StudBank Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigatorContext = context;
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(navigatorContext, '/login');
              }
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('No user logged in. Please log in to continue.'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('Firestore error: ${snapshot.error}');
                  String errorMessage = 'Error loading data. Please try again.';
                  if (snapshot.error.toString().contains('network')) {
                    errorMessage = 'Network error. Please check your internet connection and try again.';
                  } else if (snapshot.error.toString().contains('permission-denied')) {
                    errorMessage = 'Permission denied. Contact support for assistance.';
                  }
                  return Center(child: Text(errorMessage));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('User data not found. Please log in again.'));
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
                            key: const ValueKey('amount'),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter a valid amount greater than 0';
                              }
                              if (value.contains('.') && value.split('.')[1].length > 2) {
                                return 'Amount cannot have more than 2 decimal places';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          IntlPhoneField(
                            key: const ValueKey('phone'),
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                            initialCountryCode: 'UG',
                            onChanged: (phone) {
                              _selectedPhoneNumber = phone.completeNumber;
                            },
                            validator: (phone) {
                              if (phone == null || phone.number.isEmpty) {
                                return 'Please select a country code and enter a phone number';
                              }
                              if (!phone.isValidNumber()) {
                                return 'Please enter a valid phone number for the selected country';
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