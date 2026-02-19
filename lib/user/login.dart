import 'dart:convert';
import 'package:felamo/baseurl/baseurl.dart';
import 'package:felamo/screen/dashboard.dart';
import 'package:felamo/user/signup.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController =
      TextEditingController(text: "lynardbocado@gmail.com");
  final TextEditingController passwordController =
      TextEditingController(text: "password");
  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('sessionId');
    if (sessionId != null && sessionId.isNotEmpty) {
   
    }
  }

  
  void _showForgotPasswordDialog() {
    final TextEditingController forgotEmailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Forgot Password?",
          style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email to receive an OTP.",
              style: TextStyle(fontFamily: 'Fredoka', fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: forgotEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "you@example.com",
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontFamily: 'Fredoka'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: 'Fredoka')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC143C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final email = forgotEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid email")));
                return;
              }
              Navigator.pop(context);
              _requestForgotPasswordOtp(email);
            },
            child: const Text("Send OTP",
                style: TextStyle(color: Colors.white, fontFamily: 'Fredoka')),
          ),
        ],
      ),
    );
  }

  Future<void> _requestForgotPasswordOtp(String email) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/forgot-password.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (response.statusCode == 200 && data['status'] == 200) {
        _showSuccessDialog("OTP has been sent to your email.");
        Future.delayed(const Duration(milliseconds: 800), () {
          _showOtpVerificationDialog(email);
        });
      } else {
        _showErrorDialog(data['message'] ?? "Failed to send OTP.");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog("Network error. Please try again.");
    }
  }

  void _showOtpVerificationDialog(String email) {
    final TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Enter OTP",
            style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("We sent a 6-digit code to",
                style: TextStyle(fontFamily: 'Fredoka', fontSize: 14)),
            const SizedBox(height: 4),
            Text(email,
                style: const TextStyle(
                    fontFamily: 'Fredoka', fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Fredoka', fontSize: 20, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: 'Fredoka')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC143C)),
            onPressed: () {
              final otp = otpController.text.trim();
              if (otp.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid 6-digit OTP")));
                return;
              }
              Navigator.pop(context);
              _verifyOtpAndLogin(email, otp);
            },
            child: const Text("Verify & Login",
                style: TextStyle(color: Colors.white, fontFamily: 'Fredoka')),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtpAndLogin(String email, String otp) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            'https://darkslategrey-jay-754607.hostingersite.com/backend/api/app/login-using-otp.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (response.statusCode == 200 && data['status'] == 200) {
        final sessionId = data['session']?['id']?.toString() ?? '';
        final avatarId = int.tryParse(data['user']?['avatar']?.toString() ?? '0') ?? 0;
        final avatarFileName = data['user']?['avatar_file_name']?.toString() ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sessionId', sessionId);
        await prefs.setInt('avatarId', avatarId);
        await prefs.setString('avatarFileName', avatarFileName);
        await prefs.setString('firstName', data['user']?['first_name'] ?? '');
        await prefs.setInt('pointsReceived', int.tryParse(data['points_received']?.toString() ?? '0') ?? 0);
        await prefs.setInt('currentStreak', int.tryParse(data['current_streak']?.toString() ?? '0') ?? 0);
        await prefs.setInt('id', int.tryParse(data['id']?.toString() ?? '0') ?? 0);
        await prefs.setInt('points', int.tryParse(data['user']?['points']?.toString() ?? '0') ?? 0);
        await prefs.setString('profilePicture', data['user']?['profile_picture'] ?? '');
        await prefs.setString('email', data['user']?['email'] ?? '');

        _showSuccessDialog("Login successful via OTP!");
        await Future.delayed(const Duration(seconds: 1));
        await _navigateToDashboard();
      } else {
        _showErrorDialog(data['message'] ?? "Invalid or expired OTP.");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog("Login failed. Please try again.");
    }
  }

  Future<void> loginUser() async {
    final url = Uri.parse('${baseUrl}login.php');
    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': emailController.text.trim(),
              'password': passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          final sessionId = data['session']?['id']?.toString() ?? '';
          final avatarId = int.tryParse(data['user']?['avatar']?.toString() ?? '0') ?? 0;
          final avatarFileName = data['user']?['avatar_file_name']?.toString() ?? '';

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('sessionId', sessionId);
          await prefs.setInt('avatarId', avatarId);
          await prefs.setString('avatarFileName', avatarFileName);
          await prefs.setString('firstName', data['user']?['first_name'] ?? '');
          await prefs.setInt('pointsReceived', int.tryParse(data['points_received']?.toString() ?? '0') ?? 0);
          await prefs.setInt('currentStreak', int.tryParse(data['current_streak']?.toString() ?? '0') ?? 0);
          await prefs.setInt('id', int.tryParse(data['id']?.toString() ?? '0') ?? 0);
          await prefs.setInt('points', int.tryParse(data['user']?['points']?.toString() ?? '0') ?? 0);
          await prefs.setString('profilePicture', data['user']?['profile_picture'] ?? '');
          await prefs.setString('email', data['user']?['email'] ?? '');

          await _navigateToDashboard();
        } else {
          _showErrorDialog(data['message'] ?? 'Login failed.');
        }
      } else {
        _showErrorDialog('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Error: $e');
    }
  }

  Future<void> _navigateToDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Dashboard(
          firstName: prefs.getString('firstName') ?? '',
          sessionid: prefs.getString('sessionId') ?? '',
          pointsReceived: prefs.getInt('pointsReceived') ?? 0,
          currentStreak: prefs.getInt('currentStreak') ?? 0,
          id: prefs.getInt('id') ?? 0,
          email: prefs.getString('email') ?? '',
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("Success!", style: TextStyle(fontFamily: 'Fredoka')),
          ],
        ),
        content: Text(message, style: const TextStyle(fontFamily: 'Fredoka')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(fontFamily: 'Fredoka', color: Color(0xFFDC143C)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error", style: TextStyle(fontFamily: 'Fredoka')),
        content: Text(message, style: const TextStyle(fontFamily: 'Fredoka')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(fontFamily: 'Fredoka')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFDC143C);

    return Scaffold(
      backgroundColor: const Color(0xFFFFE5E5),
      body: SafeArea(
        child: Column(
          children: [
            // Logo Section
            Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 20),
              child: Image.asset(
                'assets/logofelamo.png',
                height: 160,
                fit: BoxFit.contain,
              ),
            ),

            // White Container Card - Expanded to fill remaining space
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 200,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 50),
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        _buildTextField(
                          controller: emailController,
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

                        // Password Field
                        _buildTextField(
                          controller: passwordController,
                          label: 'Password',
                          hint: 'Enter Password',
                          icon: Icons.lock_outline,
                          iconColor: primaryRed,
                          obscureText: _obscurePassword,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        const SizedBox(height: 32),

                        // Login Button
                        ElevatedButton(
                          onPressed: isLoading ? null : loginUser,
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
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.8,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),

                        // Forgot Password
                        Center(
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Sign Up Link
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Doesn't have any account? ",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => SignUp()),
                                  );
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: primaryRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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
            ),
          ],
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
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}