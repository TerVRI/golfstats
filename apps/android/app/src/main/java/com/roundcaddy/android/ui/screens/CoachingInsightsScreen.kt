package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.ui.ScreenHeader

@Composable
fun CoachingInsightsScreen() {
    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Coaching Insights", subtitle = "Personalized tips from your stats.")
        Text(text = "Review strokes gained trends to guide practice sessions.")
    }
}
