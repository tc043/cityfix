import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text('CityFix Home'),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'Home'),
              Tab(icon: Icon(Icons.report), text: 'Report'),
              Tab(icon: Icon(Icons.map), text: 'Map'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HomeTab(context), // Home tab content
            ReportIssueTab(context), // Report Issue tab content
            MapTab(context), // Map tab content
          ],
        ),
      ),
    );
  }

  Widget HomeTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome to CityFix!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            "Help improve your city by reporting and tracking public issues.",
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),

          // Quick Action Buttons
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/report'),
            child: Text("📢 Report an Issue"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/map'),
            child: Text("🗺️ View Map"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/reports'),
            child: Text("📜 View All Reports"),
          ),

          SizedBox(height: 20),

          // Recent Reports
          Text(
            "Recent Reports",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          ListView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
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

          SizedBox(height: 20),

          // Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Icon(Icons.report, size: 30, color: Colors.red),
                  Text("12 New Reports"),
                ],
              ),
              Column(
                children: [
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

  Widget ReportIssueTab(BuildContext context) {
    return Center(
      child: Text("Report an Issue Here", style: TextStyle(fontSize: 20)),
    );
  }

  Widget MapTab(BuildContext context) {
    return Center(child: Text("Map View", style: TextStyle(fontSize: 20)));
  }
}
