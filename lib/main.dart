// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\lib\main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/login.dart';
import 'pages/dashboard.dart';
import 'pages/signup.dart';
import 'pages/forgot_password.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Initializing Firebase...');
    // Retry Firebase initialization up to 3 times with delay
    int retries = 3;
    int attempt = 1;
    while (attempt <= retries) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        print('Firebase initialized successfully');
        // Configure Firestore settings
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true, // Enable offline persistence
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Unlimited cache
          // Explicitly set host for debugging network issues
          host: 'firestore.googleapis.com',
          sslEnabled: true,
          ignoreUndefinedProperties: true,
        );
        print('Firestore settings configured');
        break; // Exit loop on success
      } catch (e) {
        print('Firebase initialization error (attempt $attempt/$retries): $e');
        if (attempt == retries) {
          print('Max retries reached. Initialization failed.');
          break;
        }
        await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
        attempt++;
      }
    }
  } catch (e) {
    print('Unexpected error during Firebase setup: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building MyApp...');
    return MaterialApp(
      title: 'StudBank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5F04FC)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print('Auth state: ${snapshot.connectionState}, User: ${snapshot.data?.uid}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Auth error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Authentication error. Please try again.'),
                  ElevatedButton(
                    onPressed: () {
                      // Retry authentication or redirect to login
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return snapshot.hasData ? const DashboardPage() : const LoginPage();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}