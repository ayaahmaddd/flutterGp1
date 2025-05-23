import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'signup.dart';
import 'forgetpass.dart';
import 'home.dart'; // for Provider
import 'my_companies_page.dart'; // for Company

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool rememberMe = false;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  final String _baseUrl = "http://localhost:3000/api/auth";

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final email = await _storage.read(key: 'remembered_email');
    final pass = await _storage.read(key: 'remembered_password');
    if (mounted && email != null && pass != null) {
      setState(() {
        loginEmailController.text = email;
        loginPasswordController.text = pass;
        rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = Uri.parse('$_baseUrl/login');
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      print('Response Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = body['token'];
        final userId = body['user_id'].toString();
        final userType = body['user_type'];

        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'user_type', value: userType);

        if (rememberMe) {
          await _storage.write(key: 'remembered_email', value: email);
          await _storage.write(key: 'remembered_password', value: password);
        } else {
          await _storage.delete(key: 'remembered_email');
          await _storage.delete(key: 'remembered_password');
        }

        _showMessage('Login successful!', isError: false);
        await Future.delayed(const Duration(milliseconds: 600));

        if (!mounted) return;

        if (userType == 'Company') {
          print("Navigating to Company page...");
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MyCompaniesPage()),
            (route) => false,
          );
        } else if (userType == 'Provider') {
          print("Navigating to Provider home page...");
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        } else {
          _showMessage('Unknown user type: $userType', isError: true);
        }
      } else {
        final msg = body['message'] ?? 'Login failed. Please check credentials.';
        _showMessage(msg, isError: true);
      }
    } on SocketException {
      _showMessage('No internet connection.', isError: true);
    } on TimeoutException {
      _showMessage('Request timeout.', isError: true);
    } catch (e) {
      _showMessage('An error occurred: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSocialIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 45,
      height: 45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22.5),
          child: Center(child: FaIcon(icon, color: color, size: 22)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputTheme = Theme.of(context).inputDecorationTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text('Welcome Back!', style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Log in to continue your journey with us.', textAlign: TextAlign.center),
                const SizedBox(height: 30),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: loginEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.alternate_email),
                          ).applyDefaults(inputTheme),
                          validator: (value) =>
                              (value == null || value.isEmpty) ? 'Please enter your email.' : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: loginPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ).applyDefaults(inputTheme),
                          validator: (value) =>
                              (value == null || value.isEmpty) ? 'Please enter your password.' : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: rememberMe,
                                  onChanged: (v) => setState(() => rememberMe = v!),
                                ),
                                const Text('Remember Me'),
                              ],
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                              child: const Text("Forgot Password?"),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LOGIN'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("Or continue with"),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialIconButton(FontAwesomeIcons.google, Colors.red, () {}),
                    const SizedBox(width: 25),
                    _buildSocialIconButton(FontAwesomeIcons.facebookF, Colors.blue, () {}),
                    const SizedBox(width: 25),
                    _buildSocialIconButton(FontAwesomeIcons.apple, Colors.black, () {}),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: const Text("Don't have an account? Sign Up Now"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
