// lib/screens/flashcard_subject_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'flashcards_study_screen.dart';

class FlashcardSubjectScreen extends StatefulWidget {
  const FlashcardSubjectScreen({Key? key}) : super(key: key);

  @override
  State<FlashcardSubjectScreen> createState() => _FlashcardSubjectScreenState();
}

class _FlashcardSubjectScreenState extends State<FlashcardSubjectScreen> {
  static const int _numFlashcards = 20;

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
    // TODO: retrieve from secure storage or env
    setState(() {
      _apiKey = 'API Key';
    });
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
    final systemPrompt = '''You are a JSON parser. Extract high-level chapter titles from the syllabus and return only a JSON array of strings.''';
    final userPrompt = syllabus;

    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': 150,
        'temperature': 0.5,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('API error ${res.statusCode}');
    }
    final text = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']') + 1;
    if (start < 0 || end <= start) {
      throw FormatException('No JSON array found in chapters response.');
    }
    final jsonString = text.substring(start, end);
    final list = jsonDecode(jsonString) as List;
    return list.cast<String>();
  }

  Future<List<Map<String, String>>> _generateFlashcardsFrom(String input) async {
    final systemPrompt = '''You are a flashcard generator. Create exactly $_numFlashcards flashcards from the input text. Return only a JSON array of objects with keys "question" and "answer".''';
    final userPrompt = input;

    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': 700,
        'temperature': 0.5,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('API error ${res.statusCode}');
    }
    final text = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']') + 1;
    if (start < 0 || end <= start) {
      throw FormatException('No JSON array found in flashcards response.');
    }
    final jsonString = text.substring(start, end);
    final parsed = jsonDecode(jsonString) as List;
    return parsed.take(_numFlashcards)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<void> _loadChapters() async {
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

  Future<void> _generateFlashcards() async {
    if (_selectedChapters.isEmpty || _selectedSubjectId == null) return;
    setState(() => _isLoading = true);
    try {
      final input = _selectedChapters.join('\n\n');
      final cards = await _generateFlashcardsFrom(input);

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(_selectedSubjectId)
          .collection('flashcards');

      // 1) Clear existing flashcards
      final existing = await ref.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // 2) Add new flashcards
      for (var card in cards) {
        await ref.add({
          'question':  card['question'],
          'answer':    card['answer'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3) Navigate to study screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardsStudyScreen(subjectId: _selectedSubjectId!),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Flashcards')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Subject'),
              value: _selectedSubjectId,
              items: _subjects.map((s) {
                return DropdownMenuItem<String>(
                  value: s['id'] as String,
                  child: Text(s['name'] as String),
                );
              }).toList(),
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
                onPressed: _generateFlashcards,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Generate Flashcards'),
              ),
          ],
        ),
      ),
    );
  }
}
