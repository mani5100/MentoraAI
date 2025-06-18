// lib/screens/quiz_study_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';

class QuizStudyScreen extends StatefulWidget {
  final String subjectId;

  const QuizStudyScreen({Key? key, required this.subjectId}) : super(key: key);

  @override
  State<QuizStudyScreen> createState() => _QuizStudyScreenState();
}

class _QuizStudyScreenState extends State<QuizStudyScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  String? _selectedOption;
  int _score = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(widget.subjectId)
        .collection('quizzes')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    final loaded = snap.docs.map((d) {
      final data = d.data();
      return {
        'id':       d.id,
        'question': data['question'] as String? ?? '',
        'options':  List<String>.from(data['options'] as List<dynamic>),
        'answer':   data['answer']   as String? ?? '',
      };
    }).toList();

    setState(() {
      _questions = loaded.reversed.toList();
      _isLoading = false;
    });
  }

  void _submitAnswer() {
    if (_selectedOption != null &&
        _selectedOption == _questions[_currentIndex]['answer']) {
      _score++;
    }
  }

  void _nextQuestion() {
    _submitAnswer();
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
      });
    } else {
      _showResults();
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedOption = null;
      });
    }
  }

  // Called when quiz is complete
  Future<void> _showResults() async {
    // 1) Award XP based on score
    await _awardQuizXp();

    // 2) Show results dialog
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quiz Complete'),
        content: Text('You scored $_score out of ${_questions.length}.'),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate back to dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    (route) => false,
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // Transaction to award XP and increment quizzesCompleted
  Future<void> _awardQuizXp() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(widget.subjectId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final prevXp        = (data['xp'] ?? 0) as int;
      final prevCompleted = (data['quizzesCompleted'] ?? 0) as int;
      final deltaXp       = _score * 10; // e.g., 10 XP per correct answer

      tx.update(ref, {
        'xp':               prevXp + deltaXp,
        'quizzesCompleted': prevCompleted + 1,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Take Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Take Quiz')),
        body: const Center(child: Text('No quiz questions available.')),
      );
    }

    final current = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                current['question'] as String,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ...List<Widget>.from(
                (current['options'] as List<String>).map((opt) {
                  return RadioListTile<String>(
                    title: Text(opt),
                    value: opt,
                    groupValue: _selectedOption,
                    onChanged: (val) {
                      setState(() => _selectedOption = val);
                    },
                  );
                }),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _prevQuestion,
                  ),
                  ElevatedButton(
                    onPressed: _selectedOption == null ? null : _nextQuestion,
                    child: Text(
                        _currentIndex < _questions.length - 1 ? 'Next' : 'Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
