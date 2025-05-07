import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
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
      final snapshot =
          await FirebaseFirestore.instance.collection('reports').get();
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

  void _showReportDialog(Map<String, dynamic> report) async { // Made the function async
    String locationText = 'Location: Lat ${report['latitude']}, Lng ${report['longitude']}';

    try {
      // Use geocoding to get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        report['latitude'],
        report['longitude'],
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        locationText = 'Location: ${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      // Fallback to coordinates if geocoding fails
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(report['description'] ?? 'No description'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report['image_url'] != null &&
                  report['image_url'].toString().isNotEmpty)
                Image.network(report['image_url'],
                    height: 150, fit: BoxFit.cover),
              const SizedBox(height: 10),
              Text(locationText), // Use the determined location text
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
          initialZoom: 6.0,
          maxZoom: 18.0,
          minZoom: 5.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
            scrollWheelVelocity: 0.01,
            pinchZoomThreshold: 0.3,
            pinchMoveThreshold: 20.0,
          ),
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
