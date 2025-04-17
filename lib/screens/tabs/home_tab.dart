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

  Future<int> _fetchReportCount({bool within24Hours = false}) async {
    final collection = FirebaseFirestore.instance.collection('reports');
    Query query = collection;

    if (within24Hours) {
      final now = DateTime.now();
      final past24h = now.subtract(const Duration(hours: 24));
      query =
          query.where('created_at', isGreaterThan: past24h.toIso8601String());
    }

    final snapshot = await query.get();
    return snapshot.docs.length;
  }

  Future<int> _fetchResolvedCount({bool within24Hours = false}) async {
    final collection = FirebaseFirestore.instance.collection('reports');
    Query query = collection.where('status', isEqualTo: 'resolved');

    if (within24Hours) {
      final now = DateTime.now();
      final past24h = now.subtract(const Duration(hours: 24));
      query =
          query.where('created_at', isGreaterThan: past24h.toIso8601String());
    }

    final snapshot = await query.get();
    return snapshot.docs.length;
  }

  Future<Map<String, int>> _fetchStatusDistribution() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('reports').get();
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
    final snapshot =
        await FirebaseFirestore.instance.collection('reports').get();
    final now = DateTime.now();
    final Map<String, int> trends = SplayTreeMap();

    int range = mode == 'monthly'
        ? 30
        : mode == 'yearly'
            ? 365
            : 7;

    for (var i = range - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      trends[key] = 0;
    }

    for (var doc in snapshot.docs) {
      final createdAt =
          DateTime.tryParse(doc['created_at'] ?? '') ?? DateTime.now();
      final key =
          "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
      if (trends.containsKey(key)) {
        trends[key] = trends[key]! + 1;
      }
    }

    return trends;
  }

  void _navigateToFiltered(BuildContext context, String filter) {
    Navigator.pushNamed(context, '/reports', arguments: {'filter': filter});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CityFix Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        leading: Icon(Icons.dashboard, color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings if needed
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dashboard",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Monitor city issues in real time.",
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FutureBuilder<int>(
                  future: _fetchReportCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return GestureDetector(
                      onTap: () => _navigateToFiltered(context, 'all'),
                      child: _buildStatCard(
                          "Total Reports", count, Icons.report, Colors.red),
                    );
                  },
                ),
                FutureBuilder<int>(
                  future: _fetchResolvedCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return GestureDetector(
                      onTap: () => _navigateToFiltered(context, 'resolved'),
                      child: _buildStatCard("Total Resolved", count,
                          Icons.check_circle, Colors.green),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FutureBuilder<int>(
                  future: _fetchReportCount(within24Hours: true),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return GestureDetector(
                      onTap: () => _navigateToFiltered(context, 'recent'),
                      child: _buildStatCard("Reports (24h)", count,
                          Icons.access_time, Colors.orange),
                    );
                  },
                ),
                FutureBuilder<int>(
                  future: _fetchResolvedCount(within24Hours: true),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return GestureDetector(
                      onTap: () =>
                          _navigateToFiltered(context, 'recent_resolved'),
                      child: _buildStatCard(
                          "Resolved (24h)", count, Icons.update, Colors.blue),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Status Distribution",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, int>>(
              future: _fetchStatusDistribution(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final total = data.values.fold(0, (a, b) => a + b);
                return AspectRatio(
                  aspectRatio: 1.3,
                  child: PieChart(
                    PieChartData(
                      sections: data.entries.map((entry) {
                        final percent =
                            total == 0 ? 0 : (entry.value / total) * 100;
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title:
                              "${entry.key} (${percent.toStringAsFixed(1)}%)",
                          color: entry.key == 'Resolved'
                              ? Colors.green
                              : Colors.red,
                          titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
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
                const Text("Report Trend",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final keys = data.keys.toList();
                final values = data.values.toList();
                final average = values.isEmpty
                    ? 0
                    : (values.reduce((a, b) => a + b) / values.length).round();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                  values.length,
                                  (i) => FlSpot(
                                      i.toDouble(), values[i].toDouble())),
                              isCurved: true,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              color: Colors.teal,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.teal.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              axisNameWidget: Text('Reports'),
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (_trendMode == 'weekly')
                                    ? 1
                                    : (_trendMode == 'monthly' ? 5 : 30),
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) => Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10)),
                              ),
                            ),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              axisNameWidget: Text('Date'),
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (_trendMode == 'weekly')
                                    ? 1
                                    : (_trendMode == 'monthly' ? 5 : 30),
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < keys.length) {
                                    final label = keys[idx].split('-').last;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(label,
                                          style: const TextStyle(fontSize: 10)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          gridData:
                              FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: true),
                          minY: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("Average reports/day: $average",
                        style: const TextStyle(fontSize: 14)),
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
            Text("$count",
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
