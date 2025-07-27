import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:studbank/services/momo_service.dart';
import '../services/auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  final User? user = FirebaseAuth.instance.currentUser;
  String _selectedPhoneNumber = '';

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
    _formKey.currentState!.save(); // 👈 Ensure phone number is captured

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

    try {
      final amount = _amountController.text.trim();
      // Fallback if _selectedPhoneNumber was not set by onSaved
      final rawPhone = _selectedPhoneNumber.isNotEmpty
          ? _selectedPhoneNumber
          : _phoneController.text;
      final phone = rawPhone.replaceAll(RegExp(r'[ +]'), ''); // Remove + and spaces
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
        setState(() {
          _errorMessage = 'Deposit successful!';
          _amountController.clear();
          _phoneController.clear();
          _selectedPhoneNumber = '';
        });
      } else {
        setState(() {
          _errorMessage = 'Deposit failed. Please verify your phone number and try again.';
        });
      }
    } catch (e) {
      debugPrint('Deposit error: $e');
      setState(() {
        _errorMessage = 'Error processing deposit. ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _withdrawFunds() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // 👈 Ensure phone number is captured

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

    try {
      final amount = _amountController.text.trim();
      final rawPhone = _selectedPhoneNumber.isNotEmpty
          ? _selectedPhoneNumber
          : _phoneController.text;
      final phone = rawPhone.replaceAll(RegExp(r'[ +]'), '');
      final externalId = '${user!.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final success = await MomoService.transfer(
        amount: amount,
        currency: 'UGX',
        externalId: externalId,
        payeeMobile: phone,
        payerMessage: 'Withdrawal from StudBank',
        payeeNote: 'Withdrawal for ${user!.email}',
      );

      if (!mounted) return;
      if (success) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userDoc);
          if (!snapshot.exists) throw Exception('User document not found');
          transaction.update(userDoc, {
            'balance': FieldValue.increment(-double.parse(amount)),
          });
          transaction.set(
            userDoc.collection('transactions').doc(),
            {
              'type': 'withdrawal',
              'amount': double.parse(amount),
              'timestamp': FieldValue.serverTimestamp(),
              'externalId': externalId,
              'status': 'SUCCESSFUL',
            },
          );
        });
        setState(() {
          _errorMessage = 'Withdrawal successful!';
          _amountController.clear();
          _phoneController.clear();
          _selectedPhoneNumber = '';
        });
      } else {
        setState(() {
          _errorMessage = 'Withdrawal failed. Please verify your phone number and try again.';
        });
      }
    } catch (e) {
      debugPrint('Withdrawal error: $e');
      setState(() {
        _errorMessage = 'Error processing withdrawal. ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
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
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Error loading user data.'));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final balance = data['balance']?.toDouble() ?? 0.0;
                final name = data['name'] ?? 'User';

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, $name', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('Balance: UGX ${balance.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount (UGX)'),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        IntlPhoneField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          initialCountryCode: 'UG',
                          onChanged: (phone) {
                            _selectedPhoneNumber = phone.completeNumber;
                          },
                          onSaved: (phone) {
                            if (phone != null) {
                              _selectedPhoneNumber = phone.completeNumber;
                            }
                          },
                          validator: (phone) {
                            if (phone == null || phone.number.isEmpty) {
                              return 'Please enter a phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _addFunds,
                                      child: const Text('Add Funds'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _withdrawFunds,
                                      child: const Text('Withdraw Funds'),
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
                                color: _errorMessage!.toLowerCase().contains('successful')
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
