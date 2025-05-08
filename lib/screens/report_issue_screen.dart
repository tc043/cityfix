// lib/screens/report_issue_screen.dart
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({Key? key}) : super(key: key);
  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  Uint8List? _imageBytes;
  final _picker = ImagePicker();
  final _descCtrl = TextEditingController();
  Position? _currentPosition;
  bool _isSubmitting = false; // Add this to track submission state

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      await Geolocator.openLocationSettings();
      return;
    }

    var perm = await Permission.location.status;
    if (perm.isDenied) {
      perm = await Permission.location.request();
      if (perm.isDenied) return;
    }
    if (perm.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = pos);
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource src) async {
    final file = await _picker.pickImage(source: src);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    Uint8List data;
    if (kIsWeb) {
      final dec = img.decodeImage(bytes);
      if (dec == null) return;
      final resized = img.copyResize(dec, width: 800);
      data = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    } else {
      data = Uint8List.fromList(
          await FlutterImageCompress.compressWithList(bytes, quality: 70));
    }
    setState(() => _imageBytes = data);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showError(String message) {
    _showMessage(message, isError: true);
  }

  Future<void> _submitReport() async {
    // Validate form
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Please enter a description');
      return;
    }

    final pos = _currentPosition;
    if (pos == null) {
      _showError('Location not available');
      return;
    }

    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      _showError('You must be logged in');
      return;
    }

    // Show loading state
    setState(() {
      _isSubmitting = true;
    });

    try {
      String? url;
      if (_imageBytes != null) {
        final name = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref('reports/$name');
        await ref.putData(_imageBytes!);
        url = await ref.getDownloadURL();
      }

      final doc = {
        'description': _descCtrl.text.trim(),
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'image_url': url,
        'user_id': u.uid,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending'
      };

      await FirebaseFirestore.instance.collection('reports').add(doc);

      // Reset form
      setState(() {
        _imageBytes = null;
        _descCtrl.clear();
        _isSubmitting = false;
      });

      // Show success message
      _showMessage('Report submitted successfully!');

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      // Handle errors
      setState(() {
        _isSubmitting = false;
      });
      _showError('Failed to submit report: ${e.toString()}');
    }
  }

  bool get _hasImage => _imageBytes != null;

  @override
  Widget build(BuildContext c) {
    final loc = _currentPosition;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8)),
            child: _hasImage ? _preview() : _buttons(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
                labelText: 'Description (required)',
                border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          if (loc == null) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Fetching location...')
          ] else ...[
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                    initialCenter:
                    lat_lng.LatLng(loc.latitude, loc.longitude),
                    initialZoom: 15,
                    onTap: (_, p) => setState(() =>
                    _currentPosition = Position(
                        latitude: p.latitude,
                        longitude: p.longitude,
                        timestamp: DateTime.now(),
                        accuracy: 0,
                        altitude: 0,
                        altitudeAccuracy: 0,
                        heading: 0,
                        headingAccuracy: 0,
                        speed: 0,
                        speedAccuracy: 0,
                        floor: null,
                        isMocked: false))),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                        width: 80,
                        height: 80,
                        point:
                        lat_lng.LatLng(loc.latitude, loc.longitude),
                        child: const Icon(Icons.location_pin,
                            size: 50, color: Colors.red))
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Lat: ${loc.latitude}, Lng: ${loc.longitude}')
          ],
          const SizedBox(height: 20),
          _isSubmitting
              ? const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Submitting report...')
              ],
            ),
          )
              : ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit Report')
          )
        ]),
      ),
    );
  }

  Widget _buttons() => Column(mainAxisSize: MainAxisSize.min, children: [
    ElevatedButton.icon(
        onPressed: () => _pickImage(ImageSource.camera),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Camera')),
    const SizedBox(height: 8),
    ElevatedButton.icon(
        onPressed: () => _pickImage(ImageSource.gallery),
        icon: const Icon(Icons.photo_library),
        label: const Text('Gallery'))
  ]);

  Widget _preview() => Column(children: [
    Image.memory(_imageBytes!, height: 250, fit: BoxFit.cover),
    const SizedBox(height: 8),
    TextButton(
        onPressed: () => setState(() => _imageBytes = null),
        child: const Text('Remove Image'))
  ]);
}