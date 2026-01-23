package com.roundcaddy.android.data

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class SupabaseClient(
    private val baseUrl: String,
    val anonKey: String
) {
    fun isConfigured(): Boolean {
        return baseUrl.isNotBlank() && anonKey.isNotBlank()
    }

    fun getJsonArray(path: String, headers: Map<String, String> = emptyMap()): JSONArray {
        val response = request("GET", path, headers, null)
        return JSONArray(response)
    }

    fun getJsonObject(path: String, headers: Map<String, String> = emptyMap()): JSONObject {
        val response = request("GET", path, headers, null)
        return JSONObject(response)
    }

    fun postJson(path: String, headers: Map<String, String> = emptyMap(), body: JSONObject): JSONObject {
        val response = request("POST", path, headers, body.toString())
        return JSONObject(response)
    }

    fun postJsonArray(path: String, headers: Map<String, String> = emptyMap(), body: JSONObject): JSONArray {
        val response = request("POST", path, headers, body.toString())
        return JSONArray(response)
    }

    fun patchJson(path: String, headers: Map<String, String> = emptyMap(), body: JSONObject): String {
        return request("PATCH", path, headers, body.toString())
    }

    fun rawRequest(method: String, path: String, headers: Map<String, String> = emptyMap(), body: String?): String {
        return request(method, path, headers, body)
    }

    private fun request(method: String, path: String, headers: Map<String, String>, body: String?): String {
        val url = if (path.startsWith("http")) {
            URL(path)
        } else {
            URL("$baseUrl$path")
        }
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.setRequestProperty("apikey", anonKey)
        headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }

        if (body != null) {
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { output -> output.write(body.toByteArray()) }
        }

        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val response = BufferedReader(InputStreamReader(stream)).use { it.readText() }
        if (code !in 200..299) {
            throw IllegalStateException("Supabase request failed ($code): $response")
        }
        return response
    }
}
