package com.roundcaddy.android.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF0D7A3F),
    secondary = Color(0xFF0A5C30),
    tertiary = Color(0xFF267F4B)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF5DD68B),
    secondary = Color(0xFF3EBE73),
    tertiary = Color(0xFF79E6A2)
)

@Composable
fun RoundCaddyTheme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colors,
        content = content
    )
}

val LocalSpacing = staticCompositionLocalOf { 12 }
