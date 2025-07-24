import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/momo_service.dart'; // Imports MomoService for MoMo API interactions
import '../api_constants.dart'; // Imports ApiConstants for MoMo API credentials

// DashboardPage is a StatefulWidget that displays the main dashboard for the Safe Budget app
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

// State class for DashboardPage, managing UI state and logic
class _DashboardPageState extends State<DashboardPage> {
  Timer? _inactivityTimer; // Timer for auto sign-out after 5 minutes of inactivity
  // Controllers for user input in add/withdraw funds forms
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  // Flag to show loading indicator during API calls
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetTimer(); // Initialize inactivity timer
    // Reference ApiConstants to avoid unused_import warning (logs MoMo API base URL)
    print('MoMo API Base URL: ${ApiConstants.baseUrl}');
  }

  // Resets the inactivity timer to 5 minutes
  void _resetTimer() {
    _inactivityTimer?.cancel(); // Cancel existing timer
    _inactivityTimer = Timer(const Duration(minutes: 5), _handleInactivity);
  }

  // Handles user inactivity by signing out and navigating to login screen
  void _handleInactivity() {
    FirebaseAuth.instance.signOut().catchError((e) {
      print('Sign-out error: $e'); // Log any sign-out errors
    });
    // Fix: Check if widget is mounted before using Navigator
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel(); // Cancel timer to prevent memory leaks
    _amountController.dispose(); // Dispose amount input controller
    _phoneController.dispose(); // Dispose phone number input controller
    super.dispose();
  }

  // Returns a greeting based on the time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // Signs out the user and navigates to the login screen
  void _signOut() async {
    await FirebaseAuth.instance.signOut().catchError((e) {
      print('Sign-out error: $e'); // Log any sign-out errors
    });
    // Fix: Check if widget is mounted before using Navigator
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Shows a custom error dialog with a gentle animation and unique design
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

  // Handles adding funds via MoMo API and updates Firestore balance
  void _addFunds(String amount, String phoneNumber) async {
    // Validate amount input
    if (amount.isEmpty || double.tryParse(amount) == null || double.parse(amount) <= 0) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Please enter a valid amount');
      }
      return;
    }
    // Validate phone number format
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Please enter a valid phone number (e.g., +256123456789)');
      }
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final user = FirebaseAuth.instance.currentUser;
    // Check if user is authenticated
    if (user == null) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('User not authenticated');
      }
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
      return;
    }

    final externalId = DateTime.now().millisecondsSinceEpoch.toString();
    // Call MoMo API to initiate payment request
    final success = await MomoService.requestToPay(
      amount: amount,
      currency: 'UGX', // Changed to UGX for Uganda
      externalId: externalId,
      payerMobile: phoneNumber,
      payerMessage: 'Add funds to Safe Budget',
      payeeNote: 'User deposit',
    );

    if (success) {
      // Update user balance in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'balance': FieldValue.increment(double.parse(amount)),
      }, SetOptions(merge: true));
      // Fix: Check if widget is mounted before showing dialog and navigating
      if (mounted) {
        _showErrorDialog('Funds added successfully'); // Using dialog for consistency
        Navigator.pop(context); // Close bottom sheet on success
      }
    } else {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Failed to add funds');
      }
    }
    setState(() {
      _isLoading = false; // Hide loading indicator
    });
    _amountController.clear(); // Clear amount input
    _phoneController.clear(); // Clear phone number input
  }

  // Handles withdrawing funds via MoMo API and updates Firestore balance
  void _withdrawFunds(String amount, String phoneNumber) async {
    // Validate amount input
    if (amount.isEmpty || double.tryParse(amount) == null || double.parse(amount) <= 0) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Please enter a valid amount');
      }
      return;
    }
    // Validate phone number format
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Please enter a valid phone number (e.g., +256123456789)');
      }
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final user = FirebaseAuth.instance.currentUser;
    // Check if user is authenticated
    if (user == null) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('User not authenticated');
      }
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
      return;
    }

    // Check sufficient balance in Firestore
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentBalance = doc.data()?['balance']?.toDouble() ?? 0.0;
    final withdrawAmount = double.parse(amount);
    if (withdrawAmount > currentBalance) {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Insufficient balance');
      }
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
      return;
    }

    final externalId = DateTime.now().millisecondsSinceEpoch.toString();
    // Call MoMo API to initiate transfer
    final success = await MomoService.transfer(
      amount: amount,
      currency: 'UGX', // Changed to UGX for Uganda
      externalId: externalId,
      payeeMobile: phoneNumber,
      payerMessage: 'Withdraw from Safe Budget',
      payeeNote: 'User withdrawal',
    );

    if (success) {
      // Update user balance in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'balance': FieldValue.increment(-withdrawAmount),
      }, SetOptions(merge: true));
      // Fix: Check if widget is mounted before showing dialog and navigating
      if (mounted) {
        _showErrorDialog('Funds withdrawn successfully'); // Using dialog for consistency
        Navigator.pop(context); // Close bottom sheet on success
      }
    } else {
      // Fix: Check if widget is mounted before showing dialog
      if (mounted) {
        _showErrorDialog('Failed to withdraw funds');
      }
    }
    setState(() {
      _isLoading = false; // Hide loading indicator
    });
    _amountController.clear(); // Clear amount input
    _phoneController.clear(); // Clear phone number input
  }

  // Shows a modal bottom sheet for user actions (e.g., add funds, withdraw, view goals)
  void _showActionSheet(BuildContext context, String title, Widget content) {
    _resetTimer(); // Reset inactivity timer when opening sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5, // Initial height of the sheet
        minChildSize: 0.3, // Minimum height of the sheet
        maxChildSize: 0.6, // Maximum height of the sheet
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F6F2), // Light beige background
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and close button
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
                        _resetTimer(); // Reset timer on close
                        Navigator.pop(context); // Close bottom sheet
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1), // Separator line
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content, // Content of the bottom sheet (e.g., form fields)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _resetTimer(); // Reset timer when sheet is closed
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Check if user is authenticated; redirect to login if not
    if (user == null) {
      print('No authenticated user found');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Fix: Check if widget is mounted before using Navigator
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Main UI with gesture detection for resetting inactivity timer
    return GestureDetector(
      onTap: _resetTimer, // Reset timer on tap
      onPanDown: (_) => _resetTimer(), // Reset timer on pan
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F2), // Light beige background
        appBar: AppBar(
          title: const Text('Safe Budget Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut, // Sign out on tap
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const SizedBox(height: 32), // Spacing
              // User greeting
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
              const SizedBox(height: 16), // Spacing
              // StreamBuilder to display user balance from Firestore
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  Widget balanceWidget;
                  // Handle Firestore errors
                  if (snapshot.hasError) {
                    print('Firestore error: ${snapshot.error}');
                    balanceWidget = const Text(
                      'Error loading balance',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    );
                  }
                  // Handle no data or missing balance
                  else if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
                    print('Firestore: No data for user ${user.uid}');
                    balanceWidget = const Text(
                      'Balance Not Found',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                  // Display balance in UGX
                  else {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final balance = data['balance']?.toDouble() ?? 0.0;
                    balanceWidget = Text(
                      'UGX ${balance.toStringAsFixed(2)}', // Changed to UGX
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
              const SizedBox(height: 24), // Spacing
              // Quick actions header
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
              const SizedBox(height: 12), // Spacing
              // Action cards for add funds, withdraw, and view goals
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Add Funds card
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
                                // Amount input field
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
                                // Phone number input field
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
                                // Submit button for adding funds
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
                    const SizedBox(width: 12), // Spacing
                    // Withdraw card
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
                                // Amount input field
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
                                // Phone number input field
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
                                // Submit button for withdrawing funds
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
                    const SizedBox(width: 12), // Spacing
                    // View Goals card
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
                                // Display message if no goals exist
                                Text(
                                  'No goals set yet.',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                // Button to add a new goal
                                ElevatedButton(
                                  onPressed: () {
                                    // TODO: Implement add goal logic (e.g., save goal to Firestore with amount and description)
                                    _resetTimer();
                                    Navigator.pop(context); // Close bottom sheet
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

// HoverCard widget for interactive action cards with hover effects
class HoverCard extends StatefulWidget {
  final String label; // Label for the card (e.g., "Add Funds")
  final IconData icon; // Icon to display on the card
  final VoidCallback onTap; // Callback for tap action

  const HoverCard({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

// State class for HoverCard, managing hover animation
class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false; // Tracks hover state

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true), // Set hover state on mouse enter
      onExit: (_) => setState(() => _isHovered = false), // Clear hover state on mouse exit
      child: GestureDetector(
        onTap: widget.onTap, // Trigger tap callback
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), // Animation duration
          curve: Curves.easeInOut, // Smooth animation curve
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.grey.shade200 : Colors.grey.shade100, // Change color on hover
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? Colors.blue.shade100 : Colors.grey.shade300, // Change shadow on hover
                blurRadius: _isHovered ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 28, color: Colors.blue.shade800), // Display icon
              const SizedBox(height: 8), // Spacing
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