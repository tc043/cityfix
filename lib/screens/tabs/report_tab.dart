import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_card.dart';

class ReportIssueTab extends StatefulWidget {
  const ReportIssueTab({super.key});

  @override
  State<ReportIssueTab> createState() => _ReportIssueTabState();
}

class _ReportIssueTabState extends State<ReportIssueTab> {
  Future<List<Map<String, dynamic>>>? _reportsFuture;
  String _selectedStatus = 'all';
  String _selectedSort = 'date_desc';

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<Map<String, dynamic>>> _fetchReports() async {
    Query query = FirebaseFirestore.instance.collection('reports');

    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    } else {
      query = query.where('status', isNotEqualTo: 'rejected');
    }

    // Order by date only for date-based sort
    if (_selectedSort == 'date_desc') {
      query = query.orderBy('created_at', descending: true);
    }

    final snapshot = await query.get();

    List<Map<String, dynamic>> reports = [];

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      final upvoteSnap = await FirebaseFirestore.instance
          .collection('reports')
          .doc(doc.id)
          .collection('upvotes')
          .get();

      data['id'] = doc.id;
      data['upvoteCount'] = upvoteSnap.size;

      reports.add(data);
    }

    // Sort client-side if needed
    if (_selectedSort == 'upvotes_desc') {
      reports.sort((a, b) => b['upvoteCount'].compareTo(a['upvoteCount']));
    }

    return reports;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reported Issues',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: Column(
        children: [
          // 🔽 Status Filter Dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                // Status Filter Dropdown
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'in progress', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'resolved', child: Text('Resolved')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                          _reportsFuture = _fetchReports();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Dropdown
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'date_desc', child: Text('Newest First')),
                      DropdownMenuItem(
                          value: 'upvotes_desc', child: Text('Most Upvoted')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSort = value;
                          _reportsFuture = _fetchReports();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 🔁 Report list inside Expanded
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _reportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error loading reports: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No reports available.'));
                }

                final reports = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    final newReports = await _fetchReports();
                    setState(() {
                      _reportsFuture = Future.value(newReports);
                    });
                  },
                  child: ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final reportId = report['id'];
                      return ReportCard(report: report, reportId: reportId);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
