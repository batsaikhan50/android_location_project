import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_project_location/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart'; // Import login.dart file
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      // home: LoginScreen(),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          // While checking the login status, show a loading spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If an error occurs while checking the login status, show an error screen
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Error checking login status")),
            );
          }

          // If user is logged in, navigate to MyHomePage; otherwise, show LoginScreen
          // if (snapshot.data == true) {
          //   return const MyHomePage(title: 'Flutter Demo Home Page');
          // } else {
          //   return const LoginScreen();
          // }
        },
      ),
    );
  }

  // Method to check the login status from SharedPreferences
  Future<Widget> _getInitialScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    String? xServer = prefs.getString('X-Server');
    bool isGotToken = xServer != null && xServer.isNotEmpty;

    String? xMedsoftServer = prefs.getString('X-Medsoft-Server');
    bool isGotMedsoftToken =
        xMedsoftServer != null && xMedsoftServer.isNotEmpty;

    String? username = prefs.getString('Username');
    bool isGotUsername = username != null && username.isNotEmpty;

    // If logged in, and all required data is available, show the home page
    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      return const MyHomePage(title: 'Flutter Demo Home Page');
    } else {
      return const LoginScreen();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late String _displayText = '';
  String _liveLocation = "Fetching live location...";
  final List<String> _locationHistory = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  static const String xToken = Constants.xToken; // Your X-Token
  Map<String, String> sharedPreferencesData = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    // Listen for updates from the native side
    platform.setMethodCallHandler(_methodCallHandler);
    _sendXTokenToAppDelegate();
    _loadSharedPreferencesData();
    _getInitialScreenString();
  }

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

  // Initialize notifications
  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon'); // Add your app icon

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true, // Request permission for alerts
          requestBadgePermission: true, // Request permission for badges
          requestSoundPermission: true, // Request permission for sounds
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
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
    } else if (call.method == 'navigateToLogin') {
      _logOut();
      _showNotification();
    }
  }

  // Method to show notification
  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          channelDescription: 'Your channel description',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          badgeNumber: 1, // Set the badge count to 1, or any other number
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Logged Out',
      'You have been logged out, please log in again.',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> _sendLocationByButton() async {
    try {
      await platform.invokeMethod('sendLocationToAPIByButton');
    } on PlatformException catch (e) {
      print("Failed to send xToken to AppDelegate: '${e.message}'.");
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
    print("Entered _logOut");
    // Clear the shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn'); // Remove the login status key
    await prefs.remove('X-Server');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');

    // Stop location updates and cancel background tasks in AppDelegate
    try {
      await platform.invokeMethod(
        'stopLocationUpdates',
      ); // Request to stop location updates and cancel background tasks
    } on PlatformException catch (e) {
      print("Failed to stop location updates: '${e.message}'.");
    }

    // Navigate back to the login screen after logging out
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => LoginScreen(
              // flutterLocalNotificationsPlugin:
              //     FlutterLocalNotificationsPlugin(),
            ), // Navigate directly to LoginScreen
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
            ElevatedButton(
              onPressed:
                  _sendLocationByButton, // Add your method to handle button press
              child: Text('Send Location to API'),
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
