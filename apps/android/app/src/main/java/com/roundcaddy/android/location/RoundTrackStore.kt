package com.roundcaddy.android.location

import android.content.Context
import com.roundcaddy.android.data.TrackPoint
import org.json.JSONObject
import java.io.File

object RoundTrackStore {
    private const val FILE_NAME = "round_track.jsonl"

    private fun file(context: Context): File = File(context.filesDir, FILE_NAME)

    fun append(context: Context, lat: Double, lon: Double, accuracy: Double?) {
        val json = JSONObject()
            .put("lat", lat)
            .put("lon", lon)
            .put("timestamp", java.time.Instant.now().toString())
            .put("accuracy", accuracy)
        file(context).appendText(json.toString() + "\n")
    }

    fun readAll(context: Context): List<TrackPoint> {
        val file = file(context)
        if (!file.exists()) return emptyList()
        return file.readLines().mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val json = JSONObject(line)
            val lat = json.optDouble("lat", Double.NaN)
            val lon = json.optDouble("lon", Double.NaN)
            if (lat.isNaN() || lon.isNaN()) return@mapNotNull null
            TrackPoint(
                lat = lat,
                lon = lon,
                timestamp = json.optString("timestamp"),
                accuracy = json.optDouble("accuracy", Double.NaN).takeIf { !it.isNaN() }
            )
        }
    }

    fun clear(context: Context) {
        val file = file(context)
        if (file.exists()) {
            file.delete()
        }
    }
}
