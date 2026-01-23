package com.roundcaddy.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.roundcaddy.android.ui.ScreenHeader

@Composable
fun ClubDistancesScreen() {
    Column(modifier = Modifier.padding(16.dp)) {
        ScreenHeader(title = "Club Distances", subtitle = "Track average distance per club.")
        Text(text = "Log shots during rounds to build your distance profile.")
    }
}
