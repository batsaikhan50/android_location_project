import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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

  @override
  void initState() {
    super.initState();

    // Listen for updates from the native side
    platform.setMethodCallHandler(_methodCallHandler);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
