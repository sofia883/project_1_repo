import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeSent = false;
  String? _verificationId;
  final _auth = FirebaseAuth.instance;

  // Add loading state variables
  bool _isLoadingOTP = false;
  bool _isVerifyingOTP = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() => _isLoadingOTP = true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() => _isLoadingOTP = false);
          await _auth.signInWithCredential(credential);
          _navigateToHome();
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoadingOTP = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Verification Failed')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoadingOTP = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _isLoadingOTP = false);
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() => _isLoadingOTP = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _verifyOTP() async {
    setState(() => _isVerifyingOTP = true);
    try {
      if (_verificationId != null) {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _otpController.text,
        );
        await _auth.signInWithCredential(credential);
        _navigateToHome();
      }
    } catch (e) {
      setState(() => _isVerifyingOTP = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isSigningIn = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _navigateToHome();
    } catch (e) {
      setState(() => _isSigningIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  Widget _buildLoadingButton({
    required bool isLoading,
    required VoidCallback onPressed,
    required String text,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              )
            : Text(
                text,
                style: const TextStyle(color: Colors.black87),
              ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+1234567890',
            labelText: 'Phone Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLoadingButton(
          isLoading: _isLoadingOTP,
          onPressed: _sendOTP,
          text: 'Send OTP',
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter OTP',
            labelText: 'OTP',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLoadingButton(
          isLoading: _isVerifyingOTP,
          onPressed: _verifyOTP,
          text: 'Verify OTP',
        ),
      ],
    );
  }

  Widget _buildEmailInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Email address',
            labelText: 'Email',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Password',
            labelText: 'Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildLoadingButton(
          isLoading: _isSigningIn,
          onPressed: _signInWithEmail,
          text: 'Sign In',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rest of the build method remains unchanged
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: Colors.black87,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TabBar(
                              controller: _tabController,
                              labelColor: Colors.black,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.amber,
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.phone),
                                  text: 'Phone',
                                ),
                                Tab(
                                  icon: Icon(Icons.email),
                                  text: 'Email',
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: !_codeSent
                                        ? _buildPhoneInput()
                                        : _buildOTPInput(),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: _buildEmailInput(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
