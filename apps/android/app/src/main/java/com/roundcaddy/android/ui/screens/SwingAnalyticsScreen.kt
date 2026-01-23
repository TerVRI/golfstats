package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.ui.ScreenHeader

@Composable
fun SwingAnalyticsScreen() {
    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Swing Analytics", subtitle = "Capture swing metrics during practice.")
        Text(text = "Connect sensor data or manual notes for swing analysis.")
    }
}
