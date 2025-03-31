import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:new_project_location/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // Import the home page
import 'package:flutter_app_badger/flutter_app_badger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // Modify constructor

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedRole = ''; // Empty by default (No selection)

  List<String> _serverNames = []; // List to hold server names
  Map<String, String> sharedPreferencesData = {};

  // Define the platform method channel here
  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  late String _displayText = '';
  Future<void> _getInitialScreenString() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    String? xServer = prefs.getString('X-Server');
    bool isGotToken = xServer != null && xServer.isNotEmpty;

    String? xMedsoftServer = prefs.getString('X-Medsoft-Token');
    bool isGotMedsoftToken =
        xMedsoftServer != null && xMedsoftServer.isNotEmpty;

    String? username = prefs.getString('Username');
    bool isGotUsername = username != null && username.isNotEmpty;

    _displayText =
        'isLoggedIn: $isLoggedIn, isGotToken: $isGotToken, isGotMedsoftToken: $isGotMedsoftToken, isGotUsername: $isGotUsername';

    // If logged in, and all required data is available, show the home page
    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      print(
        'isLoggedIn: $isLoggedIn, isGotToken: $isGotToken, isGotMedsoftToken: $isGotMedsoftToken, isGotUsername: $isGotUsername',
      );
    } else {
      return print("empty shared");
    }
  }

  // Fetch server data from API
  Future<void> _fetchServerData() async {
    const url = 'https://runner-api-v2.medsoft.care/api/gateway/servers';
    final headers = {'X-Token': Constants.xToken};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<String> serverNames = List<String>.from(
            data['data'].map((server) => server['name']),
          );

          setState(() {
            _serverNames = serverNames;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load servers.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error fetching server data.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Exception: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchServerData(); // Fetch server names when the screen is initialized
    _getInitialScreenString();
  }

  // Simulate the login process with POST request to the login API
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    // Check if a server has been selected
    if (_selectedRole.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a server';
        _isLoading = false;
      });
      return;
    }

    // Create the body for the login request
    final body = {
      'username': _usernameController.text,
      'password': _passwordController.text,
    };

    final headers = {
      'X-Token': Constants.xToken,
      'X-Server': _selectedRole, // Use the selected server from the dropdown
      'Content-Type': 'application/json',
    };

    // Print the request body and headers for debugging
    debugPrint('Request Headers: $headers');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse('https://runner-api-v2.medsoft.care/api/gateway/auth'),
        headers: headers,
        body: json.encode(body),
      );

      // Print the response body for debugging
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // Successful login, save the login status
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          final String token = data['data']['token'];

          // Save the selected server name in SharedPreferences
          await prefs.setString('X-Server', _selectedRole);
          await prefs.setString('X-Medsoft-Token', token);
          await prefs.setString('Username', _usernameController.text);

          // Print the values saved to SharedPreferences
          debugPrint('X-Server: ${prefs.getString('X-Server')}');
          debugPrint('X-Medsoft-Token: ${prefs.getString('X-Medsoft-Token')}');
          debugPrint('Username: ${prefs.getString('Username')}');

          await FlutterAppBadger.updateBadgeCount(0);

          // Trigger native code to start location manager after successful login
          await _sendXMedsoftTokenToAppDelegate(token);
          _loadSharedPreferencesData();

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
                  (context) =>
                      const MyHomePage(title: 'Flutter Demo Home Page'),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Login failed: ${data['message']}';
            _isLoading = false;
          });
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        setState(() {
          _errorMessage = 'Error logging in. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Exception: $e';
        _isLoading = false;
      });
    }
  }

  // Load SharedPreferences data and store it in sharedPreferencesData
  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> data = {};

    // Fetching all keys and values in SharedPreferences
    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      data[key] = prefs.getString(key) ?? 'null'; // Store key-value pairs
    }

    setState(() {
      sharedPreferencesData = data; // Update state with SharedPreferences data
    });
  }

  Future<void> _sendXMedsoftTokenToAppDelegate(String xMedsoftToken) async {
    try {
      // Sending the xToken to AppDelegate
      await platform.invokeMethod('sendXMedsoftTokenToAppDelegate', {
        'xMedsoftToken': xMedsoftToken,
      });
    } on PlatformException catch (e) {
      print("Failed to send xToken to AppDelegate: '${e.message}'.");
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
            // Display server dropdown if available
            if (_serverNames.isNotEmpty)
              DropdownButton<String>(
                value:
                    _selectedRole.isEmpty
                        ? null
                        : _selectedRole, // No value selected initially
                hint: Text('Select Server'),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                  });
                },
                items:
                    _serverNames.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
              ),
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

            const Divider(),
            // Display all SharedPreferences keys and values at the bottom
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _displayText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sharedPreferencesData.length,
                itemBuilder: (context, index) {
                  String key = sharedPreferencesData.keys.elementAt(index);
                  String value = sharedPreferencesData[key]!;
                  return ListTile(
                    title: Text(
                      '$key: $value',
                      style: TextStyle(
                        color: Colors.black,
                      ), // Make the text black
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
