package com.example.new_project_location

import android.Manifest
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.work.*
import com.google.android.gms.location.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.new_project_location/location"
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    private var xToken: String? = null
    private var xServer: String? = null
    private var xMedsoftToken: String? = null
    private lateinit var sharedPreferences: SharedPreferences
    private var lastLocation: Location? = null
    private val distanceThreshold = 10f
    public lateinit var methodChannel: MethodChannel
    private var isBackgroundPermissionDialogShown = false
    private var shouldRetryStartLocationManager = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        sharedPreferences = getSharedPreferences("AppPrefs", Context.MODE_PRIVATE)

        xToken = sharedPreferences.getString("xToken", null)
        xToken = sharedPreferences.getString("xServer", null)
        xMedsoftToken = sharedPreferences.getString("xMedsoftToken", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        MethodChannelManager.methodChannel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLastLocation" -> getLastLocation(result)
                "sendLocationToAPIByButton" -> sendLocationToAPIByButton(result)
                "startLocationManagerAfterLogin" -> {
                    if (!hasWhileInUsePermission()) {
                        Log.d("PermissionFlow", "Requesting While in Use permission...")
                        requestLocationPermissions()
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    if (!isBackgroundLocationGranted()) {
                        Log.d(
                                "PermissionFlow",
                                "While in Use granted. Requesting Always permission..."
                        )
                        if (!isBackgroundPermissionDialogShown) {
                            showBackgroundPermissionDialog()
                        }
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    startForegroundLocationService()
                    result.success(null)
                }
                "sendXTokenToAppDelegate" -> {
                    val token = call.argument<String>("xToken")
                    xToken = token
                    sharedPreferences.edit().putString("xToken", token).apply()
                    Log.d("MainActivity", "Received xToken: $xToken")
                    result.success(null)
                }
                "sendXServerToAppDelegate" -> {
                    val hospital = call.argument<String>("xServer")
                    xServer = hospital
                    sharedPreferences.edit().putString("xServer", hospital).apply()
                    Log.d("MainActivity", "Received xServer: $xServer")
                    result.success(null)
                }
                "sendXMedsoftTokenToAppDelegate" -> {
                    val medsoftToken = call.argument<String>("xMedsoftToken")
                    xMedsoftToken = medsoftToken
                    sharedPreferences.edit().putString("xMedsoftToken", medsoftToken).apply()
                    Log.d("MainActivity", "Received xMedsoftToken: $xMedsoftToken")
                    result.success(null)
                }
                "stopLocationUpdates" -> {
                    stopLocationUpdates()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun isBackgroundLocationGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun showBackgroundPermissionDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_background_permission, null)

        val dialog =
                AlertDialog.Builder(this)
                        .setView(dialogView)
                        .setCancelable(false)
                        .setPositiveButton("Yes") { dialogInterface: DialogInterface, _: Int ->
                            shouldRetryStartLocationManager = true
                            openAppSettings()
                            dialogInterface.dismiss()
                        }
                        .setNegativeButton("No") { dialogInterface: DialogInterface, _: Int ->
                            dialogInterface.dismiss()
                            isBackgroundPermissionDialogShown = false
                            Log.d(
                                    "Permission",
                                    "User denied background permission. Try again later."
                            )
                        }
                        .create()

        dialog.show()
        isBackgroundPermissionDialogShown = true
    }

    private fun openAppSettings() {
        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = android.net.Uri.fromParts("package", packageName, null)
        startActivity(intent)
    }

    override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<out String>,
            grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == 1) {
            // val allGranted =
            //         grantResults.isNotEmpty() &&
            //                 grantResults.all {
            //                     it == android.content.pm.PackageManager.PERMISSION_GRANTED
            //                 }

            if (!hasWhileInUsePermission()) {
                Log.d("Permission", "While in use not granted. Prompting again...")
            } else {
                Log.d("Permission", "While in use granted.")

                if (!isBackgroundLocationGranted() && !isBackgroundPermissionDialogShown) {
                    showBackgroundPermissionDialog()
                    isBackgroundPermissionDialogShown = true
                }
            }
        }
    }

    private fun isNotificationPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun showNotificationPermissionDialog() {
        AlertDialog.Builder(this)
                .setTitle("Enable Notifications")
                .setMessage("This app requires notification permission to function properly.")
                .setCancelable(false)
                .setPositiveButton("Enable") { dialog, _ ->
                    openAppSettings()
                    dialog.dismiss()
                }
                .setNegativeButton("Exit App") { dialog, _ ->
                    dialog.dismiss()
                    finishAffinity()
                }
                .show()
    }

    private fun hasLocationPermissions(): Boolean {
        val fine =
                ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse =
                ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == android.content.pm.PackageManager.PERMISSION_GRANTED &&
                coarse == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    override fun onResume() {
        super.onResume()

        if (!isNotificationPermissionGranted()) {
            showNotificationPermissionDialog()
            return
        }

        if (hasWhileInUsePermission() && isBackgroundLocationGranted()) {
            if (shouldRetryStartLocationManager) {
                shouldRetryStartLocationManager = false
                startForegroundLocationService()
            }
        } else if (!hasWhileInUsePermission()) {
            requestLocationPermissions()
        } else if (!isBackgroundLocationGranted() && !isBackgroundPermissionDialogShown) {
            showBackgroundPermissionDialog()
        }
    }

    private fun hasWhileInUsePermission(): Boolean {
        val fine =
                ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse =
                ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == android.content.pm.PackageManager.PERMISSION_GRANTED ||
                coarse == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun requestLocationPermissions() {
        val permissions =
                mutableListOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.POST_NOTIFICATIONS
                )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            permissions.add(Manifest.permission.FOREGROUND_SERVICE_LOCATION)
        }

        ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 1)
    }

    private fun getLastLocation(result: MethodChannel.Result) {
        fusedLocationClient.lastLocation.addOnSuccessListener { location: Location? ->
            if (location != null) {
                lastLocation = location
                Log.d(
                        "MainActivity",
                        "Initial location: ${location.latitude}, ${location.longitude}"
                )
                result.success(
                        mapOf("latitude" to location.latitude, "longitude" to location.longitude)
                )
            } else {
                result.error("LOCATION_ERROR", "Location not available", null)
            }
        }
    }

    private fun sendLocationToAPIIfMoved(location: Location) {
        if (lastLocation == null || location.distanceTo(lastLocation!!) >= distanceThreshold) {
            sendLocationToAPI(location)
            lastLocation = location
            Log.d("MainActivity", "Location sent: ${location.latitude}, ${location.longitude}")
        } else {
            Log.d("MainActivity", "Device has not moved enough to send location")
        }
    }

    private fun sendLocationToAPIByButton(result: MethodChannel.Result) {
        fusedLocationClient.lastLocation.addOnSuccessListener { location: Location? ->
            if (location != null) {
                sendLocationToAPI(location)
                Log.d("MainActivity", "Button sent location successfully")
                result.success(null)
            } else {
                result.error("LOCATION_ERROR", "Location not available", null)
            }
        }
    }

    private fun startLocationUpdates() {
        val locationRequest =
                LocationRequest.Builder(5000L).setPriority(Priority.PRIORITY_HIGH_ACCURACY).build()

        val locationCallback =
                object : LocationCallback() {
                    override fun onLocationResult(locationResult: LocationResult) {
                        val location = locationResult.lastLocation
                        if (location != null) {
                            sendLocationToAPIIfMoved(location)

                            val locationData =
                                    mapOf(
                                            "latitude" to location.latitude,
                                            "longitude" to location.longitude
                                    )
                            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                                    .invokeMethod("updateLocation", locationData)
                        }
                    }
                }

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
    }

    private fun stopLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(object : LocationCallback() {})

        Log.d("MainActivity", "Location updates stopped")
    }

    fun sendLocationToAPI(location: Location) {
        if (xToken.isNullOrEmpty() || xMedsoftToken.isNullOrEmpty()) {
            Log.e("MainActivity", "Tokens not available")
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = "https://runner-api-v2.medsoft.care/api/gateway/location"
                val jsonBody = JSONObject()
                jsonBody.put("lat", location.latitude)
                jsonBody.put("lng", location.longitude)

                val requestBody =
                        jsonBody.toString().toRequestBody("application/json".toMediaTypeOrNull())

                val request =
                        Request.Builder()
                                .url(url)
                                .addHeader("X-Token", xToken!!)
                                .addHeader("X-Server", xServer!!)
                                .addHeader("X-Medsoft-Token", xMedsoftToken!!)
                                .addHeader("Content-Type", "application/json")
                                .post(requestBody)
                                .build()

                val client = OkHttpClient()
                val response = client.newCall(request).execute()

                if (!response.isSuccessful) {
                    Log.e("MainActivity", "Failed to send location: ${response.code}")
                    if (response.code == 401 || response.code == 403 || response.code == 400) {
                        withContext(Dispatchers.Main) { navigateToLogin() }
                    }
                } else {
                    Log.d("MainActivity", "Successfully sent location")
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Error sending location: ${e.message}")
            }
        }
    }

    private fun navigateToLogin() {
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("navigateToLogin", null)
    }

    private fun startForegroundLocationService() {
        Log.d(
                "startForegroundLocationService",
                "---CALLED------------------------------------------------CALLED"
        )
        val serviceIntent = Intent(this, LocationForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}
