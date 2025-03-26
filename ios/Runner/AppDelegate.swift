import Flutter
import UIKit
import CoreLocation
import UserNotifications
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    var flutterChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Setup CLLocationManager for background location updates
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 2  // meters
        locationManager?.allowsBackgroundLocationUpdates = true  // Enable background updates
        locationManager?.showsBackgroundLocationIndicator = true

        // Request Always Authorization
        locationManager?.requestAlwaysAuthorization()

        // Request notification permissions
        requestNotificationPermission()

        // Check if location services are enabled and the authorization status
        if CLLocationManager.locationServicesEnabled() {
            let status = CLLocationManager.authorizationStatus()

            // Only start updating location if permission is granted
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager?.startUpdatingLocation()
            } else {
                // Handle case where permission is not granted (request again if necessary)
                locationManager?.requestAlwaysAuthorization()
            }
        }

        // Create a Flutter Method Channel to communicate with Flutter code
        let controller = window?.rootViewController as! FlutterViewController
        flutterChannel = FlutterMethodChannel(name: "com.example.new_project_location/location", binaryMessenger: controller.binaryMessenger)

        flutterChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "getLastLocation" {
                self?.getLastLocation(result: result)
            } else if call.method == "sendLocationToAPI" {
                if let args = call.arguments as? [String: Any],
                   let latitude = args["latitude"] as? Double,
                   let longitude = args["longitude"] as? Double {
                    let location = CLLocation(latitude: latitude, longitude: longitude)
                    self?.sendLocationToAPI(location: location)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.new_project_location.sendLocation", using: nil) { task in
            self.handleSendLocationTask(task: task)
        }

        // Schedule a background task for sending location updates when app is terminated
        scheduleBackgroundTask()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Request notification permission for background notifications
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    // Method to send the last location to Flutter
    private func getLastLocation(result: @escaping FlutterResult) {
        if let location = locationManager?.location {
            let locationData: [String: Double] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
            result(locationData)
        } else {
            result(FlutterError(code: "LOCATION_ERROR", message: "Location not available", details: nil))
        }
    }

    // CLLocationManager Delegate method to handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        NSLog("Background Location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)")

        // Prepare location data to send to Flutter
        let locationData: [String: Double] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]

        // API service call to send the location
        sendLocationToAPI(location: location)

        // Send location data to Flutter via method channel
        flutterChannel?.invokeMethod("updateLocation", arguments: locationData)

        // Schedule the background task to send location updates when the app is terminated
        scheduleBackgroundTask()
    }

    // Handle error or permission denied
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Failed to find user's location: \(error.localizedDescription)")
    }

    // CLLocationManagerDelegate method to handle authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    // Function to send location to API
    private func sendLocationToAPI(location: CLLocation) {
        // Prepare the URL and request
        guard let url = URL(string: "https://runner-api-v2.medsoft.care/api/gateway/location") else {
            NSLog("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("gFRat7oK3STU47bWLCgbjj58rRvz0TcabW54H19mjF5Jv3ry7vzmhBxOVGRW8IhF", forHTTPHeaderField: "X-Token")
        request.addValue("ui.medsoft.care", forHTTPHeaderField: "X-Server")
        request.addValue("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJiYXlhcmtodXUiLCJpYXQiOjE3NDI4NzUyNjIsImV4cCI6MTc0Mjk2MTY2Mn0.DGBClX_ynOTWV-Udt0aNBoB4-H8MLBPwYPnLJSJHpZ8", forHTTPHeaderField: "X-Medsoft-Token")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare the request body with location data
        let body: [String: Any] = [
            "lat": location.coordinate.latitude,
            "lng": location.coordinate.longitude
        ]

        // Convert the body dictionary to JSON data
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = jsonData
        } catch {
            NSLog("Error encoding JSON body: \(error)")
            return
        }

        // Send the POST request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                NSLog("Error making POST request: \(error)")
                return
            }

            // Check the response status code
            if let response = response as? HTTPURLResponse {
                NSLog("Response status code: \(response.statusCode)")

                if response.statusCode == 200 {
                    NSLog("Successfully sent location data.")
                } else {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        NSLog("Error response: \(responseString)")
                    }
                }
            }
        }
        task.resume()
    }

    // Method to schedule background task
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.example.new_project_location.sendLocation")
        request.requiresNetworkConnectivity = true  // Requires network connectivity
        request.requiresExternalPower = false  // Optionally specify external power requirement

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            NSLog("Failed to submit background task: \(error)")
        }
    }

    // Handle background task execution
    func handleSendLocationTask(task: BGTask) {
        // Check if the location is available and send to the API
        if let location = locationManager?.location {
            sendLocationToAPI(location: location)
        }

        // Mark the background task as completed
        task.setTaskCompleted(success: true)
    }
}
