package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
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
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.data.StrokesGainedResult
import com.roundcaddy.android.data.UserStats
import com.roundcaddy.android.ui.InfoCard
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun AnalyticsScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var stats by remember { mutableStateOf<UserStats?>(null) }

    LaunchedEffect(Unit) {
        scope.launch {
            val user = container.authRepository.currentUser()
            if (user != null) {
                stats = container.dataRepository.fetchStats(user.id)
            }
        }
    }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Analytics", subtitle = "Strokes gained and performance trends.")
        stats?.let { userStats ->
            Row {
                InfoCard("SG Total", "%.2f".format(userStats.averageSG), Modifier.weight(1f))
                InfoCard("SG Off Tee", "%.2f".format(userStats.sgOffTee), Modifier.weight(1f))
            }
            Row {
                InfoCard("SG Approach", "%.2f".format(userStats.sgApproach), Modifier.weight(1f))
                InfoCard("SG Putting", "%.2f".format(userStats.sgPutting), Modifier.weight(1f))
            }
            val weakest = weakestAreaFromStats(userStats)
            Text(text = "Focus area: ${weakest.first}")
            Text(text = weakest.second)
        } ?: Text(text = "No analytics yet. Play a few rounds to see trends.")
    }
}

private fun weakestAreaFromStats(stats: UserStats): Pair<String, String> {
    val sg = StrokesGainedResult(
        sgOffTee = stats.sgOffTee,
        sgApproach = stats.sgApproach,
        sgAroundGreen = stats.sgAroundGreen,
        sgPutting = stats.sgPutting,
        sgTotal = stats.averageSG
    )
    val areas = listOf(
        "Off the Tee" to sg.sgOffTee,
        "Approach" to sg.sgApproach,
        "Around the Green" to sg.sgAroundGreen,
        "Putting" to sg.sgPutting
    )
    val weakest = areas.minBy { it.second }.first
    val recommendation = when (weakest) {
        "Off the Tee" -> "Focus on driving accuracy and distance control."
        "Approach" -> "Work on iron play and distance control with approaches."
        "Around the Green" -> "Practice chipping, pitching, and bunker play."
        else -> "Focus on speed control and short putts."
    }
    return weakest to recommendation
}
