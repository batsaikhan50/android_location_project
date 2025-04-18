import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:new_project_location/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_project_location/guide.dart';
import 'package:uni_links/uni_links.dart';

import 'login.dart';

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

      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Error checking login status")),
            );
          } else if (snapshot.hasData) {
            return snapshot.data!;
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }

  Future<Widget> _getInitialScreen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    String? xServer = prefs.getString('X-Server');
    bool isGotToken = xServer != null && xServer.isNotEmpty;

    String? xMedsoftServer = prefs.getString('X-Medsoft-Token');
    bool isGotMedsoftToken =
        xMedsoftServer != null && xMedsoftServer.isNotEmpty;

    String? username = prefs.getString('Username');
    bool isGotUsername = username != null && username.isNotEmpty;

    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      return const MyHomePage(title: 'Байршил тогтоогч');
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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late String _displayText = '';
  String _liveLocation = "Fetching live location...";
  final List<String> _locationHistory = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? username;

  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  static const String xToken = Constants.xToken;
  Map<String, dynamic> sharedPreferencesData = {};

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isLocationSent = false;

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
    _initializeNotifications();

    platform.setMethodCallHandler(_methodCallHandler);
    _sendXTokenToAppDelegate();
    _loadSharedPreferencesData();
    _sendXMedsoftTokenToAppDelegate();
    _sendXServerToAppDelegate();
    _startLocationTracking();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _handleIncomingLinks() async {
    try {
      // Listen for incoming links
      uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          debugPrint('Received link: $uri');

          if (uri.scheme == 'medsofttrack' && uri.host == 'callback') {
            // Example: myapp://callback?success=true
            final success = uri.queryParameters['success'];
            if (success == 'true') {
              // Handle successful callback (e.g., close WebView, show toast, etc.)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Амжилттай баталгаажлаа!')),
              );
            }
          }
        }
      });
    } on Exception catch (e) {
      debugPrint('Failed to handle link: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      await platform.invokeMethod('startLocationManagerAfterLogin');
    } on PlatformException catch (e) {
      debugPrint("Error starting location manager: $e");
    }
  }

  Future<void> _sendXServerToAppDelegate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      await platform.invokeMethod('sendXServerToAppDelegate', {
        'xServer': prefs.getString('X-Server'),
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to send xToken to AppDelegate: '${e.message}'.");
    }
  }

  Future<void> _sendXMedsoftTokenToAppDelegate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      await platform.invokeMethod('sendXMedsoftTokenToAppDelegate', {
        'xMedsoftToken': prefs.getString('X-Medsoft-Token'),
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to send xToken to AppDelegate: '${e.message}'.");
    }
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

    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      debugPrint(
        'isLoggedIn: $isLoggedIn, isGotToken: $isGotToken, isGotMedsoftToken: $isGotMedsoftToken, isGotUsername: $isGotUsername',
      );
    } else {
      return debugPrint("empty shared");
    }
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key == 'isLoggedIn') {
        data[key] = prefs.getBool(key);
      } else {
        data[key] = prefs.getString(key) ?? 'null';
      }
    }

    setState(() {
      username = prefs.getString('Username');
      sharedPreferencesData = data;
    });
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
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

      setState(() {
        _liveLocation =
            "Сүүлд илгээсэн байршил\nУртраг: $longitude\nӨргөрөг: $latitude";
        _addLocationToHistory(latitude, longitude);
      });
    } else if (call.method == 'navigateToLogin') {
      _logOut();
      _showNotification();
    }
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          channelDescription: 'Your channel description',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
          channelShowBadge: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(badgeNumber: 1);

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Системээс гарсан байна.',
      'Ахин нэвтэрнэ үү.',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> _sendLocationByButton() async {
    try {
      await platform.invokeMethod('sendLocationToAPIByButton');

      setState(() {
        _isLocationSent = true;
      });

      _animationController.forward();

      await Future.delayed(Duration(seconds: 2));

      setState(() {
        _isLocationSent = false;
      });
      _animationController.reverse();
    } on PlatformException catch (e) {
      debugPrint("Failed to send xToken to AppDelegate: '${e.message}'.");
    }
  }

  Future<void> _sendXTokenToAppDelegate() async {
    try {
      await platform.invokeMethod('sendXTokenToAppDelegate', {
        'xToken': xToken,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to send xToken to AppDelegate: '${e.message}'.");
    }
  }

  void _addLocationToHistory(double latitude, double longitude) {
    String newLocation = "Уртраг: $longitude\nӨргөрөг: $latitude";

    if (_locationHistory.length >= 9) {
      _locationHistory.removeAt(0);
    }

    setState(() {
      _locationHistory.add(newLocation);
    });
  }

  void _logOut() async {
    debugPrint("Entered _logOut");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('X-Server');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');

    try {
      await platform.invokeMethod('stopLocationUpdates');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop location updates: '${e.message}'.");
    }

    Navigator.pushReplacement(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF00CCCC),
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 236, 169, 175),
              ),
              child: Center(
                child: Image.asset(
                  'assets/icon/locationlogo.png',
                  width: 150,
                  height: 150,
                ),
              ),
            ),
            ListTile(
              title: Center(
                child: Text(
                  username ?? 'Guest',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.blueAccent),
              title: Text('Хэрэглэх заавар', style: TextStyle(fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GuideScreen()),
                );
              },
            ),
            Divider(),

            Spacer(),
            Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 217, 83, 96),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                title: Center(
                  child: const Text(
                    'Гарах',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  _logOut();
                },
              ),
            ),
            SizedBox(height: 50),
          ],
        ),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _liveLocation,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Байршлын түүх:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                bool isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;

                double width =
                    isLandscape
                        ? MediaQuery.of(context).size.width * 0.33
                        : MediaQuery.of(context).size.width;

                return Center(
                  child: Container(
                    width: width,
                    height: 200,
                    child: ListView.builder(
                      itemCount: _locationHistory.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Text(
                            _locationHistory[index],
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 50),

            AnimatedOpacity(
              opacity: _isLocationSent ? 1.0 : 0.0,
              duration: Duration(milliseconds: 500),
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Амжилттай',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: _sendLocationByButton,
                style: ElevatedButton.styleFrom(minimumSize: Size(200, 60)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me, size: 24, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Байршил илгээх', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),

            SizedBox(height: 170),
          ],
        ),
      ),
    );
  }
}
