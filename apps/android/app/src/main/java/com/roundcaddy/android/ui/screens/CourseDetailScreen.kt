package com.roundcaddy.android.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedButtonDefaults
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.data.Course
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.data.Weather
import com.roundcaddy.android.round.LocalRoundSession
import com.roundcaddy.android.ui.ScreenHeader
import com.roundcaddy.android.ui.screens.visualization.CourseMapView
import com.roundcaddy.android.ui.screens.visualization.CourseSchematicView
import com.roundcaddy.android.ui.screens.visualization.LayerVisibility
import kotlinx.coroutines.launch

@Composable
fun CourseDetailScreen(
    courseId: String,
    onStartRound: () -> Unit,
    onOpenDiscussions: () -> Unit,
    onConfirmCourse: () -> Unit
) {
    val container = LocalAppContainer.current
    val roundViewModel = LocalRoundSession.current
    val scope = rememberCoroutineScope()
    var course by remember { mutableStateOf<Course?>(null) }
    var weather by remember { mutableStateOf<Weather?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var visualizationMode by remember { mutableIntStateOf(0) }
    var selectedHole by remember { mutableIntStateOf(1) }
    var showSatellite by remember { mutableStateOf(false) }
    var layers by remember { mutableStateOf(LayerVisibility()) }
    val context = LocalContext.current

    LaunchedEffect(courseId) {
        scope.launch {
            course = container.dataRepository.fetchCourse(courseId)
            course?.let { loaded ->
                if (loaded.latitude != null && loaded.longitude != null) {
                    weather = container.weatherService.fetchWeather(loaded.latitude, loaded.longitude)
                }
            }
            isLoading = false
        }
    }

    if (isLoading) {
        Column(modifier = Modifier.padding(16.dp)) {
            ScreenHeader(title = "Course Details", subtitle = "Loading course info...")
        }
        return
    }

    val detail = course ?: return
    LazyColumn(modifier = Modifier.padding(16.dp)) {
        item {
            ScreenHeader(title = detail.name, subtitle = formatLocation(detail))
            Row(modifier = Modifier.fillMaxWidth()) {
                InfoChip("Par", detail.par?.toString() ?: "--")
                InfoChip("Rating", detail.courseRating?.let { "%.1f".format(it) } ?: "--")
                InfoChip("Slope", detail.slopeRating?.toString() ?: "--")
            }
            Spacer(modifier = Modifier.height(16.dp))
            weather?.let { WeatherCardAndroid(it) }
            Spacer(modifier = Modifier.height(16.dp))
            if (detail.latitude != null && detail.longitude != null) {
                Button(onClick = {
                    val uri = Uri.parse("geo:${detail.latitude},${detail.longitude}?q=${Uri.encode(detail.name)}")
                    context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                }) {
                    Text("Open in Maps")
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Text("Course Layout", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            HoleSelector(
                holeCount = detail.holeData?.size ?: 0,
                selected = selectedHole,
                onSelect = { selectedHole = it }
            )
            Spacer(modifier = Modifier.height(8.dp))
            VisualizationToggle(visualizationMode) { visualizationMode = it }
            Spacer(modifier = Modifier.height(8.dp))
            LayerToggles(layers = layers, onChange = { layers = it })
            Spacer(modifier = Modifier.height(8.dp))
            if (visualizationMode == 0) {
                CourseMapView(
                    holeData = detail.holeData ?: emptyList(),
                    selectedHole = selectedHole,
                    layers = layers,
                    showSatellite = showSatellite
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedButton(onClick = { showSatellite = !showSatellite }) {
                    Text(if (showSatellite) "Standard View" else "Satellite View")
                }
            } else {
                CourseSchematicView(
                    holeData = detail.holeData ?: emptyList(),
                    selectedHole = selectedHole,
                    layers = layers
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = {
                roundViewModel.startRound(detail)
                onStartRound()
            }) {
                Text("Start Round at This Course")
            }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onConfirmCourse) { Text("Confirm Course Data") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onOpenDiscussions) { Text("Discussions") }
            Spacer(modifier = Modifier.height(16.dp))
            Text("Hole Details", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
        }
        items(detail.holeData ?: emptyList()) { hole ->
            HoleDetailCard(hole)
        }
    }
}

@Composable
private fun VisualizationToggle(selected: Int, onSelect: (Int) -> Unit) {
    Row {
        OutlinedButton(
            onClick = { onSelect(0) },
            colors = OutlinedButtonDefaults.outlinedButtonColors(
                contentColor = if (selected == 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
            )
        ) {
            Text("Map")
        }
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedButton(
            onClick = { onSelect(1) },
            colors = OutlinedButtonDefaults.outlinedButtonColors(
                contentColor = if (selected == 1) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
            )
        ) {
            Text("Schematic")
        }
    }
}

@Composable
private fun HoleSelector(holeCount: Int, selected: Int, onSelect: (Int) -> Unit) {
    if (holeCount == 0) return
    LazyRow(modifier = Modifier.fillMaxWidth()) {
        items((1..minOf(holeCount, 18)).toList()) { hole ->
            OutlinedButton(
                onClick = { onSelect(hole) },
                modifier = Modifier.padding(end = 6.dp),
                colors = OutlinedButtonDefaults.outlinedButtonColors(
                    contentColor = if (hole == selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                )
            ) {
                Text(hole.toString())
            }
        }
    }
}

@Composable
private fun LayerToggles(layers: LayerVisibility, onChange: (LayerVisibility) -> Unit) {
    Row(modifier = Modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { onChange(layers.copy(fairway = !layers.fairway)) }) { Text("Fairway") }
        OutlinedButton(onClick = { onChange(layers.copy(green = !layers.green)) }) { Text("Green") }
        OutlinedButton(onClick = { onChange(layers.copy(bunkers = !layers.bunkers)) }) { Text("Bunkers") }
    }
    Row(modifier = Modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { onChange(layers.copy(water = !layers.water)) }) { Text("Water") }
        OutlinedButton(onClick = { onChange(layers.copy(trees = !layers.trees)) }) { Text("Trees") }
        OutlinedButton(onClick = { onChange(layers.copy(yardageMarkers = !layers.yardageMarkers)) }) { Text("Markers") }
    }
}

@Composable
private fun HoleDetailCard(hole: HoleData) {
    Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text("Hole ${hole.holeNumber} · Par ${hole.par}")
            hole.yardages?.let { yards ->
                Text("Yardages: " + yards.entries.joinToString { "${it.key}: ${it.value}" })
            }
            Text("Tees: ${hole.teeLocations?.size ?: 0} · Bunkers: ${hole.bunkers?.size ?: 0}")
        }
    }
}

@Composable
private fun InfoChip(title: String, value: String) {
    Card(modifier = Modifier.padding(end = 8.dp)) {
        Column(modifier = Modifier.padding(8.dp)) {
            Text(title, style = MaterialTheme.typography.labelSmall)
            Text(value, style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
private fun WeatherCardAndroid(weather: Weather) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Current Weather", style = MaterialTheme.typography.titleMedium)
            Text("${weather.temperature}°F · ${weather.conditions}")
            Text("Wind ${weather.windSpeed} mph ${weather.windDirection} · Humidity ${weather.humidity}%")
            Text(if (weather.isGoodForGolf) "Great day for golf!" else "Check conditions.")
        }
    }
}

private fun formatLocation(course: Course): String {
    return listOfNotNull(course.city, course.state, course.country)
        .filter { it.isNotBlank() && !it.equals("Unknown", ignoreCase = true) }
        .joinToString(", ")
        .ifBlank { "Location Unknown" }
}
