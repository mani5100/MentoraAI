// lib/screens/flashcards_study_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';

class FlashcardsStudyScreen extends StatefulWidget {
  final String subjectId;

  const FlashcardsStudyScreen({Key? key, required this.subjectId}) : super(key: key);

  @override
  State<FlashcardsStudyScreen> createState() => _FlashcardsStudyScreenState();
}

class _FlashcardsStudyScreenState extends State<FlashcardsStudyScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _cards = [];
  int _currentIndex = 0;
  bool _showingAnswer = false;
  Set<String> _learnedCardIds = {};
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  int _learnedCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _loadFlashcards();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFlashcards() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(widget.subjectId)
        .collection('flashcards')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    setState(() {
      _cards = snap.docs.map((d) {
        final data = d.data();
        return {
          'id':       d.id,
          'question': data['question'] as String? ?? '',
          'answer':   data['answer']   as String? ?? '',
        };
      }).toList();
      _isLoading = false;
    });
  }

  void _flipCard() {
    if (_controller.isCompleted || _controller.velocity > 0) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => _showingAnswer = !_showingAnswer);
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showingAnswer = false;
        _controller.reset();
      });
    }
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _showingAnswer = false;
        _controller.reset();
      });
    }
  }

  void _toggleLearned() async {
    final id = _cards[_currentIndex]['id'] as String;
    final nowLearned = !_learnedCardIds.contains(id);

    setState(() {
      if (nowLearned) {
        _learnedCardIds.add(id);
        _learnedCount++;
      } else {
        _learnedCardIds.remove(id);
        _learnedCount--;
      }
    });

    // Award XP & update progress in Firestore
    await _awardFlashcardXp(nowLearned);
  }

  Future<void> _awardFlashcardXp(bool learned) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(widget.subjectId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final prevXp   = (data['xp'] ?? 0) as int;
      final prevRead = (data['flashcardsRead'] ?? 0) as int;
      final total    = _cards.length;
      final newRead  = learned ? prevRead + 1 : prevRead - 1;
      final xpDelta  = learned ? 2 : -2; // 2 XP per card
      final newXp    = prevXp + xpDelta;
      final newProgress = ((newRead / total) * 100).round();

      tx.update(ref, {
        'xp':             newXp,
        'flashcardsRead': newRead,
        'progress':       newProgress,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Flashcards')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Flashcards')),
        body: const Center(child: Text('No flashcards available.')),
      );
    }

    final isLast = _currentIndex == _cards.length - 1;
    final card = _cards[_currentIndex];
    final learned = _learnedCardIds.contains(card['id'] as String);

    return Scaffold(
      appBar: AppBar(title: Text('Flashcard ${_currentIndex + 1} of ${_cards.length}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final isUnder = (_flipAnimation.value > 0.5);
                      final display = isUnder ? card['answer'] : card['question'];
                      return Transform(
                        transform: Matrix4.rotationY(_flipAnimation.value * 3.1416),
                        alignment: Alignment.center,
                        child: Transform(
                          transform: Matrix4.rotationY(isUnder ? 3.1416 : 0),
                          alignment: Alignment.center,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  display as String,
                                  style: const TextStyle(fontSize: 18),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevCard),
                  const SizedBox(width: 24),
                  IconButton(icon: const Icon(Icons.flip), onPressed: _flipCard),
                  const SizedBox(width: 24),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextCard),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _toggleLearned,
                icon: Icon(learned ? Icons.check_box : Icons.check_box_outline_blank),
                label: Text(learned ? 'Learned' : 'Mark as Learned'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (isLast) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          (route) => false,
                    );
                  },
                  child: const Text('Finish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
