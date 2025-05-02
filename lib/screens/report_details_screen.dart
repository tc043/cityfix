import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;


class ReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final String reportId;

  const ReportDetailsScreen({
    super.key,
    required this.report,
    required this.reportId,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  String? _address;
  String? _currentStatus;
  bool _isAdmin = false;

  final List<String> _statusOptions = ['pending', 'in progress', 'resolved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _getAddress();
    _checkIfAdmin();
    _currentStatus = widget.report['status'] ?? 'pending';
  }

  Future<void> _getAddress() async {
    try {
      final lat = widget.report['latitude'];
      final lng = widget.report['longitude'];

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address =
          '${place.name}, ${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Unable to fetch address';
      });
    }
  }

  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
    final role = userDoc.data()?['role'];

    setState(() {
      _isAdmin = role == 'admin' || role == 'moderator';
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.reportId)
        .update({'status': newStatus});

    setState(() {
      _currentStatus = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to "$newStatus"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report['image_url'] != null && report['image_url'].isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report['image_url'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              report['description'] ?? 'No description provided',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Address: ${_address ?? "Loading..."}'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: latlng.LatLng(
                    widget.report['latitude'],
                    widget.report['longitude'],
                  ),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80,
                        height: 80,
                        point: latlng.LatLng(
                          widget.report['latitude'],
                          widget.report['longitude'],
                        ),
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Text('Reported at: ${report['created_at']}'),
            const SizedBox(height: 16),
            Text('Current Status: ${_currentStatus?.toUpperCase()}'),
            const SizedBox(height: 8),

            if (_isAdmin)
              DropdownButton<String>(
                value: _currentStatus,
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != _currentStatus) {
                    _updateStatus(value);
                  }
                },
              ),

            const SizedBox(height: 24),
            const Text(
              'Comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            CommentSection(reportId: widget.reportId),
          ],
        ),
      ),
    );
  }
}

// ✅ Embedded CommentSection widget
class CommentSection extends StatefulWidget {
  final String reportId;

  const CommentSection({super.key, required this.reportId});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  Future<void> _postComment() async {
    final user = _auth.currentUser;
    final text = _commentController.text.trim();

    if (text.isEmpty || user == null) return;

    await FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.reportId)
        .collection('comments')
        .add({
      'text': text,
      'user_id': user.uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final commentsRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.reportId)
        .collection('comments')
        .orderBy('created_at', descending: true);

    return Column(
      children: [
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: commentsRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No comments yet.'),
              );
            }

            return ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final text = data['text'] ?? '';
                final userId = data['user_id'] ?? '';
                final timestamp =
                (data['created_at'] as Timestamp?)?.toDate();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(text),
                    subtitle: Text(
                      userId,
                      style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Text(
                      timestamp != null
                          ? '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                          : '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _postComment,
            )
          ],
        )
      ],
    );
  }
}

