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
fun ContributeCourseScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var country by remember { mutableStateOf("") }
    var holes by remember { mutableStateOf("18") }
    var latitude by remember { mutableStateOf("") }
    var longitude by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Contribute Course", subtitle = "Add a missing course to the directory.")
        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Course name") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(value = country, onValueChange = { country = it }, label = { Text("Country") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        OutlinedTextField(value = holes, onValueChange = { holes = it }, label = { Text("Holes") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        OutlinedTextField(value = latitude, onValueChange = { latitude = it }, label = { Text("Latitude") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        OutlinedTextField(value = longitude, onValueChange = { longitude = it }, label = { Text("Longitude") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        Button(
            onClick = {
                scope.launch {
                    val user = container.authRepository.currentUser()
                    if (user != null) {
                        container.dataRepository.contributeCourse(
                            userId = user.id,
                            name = name,
                            country = country,
                            holes = holes.toIntOrNull() ?: 18,
                            latitude = latitude.toDoubleOrNull() ?: 0.0,
                            longitude = longitude.toDoubleOrNull() ?: 0.0
                        )
                        status = "Course submitted for review."
                    } else {
                        status = "Sign in to submit a course."
                    }
                }
            },
            modifier = Modifier.padding(top = 12.dp)
        ) {
            Text("Submit")
        }
        status?.let { Text(text = it, modifier = Modifier.padding(top = 8.dp)) }
    }
}
