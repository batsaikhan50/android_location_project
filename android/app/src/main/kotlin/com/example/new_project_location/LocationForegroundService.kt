package com.example.new_project_location
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import org.json.JSONObject
import io.flutter.plugin.common.MethodChannel

import io.flutter.embedding.engine.FlutterEngine

class LocationForegroundService : Service() {
    private var methodChannel: MethodChannel? = null

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var sharedPreferences: SharedPreferences
    private var lastLocation: Location? = null
    private val distanceThreshold = 1f

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        sharedPreferences = getSharedPreferences("AppPrefs", Context.MODE_PRIVATE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, createNotification("Байршил дамжуулж байна..."))
        startLocationUpdates()
        return START_STICKY
    }

    private fun createNotification(content: String): Notification {
        val channelId = "location_channel"
        val channelName = "Location Tracking"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
            chan.setShowBadge(false)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(chan)
        }
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Medsoft track")
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setNumber(0)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .build()
    }

    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.Builder(5000L)
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .build()

        val locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                val location = locationResult.lastLocation
                if (location != null && (lastLocation == null || location.distanceTo(lastLocation!!) > distanceThreshold)) {
                    lastLocation = location
                    sendLocationToAPI(location)
                    sendLocationToFlutter(location)
                }
            }
        }



        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
    }

    // private fun sendLocationToFlutter(location: Location) {
    //     // This would send the location back to Flutter, assuming we can get the channel from the MainActivity
    //     val channel = (applicationContext as MainActivity).methodChannel // Access MainActivity's channel
    //     channel.invokeMethod("updateLocation", mapOf("latitude" to location.latitude, "longitude" to location.longitude))
    // }
    private fun sendLocationToFlutter(location: Location) {
        val channel = MethodChannelManager.methodChannel
        channel?.invokeMethod("updateLocation", mapOf("latitude" to location.latitude, "longitude" to location.longitude))
    }
    private fun sendLocationToAPI(location: Location) {
        val xToken = sharedPreferences.getString("xToken", null)
        val xServer = sharedPreferences.getString("xServer", null)
        val xMedsoftToken = sharedPreferences.getString("xMedsoftToken", null)

        if (xToken.isNullOrEmpty() || xServer.isNullOrEmpty() || xMedsoftToken.isNullOrEmpty()) {
            Log.e("LocationWorker", "Tokens not available")
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = "https://runner-api-v2.medsoft.care/api/gateway/location"
                val jsonBody = JSONObject()
                jsonBody.put("lat", location.latitude)
                jsonBody.put("lng", location.longitude)

                val requestBody = RequestBody.create("application/json".toMediaTypeOrNull(), jsonBody.toString())

                val request = Request.Builder()
                    .url(url)
                    .addHeader("X-Token", xToken)
                    .addHeader("X-Server", xServer)
                    .addHeader("X-Medsoft-Token", xMedsoftToken)
                    .addHeader("Content-Type", "application/json")
                    .post(requestBody)
                    .build()

                val client = OkHttpClient()
                val response = client.newCall(request).execute()

                if (!response.isSuccessful) {
                    Log.e("LocationWorker", "Failed to send location: ${response.code}")
                } else {
                    Log.d("LocationWorker", "Successfully sent location")
                }
            } catch (e: Exception) {
                Log.e("LocationWorker", "Error sending location: ${e.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

