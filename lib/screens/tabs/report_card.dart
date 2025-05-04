import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import '../report_details_screen.dart';

class ReportCard extends StatefulWidget {
  final Map<String, dynamic> report;
  final String reportId;

  const ReportCard({super.key, required this.report, required this.reportId});

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  bool _hasUpvoted = false;
  int _upvoteCount = 0;
  String? _address;

  @override
  void initState() {
    super.initState();
    _loadUpvoteStatus();
    _loadAddress();
  }

  Future<void> _loadUpvoteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reportRef =
        FirebaseFirestore.instance.collection('reports').doc(widget.reportId);
    final upvoteRef = reportRef.collection('upvotes').doc(user.uid);

    final upvoteSnap = await upvoteRef.get();
    final allUpvotes = await reportRef.collection('upvotes').get();

    setState(() {
      _hasUpvoted = upvoteSnap.exists;
      _upvoteCount = allUpvotes.size;
    });
  }

  Future<void> _toggleUpvote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reportRef =
        FirebaseFirestore.instance.collection('reports').doc(widget.reportId);
    final upvoteRef = reportRef.collection('upvotes').doc(user.uid);

    final alreadyUpvoted = await upvoteRef.get();

    if (alreadyUpvoted.exists) {
      // Remove upvote
      await upvoteRef.delete();
      setState(() {
        _hasUpvoted = false;
        _upvoteCount--;
      });
    } else {
      // Add upvote
      await upvoteRef.set({'voted': true});
      setState(() {
        _hasUpvoted = true;
        _upvoteCount++;
      });
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentSection(reportId: widget.reportId),
    );
  }

  Future<void> _loadAddress() async {
    try {
      final lat = widget.report['latitude'];
      final lng = widget.report['longitude'];

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address = '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Unable to load address';
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailsScreen(
                report: widget.report,
                reportId: widget.reportId,
              ),
            ),
          );
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report['image_url'] != null &&
                    report['image_url'].isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      report['image_url'],
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) =>
                          loadingProgress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  report['description'] ?? 'No description available',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                if (report['status'] != null)
                  Chip(
                    label: Text(
                      report['status'].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(report['status']),
                  ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _address != null
                                  ? _address!
                                  : 'Loading address...',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTimestamp(report['created_at']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _hasUpvoted
                            ? Icons.arrow_upward
                            : Icons.arrow_upward_outlined,
                        color: _hasUpvoted ? Colors.green : Colors.grey,
                      ),
                      onPressed: _toggleUpvote,
                    ),
                    Text('$_upvoteCount', style: const TextStyle(fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.comment, color: Colors.grey),
                      onPressed: () => _showComments(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final DateTime dateTime = DateTime.parse(timestamp);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

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

    return SafeArea(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
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
              ),
            )
          ],
        ),
      ),
    );
  }
}
