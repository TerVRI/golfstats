package com.roundcaddy.android.ui.screens

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
import com.roundcaddy.android.data.CourseDiscussion
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.ui.EmptyState
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun DiscussionsScreen(initialCourseId: String? = null) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var courseId by remember { mutableStateOf(initialCourseId ?: "") }
    var title by remember { mutableStateOf("") }
    var content by remember { mutableStateOf("") }
    var discussions by remember { mutableStateOf<List<CourseDiscussion>>(emptyList()) }

    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Course Discussions", subtitle = "Share insights and tips.")
        OutlinedTextField(
            value = courseId,
            onValueChange = { courseId = it },
            label = { Text("Course ID") },
            modifier = Modifier.fillMaxWidth()
        )
        Button(
            onClick = {
                scope.launch {
                    if (courseId.isNotBlank()) {
                        discussions = container.dataRepository.fetchCourseDiscussions(courseId)
                    }
                }
            },
            modifier = Modifier.padding(top = 8.dp)
        ) {
            Text("Load discussions")
        }

        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            label = { Text("New discussion title") },
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp)
        )
        OutlinedTextField(
            value = content,
            onValueChange = { content = it },
            label = { Text("Discussion content") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp)
        )
        Button(
            onClick = {
                scope.launch {
                    val user = container.authRepository.currentUser()
                    if (user != null && courseId.isNotBlank()) {
                        container.dataRepository.createCourseDiscussion(courseId, user.id, title, content)
                        discussions = container.dataRepository.fetchCourseDiscussions(courseId)
                        title = ""
                        content = ""
                    }
                }
            },
            modifier = Modifier.padding(top = 8.dp)
        ) {
            Text("Post discussion")
        }

        if (discussions.isEmpty()) {
            EmptyState("No discussions yet.")
        } else {
            LazyColumn(contentPadding = PaddingValues(top = 16.dp)) {
                items(discussions) { item ->
                    Card(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(text = item.title)
                            Text(text = item.content)
                            Text(text = item.createdAt)
                        }
                    }
                }
            }
        }
    }
}
