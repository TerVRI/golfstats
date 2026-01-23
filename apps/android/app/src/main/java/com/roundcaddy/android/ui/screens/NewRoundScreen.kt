package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.data.Course
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun NewRoundScreen(onSaved: () -> Unit, onCancel: () -> Unit) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var courseName by remember { mutableStateOf("") }
    var courseRating by remember { mutableStateOf("") }
    var slopeRating by remember { mutableStateOf("") }
    var totalScore by remember { mutableStateOf("") }
    var totalPutts by remember { mutableStateOf("") }
    var fairwaysHit by remember { mutableStateOf("") }
    var fairwaysTotal by remember { mutableStateOf("14") }
    var gir by remember { mutableStateOf("") }
    var penalties by remember { mutableStateOf("0") }
    var selectedCourse by remember { mutableStateOf<Course?>(null) }
    var showPicker by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "New Round", subtitle = "Quick entry for completed rounds.")

        Button(onClick = { showPicker = true }) {
            Text(selectedCourse?.name ?: "Select Course")
        }
        if (selectedCourse == null) {
            OutlinedTextField(
                value = courseName,
                onValueChange = { courseName = it },
                label = { Text("Or enter course name") },
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
            )
        }
        Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
            OutlinedTextField(
                value = courseRating,
                onValueChange = { courseRating = it },
                label = { Text("Rating") },
                modifier = Modifier.weight(1f)
            )
            Spacer(modifier = Modifier.height(0.dp).weight(0.1f))
            OutlinedTextField(
                value = slopeRating,
                onValueChange = { slopeRating = it },
                label = { Text("Slope") },
                modifier = Modifier.weight(1f)
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = totalScore,
            onValueChange = { totalScore = it },
            label = { Text("Total Score") },
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = totalPutts,
            onValueChange = { totalPutts = it },
            label = { Text("Total Putts") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(modifier = Modifier.fillMaxWidth()) {
            OutlinedTextField(
                value = fairwaysHit,
                onValueChange = { fairwaysHit = it },
                label = { Text("Fairways Hit") },
                modifier = Modifier.weight(1f)
            )
            Spacer(modifier = Modifier.height(0.dp).weight(0.1f))
            OutlinedTextField(
                value = fairwaysTotal,
                onValueChange = { fairwaysTotal = it },
                label = { Text("Total") },
                modifier = Modifier.weight(1f)
            )
        }
        OutlinedTextField(
            value = gir,
            onValueChange = { gir = it },
            label = { Text("Greens in Regulation") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        OutlinedTextField(
            value = penalties,
            onValueChange = { penalties = it },
            label = { Text("Penalties") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        error?.let { Text(it, modifier = Modifier.padding(top = 8.dp)) }
        Spacer(modifier = Modifier.height(12.dp))
        Row {
            TextButton(onClick = onCancel) { Text("Cancel") }
            Spacer(modifier = Modifier.height(0.dp).weight(1f))
            Button(onClick = {
                scope.launch {
                    val user = container.authRepository.currentUser()
                    val score = totalScore.toIntOrNull()
                    val finalCourse = selectedCourse?.name ?: courseName
                    if (user == null || score == null || finalCourse.isBlank()) {
                        error = "Enter a course and valid score."
                        return@launch
                    }
                    container.dataRepository.saveRound(
                        userId = user.id,
                        courseName = finalCourse,
                        totalScore = score,
                        totalPutts = totalPutts.toIntOrNull(),
                        fairwaysHit = fairwaysHit.toIntOrNull(),
                        fairwaysTotal = fairwaysTotal.toIntOrNull(),
                        gir = gir.toIntOrNull(),
                        penalties = penalties.toIntOrNull(),
                        courseRating = courseRating.toDoubleOrNull(),
                        slopeRating = slopeRating.toIntOrNull()
                    )
                    onSaved()
                }
            }) {
                Text("Save")
            }
        }
    }

    if (showPicker) {
        CoursePickerDialog(
            onSelect = { course ->
                selectedCourse = course
                courseName = course.name
                courseRating = course.courseRating?.let { "%.1f".format(it) } ?: ""
                slopeRating = course.slopeRating?.toString() ?: ""
                showPicker = false
            },
            onDismiss = { showPicker = false }
        )
    }
}

@Composable
private fun CoursePickerDialog(
    onSelect: (Course) -> Unit,
    onDismiss: () -> Unit
) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var courses by remember { mutableStateOf<List<Course>>(emptyList()) }
    var searchText by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        scope.launch {
            courses = container.dataRepository.fetchCourses(limit = 200)
        }
    }

    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Select course") },
        text = {
            Column {
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    label = { Text("Search") },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(8.dp))
                val filtered = courses.filter { it.name.contains(searchText, ignoreCase = true) }
                Column(modifier = Modifier.height(240.dp)) {
                    filtered.take(25).forEach { course ->
                        TextButton(onClick = { onSelect(course) }) {
                            Text(course.name)
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Close") } }
    )
}
