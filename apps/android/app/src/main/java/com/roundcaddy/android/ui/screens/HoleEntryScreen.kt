package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.round.LocalRoundSession
import com.roundcaddy.android.ui.ScreenHeader

@Composable
fun HoleEntryScreen(holeNumber: Int, onBack: () -> Unit) {
    val roundViewModel = LocalRoundSession.current
    if (roundViewModel.holeScores.isEmpty()) {
        roundViewModel.startRound()
    }
    roundViewModel.goToHole(holeNumber)
    val hole = roundViewModel.currentHoleScore

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Hole $holeNumber", subtitle = "Update score and stats.")
        Text("Par ${hole?.par ?: 4}")
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Button(onClick = { roundViewModel.decrementScore() }) { Text("Score -") }
            Text("Score ${hole?.score ?: 0}")
            Button(onClick = { roundViewModel.incrementScore() }) { Text("Score +") }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Button(onClick = { roundViewModel.updatePutts((hole?.putts ?: 0) - 1) }) { Text("Putts -") }
            Text("Putts ${hole?.putts ?: 0}")
            Button(onClick = { roundViewModel.updatePutts((hole?.putts ?: 0) + 1) }) { Text("Putts +") }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Button(onClick = { roundViewModel.toggleFairway() }) {
                Text("FW ${if (hole?.fairwayHit == true) "Yes" else "No"}")
            }
            Button(onClick = { roundViewModel.toggleGIR() }) {
                Text("GIR ${if (hole?.gir == true) "Yes" else "No"}")
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Button(onClick = { roundViewModel.updatePenalties((hole?.penalties ?: 0) - 1) }) {
                Text("Pen -")
            }
            Text("Penalties ${hole?.penalties ?: 0}")
            Button(onClick = { roundViewModel.updatePenalties((hole?.penalties ?: 0) + 1) }) {
                Text("Pen +")
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = onBack) { Text("Back to scorecard") }
    }
}

