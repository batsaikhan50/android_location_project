package com.example.new_project_location

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import org.json.JSONObject

class LocationForegroundService : Service() {
    private var methodChannel: MethodChannel? = null

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var sharedPreferences: SharedPreferences
    private var lastLocation: Location? = null
    private val distanceThreshold = 10f

    private val handler = Handler(Looper.getMainLooper())

    private var isAppInForeground = false

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        sharedPreferences = getSharedPreferences("AppPrefs", Context.MODE_PRIVATE)

        handler.postDelayed(notificationRunnable, 10000)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        if (!isAppInForeground) {
            startForeground(1, createNotification("Байршил дамжуулж байна..."))
        }
        startLocationUpdates()
        return START_STICKY
    }

    private fun createNotification(content: String): Notification {
        val channelId = "location_channel"
        val channelName = "Location Tracking"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan =
                    NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
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

    private val notificationRunnable =
            object : Runnable {
                override fun run() {
                    if (!isAppInForeground) {
                        startForeground(1, createNotification("Байршил дамжуулж байна..."))

                        handler.postDelayed(
                                {
                                    stopForegroundCompat()
                                    Log.d("LocationService", "Notification stopped after 10 sec")
                                },
                                10000
                        )
                    } else {
                        Log.d("in foreground", "App is in foreground")
                    }

                    handler.postDelayed(this, 2 * 60 * 1000) // 2 minutes
                }
            }
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
    }

    private fun cancelNotification() {
        val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(1)
        Log.d("LocationService", "Notification canceled")
    }

    private fun startLocationUpdates() {
        val locationRequest =
                LocationRequest.Builder(5000L).setPriority(Priority.PRIORITY_HIGH_ACCURACY).build()

        val locationCallback =
                object : LocationCallback() {
                    override fun onLocationResult(locationResult: LocationResult) {
                        val location = locationResult.lastLocation
                        if (location != null &&
                                        (lastLocation == null ||
                                                location.distanceTo(lastLocation!!) >
                                                        distanceThreshold)
                        ) {
                            lastLocation = location
                            sendLocationToAPI(location)
                            sendLocationToFlutter(location)
                        }
                    }
                }

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
    }

    private fun sendLocationToFlutter(location: Location) {
        val channel = MethodChannelManager.methodChannel
        channel?.invokeMethod(
                "updateLocation",
                mapOf("latitude" to location.latitude, "longitude" to location.longitude)
        )
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

                val requestBody =
                        RequestBody.create(
                                "application/json".toMediaTypeOrNull(),
                                jsonBody.toString()
                        )

                val request =
                        Request.Builder()
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

    fun setAppInForeground(isForeground: Boolean) {
        isAppInForeground = isForeground
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
