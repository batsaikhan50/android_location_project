import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

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
  int _counter = 0;
  String _location = "Fetching location...";
  late StreamSubscription<Position> _positionStream;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  // Request permission for location: first ask for "When in use" and then for "Always"
  Future<void> _requestPermission() async {
    // First, ask for "When in use" permission
    PermissionStatus whenInUsePermission =
        await Permission.locationWhenInUse.request();

    if (whenInUsePermission.isGranted) {
      // If "When in use" permission is granted, ask for "Always" permission
      PermissionStatus alwaysPermission =
          await Permission.locationAlways.request();

      if (alwaysPermission.isGranted) {
        // If "Always" permission is granted, start tracking location
        _startLocationTracking();
      } else {
        // If "Always" permission is denied, show an alert or handle accordingly
        setState(() {
          _location = "Location 'Always' permission denied.";
        });
      }
    } else {
      // If "When in use" permission is denied, show an alert or handle accordingly
      setState(() {
        _location = "Location 'When in use' permission denied.";
      });
    }
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _location = "Location services are disabled.";
      });
      return;
    }

    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
      timeLimit: Duration(minutes: 10),
    );

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        timeLimit: Duration(days: 30),
        showBackgroundLocationIndicator: true, // This is the key for iOS
        allowBackgroundLocationUpdates: true,
      );
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        forceLocationManager: true,
        intervalDuration: const Duration(milliseconds: 1000),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "Example app is tracking your location in background",
          notificationTitle: "Background tracking",
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'drawable',
          ),
        ),
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _location =
            "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
      });
      debugPrint(
        "Latitude: ${position.latitude}, Longitude: ${position.longitude}",
      );
    });

    // Background permission is handled by the LocationSettings and platform settings
    // No need for platform-specific methods like isBackgroundLocationPermitted() or setAllowsBackgroundLocationUpdates()
  }

  // Stop location tracking
  void _stopLocationTracking() {
    _positionStream.cancel();
    setState(() {
      _location = "Location tracking stopped.";
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void dispose() {
    // Cancel location tracking when the widget is disposed
    _stopLocationTracking();
    super.dispose();
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
            Text(
              'Current Location: $_location',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _incrementCounter();
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
