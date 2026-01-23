package com.roundcaddy.android.ui.screens

import android.Manifest
import android.location.Location
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.data.UserStats
import com.roundcaddy.android.ui.InfoCard
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun DashboardScreen() {
    val container = LocalAppContainer.current
    var stats by remember { mutableStateOf<UserStats?>(null) }
    var location by remember { mutableStateOf<Location?>(null) }
    var weather by remember { mutableStateOf<String?>(null) }
    var hasLocationPermission by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasLocationPermission = granted
    }

    LaunchedEffect(Unit) {
        scope.launch {
            val user = container.authRepository.currentUser()
            if (user != null) {
                stats = container.dataRepository.fetchStats(user.id)
            }
        }
    }

    LaunchedEffect(hasLocationPermission) {
        if (hasLocationPermission) {
            scope.launch {
                location = container.locationRepository.getCurrentLocation()
                val loc = location
                if (loc != null) {
                    val weatherData = container.weatherService.fetchWeather(loc.latitude, loc.longitude)
                    weather = "${weatherData.temperature}°F · ${weatherData.conditions} · ${weatherData.windSpeed} mph"
                }
            }
        }
    }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(
            title = "Dashboard",
            subtitle = "Summary of your recent performance."
        )

        if (weather != null) {
            Card(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(text = "Course Conditions")
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(text = weather ?: "")
                }
            }
        } else {
            Button(onClick = { permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION) }) {
                Text("Enable location for weather")
            }
        }

        stats?.let { userStats ->
            Row {
                InfoCard(title = "Rounds", value = userStats.roundsPlayed.toString(), modifier = Modifier.weight(1f))
                InfoCard(title = "Avg Score", value = "%.1f".format(userStats.averageScore), modifier = Modifier.weight(1f))
            }
            Row {
                InfoCard(title = "SG Total", value = "%.2f".format(userStats.averageSG), modifier = Modifier.weight(1f))
                InfoCard(title = "Handicap", value = userStats.handicapIndex?.let { "%.1f".format(it) } ?: "—", modifier = Modifier.weight(1f))
            }
        } ?: Text(text = "Load your stats by signing in.")
    }
}
