import 'dart:typed_data';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_lng;

// For mobile compression
import 'package:flutter_image_compress/flutter_image_compress.dart';

// For web compression (pure Dart)
import 'package:image/image.dart' as img;

// Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({Key? key}) : super(key: key);

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  /// We'll store the final compressed image data here (both mobile & web).
  Uint8List? _imageBytes;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// Picks an image from camera or gallery, then compresses:
  /// - On web, use the image package
  /// - On mobile, use flutter_image_compress
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) {
        debugPrint('No file picked (user may have cancelled).');
        return;
      }

      debugPrint('Picked file: ${pickedFile.path}');
      if (kIsWeb) {
        // *** WEB ***: read raw bytes, then compress with the 'image' package
        debugPrint('Platform is WEB; using "image" package for compression.');
        final rawBytes = await pickedFile.readAsBytes();

        // Decode to an in-memory image
        final decodedImage = img.decodeImage(rawBytes);
        if (decodedImage == null) {
          debugPrint('Failed to decode web image');
          return;
        }

        // Optionally resize (e.g., width=800)
        final resized = img.copyResize(decodedImage, width: 800);
        // Re-encode as JPEG with 70% quality
        final compressedBytes = img.encodeJpg(resized, quality: 70);

        setState(() {
          _imageBytes = Uint8List.fromList(compressedBytes);
        });
        debugPrint('Web image compressed. Final bytes length: ${_imageBytes!.length}');
      } else {
        // *** MOBILE ***: we have a File, compress with flutter_image_compress
        debugPrint('Platform is MOBILE; using flutter_image_compress.');
        final file = File(pickedFile.path);
        final fileBytes = await file.readAsBytes();

        final compressed = await FlutterImageCompress.compressWithList(
          fileBytes,
          quality: 70,
        );
        setState(() {
          _imageBytes = compressed;
        });
        debugPrint('Mobile image compressed. Final bytes length: ${_imageBytes!.length}');
      }
    } catch (e) {
      debugPrint('Error picking/compressing image: $e');
      _showError('Error picking or compressing image: $e');
    }
  }

  /// Get the current device location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final permAfterReq = await Geolocator.requestPermission();
      debugPrint('Permission after request: $permAfterReq');
      if (permAfterReq == LocationPermission.denied) {
        debugPrint('Location permissions denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions permanently denied.');
      return;
    }

    // If we reach here, location is presumably granted
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
    });
    debugPrint('Got location: $_currentPosition');
  }

  /// Show error in a SnackBar
  void _showError(String msg) {
    debugPrint('ERROR: $msg');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Submits the report to Supabase (Storage + Database)
  Future<void> _submitReport() async {
    // Validate description
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Please enter a description.');
      return;
    }

    // Validate location
    if (_currentPosition == null) {
      _showError('Location not available.');
      return;
    }

    // Get Supabase client instance
    final supabase = Supabase.instance.client;

    String? imageUrl;
    if (_imageBytes != null) {
      // Generate a unique file name for the image
      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        // Upload the image bytes to Supabase Storage.
        // Ensure a bucket named 'reports' exists in your Supabase project.
        await supabase.storage.from('reports').uploadBinary(fileName, _imageBytes!);
        // Get the public URL for the uploaded image.
        imageUrl = supabase.storage.from('reports').getPublicUrl(fileName);
      } catch (error) {
        _showError('Image upload failed: $error');
        return;
      }
    }

    // Prepare the report data to be inserted into the 'reports' table.
    final Map<String, dynamic> reportData = {
      'description': _descriptionController.text.trim(),
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final response = await supabase.from('reports').insert(reportData);
      if (response?.error != null) {
        _showError('Report submission failed: ${response.error!.message}');
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully!')),
      );
      // Clear the form
      setState(() {
        _imageBytes = null;
        _descriptionController.clear();
      });
      // Check if the widget is still mounted before navigating
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      _showError('Report submission failed: $error');
    }

  }

  /// True if image is selected
  bool get _hasImage => _imageBytes != null;

  @override
  Widget build(BuildContext context) {
    final bool locationReady = _currentPosition != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // BOX with either 2 buttons or image preview
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

            // Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Map or spinner
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
              Text(
                'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}',
              ),
            ],
            const SizedBox(height: 20),

            // Submit button
            ElevatedButton(
              onPressed: _submitReport,
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows 2 buttons if no image is selected
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

  /// Shows image preview and a remove button
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
          onPressed: () {
            debugPrint('Remove image pressed');
            setState(() {
              _imageBytes = null;
            });
          },
          child: const Text('Remove Image'),
        ),
      ],
    );
  }
}
