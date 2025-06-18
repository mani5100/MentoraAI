import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subject_issue_screen.dart';
import 'upload_syllabus_screen.dart';
import 'flashcard_subject_screen.dart';
import 'quiz_subject_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userName = '';
  String selectedSubject = '';
  String? selectedSubjectId;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        userName = userDoc.data()?['name'] ?? '';
      });
    }
  }

  Stream<List<Map<String, dynamic>>> getSubjectsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildFeatureGrid(),
              const SizedBox(height: 30),
              const Text(
                "Your Subjects",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _buildSubjectSelector(),
              const SizedBox(height: 28),
              _buildProgressCard(),
              const SizedBox(height: 24),
              _buildUploadSyllabusButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Dashboard",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          "Greetings, $userName 👋",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const Text(
          "Ready to crush your goal today?",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildFeatureTile('assets/icons/summerize.png', 'Summarize'),
        _buildFeatureTile('assets/icons/flashcards.png', 'Flashcards'),
        _buildFeatureTile('assets/icons/chat_with_tutor.png', 'Chat with Tutor'),
        _buildFeatureTile('assets/icons/Take_Quiz.png', 'Take Quiz'),
      ],
    );
  }

  Widget _buildFeatureTile(String asset, String label) {
    return GestureDetector(
      onTap: () {
        // handle navigation
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(asset, width: 28, height: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getSubjectsStream(),
      builder: (context, snapshot) {
        final widgets = <Widget>[_buildAddSubjectChip()];
        if (snapshot.hasData) {
          final subjects = snapshot.data!;
          if (subjects.isNotEmpty) {
            // default to first if nothing selected
            final defaultSub = subjects.firstWhere(
                  (s) => s['name'] == selectedSubject,
              orElse: () => subjects[0],
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  selectedSubject = defaultSub['name'];
                  selectedSubjectId = defaultSub['id'];
                });
              }
            });
            // build chips
            widgets.addAll(subjects.map((sub) {
              final name = sub['name'] as String;
              final id = sub['id'] as String;
              final isActive = name == selectedSubject;
              return GestureDetector(
                onTap: () => setState(() {
                  selectedSubject = name;
                  selectedSubjectId = id;
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF2D7BFF) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }));
          }
        }
        return Row(children: widgets);
      },
    );
  }

  Widget _buildAddSubjectChip() {
    return GestureDetector(
      onTap: _showAddSubjectDialog,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: const [
            Icon(Icons.add, size: 18, color: Colors.black87),
            SizedBox(width: 6),
            Text("Add Subject", style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Subject"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Subject Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('subjects')
                    .add({
                  'name': name,
                  'xp': 0,
                  'streak': 0,
                  'progress': 0,
                  'syllabusUrl': '',
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (selectedSubjectId == null) return const SizedBox();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(selectedSubjectId);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() as Map<String, dynamic>?;
        final streak = data?['streak'] as int? ?? 0;
        final xp = data?['xp'] as int? ?? 0;
        final progress = data?['progress'] as num? ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📊 Learning Progress", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("🔥 $streak Day Streak", style: const TextStyle(fontSize: 13)),
                  Text("✅ $xp XP", style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF2D7BFF),
                minHeight: 8,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "${progress.toStringAsFixed(0)}% Completed",
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadSyllabusButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadSyllabusScreen()),
        );
      },
      icon: const Icon(Icons.upload_file, size: 18),
      label: const Text("Upload Syllabus", style: TextStyle(fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2D7BFF),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      selectedItemColor: const Color(0xFF2D7BFF),
      unselectedItemColor: Colors.grey,
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() => _currentIndex = index);
        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuizSubjectScreen()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuizSubjectScreen()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlashcardSubjectScreen()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubjectIssueScreen()),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.quiz), label: "Quizzes"),
        BottomNavigationBarItem(icon: Icon(Icons.layers), label: "Flashcards"),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
