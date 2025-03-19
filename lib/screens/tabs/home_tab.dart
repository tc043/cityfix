import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_card.dart'; // adjust the path if needed

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<int> _fetchReportCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('reports').get();
    return snapshot.docs.length;
  }

  Future<int> _fetchResolvedCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'resolved')
        .get();
    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome to CityFix!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Help improve your city by reporting and tracking public issues.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),

            const Text("Recent Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .orderBy('created_at', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load reports.'));
                } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No recent reports.'));
                }

                final reports = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ReportCard(report: data);
                }).toList();

                return Column(children: reports);
              },
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FutureBuilder<int>(
                  future: _fetchReportCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Column(
                      children: [
                        const Icon(Icons.report, size: 30, color: Colors.red),
                        Text("$count New Reports"),
                      ],
                    );
                  },
                ),
                FutureBuilder<int>(
                  future: _fetchResolvedCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Column(
                      children: [
                        const Icon(Icons.check_circle, size: 30, color: Colors.green),
                        Text("$count Issues Resolved"),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
