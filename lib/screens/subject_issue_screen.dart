import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'chat_bot_screen.dart';

class SubjectIssueScreen extends StatefulWidget {
  const SubjectIssueScreen({Key? key}) : super(key: key);

  @override
  State<SubjectIssueScreen> createState() => _SubjectIssueScreenState();
}

class _SubjectIssueScreenState extends State<SubjectIssueScreen> {
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
    _loadSubjects();
  }

  Future<void> _loadApiKey() async {
    // TODO: Replace with secure retrieval
    setState(() {
      _apiKey = 'APi Kay';
    });
  }

  Future<void> _loadSubjects() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get();
    setState(() {
      _subjects = snap.docs
          .map((d) => {
        'id': d.id,
        'name': d['name'],
        'syllabus': d['syllabus'], // JSON string or plain text
      })
          .toList();
    });
  }

  Future<List<String>> _callOpenAIForChapters(String syllabus) async {
    final prompt = '''
Split the following syllabus into high-level chapter titles.
Return only a JSON array of strings without any extra text:

$syllabus
''';
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final messages = [
      {'role': 'system', 'content': 'You are an AI that splits syllabi into chapter titles.'},
      {'role': 'user', 'content': prompt},
    ];
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': messages,
        'max_tokens': 200,
        'temperature': 0.5,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final content = decoded['choices'][0]['message']['content'] as String;

    // Remove Markdown fences (``` or ```json)
    var cleaned = content
        .replaceAll(RegExp(r'```json', multiLine: false), '')
        .replaceAll('```', '')
        .trim();

    // Extract JSON array substring
    final regex = RegExp(r'\[.*\]', dotAll: true);
    final match = regex.firstMatch(cleaned);
    if (match == null) {
      throw Exception('No JSON array found in response');
    }
    final jsonText = match.group(0)!;

    try {
      final List<dynamic> list = jsonDecode(jsonText);
      return list.cast<String>();
    } catch (e) {
      throw Exception('Error parsing JSON chapters: $e');
    }
  }

  Future<void> _generateChapters() async {
    if (_selectedSubjectId == null || _apiKey == null) return;
    setState(() {
      _isLoading = true;
      _chapters = [];
      _selectedChapters.clear();
    });
    try {
      final subject = _subjects.firstWhere((s) => s['id'] == _selectedSubjectId);
      final syllabus = subject['syllabus'] as String;
      final chapters = await _callOpenAIForChapters(syllabus);
      setState(() {
        _chapters = chapters;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error parsing chapters: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToChat() {
    if (_selectedSubjectId == null || _selectedChapters.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatBotScreen(
          subjectId: _selectedSubjectId!,
          chapterFilter: _selectedChapters.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Subject & Chapters')),
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
              onChanged: (id) {
                setState(() {
                  _selectedSubjectId = id;
                  _chapters.clear();
                  _selectedChapters.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_selectedSubjectId != null && !_isLoading)
                  ? _generateChapters
                  : null,
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Load Chapters'),
            ),
            const SizedBox(height: 16),
            if (_chapters.isNotEmpty)
              Expanded(
                child: ListView(
                  children: _chapters.map((ch) {
                    return CheckboxListTile(
                      title: Text(ch),
                      value: _selectedChapters.contains(ch),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) _selectedChapters.add(ch);
                          else _selectedChapters.remove(ch);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            if (_selectedChapters.isNotEmpty)
              ElevatedButton(
                onPressed: _goToChat,
                child: const Text('Proceed to Chat'),
              ),
          ],
        ),
      ),
    );
  }
}
