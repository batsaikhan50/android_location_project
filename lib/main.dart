import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart'; // Import login.dart file

void main() {
  runApp(
    const MyApp(),
  ); // Ensure the 'main' method is defined and starts the app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginScreen(), // This should refer to your LoginScreen widget
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _liveLocation = "Fetching live location...";
  final List<String> _locationHistory = [];

  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  static const String xToken =
      'gFRat7oK3STU47bWLCgbjj58rRvz0TcabW54H19mjF5Jv3ry7vzmhBxOVGRW8IhF'; // Your X-Token

  @override
  void initState() {
    super.initState();
    // Listen for updates from the native side
    platform.setMethodCallHandler(_methodCallHandler);
    _sendXTokenToAppDelegate();
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    if (call.method == 'updateLocation') {
      final locationData = call.arguments as Map;
      final latitude = locationData['latitude'];
      final longitude = locationData['longitude'];

      // Update the live location text
      setState(() {
        _liveLocation =
            "Live Location - Latitude: $latitude, Longitude: $longitude";
        _addLocationToHistory(latitude, longitude);
      });
    }
  }

  Future<void> _sendXTokenToAppDelegate() async {
    try {
      // Sending the xToken to AppDelegate
      await platform.invokeMethod('sendXTokenToAppDelegate', {
        'xToken': xToken,
      });
    } on PlatformException catch (e) {
      print("Failed to send xToken to AppDelegate: '${e.message}'.");
    }
  }

  // Add the new location to the history (keep the last 9 locations)
  void _addLocationToHistory(double latitude, double longitude) {
    String newLocation = "Lat: $latitude, Lon: $longitude";

    // Ensure we only keep the last 9 locations
    if (_locationHistory.length >= 9) {
      _locationHistory.removeAt(0); // Remove the oldest
    }

    setState(() {
      _locationHistory.add(newLocation);
    });
  }

  // Log out method
  void _logOut() async {
    // Clear the shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn'); // Remove the login status key

    // Navigate back to the login screen after logging out
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                const LoginScreen(), // Navigate directly to LoginScreen
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text(
                'Welcome',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            // Display username in the drawer
            ListTile(title: Text('Username: to-do')),
            const Divider(), // Divider for clarity
            ListTile(
              title: const Text('Log Out'),
              onTap: () {
                _logOut(); // Call the logOut function
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Display live location
            Text(
              _liveLocation,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            // Display a list of background locations
            Text(
              'Background Location History:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _locationHistory.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(_locationHistory[index]));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
