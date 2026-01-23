package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapType
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.roundcaddy.android.data.HoleScore
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.data.Round
import com.roundcaddy.android.data.Shot
import com.roundcaddy.android.data.TrackPoint
import com.roundcaddy.android.round.LocalRoundSession
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun RoundDetailScreen(
    roundId: String,
    onResumeRound: () -> Unit,
    onEditHole: (Int) -> Unit,
    onEditShot: (String) -> Unit
) {
    val container = LocalAppContainer.current
    val roundSession = LocalRoundSession.current
    val scope = rememberCoroutineScope()
    var round by remember { mutableStateOf<Round?>(null) }
    var holes by remember { mutableStateOf<List<HoleScore>>(emptyList()) }
    var shots by remember { mutableStateOf<List<Shot>>(emptyList()) }
    var track by remember { mutableStateOf<List<TrackPoint>>(emptyList()) }

    LaunchedEffect(roundId) {
        scope.launch {
            round = container.dataRepository.fetchRound(roundId)
            holes = container.dataRepository.fetchHoleScores(roundId)
            shots = container.dataRepository.fetchShots(roundId)
            track = container.dataRepository.fetchRoundTrack(roundId)
        }
    }

    LazyColumn(contentPadding = PaddingValues(16.dp)) {
        item {
            ScreenHeader(title = "Round Details", subtitle = round?.courseName ?: "Loading...")
            round?.let {
                StatRow("Score", it.totalScore.toString())
                StatRow("Putts", it.totalPutts.toString())
                StatRow("Fairways", "${it.fairwaysHit ?: 0}/${it.fairwaysTotal ?: 0}")
                StatRow("GIR", "${it.gir ?: 0}")
                StatRow("Track points", track.size.toString())
            }
            if (track.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                RoundTrackMap(track = track, shots = shots)
            }
            Spacer(modifier = Modifier.height(12.dp))
            Button(
                onClick = {
                    round?.let { currentRound ->
                        roundSession.loadFromSaved(currentRound.courseName, holes, shots)
                        onResumeRound()
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Resume This Round")
            }
            Spacer(modifier = Modifier.height(16.dp))
            Text("Hole Scores", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
        }

        items(holes) { hole ->
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("Hole ${hole.holeNumber} · Par ${hole.par}")
                    Text("Score ${hole.score} · Putts ${hole.putts}")
                    Text("FW ${if (hole.fairwayHit == true) "Yes" else "No"} · GIR ${if (hole.gir) "Yes" else "No"}")
                    Button(onClick = { onEditHole(hole.holeNumber) }) {
                        Text("Edit Hole")
                    }
                }
            }
        }

        item {
            Spacer(modifier = Modifier.height(16.dp))
            Text("Shots", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
        }

        items(shots) { shot ->
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("Hole ${shot.holeNumber} · Shot ${shot.shotNumber}")
                    Text("Club ${shot.club ?: "Unknown"}")
                    if (shot.latitude != null && shot.longitude != null) {
                        Text("Lat ${"%.5f".format(shot.latitude)}, Lon ${"%.5f".format(shot.longitude)}")
                    }
                    Button(onClick = { onEditShot(shot.id) }) {
                        Text("Edit Shot")
                    }
                }
            }
        }
    }
}

@Composable
private fun RoundTrackMap(track: List<TrackPoint>, shots: List<Shot>) {
    val points = track.map { LatLng(it.lat, it.lon) }
    val start = points.firstOrNull()
    GoogleMap(
        modifier = Modifier
            .fillMaxWidth()
            .height(240.dp),
        properties = MapProperties(mapType = MapType.NORMAL)
    ) {
        Polyline(points = points, color = androidx.compose.ui.graphics.Color(0xFF1E88E5), width = 6f)
        start?.let { Marker(state = MarkerState(it), title = "Start") }
        shots.forEach { shot ->
            if (shot.latitude != null && shot.longitude != null) {
                Marker(
                    state = MarkerState(LatLng(shot.latitude, shot.longitude)),
                    title = "Shot ${shot.shotNumber}"
                )
            }
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(label, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.labelLarge)
    }
}
