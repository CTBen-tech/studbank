import 'dart:async'; // ⏱️ Needed for Timer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _inactivityTimer;

  // 🕐 Called when the user interacts with the screen
  void _resetTimer() {
    _inactivityTimer?.cancel(); // Cancel any existing timer
    _inactivityTimer = Timer(const Duration(minutes: 5), _handleInactivity);
  }

  // 🚪 Automatically sign out after inactivity period
  void _handleInactivity() {
    FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // 🧹 Clean up the timer when widget is disposed
  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  // 👋 Personalized greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // 🚪 Manual sign-out via button
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // 🎨 Creates a reusable action card with icon and label
  Widget _buildActionCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100, // Soft-white card
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.blue.shade800),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Guest';

    return GestureDetector(
      onTap: _resetTimer,
      onPanDown: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F2), // Luxe soft white background
        appBar: AppBar(
          title: const Text('Safe Budget Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _signOut,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // 🧑‍💼 Greeting
              Text(
                '${_getGreeting()}, $displayName!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 💙 Balance banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Your Balance',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "10,000",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🧭 Quick Actions heading
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 📦 Horizontal row of action cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _buildActionCard(
                      label: 'Add Funds',
                      icon: Icons.add_circle_outline,
                      onTap: () {
                        // TODO: Navigate to Add Funds screen
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionCard(
                      label: 'Withdraw',
                      icon: Icons.remove_circle_outline,
                      onTap: () {
                        // TODO: Navigate to Withdraw screen
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionCard(
                      label: 'View Goals',
                      icon: Icons.flag_outlined,
                      onTap: () {
                        // TODO: Navigate to Goals screen
                      },
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
