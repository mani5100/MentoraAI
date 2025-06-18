import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'onboarding_duration_screen.dart';

class OnboardingAgeScreen extends StatefulWidget {
  const OnboardingAgeScreen({super.key});

  @override
  State<OnboardingAgeScreen> createState() => _OnboardingAgeScreenState();
}

class _OnboardingAgeScreenState extends State<OnboardingAgeScreen> {
  DateTime _selectedDate = DateTime(2000, 1, 1);
  bool _isLoading = false;

  Future<void> _saveBirthDate() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'birthDate': Timestamp.fromDate(_selectedDate),
        });

        // ✅ Navigate to next screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingDurationScreen()),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Birthdate saved successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving birthDate: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.arrow_back, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.7,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF2D7BFF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 60),
                    child: Image.asset(
                      'assets/images/mentora_mascot.png',
                      width: 180,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Let's tailor your experience by knowing your age.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Date display
              GestureDetector(
                onTap: _pickDate,
                child: Chip(
                  label: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.grey.shade800,
                ),
              ),

              const SizedBox(height: 20),

              // Calendar picker
              CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                onDateChanged: (date) => setState(() => _selectedDate = date),
              ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBirthDate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
