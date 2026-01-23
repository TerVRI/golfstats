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
fun SavedShotEditScreen(shotId: String, onDone: () -> Unit) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var club by remember { mutableStateOf("") }
    var lie by remember { mutableStateOf("") }
    var result by remember { mutableStateOf("") }
    var distanceToPin by remember { mutableStateOf("") }

    LaunchedEffect(shotId) {
        scope.launch {
            val shot = container.dataRepository.fetchShot(shotId)
            if (shot != null) {
                club = shot.club ?: ""
                lie = shot.lie ?: ""
                result = shot.result ?: ""
                distanceToPin = shot.distanceToPin?.toString() ?: ""
            }
        }
    }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Edit Shot", subtitle = "Update club and result.")
        OutlinedTextField(value = club, onValueChange = { club = it }, label = { Text("Club") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = lie, onValueChange = { lie = it }, label = { Text("Lie") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        OutlinedTextField(value = result, onValueChange = { result = it }, label = { Text("Result") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        OutlinedTextField(
            value = distanceToPin,
            onValueChange = { distanceToPin = it },
            label = { Text("Distance to Pin") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = {
                scope.launch {
                    container.dataRepository.updateShot(
                        shotId = shotId,
                        clubName = club.ifBlank { null },
                        lie = lie.ifBlank { null },
                        result = result.ifBlank { null },
                        distanceToPin = distanceToPin.toIntOrNull()
                    )
                    onDone()
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Save")
        }
        Spacer(modifier = Modifier.height(8.dp))
        Button(
            onClick = {
                scope.launch {
                    container.dataRepository.deleteShot(shotId)
                    onDone()
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Delete Shot")
        }
    }
}
