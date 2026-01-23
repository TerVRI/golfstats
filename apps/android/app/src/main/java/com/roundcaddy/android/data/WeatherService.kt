package com.roundcaddy.android.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class WeatherService {
    suspend fun fetchWeather(latitude: Double, longitude: Double): Weather = withContext(Dispatchers.IO) {
        val url = URL(
            "https://api.open-meteo.com/v1/forecast" +
                "?latitude=$latitude" +
                "&longitude=$longitude" +
                "&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m" +
                "&temperature_unit=fahrenheit&wind_speed_unit=mph"
        )
        val connection = url.openConnection() as HttpURLConnection
        val response = BufferedReader(InputStreamReader(connection.inputStream)).use { it.readText() }
        val json = JSONObject(response)
        val current = json.optJSONObject("current") ?: JSONObject()

        val temp = current.optDouble("temperature_2m", 0.0)
        val windSpeed = current.optDouble("wind_speed_10m", 0.0)
        val windDir = current.optDouble("wind_direction_10m", 0.0)
        val humidity = current.optInt("relative_humidity_2m", 0)
        val weatherCode = current.optInt("weather_code", 0)

        val (conditions, icon) = weatherConditions(weatherCode)
        val windDirection = windDirectionLabel(windDir)

        Weather(
            temperature = temp.toInt(),
            windSpeed = windSpeed.toInt(),
            windDirection = windDirection,
            conditions = conditions,
            icon = icon,
            humidity = humidity,
            precipitationProbability = 0,
            isGoodForGolf = temp in 50.0..95.0 && windSpeed <= 20
        )
    }

    private fun weatherConditions(code: Int): Pair<String, String> {
        return when (code) {
            0 -> "Clear" to "☀️"
            1, 2 -> "Partly Cloudy" to "⛅"
            3 -> "Cloudy" to "☁️"
            45, 48 -> "Foggy" to "🌫️"
            51, 53, 55, 61, 63, 65, 80, 81, 82 -> "Rainy" to "🌧️"
            71, 73, 75, 77, 85, 86 -> "Snow" to "❄️"
            95, 96, 99 -> "Thunderstorm" to "⛈️"
            else -> "Unknown" to "❓"
        }
    }

    private fun windDirectionLabel(degrees: Double): String {
        val directions = listOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW")
        val index = ((degrees + 11.25) / 22.5).toInt() % directions.size
        return directions[index]
    }
}
