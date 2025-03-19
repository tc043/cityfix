import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
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
    final supabase = Supabase.instance.client;
    final response = await supabase.from('reports').select();

    if (response == null || response.isEmpty) {
      debugPrint('No reports found.');
      return;
    }

    List<Marker> fetchedMarkers = response.map<Marker>((report) {
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
              if (report['image_url'] != null)
                Image.network(report['image_url'], height: 150, fit: BoxFit.cover),
              const SizedBox(height: 10),
              Text('Location: Lat ${report['latitude']}, Lng ${report['longitude']}'),
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
      appBar: AppBar(title: const Text('Reported Issues Map')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _initialPosition, // 🌍 Starts in Malaysia 🇲🇾
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
