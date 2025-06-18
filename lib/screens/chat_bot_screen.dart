import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/chat_message.dart';

class ChatBotScreen extends StatefulWidget {
  final String subjectId;
  final List<String> chapterFilter;

  const ChatBotScreen({
    Key? key,
    required this.subjectId,
    required this.chapterFilter,
  }) : super(key: key);

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  bool _isLoading = false;

  String? _systemPrompt;
  String? _apiKey;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _buildSystemPrompt();
  }

  Future<void> _loadApiKey() async {
    // TODO: Securely load your API key
    setState(() {
      _apiKey = 'API key';
    });
  }

  Future<void> _buildSystemPrompt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Fetch user profile
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data()!;
    final name = data['name'] as String? ?? 'Student';
    final birthTs = data['birthDate'] as Timestamp;
    final goalsList = (data['topGoals'] as List<dynamic>?)?.cast<String>() ?? [];
    final studyTime = data['studyDuration'] as int? ?? 0;

    // Compute age
    final birth = birthTs.toDate();
    var age = DateTime.now().year - birth.year;
    if (DateTime.now().isBefore(DateTime(birth.year + age, birth.month, birth.day))) {
      age--;
    }

    // Fetch selected subject name
    final subjDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(widget.subjectId)
        .get();
    final subjectName = subjDoc.data()?['name'] as String? ?? 'Unknown Subject';

    // Build prompt text
    final goals = goalsList.isEmpty ? 'no specific goals' : goalsList.join(', ');
    final chapters = widget.chapterFilter.join(', ');

    final prompt = '''
You are **MentoraAI**, an adaptive, friendly AI tutor. Leverage the student’s profile and study preferences to deliver personalized, engaging explanations.

**Student Profile**  
- **Name:** $name  
- **Age:** $age  
- **Learning Goals:** $goals  
- **Available Study Time:** $studyTime minutes  

**Current Course Details**  
- **Subject:** $subjectName  
- **Chapters in Focus:** $chapters  

**Response Guidelines**  
1. **Personalize & Encourage**  
   - Greet the student by name.  
   - Use an upbeat, supportive tone.  
2. **Age-Appropriate Analogies**  
   - Adapt examples and analogies to fit the student’s age and interests.  
3. **Step-by-Step Clarity**  
   - Decompose complex ideas into sequential, digestible steps.  
4. **Enrich with Resources**  
   - When helpful, include definitions, simple diagrams (ASCII or described), and 1–2 practice questions.  
5. **Time-Aware Pacing**  
   - Keep your explanation concise enough to fit their available study time.  
6. **Next Steps**  
   - Conclude each answer with 1–2 actionable “Next Steps” to guide further learning.  

**Answer Format**  
- **Context:** Briefly restate the student’s question and relevant chapter.  
- **Explanation:** Provide the tailored lesson following the guidelines above.  
- **Next Steps:** Suggest follow-up practice or review topics.

Begin every response by restating the question context, then deliver a focused, chapter-specific explanation.
''';
    setState(() => _systemPrompt = prompt);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _apiKey == null || _systemPrompt == null) return;

    setState(() {
      _messages.add(ChatMessage(text: text, sender: Sender.user));
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    final conv = [
      {'role': 'system', 'content': _systemPrompt!},
      for (var m in _messages)
        {
          'role': m.sender == Sender.user ? 'user' : 'assistant',
          'content': m.text,
        }
    ];

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    try {
      final res = await http.post(uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': conv,
            'max_tokens': 500,
            'temperature': 0.7,
          }));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final reply = body['choices'][0]['message']['content'] as String;
        setState(() {
          _messages.add(ChatMessage(text: reply.trim(), sender: Sender.assistant));
          _isLoading = false;
        });
        _scrollToBottom();

        // ▲ Award XP for this Q/A
        await _awardChatXp();
      } else {
        throw Exception('API error ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', sender: Sender.assistant));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// Award XP for each question answered by the AI
  Future<void> _awardChatXp() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(widget.subjectId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final doc = await tx.get(ref);
      // Safely retrieve existing fields or default to 0
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final prevXp = (data['xp'] ?? 0) as int;
      final prevQs = (data['questionsAsked'] ?? 0) as int;
      tx.update(ref, {
        'xp':             prevXp + 5, // 5 XP per question
        'questionsAsked': prevQs + 1,
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.sender == Sender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_systemPrompt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading tutor...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('MentoraAI Tutor')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[i]),
            ),
          ),
          if (_isLoading) const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a question...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}