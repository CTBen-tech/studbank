import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Initialize user document in Firestore with default balance
  static Future<void> initializeUser(User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();

    if (!docSnapshot.exists) {
      // Create user document with default balance
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'Guest',
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Ensure balance field exists, set to 0.0 if missing
      await userRef.set({
        'balance': docSnapshot.data()?['balance'] ?? 0.0,
      }, SetOptions(merge: true));
    }
  }

  // Call this after sign-up or login
  static Future<void> handleAuthState(User user) async {
    await initializeUser(user);
  }
}