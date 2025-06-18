// lib/screens/profile_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mentora_ai/screens/login_screen.dart'; // adjust import path
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _name;
  String? _email;
  List<String>? _goals;
  DateTime? _birthDate;
  int? _studyDuration;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    setState(() {
      _name = data?['name'] as String?;
      _email = data?['email'] as String?;
      _goals = (data?['topGoals'] as List<dynamic>?)?.cast<String>() ?? [];
      final ts = data?['birthDate'] as Timestamp?;
      _birthDate = ts?.toDate();
      _studyDuration = data?['studyDuration'] as int?;
      _isLoading = false;
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  String _formatDate(DateTime date) {
    final day   = date.day   .toString().padLeft(2, '0');
    final month = date.month .toString().padLeft(2, '0');
    final year  = date.year  .toString();
    return '$day/$month/$year';
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            CircleAvatar(
              radius: 48,
              child: Text(
                _name != null && _name!.isNotEmpty ? _name![0] : '',
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Name'),
              subtitle: Text(_name ?? '—'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(_email ?? '—'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Learning Goals'),
              subtitle: Text(_goals!.isNotEmpty ? _goals!.join(', ') : '—'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cake),
              title: const Text('Birth Date'),
              subtitle: Text(_birthDate != null ? _formatDate(_birthDate!) : '—'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Study Duration (mins)'),
              subtitle: Text(_studyDuration?.toString() ?? '—'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              child: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}