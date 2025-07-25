// File: C:\Users\BENJA\Desktop\flutter project recess\studbank\studbank\lib\services\auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Initialize user document in Firestore with name, ID, and default balance
  static Future<void> initializeUser(User user, {String? name}) async {
    int retries = 3;
    int attempt = 1;
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    while (attempt <= retries) {
      try {
        print('Attempting to initialize user (attempt $attempt/$retries)...');
        final docSnapshot = await userRef.get();

        if (!docSnapshot.exists) {
          // Create user document with provided name and default balance
          await userRef.set({
            'uid': user.uid, // Unique ID
            'name': name ?? user.email?.split('@')[0] ?? 'Guest', // Fallback name
            'email': user.email,
            'balance': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('User initialized in Firestore: ${user.uid}');
        } else {
          // Ensure balance field exists
          await userRef.set({
            'balance': docSnapshot.data()?['balance'] ?? 0.0,
            'name': name ?? docSnapshot.data()?['name'] ?? user.email?.split('@')[0] ?? 'Guest',
          }, SetOptions(merge: true));
          print('User already initialized, updated: ${user.uid}');
        }
        break; // Exit loop on success
      } catch (e) {
        print('Error initializing user (attempt $attempt/$retries): $e');
        if (e.toString().contains('network') && attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
          attempt++;
          continue;
        }
        rethrow; // Rethrow non-network errors or after max retries
      }
    }
  }
}