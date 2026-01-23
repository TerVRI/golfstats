package com.roundcaddy.android.ui.screens

import android.Manifest
import android.content.Intent
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GolfCourse
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.round.LocalRoundSession
import com.roundcaddy.android.data.HoleData
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.round.GolfClubs
import com.roundcaddy.android.round.RoundSessionViewModel
import com.roundcaddy.android.location.ForegroundLocationService
import com.roundcaddy.android.location.RoundTrackStore
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
fun LiveRoundScreen(onEndRound: () -> Unit = {}) {
    val container = LocalAppContainer.current
    val context = LocalContext.current
    val roundViewModel = LocalRoundSession.current
    val scope = rememberCoroutineScope()
    var selectedTab by remember { mutableIntStateOf(0) }
    var showEndDialog by remember { mutableStateOf(false) }
    var showClubPicker by remember { mutableStateOf(false) }
    var hasPermission by remember { mutableStateOf(false) }
    var hasBackgroundPermission by remember { mutableStateOf(Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) }
    var hasNotificationPermission by remember { mutableStateOf(Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) }
    var isTrackingEnabled by remember { mutableStateOf(true) }
    var trackingStarted by remember { mutableStateOf(false) }
    var currentLat by remember { mutableStateOf<Double?>(null) }
    var currentLon by remember { mutableStateOf<Double?>(null) }
    var lastShotDistance by remember { mutableStateOf<Int?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val fine = result[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarse = result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        hasPermission = fine || coarse
        hasBackgroundPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            result[Manifest.permission.ACCESS_BACKGROUND_LOCATION] == true
        } else {
            true
        }
        hasNotificationPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            result[Manifest.permission.POST_NOTIFICATIONS] == true
        } else {
            true
        }
    }

    fun requestPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        permissionLauncher.launch(permissions.toTypedArray())
    }

    LaunchedEffect(hasPermission, isTrackingEnabled, roundViewModel.isRoundActive) {
        if (hasPermission && isTrackingEnabled && roundViewModel.isRoundActive) {
            if (!trackingStarted) {
                RoundTrackStore.clear(context)
                trackingStarted = true
            }
            val intent = Intent(context, ForegroundLocationService::class.java).apply {
                action = ForegroundLocationService.ACTION_START
            }
            context.startForegroundService(intent)
        } else {
            val stopIntent = Intent(context, ForegroundLocationService::class.java).apply {
                action = ForegroundLocationService.ACTION_STOP
            }
            context.startService(stopIntent)
        }
    }

    if (!roundViewModel.isRoundActive) {
        roundViewModel.startRound()
    }

    Column(modifier = Modifier.background(Color(0xFF0F1115))) {
        LiveRoundHeader(
            courseName = roundViewModel.selectedCourse?.name ?: "Round in Progress",
            totalScore = roundViewModel.totalScore,
            onEndRound = { showEndDialog = true }
        )
        HoleNavigator(
            currentHole = roundViewModel.currentHole,
            par = roundViewModel.currentHoleScore?.par ?: 4,
            onPrevious = { roundViewModel.previousHole() },
            onNext = { roundViewModel.nextHole() }
        )
        TabRow(selectedTabIndex = selectedTab) {
            Tab(selected = selectedTab == 0, onClick = { selectedTab = 0 }, text = { Text("Distance") })
            Tab(selected = selectedTab == 1, onClick = { selectedTab = 1 }, text = { Text("Scorecard") })
            Tab(selected = selectedTab == 2, onClick = { selectedTab = 2 }, text = { Text("Shots") })
        }
        when (selectedTab) {
            0 -> DistanceTab(
                hasPermission = hasPermission,
                onRequestPermission = { requestPermissions() },
                currentLat = currentLat,
                currentLon = currentLon,
                holeData = roundViewModel.selectedCourse?.holeData?.firstOrNull { it.holeNumber == roundViewModel.currentHole },
                lastShotDistance = lastShotDistance,
                hasBackgroundPermission = hasBackgroundPermission,
                hasNotificationPermission = hasNotificationPermission,
                isTrackingEnabled = isTrackingEnabled,
                onToggleTracking = { isTrackingEnabled = !isTrackingEnabled }
            )
            1 -> LiveScorecardTab(roundViewModel = roundViewModel)
            else -> ShotTrackerTab(
                shots = roundViewModel.shotsForCurrentHole(),
                lastShotDistance = lastShotDistance,
                onMarkShot = {
                    showClubPicker = true
                }
            )
        }
    }

    if (showClubPicker) {
        ClubPickerDialog(
            onSelect = { club ->
                roundViewModel.addShot(club, currentLat, currentLon)
                lastShotDistance = calculateLastShotDistance(roundViewModel, currentLat, currentLon)
                showClubPicker = false
            },
            onDismiss = { showClubPicker = false }
        )
    }

    if (showEndDialog) {
        AlertDialog(
            onDismissRequest = { showEndDialog = false },
            title = { Text("End round?") },
            text = { Text("Save your progress or discard this round.") },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        val user = container.authRepository.currentUser()
                        if (user != null) {
                            val roundId = container.dataRepository.saveRound(
                                userId = user.id,
                                courseName = roundViewModel.selectedCourse?.name ?: "Unknown Course",
                                totalScore = roundViewModel.totalScore,
                                totalPutts = roundViewModel.totalPutts,
                                fairwaysHit = roundViewModel.fairwaysHit,
                                fairwaysTotal = roundViewModel.allHoleScores().count { it.par > 3 },
                                gir = roundViewModel.greensInRegulation,
                                penalties = roundViewModel.allHoleScores().sumOf { it.penalties },
                                courseRating = roundViewModel.selectedCourse?.courseRating,
                                slopeRating = roundViewModel.selectedCourse?.slopeRating
                            )
                            container.dataRepository.saveHoleScores(roundId, roundViewModel.allHoleScores())
                            container.dataRepository.saveShots(roundId, roundViewModel.allShots())
                            val trackPoints = RoundTrackStore.readAll(context)
                            container.dataRepository.saveRoundTrack(roundId, trackPoints)
                            RoundTrackStore.clear(context)
                        }
                        val stopIntent = Intent(context, ForegroundLocationService::class.java).apply {
                            action = ForegroundLocationService.ACTION_STOP
                        }
                        context.startService(stopIntent)
                        trackingStarted = false
                        roundViewModel.endRound()
                        showEndDialog = false
                        onEndRound()
                    }
                }) { Text("Save & End") }
            },
            dismissButton = {
                TextButton(onClick = { showEndDialog = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun LiveRoundHeader(courseName: String, totalScore: Int, onEndRound: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF1E2128))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextButton(onClick = onEndRound) {
            Text(text = "End", color = Color.Red)
        }
        Spacer(modifier = Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(courseName, color = Color.White, fontWeight = FontWeight.SemiBold)
            Text("Score: $totalScore", color = Color.LightGray, style = MaterialTheme.typography.labelSmall)
        }
        Spacer(modifier = Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Watch, contentDescription = null, tint = Color(0xFF4CAF50))
            Text("Synced", color = Color(0xFF4CAF50), style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
private fun HoleNavigator(
    currentHole: Int,
    par: Int,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF1A1D23))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        TextButton(onClick = onPrevious, enabled = currentHole > 1) {
            Text("<", color = if (currentHole > 1) Color(0xFF4CAF50) else Color.Gray)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Hole $currentHole", color = Color.White, fontWeight = FontWeight.Bold)
            Text("Par $par", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
        }
        TextButton(onClick = onNext, enabled = currentHole < 18) {
            Text(">", color = if (currentHole < 18) Color(0xFF4CAF50) else Color.Gray)
        }
    }
}

@Composable
private fun DistanceTab(
    hasPermission: Boolean,
    onRequestPermission: () -> Unit,
    currentLat: Double?,
    currentLon: Double?,
    holeData: HoleData?,
    lastShotDistance: Int?,
    hasBackgroundPermission: Boolean,
    hasNotificationPermission: Boolean,
    isTrackingEnabled: Boolean,
    onToggleTracking: () -> Unit
) {
    Column(modifier = Modifier.padding(16.dp)) {
        if (!hasPermission) {
            Button(onClick = onRequestPermission) { Text("Enable GPS") }
            return
        }

        if (!hasBackgroundPermission || !hasNotificationPermission) {
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("Background tracking needs extra permissions", color = Color.White)
                    if (!hasBackgroundPermission) {
                        Text("Allow background location access", color = Color.Gray)
                    }
                    if (!hasNotificationPermission) {
                        Text("Allow notification access", color = Color.Gray)
                    }
                    Button(onClick = onRequestPermission) {
                        Text("Grant permissions")
                    }
                }
            }
        }

        Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
            Row(
                modifier = Modifier.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("Background tracking", color = Color.White)
                    Text(if (isTrackingEnabled) "Active" else "Paused", color = Color.Gray)
                }
                Button(onClick = onToggleTracking) {
                    Text(if (isTrackingEnabled) "Pause" else "Resume")
                }
            }
        }

        val distances = remember(currentLat, currentLon, holeData) {
            if (currentLat == null || currentLon == null || holeData == null) {
                Triple<Int?, Int?, Int?>(null, null, null)
            } else {
                val center = holeData.greenCenter?.let { distanceTo(currentLat, currentLon, it.lat, it.lon) }
                val front = holeData.greenFront?.let { distanceTo(currentLat, currentLon, it.lat, it.lon) }
                val back = holeData.greenBack?.let { distanceTo(currentLat, currentLon, it.lat, it.lon) }
                Triple(front?.roundToInt(), center?.roundToInt(), back?.roundToInt())
            }
        }

        ScreenHeader(title = "Distance", subtitle = "Front / Center / Back")
        CenterDistanceCard(distances.second)
        Spacer(modifier = Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
            DistanceBox(label = "Front", value = distances.first)
            DistanceBox(label = "Back", value = distances.third)
        }
        lastShotDistance?.let {
            Spacer(modifier = Modifier.height(16.dp))
            Card(modifier = Modifier.fillMaxWidth()) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.GolfCourse, contentDescription = null, tint = Color(0xFFFFB74D))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Last shot: $it yards", color = Color.White)
                }
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = if (currentLat != null && currentLon != null) {
                "Lat ${"%.6f".format(currentLat)}, Lon ${"%.6f".format(currentLon)}"
            } else {
                "Waiting for GPS signal..."
            },
            color = Color.Gray,
            style = MaterialTheme.typography.labelSmall
        )
    }
}

@Composable
private fun CenterDistanceCard(distance: Int?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF1E2128), CircleShape)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("CENTER", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
        Text(
            text = distance?.toString() ?: "---",
            color = if (distance != null) Color(0xFF4CAF50) else Color.Gray,
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold
        )
        Text("yards", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun DistanceBox(label: String, value: Int?) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label.uppercase(), color = Color.Gray, style = MaterialTheme.typography.labelSmall)
        Text(value?.toString() ?: "--", color = Color.White, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun LiveScorecardTab(roundViewModel: RoundSessionViewModel) {
    val score = roundViewModel.currentHoleScore
    Column(modifier = Modifier.padding(16.dp)) {
        Text(text = "Score", color = Color.White, style = MaterialTheme.typography.titleLarge)
        Spacer(modifier = Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
            Button(onClick = { roundViewModel.decrementScore() }) { Text("-") }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(score?.score?.toString() ?: "-", color = Color.White, style = MaterialTheme.typography.displaySmall)
                Text(score?.scoreDescription ?: "", color = scoreColor(score?.relativeToPar ?: 0))
            }
            Button(onClick = { roundViewModel.incrementScore() }) { Text("+") }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
            ToggleChip("FW", score?.fairwayHit == true) { roundViewModel.toggleFairway() }
            ToggleChip("GIR", score?.gir == true) { roundViewModel.toggleGIR() }
            val currentPutts = score?.putts ?: 0
            val currentPenalties = score?.penalties ?: 0
            StatCounter("Putts", currentPutts) { roundViewModel.updatePutts((currentPutts + 1) % 6) }
            StatCounter("Pen", currentPenalties) { roundViewModel.updatePenalties((currentPenalties + 1) % 6) }
        }
        Spacer(modifier = Modifier.height(16.dp))
        DividerRow(
            totalScore = roundViewModel.totalScore,
            totalPutts = roundViewModel.totalPutts,
            fairways = roundViewModel.fairwaysHit,
            gir = roundViewModel.greensInRegulation,
            currentHole = roundViewModel.currentHole
        )
    }
}

@Composable
private fun ToggleChip(label: String, selected: Boolean, onToggle: () -> Unit) {
    Button(onClick = onToggle) {
        Text("$label ${if (selected) "✓" else ""}")
    }
}

@Composable
private fun StatCounter(label: String, value: Int, onClick: () -> Unit) {
    Button(onClick = onClick) {
        Text("$label $value")
    }
}

@Composable
private fun DividerRow(totalScore: Int, totalPutts: Int, fairways: Int, gir: Int, currentHole: Int) {
    Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
        SummaryStat("Total", totalScore.toString())
        SummaryStat("Putts", totalPutts.toString())
        SummaryStat("FW", "$fairways/$currentHole")
        SummaryStat("GIR", "$gir/$currentHole")
    }
}

@Composable
private fun SummaryStat(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = Color.White, fontWeight = FontWeight.Bold)
        Text(label, color = Color.Gray, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun ShotTrackerTab(
    shots: List<com.roundcaddy.android.round.ShotState>,
    lastShotDistance: Int?,
    onMarkShot: () -> Unit
) {
    Column(
        modifier = Modifier.padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Shot ${shots.size + 1}", color = Color.Gray)
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = onMarkShot,
            modifier = Modifier
                .height(140.dp)
                .fillMaxWidth()
        ) {
            Text("Mark Shot")
        }
        lastShotDistance?.let {
            Spacer(modifier = Modifier.height(12.dp))
            Text("Last: $it yards", color = Color(0xFFFFB74D))
        }
        if (shots.isNotEmpty()) {
            Spacer(modifier = Modifier.height(16.dp))
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("Shots this hole", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
                    shots.forEach { shot ->
                        Text("${shot.shotNumber}. ${shot.club ?: "Unknown"}", color = Color.White)
                    }
                }
            }
        }
    }
}

@Composable
private fun ClubPickerDialog(onSelect: (String) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Select club") },
        text = {
            Column {
                GolfClubs.clubs.forEach { club ->
                    TextButton(onClick = { onSelect(club) }) {
                        Text(club)
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

private fun distanceTo(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val r = 6371000.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2)
    val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    val meters = r * c
    return meters * 1.09361
}

private fun scoreColor(diff: Int): Color {
    return when {
        diff <= -2 -> Color(0xFFFFD54F)
        diff == -1 -> Color(0xFF4CAF50)
        diff == 0 -> Color.White
        diff == 1 -> Color(0xFFFFA726)
        else -> Color(0xFFE53935)
    }
}

private fun calculateLastShotDistance(
    viewModel: RoundSessionViewModel,
    lat: Double?,
    lon: Double?
): Int? {
    val shots = viewModel.shotsForCurrentHole()
    val last = shots.lastOrNull() ?: return null
    if (lat == null || lon == null || last.latitude == null || last.longitude == null) return null
    return distanceTo(lat, lon, last.latitude, last.longitude).roundToInt()
}
