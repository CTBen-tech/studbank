import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Sign out any existing user to force re-authentication
    _auth.signOut().catchError((e) {
      print('Sign-out error: $e');
    });
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email')),
        );
      }
      return;
    }
    if (!RegExp(r'^[\w-\.]+@[\w-]+\.[a-zA-Z]+$').hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email')),
        );
      }
      return;
    }
    if (password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your password')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        print('Login successful, navigating to /dashboard');
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code}, ${e.message}');
      String errorMessage = 'Login failed';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
        case 'invalid-credential':
          errorMessage = 'Invalid email or password.';
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Try again later.';
        case 'network-request-failed':
          errorMessage = 'Network error. Check your connection.';
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      print('Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Budget Login')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Login', style: TextStyle(fontSize: 16)),
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.pushNamed(context, '/signup');
                  }
                },
                child: const Text('Create an Account'),
              ),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.pushNamed(context, '/forgot-password');
                  }
                },
                child: const Text('Forgot Password?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}