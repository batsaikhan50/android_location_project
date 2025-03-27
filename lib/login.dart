import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Import the home page

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  // Define the platform method channel here
  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  // Simulate the login process
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate login process (you can replace this with your real authentication)
    await Future.delayed(const Duration(seconds: 2));

    // Assuming successful login if username and password are correct
    if (_usernameController.text == 'user' &&
        _passwordController.text == 'password') {
      // Save login status in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Trigger native code to start location manager after successful login
      try {
        // Invoke the method to start location manager
        await platform.invokeMethod('startLocationManagerAfterLogin');
      } on PlatformException catch (e) {
        print("Error starting location manager: $e");
      }

      // Navigate to the home page after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid credentials. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
