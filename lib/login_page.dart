// login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'flutter_bridge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_data_manager.dart';
import 'home.dart';

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

  // Guest mode: signs in anonymously so the app can be used without an account. Measurements are still saved
  // (under a guest ID) and shared anonymously to the public map data. Anonymous sign-in has to be enabled in
  // the Firebase console (Authentication > Sign-in method).
  Future<void> _continueAsGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();

      if (mounted) {
        await Provider.of<UserDataProvider>(context, listen: false).fetchUserData();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'operation-not-allowed'
            ? 'Guest mode is not available right now. Please log in or register.'
            : (e.message ?? 'Could not start guest mode. Please try again.');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Sends Firebase's password reset email. The link in that email lets the user choose a new password.
  Future<void> _showForgotPasswordDialog() async {
    // start from whatever the user already typed in the login form
    final resetEmailController = TextEditingController(text: emailController.text.trim());
    String? dialogError;
    String? dialogMessage;
    bool sending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter the email for your account and we'll send you a link to reset your password."),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: dialogMessage == null,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  if (dialogMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogMessage!, style: const TextStyle(color: Colors.green, fontSize: 14)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(dialogMessage == null ? 'Cancel' : 'Close'),
                ),
                if (dialogMessage == null)
                  ElevatedButton(
                    onPressed: sending
                        ? null
                        : () async {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty) {
                              setDialogState(() => dialogError = 'Please enter your email.');
                              return;
                            }
                            setDialogState(() {
                              sending = true;
                              dialogError = null;
                            });
                            try {
                              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                              setDialogState(() {
                                sending = false;
                                // worded so it does not reveal whether an account exists for this email
                                dialogMessage = 'If an account exists for $email, a password reset link is on its way. '
                                    'Check your inbox (and spam folder).';
                              });
                            } on FirebaseAuthException catch (e) {
                              setDialogState(() {
                                sending = false;
                                dialogError = switch (e.code) {
                                  'invalid-email' => 'That does not look like a valid email address.',
                                  'network-request-failed' => 'No connection. Check your internet and try again.',
                                  'too-many-requests' => 'Too many attempts. Please wait a bit and try again.',
                                  _ => e.message ?? 'Could not send the reset email. Please try again.',
                                };
                              });
                            }
                          },
                    child: sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send Reset Link'),
                  ),
              ],
            );
          },
        );
      },
    );

    resetEmailController.dispose();
  }

  Future<void> _showRegistrationDialog() async {
    final regEmailController = TextEditingController();
    final regPasswordController = TextEditingController();
    final regConfirmController = TextEditingController();
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: regConfirmController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
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
                    final password = regPasswordController.text.trim();
                    final confirm = regConfirmController.text.trim();
                    if (password.isEmpty || confirm.isEmpty) {
                      setDialogState(() => dialogError = 'Please enter and confirm your password.');
                      return;
                    }
                    if (password != confirm) {
                      setDialogState(() => dialogError = 'Passwords do not match. Please try again.');
                      return;
                    }
                    setDialogState(() => dialogError = null);
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

    // TODO: Check if this is handled already in user data manager.
    await FirebaseFirestore.instance
        .collection('userAccountData')
        .doc(user.email)
        .set({
      'uid': user.uid,
      'email': email,
      'totalPointsCollected': 0,
      'distanceTraveled': 0.0,
      'totalRadiusGyration': 0.0,
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
      debugPrint('[LOGIN] No user logged in');
      return null;
    }

    debugPrint('[LOGIN] Getting data for UID: ${user.uid}');

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
            'Login',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 50)
        ),
        backgroundColor: const Color(0xFF440154),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 25),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF440154),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
              ),
              onPressed: _login,
              child: const Text('Log In',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 25,)),
            ),
            TextButton(
              onPressed: _loading ? null : _showForgotPasswordDialog,
              child: const Text('Forgot password?'),
            ),
            const SizedBox(height: 10),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF440154),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: _showRegistrationDialog,
              child: const Text('Register',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF440154),
                    fontSize: 16,
                  )),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF440154),
                side: const BorderSide(color: Color(0xFF440154), width: 2),
                padding: const EdgeInsets.all(15),
              ),
              onPressed: _loading ? null : _continueAsGuest,
              child: const Text('Continue as Guest',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            const SizedBox(height: 6),
            const Text(
              'No account needed. Guest data stays on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
