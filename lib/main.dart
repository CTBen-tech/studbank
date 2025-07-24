import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login.dart';
import 'pages/dashboard.dart';
import 'pages/signup.dart';
import 'pages/forgot_password.dart'; // Added import for ForgotPasswordPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase once, with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Budget',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5F04FC)),
        useMaterial3: true,
      ),
      home: const LoginPage(), // ✅ Always starts at LoginPage
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(), // Use actual page
      },
    );
  }
}
