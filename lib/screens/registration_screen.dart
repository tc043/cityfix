import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _statusMessage;
  Color _statusColor = Colors.green;

  Future<void> _pickProfileImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source);
    if (file == null) return;

    Uint8List rawBytes;
    if (kIsWeb) {
      rawBytes = await file.readAsBytes();
    } else {
      rawBytes = await File(file.path).readAsBytes();
    }

    final compressedBytes = await FlutterImageCompress.compressWithList(
      rawBytes,
      quality: 70,
    );

    setState(() {
      _imageBytes = compressedBytes;
    });
  }

  Future<void> _scrollToTop() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final fullName = _nameController.text.trim();

    setState(() {
      _nameError = fullName.isEmpty ? 'Please enter your full name' : null;
      _emailError = email.isEmpty || !email.contains('@') ? 'Enter a valid email' : null;
      _passwordError = password.length < 6 ? 'Password must be at least 6 characters' : null;
      _confirmPasswordError = confirmPassword != password ? 'Passwords do not match' : null;
      _statusMessage = null;
    });

    if (_nameError != null || _emailError != null || _passwordError != null || _confirmPasswordError != null) {
      _scrollToTop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        String avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(fullName)}';

        if (_imageBytes != null) {
          final fileName = 'avatars/${user.uid}/profile.jpg';
          final ref = FirebaseStorage.instance.ref().child(fileName);
          await ref.putData(_imageBytes!);
          avatarUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
          'full_name': fullName,
          'email': email,
          'avatar_url': avatarUrl,
          'joined_at': DateTime.now().toIso8601String(),
        });

        setState(() {
          _statusMessage = 'Registration successful! Redirecting...';
          _statusColor = Colors.green;
        });

        await Future.delayed(Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _emailError = e.message;
        _statusMessage = 'Registration failed';
        _statusColor = Colors.red;
      });
      _scrollToTop();
    } catch (e) {
      setState(() {
        _emailError = 'Unexpected error: $e';
        _statusMessage = 'Something went wrong';
        _statusColor = Colors.red;
      });
      _scrollToTop();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Register')),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(16.0),
        child: ListView(
          controller: _scrollController,
          children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _imageBytes != null
                  ? CircleAvatar(
                key: ValueKey('image'),
                radius: 50,
                backgroundImage: MemoryImage(_imageBytes!),
              )
                  : const CircleAvatar(
                key: ValueKey('placeholder'),
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _pickProfileImage(ImageSource.gallery),
                  child: const Text("Pick from Gallery"),
                ),
                TextButton(
                  onPressed: () => _pickProfileImage(ImageSource.camera),
                  child: const Text("Take a Photo"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Full Name',
              controller: _nameController,
              errorText: _nameError,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Email',
              controller: _emailController,
              errorText: _emailError,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Password',
              controller: _passwordController,
              obscure: _obscurePassword,
              errorText: _passwordError,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Confirm Password',
              controller: _confirmPasswordController,
              obscure: true,
              errorText: _confirmPasswordError,
            ),
            const SizedBox(height: 24),
            if (_statusMessage != null)
              AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: 1.0,
                child: Text(
                  _statusMessage!,
                  style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _register,
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
