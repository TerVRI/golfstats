package com.roundcaddy.android.round

import androidx.compose.runtime.staticCompositionLocalOf

val LocalRoundSession = staticCompositionLocalOf<RoundSessionViewModel> {
    error("RoundSessionViewModel not provided")
}
