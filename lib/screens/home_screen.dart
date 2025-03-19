import 'package:cityfix/screens/map_screen.dart';
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
    const ReportIssueTab(),
    const MapScreen(),
    const ProfileTab(),
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
        backgroundColor: Colors.white, // ✅ Ensure it has a background color
        selectedItemColor: Colors.blue, // ✅ Active tab color
        unselectedItemColor: Colors.grey, // ✅ Inactive tab color
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile', // ✅ Profile Tab Added
          ),
        ],
      ),    );
  }
}



// Home tab content
class HomeTab extends StatelessWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CityFix Home'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
        .order('created_at', ascending: false);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reported Issues'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
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
              return ReportCard(report: report);
            },
          );
        },
      ),
    );
  }
}

// Custom Report Card Widget
class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportCard({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Image (if available)
            if (report['image_url'] != null && report['image_url'].isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report['image_url'],
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),

            // Report Description (Title)
            Text(
              report['description'] ?? 'No description available',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),

            // Location & Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      'Lat: ${report['latitude']}, Lng: ${report['longitude']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  _formatTimestamp(report['created_at']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Upvote & Comment Section (Optional)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, color: Colors.grey),
                  onPressed: () {}, // Placeholder for upvote action
                ),
                IconButton(
                  icon: const Icon(Icons.comment, color: Colors.grey),
                  onPressed: () {}, // Placeholder for comments
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Format timestamp into a user-friendly format
  String _formatTimestamp(String timestamp) {
    final DateTime dateTime = DateTime.parse(timestamp);
    return '${dateTime.year}-${dateTime.month}-${dateTime.day} at ${dateTime.hour}:${dateTime.minute}';
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

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _userData = response;
      });
        } catch (error) {
      debugPrint("Error fetching user data: $error");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 50,
              backgroundImage: _userData?['avatar_url'] != null
                  ? NetworkImage(_userData!['avatar_url'])
                  : null,
              child: _userData?['avatar_url'] == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 10),

            // User Info
            Text(
              _userData?['full_name'] ?? 'No Name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(_userData?['email'] ?? 'No Email',
                style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 20),

            // Edit Profile Button
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/edit-profile');
              },
              child: const Text("Edit Profile"),
            ),

            const SizedBox(height: 20),

            // User Reports Section
            const Divider(),
            const Text("Your Reports",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _fetchUserReports(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No reports submitted.'));
                  }

                  final reports = snapshot.data!;
                  return ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(report['description']),
                          subtitle: Text('Reported on: ${report['created_at']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteReport(report['id']),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(),

            // Logout Button
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<dynamic>> _fetchUserReports() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('reports')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return [];
  }

  Future<void> _deleteReport(String reportId) async {
    await supabase.from('reports').delete().eq('id', reportId);
    setState(() {
      _fetchUserReports();
    });
  }
}
