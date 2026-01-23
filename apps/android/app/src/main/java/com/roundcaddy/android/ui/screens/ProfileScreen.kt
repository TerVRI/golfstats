package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
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
import com.roundcaddy.android.data.User
import com.roundcaddy.android.ui.ScreenHeader
import kotlinx.coroutines.launch

@Composable
fun ProfileScreen(
    onNavigateNotifications: () -> Unit,
    onNavigateDiscussions: () -> Unit,
    onNavigateContribute: () -> Unit,
    onNavigateConfirm: () -> Unit,
    onNavigateClubDistances: () -> Unit,
    onNavigateCoaching: () -> Unit,
    onNavigateSwingAnalytics: () -> Unit
) {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    var user by remember { mutableStateOf<User?>(null) }

    LaunchedEffect(Unit) {
        scope.launch {
            user = container.authRepository.currentUser()
        }
    }

    Column {
        ScreenHeader(title = "Profile", subtitle = "Account, preferences, and stats.")
        if (user != null) {
            Text(text = user?.fullName ?: "Golfer")
            Text(text = user?.email ?: "")
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = onNavigateNotifications) { Text("Notifications") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onNavigateDiscussions) { Text("Course discussions") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onNavigateContribute) { Text("Contribute course") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onNavigateConfirm) { Text("Confirm course") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onNavigateClubDistances) { Text("Club distances") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onNavigateCoaching) { Text("Coaching insights") }
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onNavigateSwingAnalytics) { Text("Swing analytics") }
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = {
                scope.launch { container.authRepository.signOut() }
            }) {
                Text("Sign out")
            }
        } else {
            Text(text = "Sign in to view your profile.")
        }
    }
}
