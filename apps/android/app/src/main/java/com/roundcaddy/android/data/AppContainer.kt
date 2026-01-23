package com.roundcaddy.android.data

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import com.roundcaddy.android.BuildConfig
import com.roundcaddy.android.location.LocationRepository

class AppContainer(context: Context) {
    val supabaseClient = SupabaseClient(
        baseUrl = BuildConfig.SUPABASE_URL,
        anonKey = BuildConfig.SUPABASE_ANON_KEY
    )
    val authRepository = AuthRepository(context, supabaseClient)
    val dataRepository = DataRepository(supabaseClient, authRepository)
    val weatherService = WeatherService()
    val locationRepository = LocationRepository(context)
}

val LocalAppContainer = staticCompositionLocalOf<AppContainer> {
    error("AppContainer not provided")
}
