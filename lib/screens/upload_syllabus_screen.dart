// 📄 Upload Syllabus Screen (Text-based, Fixed + Styled)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadSyllabusScreen extends StatefulWidget {
  const UploadSyllabusScreen({super.key});

  @override
  State<UploadSyllabusScreen> createState() => _UploadSyllabusScreenState();
}

class _UploadSyllabusScreenState extends State<UploadSyllabusScreen> {
  String? selectedSubjectId;
  String? selectedSubjectName;
  List<Map<String, dynamic>> subjects = [];
  final _syllabusController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get();

    setState(() {
      subjects = snapshot.docs
          .map((doc) => {'id': doc.id, 'name': doc['name']})
          .toList();
    });
  }

  Future<void> _saveSyllabus() async {
    if (selectedSubjectId == null || _syllabusController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(selectedSubjectId!)
        .update({'syllabus': _syllabusController.text.trim()});

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Syllabus saved successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Syllabus"),
        backgroundColor: const Color(0xFF2D7BFF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Subject:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedSubjectId,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF2F6FF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              hint: const Text('Choose a subject'),
              items: subjects.map<DropdownMenuItem<String>>((subject) {
                return DropdownMenuItem<String>(
                  value: subject['id'] as String,
                  child: Text(subject['name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubjectId = value;
                  selectedSubjectName = subjects.firstWhere((s) => s['id'] == value)['name'];
                  _syllabusController.clear();
                });
              },
            ),

            const SizedBox(height: 24),

            if (selectedSubjectId != null) ...[
              const Text("Syllabus Text:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF2D7BFF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: TextFormField(
                  controller: _syllabusController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: "Enter syllabus topics here...",
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSyllabus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Syllabus", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _syllabusController.dispose();
    super.dispose();
  }
}
