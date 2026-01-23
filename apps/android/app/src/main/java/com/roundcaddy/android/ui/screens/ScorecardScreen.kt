package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.round.HoleScoreState
import com.roundcaddy.android.round.LocalRoundSession
import com.roundcaddy.android.ui.ScreenHeader

@Composable
fun ScorecardScreen(onSelectHole: (Int) -> Unit) {
    val roundViewModel = LocalRoundSession.current
    var selectedHole by remember { mutableStateOf(roundViewModel.currentHole) }
    if (roundViewModel.holeScores.isEmpty()) {
        roundViewModel.startRound()
    }

    Column {
        ScreenHeader(title = "Scorecard", subtitle = "Tap a hole to edit details.")
        LazyColumn(modifier = Modifier.padding(16.dp)) {
            items(roundViewModel.holeScores) { hole ->
                ScorecardRow(hole = hole, onClick = {
                    selectedHole = hole.holeNumber
                    roundViewModel.goToHole(hole.holeNumber)
                    onSelectHole(hole.holeNumber)
                })
            }
        }
    }
}

@Composable
private fun ScorecardRow(hole: HoleScoreState, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Hole ${hole.holeNumber} · Par ${hole.par}")
            Text("Score ${hole.score} · Putts ${hole.putts} · ${hole.scoreDescription}")
            Text("FW ${if (hole.fairwayHit == true) "Yes" else "No"} · GIR ${if (hole.gir) "Yes" else "No"}")
        }
    }
}
