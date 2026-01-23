package com.roundcaddy.android.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

class AuthRepository(
    context: Context,
    private val client: SupabaseClient
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("roundcaddy_auth", Context.MODE_PRIVATE)

    private var accessToken: String?
        get() = prefs.getString("access_token", null)
        set(value) = prefs.edit().putString("access_token", value).apply()

    private var refreshToken: String?
        get() = prefs.getString("refresh_token", null)
        set(value) = prefs.edit().putString("refresh_token", value).apply()

    suspend fun currentUser(): User? = withContext(Dispatchers.IO) {
        val token = accessToken ?: return@withContext null
        fetchUser(token)
    }

    suspend fun signInWithEmail(email: String, password: String): User = withContext(Dispatchers.IO) {
        ensureConfigured()
        val body = JSONObject()
            .put("email", email)
            .put("password", password)
        val response = client.rawRequest(
            "POST",
            "/auth/v1/token?grant_type=password",
            headers = mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
        handleAuthResponse(response)
    }

    suspend fun signUpWithEmail(email: String, password: String, fullName: String): User? =
        withContext(Dispatchers.IO) {
            ensureConfigured()
            val body = JSONObject()
                .put("email", email)
                .put("password", password)
                .put("data", JSONObject().put("full_name", fullName))
            val response = client.rawRequest(
                "POST",
                "/auth/v1/signup",
                headers = mapOf("Content-Type" to "application/json"),
                body = body.toString()
            )
            val json = JSONObject(response)
            if (json.optString("access_token").isNullOrBlank()) {
                return@withContext null
            }
            handleAuthResponse(response)
        }

    suspend fun refreshSession(): User = withContext(Dispatchers.IO) {
        val refresh = refreshToken ?: throw IllegalStateException("No refresh token")
        val body = JSONObject().put("refresh_token", refresh)
        val response = client.rawRequest(
            "POST",
            "/auth/v1/token?grant_type=refresh_token",
            headers = mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
        handleAuthResponse(response)
    }

    suspend fun signOut() = withContext(Dispatchers.IO) {
        accessToken = null
        refreshToken = null
    }

    fun authHeaders(): Map<String, String> {
        val headers = mutableMapOf("apikey" to client.anonKey)
        accessToken?.let { headers["Authorization"] = "Bearer $it" }
        return headers
    }

    private suspend fun fetchUser(token: String): User = withContext(Dispatchers.IO) {
        val response = client.rawRequest(
            "GET",
            "/auth/v1/user",
            headers = mapOf(
                "Authorization" to "Bearer $token",
                "apikey" to client.anonKey
            ),
            body = null
        )
        val json = JSONObject(response)
        return@withContext User(
            id = json.optString("id"),
            email = json.optString("email"),
            fullName = json.optJSONObject("user_metadata")?.optString("full_name"),
            avatarUrl = json.optJSONObject("user_metadata")?.optString("avatar_url")
        )
    }

    private fun handleAuthResponse(response: String): User {
        val json = JSONObject(response)
        accessToken = json.optString("access_token")
        refreshToken = json.optString("refresh_token")
        val user = json.optJSONObject("user")
        return User(
            id = user?.optString("id") ?: "",
            email = user?.optString("email"),
            fullName = user?.optJSONObject("user_metadata")?.optString("full_name"),
            avatarUrl = user?.optJSONObject("user_metadata")?.optString("avatar_url")
        )
    }

    private fun ensureConfigured() {
        if (!client.isConfigured()) {
            throw IllegalStateException("Supabase not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.")
        }
    }
}
