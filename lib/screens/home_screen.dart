import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of widgets for each screen tab
  final List<Widget> _screens = [
    const HomeTab(),
    const ReportIssueTab(), // Now displays reports from Supabase
    const MapTab(),
  ];

  // When the user taps the bottom navigation bar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityFix Home'),
      ),
      body: _screens[_selectedIndex],

      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/report');
        },
        child: const Icon(Icons.add),
      )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}

// Home tab content
class HomeTab extends StatelessWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Welcome to CityFix!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Help improve your city by reporting and tracking public issues.",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/report'),
            child: const Text("📢 Report an Issue"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/map'),
            child: const Text("🗺️ View Map"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/reports'),
            child: const Text("📜 View All Reports"),
          ),
          const SizedBox(height: 20),

          const Text(
            "Recent Reports",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text("Pothole on Main Street"),
                subtitle: Text("Reported 2 hours ago"),
              ),
              ListTile(
                leading: Icon(Icons.lightbulb, color: Colors.yellow),
                title: Text("Streetlight Not Working"),
                subtitle: Text("Reported 1 day ago"),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: const [
                  Icon(Icons.report, size: 30, color: Colors.red),
                  Text("12 New Reports"),
                ],
              ),
              Column(
                children: const [
                  Icon(Icons.check_circle, size: 30, color: Colors.green),
                  Text("5 Issues Resolved"),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Report tab content - Fetch and display reports from Supabase
class ReportIssueTab extends StatefulWidget {
  const ReportIssueTab({Key? key}) : super(key: key);

  @override
  State<ReportIssueTab> createState() => _ReportIssueTabState();
}

class _ReportIssueTabState extends State<ReportIssueTab> {
  Future<List<dynamic>>? _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<dynamic>> _fetchReports() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('reports')
        .select()
        .order('created_at', ascending: false); // Fetch reports, newest first

    if (response == null) {
      throw Exception('Error fetching reports.');
    }
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
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
            final report = reports[index] as Map<String, dynamic>;
            return ListTile(
              leading: report['image_url'] != null
                  ? Image.network(
                report['image_url'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.report),
              title: Text(report['description'] ?? 'No description'),
              subtitle: Text('Reported at: ${report['created_at']}'),
              onTap: () {
                // Navigate to a detailed view if needed
              },
            );
          },
        );
      },
    );
  }
}

// Map tab content
class MapTab extends StatelessWidget {
  const MapTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("Map View", style: TextStyle(fontSize: 20)),
    );
  }
}
