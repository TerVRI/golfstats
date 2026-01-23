package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
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
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun SavedHoleEditScreen(roundId: String, holeNumber: Int, onDone: () -> Unit) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var score by remember { mutableStateOf("") }
    var putts by remember { mutableStateOf("") }
    var fairwayHit by remember { mutableStateOf(false) }
    var gir by remember { mutableStateOf(false) }
    var penalties by remember { mutableStateOf("") }

    LaunchedEffect(roundId, holeNumber) {
        scope.launch {
            val hole = container.dataRepository.fetchHoleScores(roundId).firstOrNull { it.holeNumber == holeNumber }
            if (hole != null) {
                score = hole.score.toString()
                putts = hole.putts.toString()
                fairwayHit = hole.fairwayHit == true
                gir = hole.gir
                penalties = hole.penalties.toString()
            }
        }
    }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Edit Hole $holeNumber", subtitle = "Update saved score data.")
        OutlinedTextField(value = score, onValueChange = { score = it }, label = { Text("Score") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = putts, onValueChange = { putts = it }, label = { Text("Putts") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        OutlinedTextField(value = penalties, onValueChange = { penalties = it }, label = { Text("Penalties") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = { fairwayHit = !fairwayHit }) { Text("Fairway Hit: ${if (fairwayHit) "Yes" else "No"}") }
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = { gir = !gir }) { Text("GIR: ${if (gir) "Yes" else "No"}") }
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = {
                scope.launch {
                    container.dataRepository.updateHoleScore(
                        roundId = roundId,
                        holeNumber = holeNumber,
                        score = score.toIntOrNull() ?: 0,
                        putts = putts.toIntOrNull() ?: 0,
                        fairwayHit = fairwayHit,
                        gir = gir,
                        penalties = penalties.toIntOrNull() ?: 0
                    )
                    onDone()
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Save")
        }
    }
}
