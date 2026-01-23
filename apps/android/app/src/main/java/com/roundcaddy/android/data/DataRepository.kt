package com.roundcaddy.android.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder

class DataRepository(
    private val client: SupabaseClient,
    private val authRepository: AuthRepository
) {
    suspend fun fetchRounds(userId: String, limit: Int = 20): List<Round> =
        withContext(Dispatchers.IO) {
            val path = "/rest/v1/rounds?user_id=eq.$userId&order=played_at.desc&limit=$limit"
            val rounds = client.getJsonArray(path, authRepository.authHeaders())
            parseRounds(rounds)
        }

    suspend fun fetchHoleScores(roundId: String): List<HoleScore> = withContext(Dispatchers.IO) {
        val path = "/rest/v1/hole_scores?round_id=eq.$roundId&order=hole_number.asc"
        val response = client.getJsonArray(path, authRepository.authHeaders())
        parseHoleScores(response)
    }

    suspend fun fetchShots(roundId: String): List<Shot> = withContext(Dispatchers.IO) {
        val path = "/rest/v1/shots?round_id=eq.$roundId&order=hole_number.asc,shot_number.asc"
        val response = client.getJsonArray(path, authRepository.authHeaders())
        parseShots(response)
    }

    suspend fun fetchShot(shotId: String): Shot? = withContext(Dispatchers.IO) {
        val path = "/rest/v1/shots?id=eq.$shotId"
        val response = client.getJsonArray(path, authRepository.authHeaders())
        parseShots(response).firstOrNull()
    }

    suspend fun fetchRoundTrack(roundId: String): List<TrackPoint> = withContext(Dispatchers.IO) {
        val path = "/rest/v1/round_tracks?round_id=eq.$roundId"
        val response = client.getJsonArray(path, authRepository.authHeaders())
        if (response.length() == 0) return@withContext emptyList()
        val json = response.getJSONObject(0)
        val points = json.optJSONArray("track_points") ?: JSONArray()
        parseTrackPoints(points)
    }

    suspend fun fetchRound(id: String): Round? = withContext(Dispatchers.IO) {
        val path = "/rest/v1/rounds?id=eq.$id"
        val rounds = client.getJsonArray(path, authRepository.authHeaders())
        parseRounds(rounds).firstOrNull()
    }

    suspend fun fetchCourses(search: String? = null, country: String? = null, limit: Int = 50): List<Course> =
        withContext(Dispatchers.IO) {
            val query = mutableListOf("order=review_count.desc", "limit=$limit")
            if (!country.isNullOrBlank()) {
                query.add("country=eq.${URLEncoder.encode(country, "UTF-8")}")
            }
            if (!search.isNullOrBlank()) {
                query.add("name=ilike.*${URLEncoder.encode(search, "UTF-8")}*")
            }
            val path = "/rest/v1/courses?${query.joinToString("&")}"
            val courses = client.getJsonArray(path, mapOf("apikey" to client.anonKey))
            parseCourses(courses)
        }

    suspend fun fetchCourse(id: String): Course? = withContext(Dispatchers.IO) {
        val path = "/rest/v1/courses?id=eq.$id"
        val courses = client.getJsonArray(path, mapOf("apikey" to client.anonKey))
        parseCourses(courses).firstOrNull()
    }

    suspend fun fetchNearbyCourses(
        latitude: Double,
        longitude: Double,
        radiusMiles: Double = 50.0,
        limit: Int = 50
    ): List<Course> = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("p_latitude", latitude)
            .put("p_longitude", longitude)
            .put("p_radius_miles", radiusMiles)
            .put("p_limit", limit)
        return@withContext try {
            val response = client.postJsonArray(
                "/rest/v1/rpc/get_nearby_courses",
                headers = mapOf("apikey" to client.anonKey, "Content-Type" to "application/json"),
                body = body
            )
            parseCourses(response)
        } catch (error: Exception) {
            fetchNearbyCoursesFallback(latitude, longitude, radiusMiles)
        }
    }

    private suspend fun fetchNearbyCoursesFallback(
        latitude: Double,
        longitude: Double,
        radiusMiles: Double
    ): List<Course> = withContext(Dispatchers.IO) {
        val courses = fetchCourses(limit = 200)
        courses
            .filter { it.latitude != null && it.longitude != null }
            .filter {
                val dist = haversineDistance(latitude, longitude, it.latitude!!, it.longitude!!)
                dist <= radiusMiles
            }
            .sortedBy { haversineDistance(latitude, longitude, it.latitude!!, it.longitude!!) }
    }

    suspend fun fetchStats(userId: String): UserStats = withContext(Dispatchers.IO) {
        val rounds = fetchRounds(userId, 100)
        if (rounds.isEmpty()) return@withContext UserStats.empty
        val scores = rounds.map { it.totalScore }
        val sgTotals = rounds.mapNotNull { it.sgTotal }
        val sgOffTee = rounds.mapNotNull { it.sgOffTee }
        val sgApproach = rounds.mapNotNull { it.sgApproach }
        val sgAroundGreen = rounds.mapNotNull { it.sgAroundGreen }
        val sgPutting = rounds.mapNotNull { it.sgPutting }

        val fairwayData = rounds.mapNotNull { round ->
            val hit = round.fairwaysHit
            val total = round.fairwaysTotal
            if (hit != null && total != null && total > 0) Pair(hit, total) else null
        }
        val totalFairwaysHit = fairwayData.sumOf { it.first }
        val totalFairways = fairwayData.sumOf { it.second }
        val fairwayPercentage =
            if (totalFairways > 0) totalFairwaysHit.toDouble() / totalFairways * 100 else 0.0

        val girData = rounds.mapNotNull { it.gir }
        val totalGIR = girData.sum()
        val totalGreens = girData.size * 18
        val girPercentage = if (totalGreens > 0) totalGIR.toDouble() / totalGreens * 100 else 0.0

        val puttsData = rounds.map { it.totalPutts }
        val totalPutts = puttsData.sum()
        val totalHoles = puttsData.size * 18
        val puttsPerHole = if (totalHoles > 0) totalPutts.toDouble() / totalHoles else 0.0

        val scramblingPercentage = (sgAroundGreen.averageOrNull() ?: 0.0) * 10 + 50

        UserStats(
            roundsPlayed = rounds.size,
            averageScore = scores.average(),
            bestScore = scores.minOrNull() ?: 0,
            averageSG = sgTotals.averageOrNull() ?: 0.0,
            sgOffTee = sgOffTee.averageOrNull() ?: 0.0,
            sgApproach = sgApproach.averageOrNull() ?: 0.0,
            sgAroundGreen = sgAroundGreen.averageOrNull() ?: 0.0,
            sgPutting = sgPutting.averageOrNull() ?: 0.0,
            fairwayPercentage = fairwayPercentage,
            girPercentage = girPercentage,
            puttsPerHole = puttsPerHole,
            scramblingPercentage = scramblingPercentage.coerceIn(0.0, 100.0),
            handicapIndex = calculateHandicap(rounds)
        )
    }

    suspend fun confirmCourse(
        courseId: String,
        userId: String,
        dimensionsMatch: Boolean = true,
        teeLocationsMatch: Boolean = true,
        greenLocationsMatch: Boolean = true,
        hazardLocationsMatch: Boolean = true,
        confidenceLevel: Int = 3,
        discrepancyNotes: String? = null
    ) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("course_id", courseId)
            .put("user_id", userId)
            .put("dimensions_match", dimensionsMatch)
            .put("tee_locations_match", teeLocationsMatch)
            .put("green_locations_match", greenLocationsMatch)
            .put("hazard_locations_match", hazardLocationsMatch)
            .put("confidence_level", confidenceLevel)
        discrepancyNotes?.let { body.put("discrepancy_notes", it) }

        client.rawRequest(
            "POST",
            "/rest/v1/course_confirmations",
            headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
    }

    suspend fun fetchContributorLeaderboard(limit: Int = 50): List<ContributorStats> =
        withContext(Dispatchers.IO) {
            val path = "/rest/v1/contributor_reputation?order=reputation_score.desc&limit=$limit"
            val response = client.getJsonArray(path, authRepository.authHeaders())
            parseContributorStats(response)
        }

    suspend fun fetchNotifications(userId: String, limit: Int = 50): List<NotificationItem> =
        withContext(Dispatchers.IO) {
            val path = "/rest/v1/notifications?user_id=eq.$userId&order=created_at.desc&limit=$limit"
            val response = client.getJsonArray(path, authRepository.authHeaders())
            parseNotifications(response)
        }

    suspend fun markNotificationAsRead(notificationId: String) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("read", true)
            .put("read_at", isoNow())
        client.rawRequest(
            "PATCH",
            "/rest/v1/notifications?id=eq.$notificationId",
            headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
    }

    suspend fun markAllNotificationsAsRead(userId: String) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("read", true)
            .put("read_at", isoNow())
        client.rawRequest(
            "PATCH",
            "/rest/v1/notifications?user_id=eq.$userId&read=eq.false",
            headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
    }

    suspend fun fetchCourseDiscussions(courseId: String): List<CourseDiscussion> =
        withContext(Dispatchers.IO) {
            val path = "/rest/v1/course_discussions?course_id=eq.$courseId&order=created_at.desc"
            val response = client.getJsonArray(path, authRepository.authHeaders())
            parseCourseDiscussions(response)
        }

    suspend fun createCourseDiscussion(
        courseId: String,
        userId: String,
        title: String,
        content: String
    ) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("course_id", courseId)
            .put("user_id", userId)
            .put("title", title)
            .put("content", content)
        client.rawRequest(
            "POST",
            "/rest/v1/course_discussions",
            headers = authRepository.authHeaders() + mapOf(
                "Content-Type" to "application/json",
                "Prefer" to "return=representation"
            ),
            body = body.toString()
        )
    }

    suspend fun fetchDiscussionReplies(discussionId: String): List<DiscussionReply> =
        withContext(Dispatchers.IO) {
            val path = "/rest/v1/discussion_replies?discussion_id=eq.$discussionId&order=created_at.asc"
            val response = client.getJsonArray(path, authRepository.authHeaders())
            parseDiscussionReplies(response)
        }

    suspend fun replyToDiscussion(discussionId: String, userId: String, content: String) =
        withContext(Dispatchers.IO) {
            val body = JSONObject()
                .put("discussion_id", discussionId)
                .put("user_id", userId)
                .put("content", content)
            client.rawRequest(
                "POST",
                "/rest/v1/discussion_replies",
                headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
                body = body.toString()
            )
        }

    suspend fun searchOSMCourses(
        latitude: Double,
        longitude: Double,
        radius: Double = 5000.0
    ): List<OSMCourse> = withContext(Dispatchers.IO) {
        val query = """
            [out:json][timeout:25];
            (
              way["leisure"="golf_course"](around:${radius.toInt()},$latitude,$longitude);
              relation["leisure"="golf_course"](around:${radius.toInt()},$latitude,$longitude);
              node["leisure"="golf_course"](around:${radius.toInt()},$latitude,$longitude);
            );
            out center meta;
        """.trimIndent()
        val body = "data=${URLEncoder.encode(query, "UTF-8")}"
        val response = client.rawRequest(
            "POST",
            "https://overpass-api.de/api/interpreter",
            headers = mapOf("Content-Type" to "application/x-www-form-urlencoded"),
            body = body
        )
        val json = JSONObject(response)
        val elements = json.optJSONArray("elements") ?: JSONArray()
        parseOSMCourses(elements)
    }

    suspend fun contributeCourse(
        userId: String,
        name: String,
        country: String,
        holes: Int,
        latitude: Double,
        longitude: Double,
        city: String? = null,
        state: String? = null,
        address: String? = null,
        phone: String? = null,
        website: String? = null,
        courseRating: Double? = null,
        slopeRating: Int? = null,
        par: Int? = null
    ) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("contributor_id", userId)
            .put("name", name)
            .put("country", country)
            .put("holes", holes)
            .put("latitude", latitude)
            .put("longitude", longitude)
            .put("status", "pending")
        city?.let { body.put("city", it) }
        state?.let { body.put("state", it) }
        address?.let { body.put("address", it) }
        phone?.let { body.put("phone", it) }
        website?.let { body.put("website", it) }
        courseRating?.let { body.put("course_rating", it) }
        slopeRating?.let { body.put("slope_rating", it) }
        par?.let { body.put("par", it) }

        client.rawRequest(
            "POST",
            "/rest/v1/course_contributions",
            headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
    }

    suspend fun saveRound(
        userId: String,
        courseName: String,
        totalScore: Int,
        totalPutts: Int?,
        fairwaysHit: Int?,
        fairwaysTotal: Int?,
        gir: Int?,
        penalties: Int?,
        courseRating: Double?,
        slopeRating: Int?
    ): String = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("user_id", userId)
            .put("course_name", courseName)
            .put("played_at", isoNow().substring(0, 10))
            .put("total_score", totalScore)
            .put("total_putts", totalPutts)
            .put("fairways_hit", fairwaysHit)
            .put("fairways_total", fairwaysTotal)
            .put("gir", gir)
            .put("penalties", penalties)
            .put("course_rating", courseRating)
            .put("slope_rating", slopeRating)
            .put("scoring_format", "stroke")
        val response = client.rawRequest(
            "POST",
            "/rest/v1/rounds",
            headers = authRepository.authHeaders() + mapOf(
                "Content-Type" to "application/json",
                "Prefer" to "return=representation"
            ),
            body = body.toString()
        )
        val json = JSONArray(response)
        json.optJSONObject(0)?.optString("id") ?: throw IllegalStateException("Missing round id")
    }

    suspend fun saveHoleScores(roundId: String, holes: List<com.roundcaddy.android.round.HoleScoreState>) =
        withContext(Dispatchers.IO) {
            val payload = JSONArray()
            holes.forEach { hole ->
                val json = JSONObject()
                    .put("round_id", roundId)
                    .put("hole_number", hole.holeNumber)
                    .put("par", hole.par)
                    .put("score", hole.score)
                    .put("putts", hole.putts)
                    .put("fairway_hit", hole.fairwayHit)
                    .put("gir", hole.gir)
                    .put("penalties", hole.penalties)
                payload.put(json)
            }
            client.rawRequest(
                "POST",
                "/rest/v1/hole_scores",
                headers = authRepository.authHeaders() + mapOf(
                    "Content-Type" to "application/json",
                    "Prefer" to "return=representation"
                ),
                body = payload.toString()
            )
        }

    suspend fun saveShots(roundId: String, shots: List<com.roundcaddy.android.round.ShotState>) =
        withContext(Dispatchers.IO) {
            if (shots.isEmpty()) return@withContext
            val payload = JSONArray()
            shots.forEach { shot ->
                val json = JSONObject()
                    .put("round_id", roundId)
                    .put("hole_number", shot.holeNumber)
                    .put("shot_number", shot.shotNumber)
                    .put("club_name", shot.club)
                    .put("latitude", shot.latitude)
                    .put("longitude", shot.longitude)
                    .put("shot_time", shot.timestamp.toString())
                payload.put(json)
            }
            client.rawRequest(
                "POST",
                "/rest/v1/shots",
                headers = authRepository.authHeaders() + mapOf(
                    "Content-Type" to "application/json",
                    "Prefer" to "return=representation"
                ),
                body = payload.toString()
            )
        }

    suspend fun saveRoundTrack(roundId: String, points: List<TrackPoint>) = withContext(Dispatchers.IO) {
        if (points.isEmpty()) return@withContext
        val payload = JSONArray()
        points.forEach { point ->
            payload.put(
                JSONObject()
                    .put("lat", point.lat)
                    .put("lon", point.lon)
                    .put("timestamp", point.timestamp)
                    .put("accuracy", point.accuracy)
            )
        }
        val body = JSONObject()
            .put("round_id", roundId)
            .put("track_points", payload)
            .put("started_at", points.first().timestamp)
            .put("ended_at", points.last().timestamp)
        client.rawRequest(
            "POST",
            "/rest/v1/round_tracks",
            headers = authRepository.authHeaders() + mapOf(
                "Content-Type" to "application/json",
                "Prefer" to "return=representation"
            ),
            body = body.toString()
        )
    }

    suspend fun updateHoleScore(
        roundId: String,
        holeNumber: Int,
        score: Int,
        putts: Int,
        fairwayHit: Boolean?,
        gir: Boolean,
        penalties: Int
    ) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("score", score)
            .put("putts", putts)
            .put("fairway_hit", fairwayHit)
            .put("gir", gir)
            .put("penalties", penalties)
        client.rawRequest(
            "PATCH",
            "/rest/v1/hole_scores?round_id=eq.$roundId&hole_number=eq.$holeNumber",
            headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
    }

    suspend fun updateShot(
        shotId: String,
        clubName: String?,
        lie: String?,
        result: String?,
        distanceToPin: Int?
    ) = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("club_name", clubName)
            .put("lie", lie)
            .put("result", result)
            .put("distance_to_pin", distanceToPin)
        client.rawRequest(
            "PATCH",
            "/rest/v1/shots?id=eq.$shotId",
            headers = authRepository.authHeaders() + mapOf("Content-Type" to "application/json"),
            body = body.toString()
        )
    }

    suspend fun deleteShot(shotId: String) = withContext(Dispatchers.IO) {
        client.rawRequest(
            "DELETE",
            "/rest/v1/shots?id=eq.$shotId",
            headers = authRepository.authHeaders(),
            body = null
        )
    }

    private fun parseRounds(array: JSONArray): List<Round> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            Round(
                id = json.optString("id"),
                userId = json.optString("user_id"),
                courseName = json.optString("course_name"),
                courseRating = json.optDoubleOrNull("course_rating"),
                slopeRating = json.optIntOrNull("slope_rating"),
                playedAt = json.optString("played_at"),
                totalScore = json.optInt("total_score"),
                totalPutts = json.optInt("total_putts"),
                fairwaysHit = json.optIntOrNull("fairways_hit"),
                fairwaysTotal = json.optIntOrNull("fairways_total"),
                gir = json.optIntOrNull("gir"),
                penalties = json.optIntOrNull("penalties"),
                sgTotal = json.optDoubleOrNull("sg_total"),
                sgOffTee = json.optDoubleOrNull("sg_off_tee"),
                sgApproach = json.optDoubleOrNull("sg_approach"),
                sgAroundGreen = json.optDoubleOrNull("sg_around_green"),
                sgPutting = json.optDoubleOrNull("sg_putting"),
                notes = json.optString("notes").ifBlank { null }
            )
        }
    }

    private fun parseHoleScores(array: JSONArray): List<HoleScore> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            HoleScore(
                id = json.optString("id"),
                roundId = json.optString("round_id"),
                holeNumber = json.optInt("hole_number"),
                par = json.optInt("par"),
                score = json.optInt("score"),
                putts = json.optIntOrNull("putts") ?: 0,
                fairwayHit = if (json.isNull("fairway_hit")) null else json.optBoolean("fairway_hit"),
                gir = json.optBoolean("gir"),
                penalties = json.optIntOrNull("penalties") ?: 0,
                teeClub = json.optString("tee_club").ifBlank { null },
                approachDistance = json.optIntOrNull("approach_distance"),
                approachClub = json.optString("approach_club").ifBlank { null },
                approachResult = json.optString("approach_result").takeIf { it.isNotBlank() }?.let {
                    runCatching { ApproachResult.valueOf(it.uppercase()) }.getOrNull()
                },
                upAndDown = if (json.isNull("up_and_down")) null else json.optBoolean("up_and_down"),
                sandSave = if (json.isNull("sand_save")) null else json.optBoolean("sand_save"),
                firstPuttDistance = json.optIntOrNull("first_putt_distance"),
                sgOffTee = json.optDoubleOrNull("sg_off_tee"),
                sgApproach = json.optDoubleOrNull("sg_approach"),
                sgAroundGreen = json.optDoubleOrNull("sg_around_green"),
                sgPutting = json.optDoubleOrNull("sg_putting")
            )
        }
    }

    private fun parseShots(array: JSONArray): List<Shot> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            Shot(
                id = json.optString("id"),
                roundId = json.optString("round_id"),
                holeNumber = json.optInt("hole_number"),
                shotNumber = json.optInt("shot_number"),
                club = json.optString("club_name").ifBlank { null },
                latitude = json.optDoubleOrNull("latitude"),
                longitude = json.optDoubleOrNull("longitude"),
                distanceToPin = json.optIntOrNull("distance_to_pin"),
                lie = json.optString("lie").ifBlank { null },
                result = json.optString("result").ifBlank { null },
                shotTime = json.optString("shot_time")
            )
        }
    }

    private fun parseCourses(array: JSONArray): List<Course> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            val holeData = json.optJSONArray("hole_data")?.let { parseHoleData(it) }
            Course(
                id = json.optString("id"),
                name = json.optString("name"),
                city = json.optString("city").ifBlank { null },
                state = json.optString("state").ifBlank { null },
                country = json.optString("country").ifBlank { null },
                address = json.optString("address").ifBlank { null },
                phone = json.optString("phone").ifBlank { null },
                website = json.optString("website").ifBlank { null },
                courseRating = json.optDoubleOrNull("course_rating"),
                slopeRating = json.optIntOrNull("slope_rating"),
                par = json.optIntOrNull("par"),
                holes = json.optIntOrNull("holes"),
                latitude = json.optDoubleOrNull("latitude"),
                longitude = json.optDoubleOrNull("longitude"),
                avgRating = json.optDoubleOrNull("avg_rating"),
                reviewCount = json.optIntOrNull("review_count"),
                holeData = holeData
            )
        }
    }

    private fun parseContributorStats(array: JSONArray): List<ContributorStats> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            ContributorStats(
                userId = json.optString("user_id"),
                fullName = json.optString("full_name").ifBlank { null },
                reputationScore = json.optInt("reputation_score"),
                coursesAdded = json.optInt("courses_added"),
                coursesConfirmed = json.optInt("courses_confirmed")
            )
        }
    }

    private fun parseNotifications(array: JSONArray): List<NotificationItem> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            NotificationItem(
                id = json.optString("id"),
                userId = json.optString("user_id"),
                title = json.optString("title"),
                content = json.optString("content"),
                read = json.optBoolean("read"),
                createdAt = json.optString("created_at")
            )
        }
    }

    private fun parseCourseDiscussions(array: JSONArray): List<CourseDiscussion> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            CourseDiscussion(
                id = json.optString("id"),
                courseId = json.optString("course_id"),
                userId = json.optString("user_id"),
                title = json.optString("title"),
                content = json.optString("content"),
                createdAt = json.optString("created_at")
            )
        }
    }

    private fun parseDiscussionReplies(array: JSONArray): List<DiscussionReply> {
        return (0 until array.length()).map { index ->
            val json = array.getJSONObject(index)
            DiscussionReply(
                id = json.optString("id"),
                discussionId = json.optString("discussion_id"),
                userId = json.optString("user_id"),
                content = json.optString("content"),
                createdAt = json.optString("created_at")
            )
        }
    }

    private fun parseOSMCourses(array: JSONArray): List<OSMCourse> {
        return (0 until array.length()).mapNotNull { index ->
            val json = array.getJSONObject(index)
            val tags = json.optJSONObject("tags") ?: return@mapNotNull null
            val (lat, lon) = when {
                json.has("lat") && json.has("lon") -> Pair(json.optDouble("lat"), json.optDouble("lon"))
                json.has("center") -> {
                    val center = json.optJSONObject("center")
                    Pair(center?.optDouble("lat") ?: return@mapNotNull null, center.optDouble("lon"))
                }
                else -> return@mapNotNull null
            }
            OSMCourse(
                id = json.optInt("id"),
                name = tags.optString("name", "Unnamed Golf Course"),
                latitude = lat,
                longitude = lon,
                city = tags.optString("addr:city").ifBlank { null },
                state = tags.optString("addr:state").ifBlank { null },
                country = tags.optString("addr:country").ifBlank { null },
                address = listOf(
                    tags.optString("addr:housenumber").ifBlank { null },
                    tags.optString("addr:street").ifBlank { null }
                ).filterNotNull().joinToString(" ").ifBlank { null },
                phone = tags.optString("phone").ifBlank { null }
                    ?: tags.optString("contact:phone").ifBlank { null },
                website = tags.optString("website").ifBlank { null }
                    ?: tags.optString("contact:website").ifBlank { null }
            )
        }
    }

    private fun parseHoleData(array: JSONArray): List<HoleData> {
        return (0 until array.length()).mapNotNull { index ->
            val json = array.optJSONObject(index) ?: return@mapNotNull null
            val yardages = json.optJSONObject("yardages")?.let { obj ->
                obj.keys().asSequence().associateWith { key -> obj.optInt(key) }
            }
            HoleData(
                holeNumber = json.optInt("hole_number"),
                par = json.optInt("par"),
                yardages = yardages,
                greenCenter = json.optJSONObject("green_center")?.toCoordinate(),
                greenFront = json.optJSONObject("green_front")?.toCoordinate(),
                greenBack = json.optJSONObject("green_back")?.toCoordinate(),
                teeLocations = json.optJSONArray("tee_locations")?.let { parseTees(it) },
                fairway = json.optJSONArray("fairway")?.let { parsePolygon(it) },
                green = json.optJSONArray("green")?.let { parsePolygon(it) },
                rough = json.optJSONArray("rough")?.let { parsePolygon(it) },
                bunkers = json.optJSONArray("bunkers")?.let { parsePolygonFeatures(it) },
                waterHazards = json.optJSONArray("water_hazards")?.let { parsePolygonFeatures(it) },
                trees = json.optJSONArray("trees")?.let { parsePolygonFeatures(it) },
                yardageMarkers = json.optJSONArray("yardage_markers")?.let { parseYardageMarkers(it) }
            )
        }
    }

    private fun parseTees(array: JSONArray): List<TeeLocation> {
        return (0 until array.length()).mapNotNull { index ->
            val json = array.optJSONObject(index) ?: return@mapNotNull null
            val tee = json.optString("tee")
            val lat = json.optDouble("lat")
            val lon = json.optDouble("lon")
            if (tee.isBlank()) null else TeeLocation(tee = tee, lat = lat, lon = lon)
        }
    }

    private fun parsePolygon(array: JSONArray): List<Coordinate> {
        return (0 until array.length()).mapNotNull { index ->
            array.optJSONObject(index)?.toCoordinate()
        }
    }

    private fun parsePolygonFeatures(array: JSONArray): List<PolygonFeature> {
        return (0 until array.length()).mapNotNull { index ->
            val json = array.optJSONObject(index) ?: return@mapNotNull null
            val polygon = json.optJSONArray("polygon")?.let { parsePolygon(it) } ?: emptyList()
            if (polygon.isEmpty()) return@mapNotNull null
            PolygonFeature(
                type = json.optString("type").ifBlank { null },
                polygon = polygon
            )
        }
    }

    private fun parseYardageMarkers(array: JSONArray): List<YardageMarker> {
        return (0 until array.length()).mapNotNull { index ->
            val json = array.optJSONObject(index) ?: return@mapNotNull null
            YardageMarker(
                distance = json.optInt("distance"),
                lat = json.optDouble("lat"),
                lon = json.optDouble("lon")
            )
        }
    }

    private fun parseTrackPoints(array: JSONArray): List<TrackPoint> {
        return (0 until array.length()).mapNotNull { index ->
            val json = array.optJSONObject(index) ?: return@mapNotNull null
            val lat = json.optDouble("lat", Double.NaN)
            val lon = json.optDouble("lon", Double.NaN)
            if (lat.isNaN() || lon.isNaN()) return@mapNotNull null
            TrackPoint(
                lat = lat,
                lon = lon,
                timestamp = json.optString("timestamp"),
                accuracy = json.optDoubleOrNull("accuracy")
            )
        }
    }

    private fun haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 3959.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return r * c
    }

    private fun calculateHandicap(rounds: List<Round>): Double? {
        if (rounds.size < 3) return null
        val recent = rounds.take(20)
        val diffs = recent.mapNotNull { round ->
            val rating = round.courseRating ?: return@mapNotNull null
            val slope = round.slopeRating ?: return@mapNotNull null
            (round.totalScore - rating) * 113 / slope
        }.sorted()
        if (diffs.isEmpty()) return null
        val count = minOf(diffs.size, maxOf(1, diffs.size / 2))
        val best = diffs.take(count)
        return best.average() * 0.96
    }

    private fun isoNow(): String = java.time.Instant.now().toString()
}

private fun JSONArray.toList(): List<JSONObject> =
    (0 until length()).map { getJSONObject(it) }

private fun JSONObject.optDoubleOrNull(key: String): Double? =
    if (has(key) && !isNull(key)) optDouble(key) else null

private fun JSONObject.optIntOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) optInt(key) else null

private fun List<Double>.averageOrNull(): Double? = if (isEmpty()) null else average()

private fun JSONObject.toCoordinate(): Coordinate? {
    val lat = optDouble("lat", Double.NaN)
    val lon = optDouble("lon", Double.NaN)
    if (lat.isNaN() || lon.isNaN()) return null
    return Coordinate(lat = lat, lon = lon)
}
