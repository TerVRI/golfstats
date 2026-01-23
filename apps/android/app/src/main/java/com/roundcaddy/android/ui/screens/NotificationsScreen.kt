package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import com.roundcaddy.android.data.NotificationItem
import com.roundcaddy.android.ui.EmptyState
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun NotificationsScreen() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var notifications by remember { mutableStateOf<List<NotificationItem>>(emptyList()) }

    LaunchedEffect(Unit) {
        scope.launch {
            val user = container.authRepository.currentUser()
            if (user != null) {
                notifications = container.dataRepository.fetchNotifications(user.id)
            }
        }
    }

    Column {
        ScreenHeader(title = "Notifications", subtitle = "Updates from courses and discussions.")
        if (notifications.isEmpty()) {
            EmptyState("You're all caught up.")
        } else {
            LazyColumn(contentPadding = PaddingValues(16.dp)) {
                items(notifications) { item ->
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
