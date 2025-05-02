import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
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
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      if (kIsWeb) {
        final rawBytes = await pickedFile.readAsBytes();
        final decodedImage = img.decodeImage(rawBytes);
        if (decodedImage == null) return;
        final resized = img.copyResize(decodedImage, width: 800);
        final compressedBytes = img.encodeJpg(resized, quality: 70);
        setState(() {
          _imageBytes = Uint8List.fromList(compressedBytes);
        });
      } else {
        final file = File(pickedFile.path);
        final fileBytes = await file.readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          fileBytes,
          quality: 70,
        );
        setState(() {
          _imageBytes = compressed;
        });
      }
    } catch (e) {
      _showError('Error picking or compressing image: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
    });
  }




  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please enter a description.');
      return;
    }

    if (_currentPosition == null) {
      _showError('Location not available.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not logged in.');
      return;
    }

    String? imageUrl;
    if (_imageBytes != null) {
      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('reports/$fileName');
      try {
        await storageRef.putData(_imageBytes!);
        imageUrl = await storageRef.getDownloadURL();
      } catch (error) {
        _showError('Image upload failed: $error');
        return;
      }
    }

    final reportData = {
      'description': _descriptionController.text.trim(),
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'image_url': imageUrl,
      'user_id': user.uid,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    };


    try {
      await FirebaseFirestore.instance.collection('reports').add(reportData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );
      setState(() {
        _imageBytes = null;
        _descriptionController.clear();
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      _showError('Report submission failed: $error');
    }
  }

  bool get _hasImage => _imageBytes != null;

  @override
  Widget build(BuildContext context) {
    final bool locationReady = _currentPosition != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _hasImage ? _buildImagePreview() : _buildImageButtons(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            if (!locationReady) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Fetching location...'),
            ] else ...[
              SizedBox(
                height: 300,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: lat_lng.LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    initialZoom: 15,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _currentPosition = Position(
                          latitude: point.latitude,
                          longitude: point.longitude,
                          timestamp: DateTime.now(),
                          accuracy: 0.0,
                          altitude: 0.0,
                          altitudeAccuracy: 0.0,
                          heading: 0.0,
                          headingAccuracy: 0.0,
                          speed: 0.0,
                          speedAccuracy: 0.0,
                          floor: null,
                          isMocked: false,
                        );
                      });
                    },
                  ),

                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80,
                          height: 80,
                          point: lat_lng.LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          child: const Icon(
                            Icons.location_pin,
                            size: 50,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitReport,
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo with Camera'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Choose from Gallery'),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Image.memory(
          _imageBytes!,
          height: 250,
          fit: BoxFit.cover,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _imageBytes = null),
          child: const Text('Remove Image'),
        ),
      ],
    );
  }
}
