import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cityfix/theme_controller.dart';
import 'package:intl/intl.dart';

import '../../notifications_service.dart';

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
  bool _notificationsEnabled = true;

  final int _pageSize = 10;
  DocumentSnapshot? _lastVisible;
  final List<Map<String, dynamic>> _reports = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadPreferences();
    _fetchUserReports();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final snapshot =
    await _firestore.collection('profiles').doc(user.uid).get();

    if (snapshot.exists) {
      setState(() {
        _userData = snapshot.data();
      });
    }


    setState(() => _isLoading = false);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
  }

  Future<void> _fetchUserReports() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final user = _auth.currentUser;
    if (user == null) return;

    Query query = _firestore
        .collection('reports')
        .where('user_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .limit(_pageSize);

    if (_lastVisible != null) {
      query = query.startAfterDocument(_lastVisible!);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      _lastVisible = snapshot.docs.last;
    }

    final newReports = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        ...data,
        'id': doc.id,
      };
    }).toList();

    setState(() {
      _reports.addAll(newReports);
      _hasMore = newReports.length == _pageSize;
      _isLoadingMore = false;
    });
  }

  Future<void> _deleteReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).delete();
    setState(() {
      _reports.removeWhere((r) => r['id'] == reportId);
    });
  }

  // Show logout confirmation dialog
  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _signOut();
    }
  }

  Future<void> _signOut() async {
    await FirebaseMessaging.instance.deleteToken();
    await _firestore.collection('profiles').doc(_auth.currentUser!.uid).update({'fcm_token': FieldValue.delete()});
    await _auth.signOut();
    if (!mounted) return;

    // Show SnackBar after logging out
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You have logged out successfully."),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }


  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final date = ts.toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } else if (ts is String) {
      try {
        final date = DateTime.parse(ts);
        return DateFormat('yyyy-MM-dd HH:mm').format(date);
      } catch (_) {
        return 'Invalid date';
      }
    } else {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final isDarkMode = themeController.themeMode == ThemeMode.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: (_userData?['avatar_url'] != null &&
                  _userData!['avatar_url'].toString().startsWith('http'))
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
                Navigator.pushNamed(context, '/edit-profile')
                    .then((_) => _fetchUserData());
              },
              child: const Text("Edit Profile"),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text("Your Reports",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: _reports.isEmpty
                  ? const Center(child: Text('No reports submitted.'))
                  : NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (!_isLoadingMore &&
                      _hasMore &&
                      scrollInfo.metrics.pixels ==
                          scrollInfo.metrics.maxScrollExtent) {
                    _fetchUserReports();
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _reports.clear();
                      _lastVisible = null;
                      _hasMore = true;
                    });
                    await _fetchUserReports();
                  },
                  child: ListView.builder(
                    itemCount: _reports.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _reports.length) {
                        return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(),
                            ));
                      }
                      final report = _reports[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(report['description']),
                          subtitle: Text(
                              'Reported on: ${_formatTimestamp(report['created_at'])}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Confirm Deletion"),
                                  content: const Text(
                                      "Are you sure you want to delete this report?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteReport(report['id']);
                                      },
                                      child: const Text("Delete",
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              secondary: const Icon(Icons.notifications),
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() {
                  _notificationsEnabled = value;
                });
                await _savePreferences();
                await NotificationsService().toggleNotifications(value);
              },
            ),
            SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.dark_mode),
              value: isDarkMode,
              onChanged: (value) {
                themeController.toggleTheme(value);
              },
            ),
            ElevatedButton.icon(
              onPressed: _confirmLogout, // Changed from _signOut to _confirmLogout
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