package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
fun CourseConfirmationScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()

    var courseId by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Confirm Course", subtitle = "Verify course layout and details.")
        OutlinedTextField(
            value = courseId,
            onValueChange = { courseId = it },
            label = { Text("Course ID") },
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = notes,
            onValueChange = { notes = it },
            label = { Text("Notes") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        Button(
            onClick = {
                scope.launch {
                    val user = container.authRepository.currentUser()
                    if (user != null && courseId.isNotBlank()) {
                        container.dataRepository.confirmCourse(
                            courseId = courseId,
                            userId = user.id,
                            discrepancyNotes = notes.ifBlank { null }
                        )
                        status = "Course confirmation submitted."
                    } else {
                        status = "Sign in and enter a course ID."
                    }
                }
            },
            modifier = Modifier.padding(top = 12.dp)
        ) {
            Text("Submit confirmation")
        }
        status?.let { Text(text = it, modifier = Modifier.padding(top = 8.dp)) }
    }
}
