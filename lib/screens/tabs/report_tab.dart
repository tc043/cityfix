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

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<Map<String, dynamic>>> _fetchReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading reports: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reports available.'));
          }

          final reports = snapshot.data!;
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return ReportCard(report: reports[index]);
            },
          );
        },
      ),
    );
  }
}
