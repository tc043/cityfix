import 'dart:io'; // Import for File

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Import for image_picker
import 'package:firebase_storage/firebase_storage.dart'; // Import for Firebase Storage

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance; // Firebase Storage instance

  String _fullName = '';
  String _avatarUrl = '';
  File? _pickedImage; // To store the selected image file
  bool _isLoading = true;
  bool _isSaving = false; // To indicate if the profile is being saved

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('profiles').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _fullName = data['full_name'] ?? '';
          _avatarUrl = data['avatar_url'] ?? '';
        });
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedImageFile = await picker.pickImage(source: source, imageQuality: 50); // imageQuality reduces file size

    if (pickedImageFile != null) {
      setState(() {
        _pickedImage = File(pickedImageFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      String? newAvatarUrl = _avatarUrl; // Start with the existing URL

      // Upload the new image if one was picked
      if (_pickedImage != null) {
        final ref = _storage
            .ref()
            .child('avatars/${user.uid}/profile.jpg'); // Use user UID for unique filename

        await ref.putFile(_pickedImage!);
        newAvatarUrl = await ref.getDownloadURL(); // Get the download URL of the uploaded image
      }

      await _firestore.collection('profiles').doc(user.uid).set({
        'full_name': _fullName,
        'avatar_url': newAvatarUrl, // Use the new or existing avatar URL
        'email': user.email,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
    }

    setState(() {
      _isSaving = false;
    });
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Gallery'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Use ListView to avoid overflow with keyboard
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImagePicker,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider // Use FileImage for picked image
                        : _avatarUrl.isNotEmpty
                        ? NetworkImage(_avatarUrl) as ImageProvider // Use NetworkImage for existing URL
                        : null, // No image if neither picked nor existing
                    child: _pickedImage == null && _avatarUrl.isEmpty
                        ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _fullName,
                decoration: const InputDecoration(labelText: 'Full Name'),
                onSaved: (value) => _fullName = value?.trim() ?? '',
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile, // Disable button while saving
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white) // Show progress indicator while saving
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}