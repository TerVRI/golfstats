package com.roundcaddy.android.round

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import com.roundcaddy.android.data.Course
import com.roundcaddy.android.data.HoleScore
import com.roundcaddy.android.data.Shot
import com.roundcaddy.android.data.TrackPoint
import java.time.Instant
import java.util.UUID

data class HoleScoreState(
    val holeNumber: Int,
    val par: Int,
    val score: Int,
    val putts: Int,
    val fairwayHit: Boolean?,
    val gir: Boolean,
    val penalties: Int
) {
    val relativeToPar: Int get() = score - par
    val scoreDescription: String
        get() = when (relativeToPar) {
            -3 -> "Albatross"
            -2 -> "Eagle"
            -1 -> "Birdie"
            0 -> "Par"
            1 -> "Bogey"
            2 -> "Double"
            else -> if (relativeToPar < -3) "Great!" else "+$relativeToPar"
        }
}

data class ShotState(
    val id: String,
    val holeNumber: Int,
    val shotNumber: Int,
    val club: String?,
    val latitude: Double?,
    val longitude: Double?,
    val timestamp: Instant
)

class RoundSessionViewModel : ViewModel() {
    var isRoundActive by mutableStateOf(false)
        private set
    var currentHole by mutableStateOf(1)
        private set
    var selectedCourse by mutableStateOf<Course?>(null)
        private set
    val holeScores = mutableStateListOf<HoleScoreState>()
    val shots = mutableStateListOf<ShotState>()
    val trackPoints = mutableStateListOf<TrackPoint>()

    val totalScore: Int
        get() = holeScores.sumOf { it.score }
    val totalPutts: Int
        get() = holeScores.sumOf { it.putts }
    val fairwaysHit: Int
        get() = holeScores.count { it.fairwayHit == true }
    val greensInRegulation: Int
        get() = holeScores.count { it.gir }
    val currentHoleScore: HoleScoreState?
        get() = holeScores.firstOrNull { it.holeNumber == currentHole }

    fun startRound(course: Course? = null) {
        selectedCourse = course
        isRoundActive = true
        currentHole = 1
        shots.clear()
        trackPoints.clear()
        holeScores.clear()
        val pars = course?.holeData?.sortedBy { it.holeNumber }?.map { it.par }
        (1..18).forEach { hole ->
            val par = pars?.getOrNull(hole - 1) ?: 4
            holeScores.add(
                HoleScoreState(
                    holeNumber = hole,
                    par = par,
                    score = par,
                    putts = 2,
                    fairwayHit = if (par == 3) null else false,
                    gir = false,
                    penalties = 0
                )
            )
        }
    }

    fun endRound() {
        isRoundActive = false
    }

    fun nextHole() {
        if (currentHole < 18) currentHole += 1
    }

    fun previousHole() {
        if (currentHole > 1) currentHole -= 1
    }

    fun goToHole(hole: Int) {
        if (hole in 1..18) currentHole = hole
    }

    fun incrementScore() {
        updateScore(currentHoleScore?.score?.plus(1) ?: 1)
    }

    fun decrementScore() {
        val current = currentHoleScore?.score ?: 1
        if (current > 1) updateScore(current - 1)
    }

    fun updateScore(score: Int) {
        updateCurrent { it.copy(score = score) }
    }

    fun updatePutts(putts: Int) {
        updateCurrent { it.copy(putts = putts.coerceAtLeast(0)) }
    }

    fun updatePenalties(penalties: Int) {
        updateCurrent { it.copy(penalties = penalties.coerceAtLeast(0)) }
    }

    fun toggleFairway() {
        updateCurrent { score ->
            val next = !(score.fairwayHit ?: false)
            score.copy(fairwayHit = if (score.par == 3) null else next)
        }
    }

    fun toggleGIR() {
        updateCurrent { score -> score.copy(gir = !score.gir) }
    }

    fun addShot(club: String?, latitude: Double?, longitude: Double?) {
        val shotNumber = shots.count { it.holeNumber == currentHole } + 1
        shots.add(
            ShotState(
                id = UUID.randomUUID().toString(),
                holeNumber = currentHole,
                shotNumber = shotNumber,
                club = club,
                latitude = latitude,
                longitude = longitude,
                timestamp = Instant.now()
            )
        )
    }

    fun shotsForCurrentHole(): List<ShotState> = shots.filter { it.holeNumber == currentHole }

    fun allHoleScores(): List<HoleScoreState> = holeScores.toList()

    fun allShots(): List<ShotState> = shots.toList()

    fun addTrackPoint(lat: Double, lon: Double, accuracy: Double?) {
        trackPoints.add(
            TrackPoint(
                lat = lat,
                lon = lon,
                timestamp = Instant.now().toString(),
                accuracy = accuracy
            )
        )
    }

    fun allTrackPoints(): List<TrackPoint> = trackPoints.toList()

    fun loadFromSaved(roundCourseName: String?, holes: List<HoleScore>, savedShots: List<Shot>) {
        selectedCourse = null
        isRoundActive = true
        currentHole = holes.minByOrNull { it.holeNumber }?.holeNumber ?: 1
        holeScores.clear()
        shots.clear()
        trackPoints.clear()

        holes.sortedBy { it.holeNumber }.forEach { hole ->
            holeScores.add(
                HoleScoreState(
                    holeNumber = hole.holeNumber,
                    par = hole.par,
                    score = hole.score,
                    putts = hole.putts,
                    fairwayHit = hole.fairwayHit,
                    gir = hole.gir,
                    penalties = hole.penalties
                )
            )
        }

        savedShots.sortedBy { it.shotNumber }.forEach { shot ->
            shots.add(
                ShotState(
                    id = shot.id,
                    holeNumber = shot.holeNumber,
                    shotNumber = shot.shotNumber,
                    club = shot.club,
                    latitude = shot.latitude,
                    longitude = shot.longitude,
                    timestamp = Instant.parse(shot.shotTime)
                )
            )
        }
    }

    private fun updateCurrent(transform: (HoleScoreState) -> HoleScoreState) {
        val index = holeScores.indexOfFirst { it.holeNumber == currentHole }
        if (index != -1) {
            holeScores[index] = transform(holeScores[index])
        }
    }
}
