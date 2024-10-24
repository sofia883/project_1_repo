import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:project_1/pages/home_screen.dart';
import 'package:project_1/pages/login_page.dart';
// File: lib/services/phone_auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            onError('Auto-verification failed: ${e.toString()}');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'The provided phone number is invalid.';
              break;
            case 'quota-exceeded':
              errorMessage = 'SMS quota exceeded. Please try again later.';
              break;
            default:
              errorMessage = e.message ?? 'Verification failed: ${e.code}';
          }
          onError(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('SMS code sent successfully');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout');
        },
        timeout: Duration(seconds: 60),
      );
    } catch (e) {
      onError('Verification error: ${e.toString()}');
    }
  }

  Future<bool> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// AuthService to handle user authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update or create user document in Firestore
      await _updateUserData(credential.user!);

      return credential;
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _createUserData(credential.user!, name, phone);

      return credential;
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  // Create user data in Firestore
  Future<void> _createUserData(User user, String name, String phone) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // Update user data in Firestore
  Future<void> _updateUserData(User user) async {
    await _firestore.collection('users').doc(user.uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }

  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  });

  return MaterialColor(color.value, swatch);
}
