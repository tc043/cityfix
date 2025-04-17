import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:collection';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _trendMode = 'weekly';

  Future<Map<String, int>> _fetchDashboardCounts() async {
    final now = DateTime.now();
    final past24h = now.subtract(const Duration(hours: 24));

    final snapshot = await FirebaseFirestore.instance.collection('reports').get();

    int total = 0;
    int resolved = 0;
    int recent = 0;
    int recentResolved = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      total++;

      final createdAt = DateTime.tryParse(data['created_at'] ?? '') ?? now;
      final isRecent = createdAt.isAfter(past24h);

      if (data['status'] == 'resolved') {
        resolved++;
        if (isRecent) recentResolved++;
      }
      if (isRecent) recent++;
    }

    return {
      'total': total,
      'resolved': resolved,
      'recent': recent,
      'recentResolved': recentResolved,
    };
  }

  Future<Map<String, int>> _fetchStatusDistribution() async {
    final snapshot = await FirebaseFirestore.instance.collection('reports').get();
    int resolved = 0;
    int unresolved = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'resolved') {
        resolved++;
      } else {
        unresolved++;
      }
    }
    return {'Resolved': resolved, 'Unresolved': unresolved};
  }

  Future<Map<String, int>> _fetchTrendData(String mode) async {
    final now = DateTime.now();
    final range = mode == 'monthly' ? 30 : mode == 'yearly' ? 365 : 7;
    final earliestDate = now.subtract(Duration(days: range));

    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('created_at', isGreaterThan: earliestDate.toIso8601String())
        .get();

    final Map<String, int> trends = SplayTreeMap();

    for (var i = range - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      trends[key] = 0;
    }

    for (var doc in snapshot.docs) {
      final createdAt = DateTime.tryParse(doc['created_at'] ?? '') ?? now;
      final key = "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
      if (trends.containsKey(key)) {
        trends[key] = trends[key]! + 1;
      }
    }

    return trends;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityFix Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        leading: const Icon(Icons.dashboard, color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Monitor city issues in real time.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),

            FutureBuilder<Map<String, int>>(
              future: _fetchDashboardCounts(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {'total': 0, 'resolved': 0, 'recent': 0, 'recentResolved': 0};
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard("Total Reports", data['total']!, Icons.report, Colors.red),
                        _buildStatCard("Total Resolved", data['resolved']!, Icons.check_circle, Colors.green),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard("Reports (24h)", data['recent']!, Icons.access_time, Colors.orange),
                        _buildStatCard("Resolved (24h)", data['recentResolved']!, Icons.update, Colors.blue),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            const Text("Status Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, int>>(
              future: _fetchStatusDistribution(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final total = data.values.fold(0, (a, b) => a + b);
                return AspectRatio(
                  aspectRatio: 1.3,
                  child: PieChart(
                    PieChartData(
                      sections: data.entries.map((entry) {
                        final percent = total == 0 ? 0 : (entry.value / total) * 100;
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title: "${entry.key} (${percent.toStringAsFixed(1)}%)",
                          color: entry.key == 'Resolved' ? Colors.green : Colors.red,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 70,
                        );
                      }).toList(),
                      sectionsSpace: 4,
                      centerSpaceRadius: 30,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Report Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _trendMode,
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text("Weekly")),
                    DropdownMenuItem(value: 'monthly', child: Text("Monthly")),
                    DropdownMenuItem(value: 'yearly', child: Text("Yearly")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _trendMode = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, int>>(
              future: _fetchTrendData(_trendMode),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final keys = data.keys.toList();
                final values = data.values.toList();
                final average = values.isEmpty ? 0 : (values.reduce((a, b) => a + b) / values.length).round();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i].toDouble())),
                              isCurved: true,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              color: Colors.teal,
                              belowBarData: BarAreaData(show: true, color: Colors.teal.withValues(alpha: 0.2)),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              axisNameWidget: const Text('Reports'),
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (_trendMode == 'weekly') ? 1 : (_trendMode == 'monthly' ? 5 : 30),
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Date'),
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (_trendMode == 'weekly') ? 1 : (_trendMode == 'monthly' ? 5 : 30),
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < keys.length) {
                                    final label = keys[idx].split('-').last;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(label, style: const TextStyle(fontSize: 10)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true),
                          minY: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("Average reports/day: $average", style: const TextStyle(fontSize: 14)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text("$count", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
