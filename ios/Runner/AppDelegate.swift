import Flutter
import UIKit
import CoreLocation
import UserNotifications
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    var flutterChannel: FlutterMethodChannel?
    var xToken: String?
    var xMedsoftToken: String?
    // Declare counter variable

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Remove location manager setup from here
        // locationManager = CLLocationManager()
        // locationManager?.delegate = self
        // locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        // locationManager?.distanceFilter = 10
        // locationManager?.allowsBackgroundLocationUpdates = true
        // locationManager?.showsBackgroundLocationIndicator = true
        // locationManager?.requestWhenInUseAuthorization()

        // Create a Flutter Method Channel to communicate with Flutter code
        let controller = window?.rootViewController as! FlutterViewController
        flutterChannel = FlutterMethodChannel(name: "com.example.new_project_location/location", binaryMessenger: controller.binaryMessenger)

        flutterChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "getLastLocation" {
                self?.getLastLocation(result: result)
            } else if call.method == "sendLocationToAPIByButton" {
                self?.sendLocationToAPIByButton(result: result)
            } else if call.method == "startLocationManagerAfterLogin" {
                self?.startLocationManagerAfterLogin()  // Ensure this line is added
                 result(nil)  // You can send a response if needed
            } else if call.method == "sendXTokenToAppDelegate" {
                if let args = call.arguments as? [String: Any], let token = args["xToken"] as? String {
                    self?.xToken = token
                    print("Received xToken: \(self?.xToken ?? "No token")")
                }
                 result(nil) // Respond back to Flutter
            } else if call.method == "sendXMedsoftTokenToAppDelegate" {
                if let args = call.arguments as? [String: Any], let medsoftToken = args["xMedsoftToken"] as? String {
                    self?.xMedsoftToken = medsoftToken
                    print("Received xMedsoftToken: \(self?.xMedsoftToken ?? "No token")")
                }
                 result(nil)
            } else if call.method == "stopLocationUpdates" {
                self?.stopLocationUpdates()  // Stop location updates and background tasks
                 result(nil)  // Respond back to Flutter
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
                NSLog("Notification permission granted.")
            } else {
                NSLog("Notification permission denied.")
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

        // Check if always authorization is necessary, if so request it.
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            requestAlwaysLocationPermission()
        }

        // Schedule the background task to send location updates when the app is terminated
        scheduleBackgroundTask()
    }

    // Handle error or permission denied
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("Failed to find user's location: \(error.localizedDescription)")
    }

    @objc func sendLocationToAPIByButton(result: @escaping FlutterResult) {
        // Ensure locationManager is set up
        guard let location = locationManager?.location else {
            result(FlutterError(code: "LOCATION_ERROR", message: "Location not available", details: nil))
            return
        }

        // Call the existing method to send location to API
        sendLocationToAPI(location: location)
        NSLog("button sent success")
        // Optionally, return a success response if needed
        result(nil)
    }

    // CLLocationManagerDelegate method to handle authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            if status == .authorizedAlways {
                requestNotificationPermission()
            } else{
                showLocationPermissionDialog()
            }
        case .denied, .restricted:
            // Handle denied or restricted cases, e.g., show an alert
            NSLog("Location authorization denied or restricted.")
            manager.stopUpdatingLocation()
        case .notDetermined:
            // The user hasn't made a choice yet.
            break
        @unknown default:
            NSLog("Unknown location authorization status")
        }
    }

    func showLocationPermissionDialog() {
        let alertController = UIAlertController(
            title: "Location Permission Needed",
            message: "To provide accurate location updates, we need access to your location always. Would you like to open settings and grant access?",
            preferredStyle: .alert
        )

        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.alignment = .center
        containerView.spacing = 10

        if let image = UIImage(named: "location_permission_image") {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            containerView.addArrangedSubview(imageView)

            // Add constraints to the imageView
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 261).isActive = true // Adjust width
            imageView.heightAnchor.constraint(equalToConstant: 261).isActive = true // Adjust height
        }

        // let messageLabel = UILabel()
        // messageLabel.text = "To provide accurate location updates, we need access to your location always. Would you like to open settings and grant access?"
        // messageLabel.numberOfLines = 0
        // messageLabel.textAlignment = .center
        // messageLabel.font = UIFont.preferredFont(forTextStyle: .body)
        // messageLabel.textColor = .black
        // containerView.addArrangedSubview(messageLabel)

        alertController.view.addSubview(containerView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.topAnchor.constraint(equalTo: alertController.view.topAnchor, constant: 120).isActive = true
        containerView.leadingAnchor.constraint(equalTo: alertController.view.leadingAnchor, constant: 20).isActive = true
        containerView.trailingAnchor.constraint(equalTo: alertController.view.trailingAnchor, constant: -20).isActive = true
        containerView.bottomAnchor.constraint(equalTo: alertController.view.bottomAnchor, constant: -50).isActive = true

        let openSettingsAction = UIAlertAction(title: "Yes", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
                }
            }
        }
        alertController.addAction(openSettingsAction)

        let clearAndLoginAction = UIAlertAction(title: "No", style: .destructive) { _ in
            self.clearSharedPreferencesAndNavigateToLogin()
        }
        alertController.addAction(clearAndLoginAction)

        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(alertController, animated: true, completion: nil)
        }
    }

    // Function to request Always Authorization when needed
    func requestAlwaysLocationPermission() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager?.requestAlwaysAuthorization()
        }
    }

    // Function to send location to API
    private func sendLocationToAPI(location: CLLocation) {
        guard let token = xToken else {
            NSLog("Error: xToken not available")
            return
        }

        guard let medsoftToken = xMedsoftToken else {
            NSLog("Error: xMedsoftToken not available")
            return
        }


        // Prepare the URL and request
        guard let url = URL(string: "https://runner-api-v2.medsoft.care/api/gateway/location") else {
            NSLog("Invalid URL")
            return
        }


        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(token, forHTTPHeaderField: "X-Token")
        // request.addValue("gFRat7oK3STU47bWLCgbjj58rRvz0TcabW54H19mjF5Jv3ry7vzmhBxOVGRW8IhF", forHTTPHeaderField: "X-Token")
        request.addValue("ui.medsoft.care", forHTTPHeaderField: "X-Server")
        request.addValue(medsoftToken, forHTTPHeaderField: "X-Medsoft-Token")
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
                    NSLog("response.statusCode: \(response.statusCode)")
                    // If the status code is 401 or 403, clear SharedPreferences and navigate to LoginScreen
                    if response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 400 {
                        DispatchQueue.main.async {
                            self.clearSharedPreferencesAndNavigateToLogin()
                        }
                    } else {
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            NSLog("Error response: \(responseString)")
                        }
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

    // Start location manager after user logs in
    func startLocationManagerAfterLogin() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 10
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.showsBackgroundLocationIndicator = true
        locationManager?.requestWhenInUseAuthorization()
    }

    // Stop location updates and cancel background tasks
    func stopLocationUpdates() {
        // Stop location updates
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil  // Remove the delegate to avoid any further updates
        NSLog("Location updates stopped.")
        
        // Cancel background tasks
        stopBackgroundTasks()
    }

    func stopBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        NSLog("Background tasks canceled.")
    }
    
    private func clearSharedPreferencesAndNavigateToLogin() {
        NSLog("clearSharedPreferencesAndNavigateToLogin")
        // Send method to Flutter side to navigate to LoginScreen
        flutterChannel?.invokeMethod("navigateToLogin", arguments: nil)   
    }

}
