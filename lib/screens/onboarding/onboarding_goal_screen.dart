import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'onboarding_age_screen.dart';

class OnboardingGoalScreen extends StatefulWidget {
  const OnboardingGoalScreen({super.key});

  @override
  State<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends State<OnboardingGoalScreen> {
  final Set<String> _selectedGoals = {};
  bool _isLoading = false;

  final List<Map<String, String>> _goals = [
    { 'label': "Improve My Grades", 'icon': 'assets/icons/Improving_grades.png' },
    { 'label': "Understand My Syllabus Better", 'icon': 'assets/icons/Book.png' },
    { 'label': "Score Higher in Exams", 'icon': 'assets/icons/Cup.png' },
    { 'label': "Stay Focused While Studying", 'icon': 'assets/icons/Focused.png' },
    { 'label': "Professional Growth", 'icon': 'assets/icons/Growth.png' },
    { 'label': "Get Better at Difficult Subjects", 'icon': 'assets/icons/getting_better.png' },
  ];

  void _toggleGoal(String goal) {
    setState(() {
      if (_selectedGoals.contains(goal)) {
        _selectedGoals.remove(goal);
      } else {
        _selectedGoals.add(goal);
      }
    });
  }

  Future<void> _saveGoalsToFirestore() async {
    if (_selectedGoals.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'topGoals': _selectedGoals.toList(),
        });
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingAgeScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Firestore Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.arrow_back, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF2D7BFF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 60),
                        child: Image.asset(
                          'assets/images/mentora_mascot.png',
                          width: 180,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "What’s your top goal?",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    final label = goal['label']!;
                    final iconPath = goal['icon']!;
                    final isSelected = _selectedGoals.contains(label);

                    return GestureDetector(
                      onTap: () => _toggleGoal(label),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2D7BFF) : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? const Color(0xFFEDF4FF) : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              iconPath,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? const Color(0xFF2D7BFF) : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Color(0xFF2D7BFF)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_selectedGoals.isEmpty || _isLoading) ? null : _saveGoalsToFirestore,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
