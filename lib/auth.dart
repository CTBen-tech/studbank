import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pages/dashboard.dart';
import 'pages/login.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key}); // Fixed: Use super.key

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // User is signed in, navigate to Dashboard
          return const DashboardPage();
        }
        // User is not signed in, navigate to Login
        return const LoginPage();
      },
    );
  }
}