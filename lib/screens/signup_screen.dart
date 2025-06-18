import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _generatedOTP = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🔐 Validations
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // 🔐 Generate 6-digit OTP
  void _generateOTP() {
    final random = Random();
    _generatedOTP = List.generate(6, (_) => random.nextInt(10)).join();
    print("Generated OTP: $_generatedOTP");
  }

  // 📧 Send OTP via EmailJS
  Future<void> _sendOTPEmail(String email, String otp) async {
    const serviceId = 'service_a1asrwe';
    const templateId = 'template_vuyb92s';
    const userId = 'CdiUQsd9Q3n-iBRI_';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {
          'user_email': email,
          'otp_code': otp,
        }
      }),
    );

    if (response.statusCode == 200) {
      print('✅ OTP sent to $email');
    } else {
      print('❌ Failed to send OTP: ${response.body}');
    }
  }

  // 📲 Create Account Button Handler
  void _handleCreateAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      _generateOTP();
      await _sendOTPEmail(_emailController.text.trim(), _generatedOTP);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            otp: _generatedOTP,
          ),
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔙 Back
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 10),

                // 🖼 Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo_with_caption.png',
                    width: 120,
                  ),
                ),

                const SizedBox(height: 20),

                const Center(
                  child: Text(
                    'Create account',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'If you create an account, we’ll link your\nsubscription to it so you can use MentoraAI\non any device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),

                const SizedBox(height: 30),

                // 📧 Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _validateEmail,
                ),

                const SizedBox(height: 16),

                // 🔐 Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _validatePassword,
                ),

                const SizedBox(height: 16),

                // 🔐 Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _validateConfirmPassword,
                ),

                const SizedBox(height: 24),

                // 🎯 Create Account Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreateAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7BFF),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'We promise we won’t spam you. We value your privacy.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
