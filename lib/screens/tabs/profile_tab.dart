import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final snapshot = await _firestore.collection('profiles').doc(user.uid).get();

    if (snapshot.exists) {
      setState(() {
        _userData = snapshot.data();
      });
    }

    setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchUserReports() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('reports')
        .where('user_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id,
    }).toList();
  }

  Future<void> _deleteReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).delete();
    setState(() {});
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _userData?['avatar_url'] != null
                  ? NetworkImage(_userData!['avatar_url'])
                  : null,
              child: _userData?['avatar_url'] == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 10),

            Text(
              _userData?['full_name'] ?? 'No Name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(_userData?['email'] ?? 'No Email',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/edit-profile');
              },
              child: const Text("Edit Profile"),
            ),

            const SizedBox(height: 20),
            const Divider(),

            const Text("Your Reports",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchUserReports(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No reports submitted.'));
                  }

                  final reports = snapshot.data!;
                  return ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(report['description']),
                          subtitle: Text('Reported on: ${report['created_at']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteReport(report['id']),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(),

            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
