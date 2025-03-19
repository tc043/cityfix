import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _emailShakeController;
  late AnimationController _passwordShakeController;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _emailShakeController = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _passwordShakeController = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _emailShakeController.dispose();
    _passwordShakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToTop() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = email.isEmpty || !email.contains('@') ? 'Enter a valid email' : null;
      _passwordError = password.isEmpty ? 'Password is required' : null;
    });

    if (_emailError != null || _passwordError != null) {
      _scrollToTop();
      if (_emailError != null) _emailShakeController.forward(from: 0);
      if (_passwordError != null) _passwordShakeController.forward(from: 0);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login successful!'),backgroundColor: Colors.green),
          );
          await Future.delayed(Duration(seconds: 2));
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _emailError = e.message;
      });
      _scrollToTop();
      _emailShakeController.forward(from: 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      _scrollToTop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildShakingField({required AnimationController controller, required Widget child}) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, childWidget) {
        final offset = 6.0 * (1 - controller.value);
        return Transform.translate(
          offset: Offset(offset * (controller.status == AnimationStatus.forward ? 1 : -1), 0),
          child: childWidget,
        );
      },
      child: child,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    String? errorText,
    Widget? suffixIcon,
    AnimationController? shakeController,
  }) {
    final field = AnimatedContainer(
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
    return shakeController != null ? _buildShakingField(controller: shakeController, child: field) : field;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          controller: _scrollController,
          children: [
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Login',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              label: 'Email',
              controller: _emailController,
              errorText: _emailError,
              shakeController: _emailShakeController,
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
              shakeController: _passwordShakeController,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
