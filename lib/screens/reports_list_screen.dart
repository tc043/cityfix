import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Reports'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null || data.docs.isEmpty) {
            return Center(child: Text('No reports available.'));
          }
          return ListView.builder(
            itemCount: data.docs.length,
            itemBuilder: (context, index) {
              var report = data.docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(report['description'] ?? 'No Description'),
                subtitle: Text('Status: ${report['status'] ?? 'Unknown'}'),
                onTap: () {
                  // Optionally navigate to a detailed report view.
                },
              );
            },
          );
        },
      ),
    );
  }
}
