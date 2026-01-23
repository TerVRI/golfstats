package com.roundcaddy.android.ui.screens

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
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
import com.roundcaddy.android.data.Course
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.ui.EmptyState
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun CoursesScreen(onOpenCourse: (String) -> Unit) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var query by remember { mutableStateOf("") }
    var courses by remember { mutableStateOf<List<Course>>(emptyList()) }
    var hasLocationPermission by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasLocationPermission = granted
    }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Courses", subtitle = "Discover courses and confirm details.")
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("Search courses") },
            modifier = Modifier.fillMaxWidth()
        )
        Button(
            onClick = {
                scope.launch {
                    courses = container.dataRepository.fetchCourses(search = query.ifBlank { null })
                }
            },
            modifier = Modifier.padding(top = 8.dp)
        ) {
            Text("Search")
        }
        Button(
            onClick = { permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION) },
            modifier = Modifier.padding(top = 8.dp)
        ) {
            Text("Nearby courses")
        }

        if (hasLocationPermission) {
            Button(
                onClick = {
                    scope.launch {
                        val location = container.locationRepository.getCurrentLocation()
                        if (location != null) {
                            courses = container.dataRepository.fetchNearbyCourses(
                                latitude = location.latitude,
                                longitude = location.longitude
                            )
                        }
                    }
                },
                modifier = Modifier.padding(top = 8.dp)
            ) {
                Text("Load nearby")
            }
        }

        if (courses.isEmpty()) {
            EmptyState("Search for a course to see details, ratings, and discussions.")
        } else {
            LazyColumn(contentPadding = PaddingValues(top = 16.dp)) {
                items(courses) { course ->
                    CourseCard(course) { onOpenCourse(course.id) }
                }
            }
        }
    }
}

@Composable
private fun CourseCard(course: Course, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = course.name)
            Text(text = listOfNotNull(course.city, course.state, course.country).joinToString(", "))
            Text(text = "Rating: ${course.courseRating ?: "—"} · Slope: ${course.slopeRating ?: "—"}")
        }
    }
}
