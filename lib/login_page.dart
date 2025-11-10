// login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null; // Clear previous errors
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Get user data after login
      await getCurrentUserData();

      // Navigate to homepage after login
      if (mounted) {  // Check if widget is still mounted
        await Provider.of<UserDataProvider>(context, listen: false)
            .fetchUserData();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showRegistrationDialog() async {
    final regEmailController = TextEditingController();
    final regPasswordController = TextEditingController();
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(  // Allows setState inside dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Register Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: regEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: regPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Call signup with the TEXT from controllers
                      await signUpNewUser(
                        regEmailController.text.trim(),
                        regPasswordController.text.trim(),
                      );

                      // Close dialog on success
                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        // Navigate to homepage
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      setDialogState(() {
                        dialogError = e.message;
                      });
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> signUpNewUser(String email, String password) async {
    // Create auth account
    UserCredential credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    User user = credential.user!;
    print('Created user with UID: ${user.uid}');

    // Create Firestore document with SAME UID
    await FirebaseFirestore.instance
        .collection('userData')
        .doc(user.uid)  // ← This is the key!
        .set({
      'uid': user.uid,
      'email': email,
      'measurementsTaken': 0,
      'distanceTraveled': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('Created Firestore document at: userData/${user.uid}');

    if (mounted) {
      await Provider.of<UserDataProvider>(context, listen: false)
          .fetchUserData();
    }
    
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    // Get logged-in user
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('No user logged in');
      return null;
    }

    print('Getting data for UID: ${user.uid}');

    // Get their document directly
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('userData')
        .doc(user.uid)  // Direct access using UID
        .get();

    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }

    return null;
  }

  // This may not be necessary in this file, look into later
  Future<void> updateMeasurements(int newValue) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    // Update their document directly
    await FirebaseFirestore.instance
        .collection('userData')
        .doc(user.uid)  // Direct access using UID
        .update({
      'measurementsTaken': newValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _login,
              child: const Text('Log In'),
            ),
            const SizedBox(height: 20),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _showRegistrationDialog,
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

}
