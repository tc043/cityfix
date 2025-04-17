import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapTab> {
  final MapController _mapController = MapController();

  // 🌍 Set Malaysia (Kuala Lumpur) as the default map center
  final LatLng _initialPosition = const LatLng(3.1390, 101.6869);

  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('reports')
          .get();
      if (snapshot.docs.isEmpty) {
        debugPrint('No reports found.');
        return;
      }

      List<Marker> fetchedMarkers = snapshot.docs.map((doc) {
        final report = doc.data();
        return Marker(
          width: 50,
          height: 50,
          point: LatLng(report['latitude'], report['longitude']),
          child: GestureDetector(
            onTap: () {
              _showReportDialog(report);
            },
            child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
          ),
        );
      }).toList();

      setState(() {
        _markers = fetchedMarkers;
      });
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    }
  }

  void _showReportDialog(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(report['description'] ?? 'No description'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report['image_url'] != null && report['image_url']
                  .toString()
                  .isNotEmpty)
                Image.network(
                    report['image_url'], height: 150, fit: BoxFit.cover),
              const SizedBox(height: 10),
              Text(
                  'Location: Lat ${report['latitude']}, Lng ${report['longitude']}'),
              Text('Reported on: ${report['created_at']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CityFix Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _initialPosition,
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}
