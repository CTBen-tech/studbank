import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Importing Firebase Auth to monitor authentication status
import 'firebase_options.dart'; // <-- Firebase initialization options
import 'pages/login.dart'; // <-- Your login screen
import 'pages/dashboard.dart'; // <-- Your dashboard screen
import 'pages/signup.dart'; // <-- Your signup screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // <-- Required before calling async Firebase.initializeApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // <-- Initializes Firebase using platform-specific config
  );
  runApp(const MyApp()); // <-- Launches the root widget
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Budget',
      debugShowCheckedModeBanner: false, // <-- Removes the debug banner from the corner of the app
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5F04FC)), // <-- Custom color theme
        useMaterial3: true, // <-- Opts into Material Design 3
      ),

      // 🔐 Handles auth routing: sends user to dashboard if logged in, login page if not
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // <-- Firebase stream that updates on login/logout
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 🔄 Optional: show loading spinner while checking auth status
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            // ✅ User is signed in — redirect to dashboard
            return const DashboardPage();
          } else {
            // 🚪 User is not signed in — redirect to login screen
            return const LoginPage();
          }
        },
      ),

      // 🗺️ Named routes for navigation throughout your app
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/signup': (context) => const SignUpPage(), // <-- Register new users
        // Add other routes here (e.g., settings, transactions, etc.)
      },
    );
  }
}
