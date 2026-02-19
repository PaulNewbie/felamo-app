// File: sign_up.dart (or lib/screens/sign_up.dart)

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();

  final _lrnController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _canResend = true;
  int _countdown = 0;
  Timer? _timer;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _lrnController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _countdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) _countdown--;
        else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  bool _isValidEmail(String email) {
    return email.isNotEmpty &&
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/register-sent-otp.php');

      print('SEND OTP → $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'lrn': _lrnController.text.trim(),
          'password': _passwordController.text.trim(),
          'confirm_password': _confirmPasswordController.text.trim(),
        }),
      );

      print('Status: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showMessage('Server error (${response.statusCode})');
        return;
      }

      final json = jsonDecode(response.body);

      if (json['status'] == 200) {
        _startResendTimer();
        _showMessage(json['message'] ?? 'OTP sent!');
      } else {
        _showMessage(json['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) _showMessage('Connection issue: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    final lrn = _lrnController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final cpass = _confirmPasswordController.text.trim();
    final otp = _otpController.text.trim();

    if (lrn.isEmpty || email.isEmpty || pass.isEmpty || cpass.isEmpty) {
      _showMessage('Please fill all fields');
      return;
    }

    if (pass != cpass) {
      _showMessage('Passwords do not match');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Invalid email format');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/register-v2.php');

      print('REGISTER → $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lrn': lrn,
          'email': email,
          'password': pass,
          'confirm_password': cpass,
          'otp': otp,
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        _showMessage('Server error (${response.statusCode})');
        return;
      }

      final json = jsonDecode(response.body);

      if (json['status'] == 'success') {
        _showSuccessDialog();
      } else {
        _showMessage(json['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (mounted) _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!', style: TextStyle(color: Color(0xFFDC143C))),
        content: const Text('Registration successful.\nYou can now log in.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFDC143C))),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC143C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFDC143C); // Bright red like in the image
    final transparentRed = primaryRed.withOpacity(0.5);

    return Scaffold(
      backgroundColor:const Color.fromARGB(255, 255, 17, 0).withOpacity(0.5), // Light pinkish red background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Logo Section (replace with your actual logo asset)
              Padding(
                padding: const EdgeInsets.only(top: 40, bottom: 20),
                child: Column(
                  children: [
                    
                    Image.asset('assets/logofelamo.png', height: 120),
                   
                  ],
                ),
              ),

              // White Container Card - No margin
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // Email
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: '',
                          icon: Icons.email_outlined,
                          iconColor: primaryRed,
                          keyboardType: TextInputType.emailAddress,
                          suffix: const Padding(
                            padding: EdgeInsets.only(right: 12, top: 14),
                            child: Text(
                              '@gmail.com',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // LRN
                        _buildTextField(
                          controller: _lrnController,
                          label: 'LRN',
                          hint: 'Enter LRN',
                          icon: Icons.badge_outlined,
                          iconColor: primaryRed,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter Password',
                          icon: Icons.lock_outline,
                          iconColor: primaryRed,
                          obscureText: _obscurePassword,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hint: 'Confirm Password',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirm,
                          onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          suffixIcon: _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        ),
                        const SizedBox(height: 24),

                        // OTP Section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _otpController,
                                label: 'OTP',
                                hint: 'Enter OTP',
                                icon: Icons.verified_user_outlined,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _canResend && !_isLoading ? _sendOtp : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canResend ? primaryRed : Colors.grey[300],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: _canResend ? 2 : 0,
                                ),
                                child: Text(
                                  _canResend ? 'Send' : '$_countdown s',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _canResend ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Register Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                            shadowColor: primaryRed.withOpacity(0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.8,
                                  ),
                                )
                              : const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
    TextInputType? keyboardType,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    IconData? suffixIcon,
    int? maxLength,
    Widget? suffix,
  }) {
    const primaryRed = Color(0xFFDC143C);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? primaryRed).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? Colors.black54,
                size: 20,
              ),
            ),
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon, color: primaryRed),
                    onPressed: onSuffixTap,
                  )
                : null,
            suffix: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryRed, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryRed, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryRed, width: 2),
            ),
            counterStyle: const TextStyle(height: 0),
          ),
        ),
      ],
    );
  }
}