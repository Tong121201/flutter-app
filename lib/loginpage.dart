import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home/mainscreen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Initialize GoogleSignIn

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.red.shade50,
              Colors.red.shade100,
              Colors.red.shade200,
              Colors.red.shade400,
              Colors.red,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // University Logo
                Image.asset(
                  'assets/login_pic.png',
                  height: 400,
                  width: 400,
                ),

                const SizedBox(height: 120),

                // Custom Google Sign-In Button with your own styling
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    minimumSize: const Size(240, 50),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    _handleGoogleSignIn(); // Call the Google Sign-In method
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Google Logo (make sure to add this in your assets)
                      Image.asset(
                        'assets/google_logo.png',
                        // Path to your Google logo asset
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// Method to handle Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    try {
      // Force user to choose an account by signing out first
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        String email = googleUser.email;

        // Check if email domain is @qiu.edu.my
        if (!email.endsWith('@qiu.edu.my')) {
          _showErrorDialog("Invalid Email", "Please use your Quest International University email.");
          await _googleSignIn.signOut();
          return;
        }

        // Check if email is registered in Firestore
        bool isEmailRegistered = await _checkEmailInFirestore(email);

        if (!isEmailRegistered) {
          _showErrorDialog("Access Denied", "Your email is not registered in the system.");
          await _googleSignIn.signOut();
          return;
        }

        // If email is valid and registered, proceed with authentication
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase
        final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
        final User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => MainScreen())
          );
        }
      } else {
        _showErrorDialog("Sign In Cancelled", "You have cancelled the sign-in process.");
      }
    } catch (error) {
      print("Google Sign-In failed: $error");
    }
  }


  // Method to check if the email exists in Firestore
  Future<bool> _checkEmailInFirestore(String? email) async {
    if (email == null) return false;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("email")
          .where("email", isEqualTo: email)
          .get();

      return querySnapshot.docs.isNotEmpty; // Return true if email exists
    } catch (e) {
      print("Error checking Firestore for email: $e");
      return false; // In case of an error, return false
    }
  }

  // Method to show error dialogs
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}