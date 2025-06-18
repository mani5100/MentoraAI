// lib/screens/quiz_subject_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'quiz_study_screen.dart';  // You’ll build this next

class QuizSubjectScreen extends StatefulWidget {
  const QuizSubjectScreen({Key? key}) : super(key: key);

  @override
  State<QuizSubjectScreen> createState() => _QuizSubjectScreenState();
}

class _QuizSubjectScreenState extends State<QuizSubjectScreen> {
  List<Map<String, dynamic>> _subjects = [];
  String? _selectedSubjectId;
  List<String> _chapters = [];
  Set<String> _selectedChapters = {};
  bool _isLoading = false;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _fetchSubjects();
  }

  Future<void> _loadApiKey() async {
    // TODO: replace with secure storage
    setState(() => _apiKey = 'API');
  }

  Future<void> _fetchSubjects() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get();
    setState(() {
      _subjects = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] as String,
          'syllabus': data['syllabus'] as String,
        };
      }).toList();
    });
  }

  Future<List<String>> _fetchChapters(String syllabus) async {
    final prompt = '''
Split the following syllabus into high-level chapter titles.
Return only a JSON array of strings:

$syllabus
''';
    final resp = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': 'Extract chapter titles.'},
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 150,
      }),
    );
    if (resp.statusCode != 200) throw Exception('API error ${resp.statusCode}');
    final content = jsonDecode(resp.body)['choices'][0]['message']['content'] as String;
    final match = RegExp(r'(\[.*?\])', dotAll: true).firstMatch(content);
    if (match == null) throw Exception('No JSON array found');
    return List<String>.from(jsonDecode(match.group(1)!));
  }

  Future<List<Map<String, dynamic>>> _generateQuizQuestions(String input) async {
    // A system prompt that forces JSON-only output
    final systemPrompt = '''
You are a JSON generator. 
Generate exactly 10 multiple-choice quiz questions with four options each, 
and indicate the correct answer. 

Return _only_ a JSON array of objects with keys:
- "question": string,
- "options": array of exactly 4 strings,
- "answer": string (must exactly match one element of "options").

Do not wrap the array in backticks or add any extra commentary.
''';

    final userPrompt = '''
Here is the source text. Create your quiz from this:

$input
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system',  'content': systemPrompt},
          {'role': 'user',    'content': userPrompt},
        ],
        'max_tokens': 700,
        'temperature': 0.2,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}');
    }

    final content = jsonDecode(response.body)
    ['choices'][0]['message']['content'] as String;

    // Extract from first `[` to last `]`
    final start = content.indexOf('[');
    final end   = content.lastIndexOf(']') + 1;
    if (start < 0 || end <= start) {
      throw FormatException(
          'No full JSON array found in response:\n$content'
      );
    }

    final jsonString = content.substring(start, end);
    List<dynamic> parsed;
    try {
      parsed = jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      throw FormatException(
          'Failed to parse JSON array:\n$jsonString\nError: $e'
      );
    }

    // Enforce exactly 10 items
    final questions = parsed.take(10).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      if (!(map.containsKey('question') &&
          map.containsKey('options') &&
          map.containsKey('answer'))) {
        throw FormatException('Missing keys in: $e');
      }
      return map;
    }).toList();

    return questions;
  }


  void _loadChapters() async {
    if (_selectedSubjectId == null) return;
    setState(() => _isLoading = true);
    try {
      final subj = _subjects.firstWhere((s) => s['id'] == _selectedSubjectId);
      _chapters = await _fetchChapters(subj['syllabus'] as String);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateQuiz() async {
    if (_selectedChapters.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final input = _selectedChapters.join('\n\n');
      final questions = await _generateQuizQuestions(input);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(_selectedSubjectId)
          .collection('quizzes');

      // 1) Delete any existing quizzes for this subject
      final existing = await ref.get();
      final batch    = FirebaseFirestore.instance.batch();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 2) Add exactly 10 new questions with timestamps
      for (var q in questions) {
        await ref.add({
          'question':  q['question'],
          'options':   q['options'],
          'answer':    q['answer'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3) Navigate to the study screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizStudyScreen(subjectId: _selectedSubjectId!),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Subject'),
              value: _selectedSubjectId,
              items: _subjects.map((s) => DropdownMenuItem(
                value: s['id'] as String,
                child: Text(s['name'] as String),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedSubjectId = v;
                  _chapters.clear();
                  _selectedChapters.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_selectedSubjectId != null && !_isLoading) ? _loadChapters : null,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Load Chapters'),
            ),
            const SizedBox(height: 8),
            if (_chapters.isNotEmpty)
              Expanded(
                child: ListView(
                  children: _chapters.map((ch) => CheckboxListTile(
                    title: Text(ch),
                    value: _selectedChapters.contains(ch),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) _selectedChapters.add(ch);
                        else _selectedChapters.remove(ch);
                      });
                    },
                  )).toList(),
                ),
              ),
            if (_selectedChapters.isNotEmpty)
              ElevatedButton(
                onPressed: _generateQuiz,
                child: const Text('Generate Quiz'),
              ),
          ],
        ),
      ),
    );
  }
}
