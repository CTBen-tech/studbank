import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:studbank/services/momo_service.dart';
import '../services/auth_service.dart';
import 'dart:async'; // Import for Timer

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
  String _selectedPhoneNumber = ''; // Holds the complete number from IntlPhoneField

  // Map to hold pending transactions: {externalId: Timer}
  final Map<String, Timer> _pendingTransactions = {};

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
      _loadAndMonitorPendingTransactions(); // Load existing pending transactions
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
    for (var timer in _pendingTransactions.values) {
      timer.cancel();
    } // Cancel all active timers
    super.dispose();
  }

  // New method to load and monitor pending transactions from Firestore
  void _loadAndMonitorPendingTransactions() {
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('transactions')
        .where('status', isEqualTo: 'PENDING')
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        final externalId = doc.data()['externalId'] as String?;
        if (externalId != null && !_pendingTransactions.containsKey(externalId)) {
          _startPollingTransaction(externalId, doc.reference);
        }
      }
    }).catchError((e) {
      debugPrint('Error loading pending transactions: $e');
    });
  }


  // New method to handle polling for transaction status
  void _startPollingTransaction(String externalId, DocumentReference transactionDocRef) {
    // Poll every 10 seconds for up to 2 minutes (12 attempts)
    int attempts = 0;
    const maxAttempts = 12; // 12 attempts * 10 seconds = 120 seconds (2 minutes)

    final timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        _pendingTransactions.remove(externalId);
        return;
      }

      attempts++;
      debugPrint('Polling status for $externalId (Attempt $attempts)');

      try {
        final statusResponse = await MomoService().getPaymentStatus(externalId);
        final moMoStatus = statusResponse['status'] as String?;
        final financialTransactionId = statusResponse['financialTransactionId'] as String?;

        if (moMoStatus == 'SUCCESSFUL' || moMoStatus == 'FAILED') {
          timer.cancel();
          _pendingTransactions.remove(externalId);
          await _handleFinalTransactionStatus(transactionDocRef, moMoStatus!, financialTransactionId);
        } else if (attempts >= maxAttempts) {
          timer.cancel();
          _pendingTransactions.remove(externalId);
          debugPrint('Max polling attempts reached for $externalId. Marking as UNKNOWN/FAILED.');
          await _handleFinalTransactionStatus(transactionDocRef, 'FAILED_TIMEOUT', financialTransactionId);
        }
      } catch (e) {
        debugPrint('Error during polling for $externalId: $e');
        if (attempts >= maxAttempts) {
          timer.cancel();
          _pendingTransactions.remove(externalId);
          await _handleFinalTransactionStatus(transactionDocRef, 'FAILED_POLLING_ERROR', null);
        }
      }
    });

    _pendingTransactions[externalId] = timer;
  }

  // New method to update Firestore based on final MoMo status
  Future<void> _handleFinalTransactionStatus(
      DocumentReference transactionDocRef, String status, String? financialTransactionId) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final transactionSnapshot = await transaction.get(transactionDocRef);
      if (!transactionSnapshot.exists) {
        throw Exception('Transaction document not found during status update');
      }

      final transactionData = transactionSnapshot.data() as Map<String, dynamic>;
      final transactionType = transactionData['type'];
      final transactionAmount = transactionData['amount'];
      final userId = transactionDocRef.parent.parent!.id; // Get the user ID from the transaction path
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Update the transaction status
      final updateData = {
        'status': status,
        'finalTimestamp': FieldValue.serverTimestamp(),
      };
      if (financialTransactionId != null) {
        updateData['financialTransactionId'] = financialTransactionId;
      }
      transaction.update(transactionDocRef, updateData);


      // Only update balance if SUCCESSFUL and if it's a deposit/withdrawal
      if (status == 'SUCCESSFUL') {
        if (transactionType == 'deposit') {
          transaction.update(userDocRef, {
            'balance': FieldValue.increment(transactionAmount),
          });
          if (mounted) {
            setState(() {
              _errorMessage = 'Deposit of $transactionAmount EUR successful!'; // Indicate EUR
            });
          }
        } else if (transactionType == 'withdrawal') {
          // IMPORTANT: For withdrawal, you must verify the user has sufficient balance
          // before initiating the MoMo transfer. The Firestore update below only occurs
          // AFTER MoMo confirms success. It's best to check balance *before* MoMo call.
          transaction.update(userDocRef, {
            'balance': FieldValue.increment(-transactionAmount),
          });
          if (mounted) {
            setState(() {
              _errorMessage = 'Withdrawal of $transactionAmount EUR successful!'; // Indicate EUR
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '${transactionType == 'deposit' ? 'Deposit' : 'Withdrawal'} failed/timed out: $status';
          });
        }
      }
    }).catchError((e) {
      debugPrint('Error during Firestore transaction update: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update transaction in database: $e';
        });
      }
    });
  }


  Future<void> _addFunds() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

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

    final amount = _amountController.text.trim();
    // MoMo Sandbox test numbers for success: 256772123456
    // For failure: 256772123457
    // For pending: 256772123458
    // For too many requests: 256772123459
    // Always use these for testing in sandbox.

    // Generate a unique ID for this transaction
    final externalId = '${user!.uid}_deposit_${DateTime.now().millisecondsSinceEpoch}';

    try {
      debugPrint('Dashboard: Phone number being sent for Deposit: $_selectedPhoneNumber');

      // Store the transaction as PENDING immediately in Firestore
      final transactionDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .doc(); // Let Firestore generate the ID

      await transactionDocRef.set({
        'type': 'deposit',
        'amount': double.parse(amount),
        'timestamp': FieldValue.serverTimestamp(),
        'externalId': externalId,
        'status': 'PENDING', // Initial status
        'phoneNumber': _selectedPhoneNumber, // Store for auditing
        'currency': 'EUR', // Store the currency used with MoMo
      });


      final moMoResponse = await MomoService().requestToPay(
        amount: amount,
        currency: 'EUR', // Hardcode EUR for MoMo Sandbox
       
        payerMobile: _selectedPhoneNumber,
        payerMessage: 'Deposit to StudBank',
        payeeNote: 'Deposit for ${user!.email}',
      );

      // If we get a 202 Accepted, start polling for status
      if (moMoResponse['status'] == 'PENDING') {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Deposit request sent. Waiting for confirmation. (Ref: $externalId)';
        });
        // Start polling for the status of this transaction
        _startPollingTransaction(externalId, transactionDocRef);
      } else {
        // This case should ideally not happen if the worker returns 202 and 'PENDING'
        // for successful initiation, but good for robustness.
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Deposit request received unexpected status: ${moMoResponse['status']}';
          // Update transaction status to reflect immediate failure if response wasn't PENDING
          transactionDocRef.update({'status': 'FAILED_INITIATION', 'finalTimestamp': FieldValue.serverTimestamp()});
        });
      }
    } catch (e) {
      debugPrint('Deposit error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error processing deposit. ${e.toString()}';
      });
      // Consider updating transaction status to FAILED in Firestore if it was initially added
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _amountController.clear();
          _phoneController.clear();
          _selectedPhoneNumber = ''; // Clear for next input
        });
      }
    }
  }

  Future<void> _withdrawFunds() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

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

    final amount = _amountController.text.trim();
    final currentBalance = (await FirebaseFirestore.instance.collection('users').doc(user!.uid).get()).data()?['balance']?.toDouble() ?? 0.0;

    // IMPORTANT: Check balance *before* initiating withdrawal
    if (double.parse(amount) > currentBalance) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Insufficient balance for withdrawal.';
        _isLoading = false;
      });
      return;
    }

    final externalId = '${user!.uid}_withdrawal_${DateTime.now().millisecondsSinceEpoch}';

    try {
      debugPrint('Dashboard: Phone number being sent for Withdrawal: $_selectedPhoneNumber');

      // Store the transaction as PENDING immediately in Firestore
      final transactionDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .doc();

      await transactionDocRef.set({
        'type': 'withdrawal',
        'amount': double.parse(amount),
        'timestamp': FieldValue.serverTimestamp(),
        'externalId': externalId,
        'status': 'PENDING', // Initial status
        'phoneNumber': _selectedPhoneNumber, // Store for auditing
        'currency': 'EUR', // Store the currency used with MoMo
      });

      final moMoResponse = await MomoService().transfer( // Use the transfer method
        amount: amount,
        currency: 'EUR', // Hardcode EUR for MoMo Sandbox
       
        payeeMobile: _selectedPhoneNumber,
        payerMessage: 'Withdrawal from StudBank',
        payeeNote: 'Withdrawal for ${user!.email}',
      );

      if (moMoResponse['status'] == 'PENDING') {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Withdrawal request sent. Waiting for confirmation. (Ref: $externalId)';
        });
        _startPollingTransaction(externalId, transactionDocRef);
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Withdrawal request received unexpected status: ${moMoResponse['status']}';
          transactionDocRef.update({'status': 'FAILED_INITIATION', 'finalTimestamp': FieldValue.serverTimestamp()});
        });
      }

    } catch (e) {
      debugPrint('Withdrawal error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error processing withdrawal. ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _amountController.clear();
          _phoneController.clear();
          _selectedPhoneNumber = '';
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
                        Text('Balance: UGX ${balance.toStringAsFixed(2)}', // Display as UGX, but remember MoMo is EUR in sandbox
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount (EUR in Sandbox)'),
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
                            debugPrint('IntlPhoneField onChanged: ${phone.completeNumber}');
                          },
                          onSaved: (phone) {
                            if (phone != null) {
                              _selectedPhoneNumber = phone.completeNumber;
                              debugPrint('IntlPhoneField onSaved: ${phone.completeNumber}');
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