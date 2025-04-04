package com.example.new_project_location

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.work.*
import com.google.android.gms.location.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.new_project_location/location"
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    // private lateinit var locationRequest: LocationRequest
    private var xToken: String? = null
    private var xServer: String? = null
    private var xMedsoftToken: String? = null
    private lateinit var sharedPreferences: SharedPreferences
    private var lastLocation: Location? = null // Store the last sent location
    private val distanceThreshold = 1f // Distance threshold in meters (100 meters for example)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        sharedPreferences = getSharedPreferences("AppPrefs", Context.MODE_PRIVATE)

        xToken = sharedPreferences.getString("xToken", null)
        xToken = sharedPreferences.getString("xServer", null)
        xMedsoftToken = sharedPreferences.getString("xMedsoftToken", null)

        requestLocationPermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "getLastLocation" -> getLastLocation(result)
                "sendLocationToAPIByButton" -> sendLocationToAPIByButton(result)
                "startLocationManagerAfterLogin" -> {
                    startLocationUpdates()
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

    private fun requestLocationPermissions() {
        ActivityCompat.requestPermissions(
                this,
                arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.POST_NOTIFICATIONS
                ),
                1
        )
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
                ) // Return location
            } else {
                result.error("LOCATION_ERROR", "Location not available", null)
            }
        }
    }

    private fun sendLocationToAPIIfMoved(location: Location) {
        // Check if last location is null or if the device has moved the required threshold distance
        if (lastLocation == null || location.distanceTo(lastLocation!!) >= distanceThreshold) {
            sendLocationToAPI(location) // Send location to API
            lastLocation = location // Update last location
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
                            sendLocationToAPIIfMoved(location) // Send location based on distance

                            // Send location update to Flutter
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
        cancelBackgroundWorker()
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
                        RequestBody.create(
                                "application/json".toMediaTypeOrNull(),
                                jsonBody.toString()
                        )

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

    private fun scheduleBackgroundWorker() {
        val constraints =
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

        val workRequest =
                PeriodicWorkRequestBuilder<LocationWorker>(15, TimeUnit.MINUTES)
                        .setConstraints(constraints)
                        .build()

        WorkManager.getInstance(applicationContext)
                .enqueueUniquePeriodicWork(
                        "sendLocationWork",
                        ExistingPeriodicWorkPolicy.REPLACE,
                        workRequest
                )
    }

    private fun cancelBackgroundWorker() {
        WorkManager.getInstance(applicationContext).cancelUniqueWork("sendLocationWork")
    }
}
