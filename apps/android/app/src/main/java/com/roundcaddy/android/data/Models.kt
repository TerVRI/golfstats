package com.roundcaddy.android.data

data class User(
    val id: String,
    val email: String?,
    val fullName: String?,
    val avatarUrl: String?
)

data class Round(
    val id: String,
    val userId: String,
    val courseName: String,
    val courseRating: Double?,
    val slopeRating: Int?,
    val playedAt: String,
    val totalScore: Int,
    val totalPutts: Int,
    val fairwaysHit: Int?,
    val fairwaysTotal: Int?,
    val gir: Int?,
    val penalties: Int?,
    val sgTotal: Double?,
    val sgOffTee: Double?,
    val sgApproach: Double?,
    val sgAroundGreen: Double?,
    val sgPutting: Double?,
    val notes: String?
)

data class Shot(
    val id: String,
    val roundId: String,
    val holeNumber: Int,
    val shotNumber: Int,
    val club: String?,
    val latitude: Double?,
    val longitude: Double?,
    val distanceToPin: Int?,
    val lie: String?,
    val result: String?,
    val shotTime: String
)

data class TrackPoint(
    val lat: Double,
    val lon: Double,
    val timestamp: String,
    val accuracy: Double?
)

data class HoleScore(
    val id: String,
    val roundId: String,
    val holeNumber: Int,
    val par: Int,
    val score: Int,
    val putts: Int,
    val fairwayHit: Boolean?,
    val gir: Boolean,
    val penalties: Int,
    val teeClub: String?,
    val approachDistance: Int?,
    val approachClub: String?,
    val approachResult: ApproachResult?,
    val upAndDown: Boolean?,
    val sandSave: Boolean?,
    val firstPuttDistance: Int?,
    val sgOffTee: Double?,
    val sgApproach: Double?,
    val sgAroundGreen: Double?,
    val sgPutting: Double?
)

enum class ApproachResult {
    GREEN, FRINGE, GREENSIDE_ROUGH, BUNKER, SHORT, LONG, LEFT, RIGHT
}

data class HoleEntryData(
    val holeNumber: Int,
    val par: Int,
    val score: Int,
    val putts: Int,
    val fairwayHit: Boolean?,
    val gir: Boolean,
    val penalties: Int,
    val teeClub: String?,
    val approachDistance: Int?,
    val approachClub: String?,
    val approachResult: ApproachResult?,
    val firstPuttDistance: Int?
)

data class RoundEntryData(
    val courseName: String,
    val courseRating: Double?,
    val slopeRating: Int?,
    val playedAt: String,
    val notes: String?,
    val holes: List<HoleEntryData>
)

data class Course(
    val id: String,
    val name: String,
    val city: String?,
    val state: String?,
    val country: String?,
    val address: String?,
    val phone: String?,
    val website: String?,
    val courseRating: Double?,
    val slopeRating: Int?,
    val par: Int?,
    val holes: Int?,
    val latitude: Double?,
    val longitude: Double?,
    val avgRating: Double?,
    val reviewCount: Int?,
    val holeData: List<HoleData>? = null
)

data class Coordinate(
    val lat: Double,
    val lon: Double
)

data class TeeLocation(
    val tee: String,
    val lat: Double,
    val lon: Double
)

data class YardageMarker(
    val distance: Int,
    val lat: Double,
    val lon: Double
)

data class PolygonFeature(
    val type: String?,
    val polygon: List<Coordinate>
)

data class HoleData(
    val holeNumber: Int,
    val par: Int,
    val yardages: Map<String, Int>?,
    val greenCenter: Coordinate?,
    val greenFront: Coordinate?,
    val greenBack: Coordinate?,
    val teeLocations: List<TeeLocation>?,
    val fairway: List<Coordinate>?,
    val green: List<Coordinate>?,
    val rough: List<Coordinate>?,
    val bunkers: List<PolygonFeature>?,
    val waterHazards: List<PolygonFeature>?,
    val trees: List<PolygonFeature>?,
    val yardageMarkers: List<YardageMarker>?
)

data class Weather(
    val temperature: Int,
    val windSpeed: Int,
    val windDirection: String,
    val conditions: String,
    val icon: String,
    val humidity: Int,
    val precipitationProbability: Int,
    val isGoodForGolf: Boolean
)

data class UserStats(
    val roundsPlayed: Int,
    val averageScore: Double,
    val bestScore: Int,
    val averageSG: Double,
    val sgOffTee: Double,
    val sgApproach: Double,
    val sgAroundGreen: Double,
    val sgPutting: Double,
    val fairwayPercentage: Double,
    val girPercentage: Double,
    val puttsPerHole: Double,
    val scramblingPercentage: Double,
    val handicapIndex: Double?
) {
    companion object {
        val empty = UserStats(
            roundsPlayed = 0,
            averageScore = 0.0,
            bestScore = 0,
            averageSG = 0.0,
            sgOffTee = 0.0,
            sgApproach = 0.0,
            sgAroundGreen = 0.0,
            sgPutting = 0.0,
            fairwayPercentage = 0.0,
            girPercentage = 0.0,
            puttsPerHole = 0.0,
            scramblingPercentage = 0.0,
            handicapIndex = null
        )
    }
}

data class ContributorStats(
    val userId: String,
    val fullName: String?,
    val reputationScore: Int,
    val coursesAdded: Int,
    val coursesConfirmed: Int
)

data class NotificationItem(
    val id: String,
    val userId: String,
    val title: String,
    val content: String,
    val read: Boolean,
    val createdAt: String
)

data class CourseDiscussion(
    val id: String,
    val courseId: String,
    val userId: String,
    val title: String,
    val content: String,
    val createdAt: String
)

data class DiscussionReply(
    val id: String,
    val discussionId: String,
    val userId: String,
    val content: String,
    val createdAt: String
)

data class OSMCourse(
    val id: Int,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val city: String?,
    val state: String?,
    val country: String?,
    val address: String?,
    val phone: String?,
    val website: String?
)
