package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
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
import com.roundcaddy.android.data.Round
import com.roundcaddy.android.ui.EmptyState
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun RoundsScreen(onNewRound: () -> Unit, onOpenRound: (String) -> Unit) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var rounds by remember { mutableStateOf<List<Round>>(emptyList()) }

    LaunchedEffect(Unit) {
        scope.launch {
            val user = container.authRepository.currentUser()
            if (user != null) {
                rounds = container.dataRepository.fetchRounds(user.id)
            }
        }
    }

    Column {
        ScreenHeader(title = "Rounds", subtitle = "Your recent rounds and scores.")
        Button(onClick = onNewRound, modifier = Modifier.padding(horizontal = 16.dp)) {
            Text("Add Round")
        }
        if (rounds.isEmpty()) {
            EmptyState("No rounds yet. Start a new round to track your stats.")
        } else {
            LazyColumn(contentPadding = PaddingValues(16.dp)) {
                items(rounds) { round ->
                    RoundCard(round) { onOpenRound(round.id) }
                }
            }
        }
    }
}

@Composable
private fun RoundCard(round: Round, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = round.courseName)
            Text(text = "Score: ${round.totalScore} · ${round.playedAt}")
            Text(text = "SG Total: ${round.sgTotal ?: 0.0}")
        }
    }
}
