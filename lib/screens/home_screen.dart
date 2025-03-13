import 'package:flutter/material.dart';

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
    const ReportIssueTab(),
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

      // Conditionally render the FAB if we're on the "Report" tab (index 1)
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
        onPressed: () {
          // Handle your "report an issue" action here
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

          // Quick Action Buttons
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

          // Recent Reports
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

          // Some Statistics
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

// Report tab content
class ReportIssueTab extends StatelessWidget {
  const ReportIssueTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Here you could show a list of open issues, or a form, etc.
    // The FAB (for actually creating a new report) will show up
    // conditionally in HomeScreen above (when index == 1).
    return const Center(
      child: Text("Report an Issue Tab", style: TextStyle(fontSize: 20)),
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
