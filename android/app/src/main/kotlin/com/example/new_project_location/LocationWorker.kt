package com.example.new_project_location

import android.content.Context
import android.content.SharedPreferences
import android.location.Location
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.location.LocationServices
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import org.json.JSONObject

class LocationWorker(context: Context, workerParams: WorkerParameters) : Worker(context, workerParams) {

    private val sharedPreferences = context.getSharedPreferences("AppPrefs", Context.MODE_PRIVATE)
    private var lastLocation: Location? = null
    private val distanceThreshold = 1f // 100 meters threshold

    
    override fun doWork(): Result {
        val fusedLocationClient = LocationServices.getFusedLocationProviderClient(applicationContext)

        // Fetch the current location
        fusedLocationClient.lastLocation.addOnSuccessListener { location: Location? ->
            if (location != null) {
                // Get the last stored location from SharedPreferences
                val storedLocation = getLastStoredLocation()

                // If the stored location is null or the device has moved the required threshold
                if (storedLocation == null || location.distanceTo(storedLocation) >= distanceThreshold) {
                    // Send the location to the API
                    sendLocationToAPI(location)
                    
                    // Save the new location to SharedPreferences
                    saveLastLocation(location)
                }
            } else {
                Log.e("LocationWorker", "Failed to get location")
            }
        }

        return Result.success()
    }

    private fun getLastStoredLocation(): Location? {
        // You can retrieve the last location from SharedPreferences or a database.
        // Example for SharedPreferences:
        val latitude = sharedPreferences.getFloat("lastLatitude", Float.NaN)
        val longitude = sharedPreferences.getFloat("lastLongitude", Float.NaN)
        return if (!latitude.isNaN() && !longitude.isNaN()) {
            Location("").apply {
                this.latitude = latitude.toDouble()
                this.longitude = longitude.toDouble()
            }
        } else {
            null
        }
    }

    private fun saveLastLocation(location: Location) {
        // Save the current location to SharedPreferences
        sharedPreferences.edit().apply {
            putFloat("lastLatitude", location.latitude.toFloat())
            putFloat("lastLongitude", location.longitude.toFloat())
            apply()
        }
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
}
