import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding_final_screen.dart';
class OnboardingDurationScreen extends StatefulWidget {
  const OnboardingDurationScreen({super.key});

  @override
  State<OnboardingDurationScreen> createState() => _OnboardingDurationScreenState();
}

class _OnboardingDurationScreenState extends State<OnboardingDurationScreen> {
  final List<int> _durations = [30, 45, 60, 90, 120];
  int? _selectedDuration = 120;
  bool _isLoading = false;

  Future<void> _saveDuration() async {
    if (_selectedDuration == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'studyDuration': _selectedDuration,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Study duration saved')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingFinalScreen()),
          );

        }
      }
    } catch (e) {
      debugPrint('Error saving studyDuration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCustomDurationDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Custom Duration (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 75'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = int.tryParse(controller.text.trim());
              if (input != null && input > 0) {
                setState(() => _selectedDuration = input);
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Back + progress
              Row(
                children: [
                  const Icon(Icons.arrow_back, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.85,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF2D7BFF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Mascot + bubble
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 60),
                    child: Image.asset('assets/images/mentora_mascot.png', width: 160),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Let me know how long we’ve got to study together!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Button Grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var mins in _durations) _buildDurationButton(mins),
                  _buildDurationButton(null, isCustom: true),
                ],
              ),

              const Spacer(),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDuration,
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

  Widget _buildDurationButton(int? minutes, {bool isCustom = false}) {
    final isSelected = _selectedDuration == minutes;

    return GestureDetector(
      onTap: () {
        if (isCustom) {
          _showCustomDurationDialog();
        } else {
          setState(() => _selectedDuration = minutes);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D7BFF) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isCustom
              ? (_selectedDuration != null && !_durations.contains(_selectedDuration))
              ? "${_selectedDuration!} mins"
              : "Custom"
              : "$minutes mins",
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
