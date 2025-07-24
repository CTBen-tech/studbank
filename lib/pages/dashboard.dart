import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/momo_service.dart';
import '../api_constants.dart';

// DashboardPage is a StatefulWidget that displays the main dashboard for the Safe Budget app
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _inactivityTimer;
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetTimer();
    print('MoMo API Base URL: ${ApiConstants.baseUrl}');
    _initializeUser();
  }

  void _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnapshot = await userRef.get();
        if (!docSnapshot.exists) {
          await userRef.set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? 'Guest',
            'balance': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (docSnapshot.data()?['balance'] == null) {
          await userRef.set({
            'balance': 0.0,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        print('Error initializing user: $e');
      }
    }
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), _handleInactivity);
  }

  void _handleInactivity() {
    FirebaseAuth.instance.signOut().catchError((e) {
      print('Sign-out error: $e');
    });
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut().catchError((e) {
      print('Sign-out error: $e');
    });
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => FadeTransition(
        opacity: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeInOut,
        ),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text(
            'Error',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addFunds(String amount, String phoneNumber) async {
    if (amount.isEmpty || double.tryParse(amount) == null || double.parse(amount) <= 0) {
      if (mounted) {
        _showErrorDialog('Please enter a valid amount greater than 0');
      }
      return;
    }
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      if (mounted) {
        _showErrorDialog('Please enter a valid phone number (e.g., +256123456789)');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        _showErrorDialog('User not authenticated');
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final externalId = DateTime.now().millisecondsSinceEpoch.toString();
    final success = await MomoService.requestToPay(
      amount: amount,
      currency: 'UGX',
      externalId: externalId,
      payerMobile: phoneNumber,
      payerMessage: 'Add funds to Safe Budget',
      payeeNote: 'User deposit',
    );

    if (success) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'balance': FieldValue.increment(double.parse(amount)),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          _showErrorDialog('Funds added successfully');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Failed to update balance: $e');
        }
      }
    } else {
      if (mounted) {
        _showErrorDialog('Payment failed. Please try again.');
      }
    }
    setState(() {
      _isLoading = false;
    });
    _amountController.clear();
    _phoneController.clear();
  }

  void _withdrawFunds(String amount, String phoneNumber) async {
    if (amount.isEmpty || double.tryParse(amount) == null || double.parse(amount) <= 0) {
      if (mounted) {
        _showErrorDialog('Please enter a valid amount greater than 0');
      }
      return;
    }
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      if (mounted) {
        _showErrorDialog('Please enter a valid phone number (e.g., +256123456789)');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        _showErrorDialog('User not authenticated');
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentBalance = doc.data()?['balance']?.toDouble() ?? 0.0;
    final withdrawAmount = double.parse(amount);
    if (withdrawAmount > currentBalance) {
      if (mounted) {
        _showErrorDialog('Insufficient balance');
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final externalId = DateTime.now().millisecondsSinceEpoch.toString();
    final success = await MomoService.transfer(
      amount: amount,
      currency: 'UGX',
      externalId: externalId,
      payeeMobile: phoneNumber,
      payerMessage: 'Withdraw from Safe Budget',
      payeeNote: 'User withdrawal',
    );

    if (success) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'balance': FieldValue.increment(-withdrawAmount),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          _showErrorDialog('Funds withdrawn successfully');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Failed to update balance: $e');
        }
      }
    } else {
      if (mounted) {
        _showErrorDialog('Withdrawal failed. Please try again.');
      }
    }
    setState(() {
      _isLoading = false;
    });
    _amountController.clear();
    _phoneController.clear();
  }

  void _showActionSheet(BuildContext context, String title, Widget content) {
    _resetTimer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F6F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () {
                        _resetTimer();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _resetTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('No authenticated user found');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: _resetTimer,
      onPanDown: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F2),
        appBar: AppBar(
          title: const Text('Safe Budget Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_getGreeting()}, ${user.displayName ?? 'Guest'}!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  Widget balanceWidget;
                  if (snapshot.hasError) {
                    print('Firestore error: ${snapshot.error}');
                    balanceWidget = const Text(
                      'Error loading balance',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    );
                  } else if (!snapshot.hasData || !snapshot.data!.exists) {
                    balanceWidget = const Text(
                      'UGX 0.00',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final balance = data?['balance']?.toDouble() ?? 0.0;
                    balanceWidget = Text(
                      'UGX ${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Balance',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        balanceWidget,
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: HoverCard(
                        label: 'Add Funds',
                        icon: Icons.add_circle_outline,
                        onTap: () {
                          _showActionSheet(
                            context,
                            'Add Funds',
                            Column(
                              children: [
                                TextField(
                                  controller: _amountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number (e.g., +256123456789)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _isLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: () {
                                          _addFunds(
                                            _amountController.text,
                                            _phoneController.text,
                                          );
                                          _resetTimer();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Submit'),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HoverCard(
                        label: 'Withdraw',
                        icon: Icons.remove_circle_outline,
                        onTap: () {
                          _showActionSheet(
                            context,
                            'Withdraw Funds',
                            Column(
                              children: [
                                TextField(
                                  controller: _amountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number (e.g., +256123456789)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _isLoading
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: () {
                                          _withdrawFunds(
                                            _amountController.text,
                                            _phoneController.text,
                                          );
                                          _resetTimer();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Submit'),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HoverCard(
                        label: 'View Goals',
                        icon: Icons.flag_outlined,
                        onTap: () {
                          _showActionSheet(
                            context,
                            'Financial Goals',
                            Column(
                              children: [
                                Text(
                                  'No goals set yet.',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    _resetTimer();
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Add Goal'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const HoverCard({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.grey.shade200 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? Colors.blue.shade100 : Colors.grey.shade300,
                blurRadius: _isHovered ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 28, color: Colors.blue.shade800),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}