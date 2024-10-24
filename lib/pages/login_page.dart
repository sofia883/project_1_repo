// First, ensure you have these dependencies in pubspec.yaml:
// firebase_core: ^latest_version
// firebase_auth: ^latest_version

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  // Send OTP
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification if possible (mainly on Android)
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification Failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent('OTP sent successfully');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Verify OTP
  Future<bool> verifyOTP({
    required String otp,
    required Function(String) onError,
  }) async {
    try {
      if (_verificationId != null) {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );

        await _auth.signInWithCredential(credential);
        return true;
      } else {
        onError('Verification ID is null');
        return false;
      }
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }
}

// UI Implementation
class PhoneAuthScreen extends StatefulWidget {
  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final PhoneAuthService _authService = PhoneAuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Phone Authentication')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1234567890',
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _authService.sendOTP(
                    phoneNumber: _phoneController.text,
                    onCodeSent: (message) {
                      setState(() => _codeSent = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    },
                    onError: (error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    },
                  );
                },
                child: Text('Send OTP'),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  bool verified = await _authService.verifyOTP(
                    otp: _otpController.text,
                    onError: (error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    },
                  );

                  if (verified) {
                    // Navigate to next screen or perform required action
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
                child: Text('Verify OTP'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
