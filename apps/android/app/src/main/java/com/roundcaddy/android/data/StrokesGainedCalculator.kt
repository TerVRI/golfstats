package com.roundcaddy.android.data

data class StrokesGainedResult(
    val sgOffTee: Double,
    val sgApproach: Double,
    val sgAroundGreen: Double,
    val sgPutting: Double,
    val sgTotal: Double
)

object StrokesGainedCalculator {
    fun calculateHoleStrokesGained(hole: HoleEntryData, holeYardage: Int = 400): StrokesGainedResult {
        val par = hole.par
        val score = hole.score
        val putts = hole.putts
        val fairwayHit = hole.fairwayHit
        val gir = hole.gir
        val approachDistance = hole.approachDistance ?: estimateApproachDistance(par, holeYardage)
        val firstPuttDistance = hole.firstPuttDistance ?: estimateFirstPuttDistance(gir, score, par, putts)

        var sgOffTee = 0.0
        var sgApproach = 0.0
        var sgAroundGreen = 0.0
        var sgPutting = 0.0

        if (putts > 0 && firstPuttDistance > 0) {
            val expectedPutts = getExpectedPutts(firstPuttDistance)
            sgPutting = expectedPutts - putts
        }

        if (par >= 4) {
            val expectedFromTee = getExpectedFromTee(holeYardage)
            val expectedFromLie = when (fairwayHit) {
                true -> getExpectedFromFairway(approachDistance)
                false -> getExpectedFromRough(approachDistance)
                null -> (getExpectedFromFairway(approachDistance) + getExpectedFromRough(approachDistance)) / 2
            }
            sgOffTee = expectedFromTee - expectedFromLie - 1
        }

        if (approachDistance > 0) {
            val startingExpected = if (fairwayHit == true) {
                getExpectedFromFairway(approachDistance)
            } else {
                getExpectedFromRough(approachDistance)
            }
            sgApproach = if (gir) {
                val expectedOnGreen = getExpectedOnGreen(firstPuttDistance)
                startingExpected - expectedOnGreen - 1
            } else {
                val endingExpected = getExpectedFromMissedGreen(hole.approachResult, approachDistance)
                startingExpected - endingExpected - 1
            }
        }

        if (!gir) {
            val shotsAroundGreen = score - putts - if (par >= 4) 2 else 1
            if (shotsAroundGreen > 0) {
                val expectedFromAround = getExpectedFromChipPosition(hole.approachResult)
                val expectedOnGreen = getExpectedOnGreen(firstPuttDistance)
                sgAroundGreen = expectedFromAround - expectedOnGreen - shotsAroundGreen
            }
        }

        val total = sgOffTee + sgApproach + sgAroundGreen + sgPutting

        return StrokesGainedResult(
            sgOffTee = roundToHundredth(sgOffTee),
            sgApproach = roundToHundredth(sgApproach),
            sgAroundGreen = roundToHundredth(sgAroundGreen),
            sgPutting = roundToHundredth(sgPutting),
            sgTotal = roundToHundredth(total)
        )
    }

    fun calculateRoundStrokesGained(holes: List<HoleEntryData>, holeYardages: List<Int>? = null): StrokesGainedResult {
        var totalOffTee = 0.0
        var totalApproach = 0.0
        var totalAroundGreen = 0.0
        var totalPutting = 0.0
        var total = 0.0

        holes.forEachIndexed { index, hole ->
            val yardage = holeYardages?.getOrNull(index) ?: getDefaultYardage(hole.par)
            val result = calculateHoleStrokesGained(hole, yardage)
            totalOffTee += result.sgOffTee
            totalApproach += result.sgApproach
            totalAroundGreen += result.sgAroundGreen
            totalPutting += result.sgPutting
            total += result.sgTotal
        }

        return StrokesGainedResult(
            sgOffTee = roundToHundredth(totalOffTee),
            sgApproach = roundToHundredth(totalApproach),
            sgAroundGreen = roundToHundredth(totalAroundGreen),
            sgPutting = roundToHundredth(totalPutting),
            sgTotal = roundToHundredth(total)
        )
    }

    fun identifyWeakestArea(sg: StrokesGainedResult): Pair<String, String> {
        val areas = listOf(
            "Off the Tee" to sg.sgOffTee,
            "Approach" to sg.sgApproach,
            "Around the Green" to sg.sgAroundGreen,
            "Putting" to sg.sgPutting
        )
        val weakest = areas.minBy { it.second }
        val recommendation = when (weakest.first) {
            "Off the Tee" -> "Focus on driving accuracy and distance control"
            "Approach" -> "Work on iron play and distance control with approaches"
            "Around the Green" -> "Practice chipping, pitching, and bunker play"
            else -> "Focus on speed control and short putts"
        }
        return weakest.first to recommendation
    }

    fun identifyStrongestArea(sg: StrokesGainedResult): String {
        return listOf(
            "Off the Tee" to sg.sgOffTee,
            "Approach" to sg.sgApproach,
            "Around the Green" to sg.sgAroundGreen,
            "Putting" to sg.sgPutting
        ).maxBy { it.second }.first
    }

    private fun roundToHundredth(value: Double): Double = kotlin.math.round(value * 100) / 100

    private fun estimateApproachDistance(par: Int, holeYardage: Int): Int {
        val avgDrive = 250
        return when (par) {
            3 -> holeYardage
            4 -> (holeYardage - avgDrive).coerceAtLeast(50)
            5 -> 150
            else -> 150
        }
    }

    private fun estimateFirstPuttDistance(gir: Boolean, score: Int, par: Int, putts: Int): Int {
        if (gir) return 25
        if (score == par && putts == 1) return 3
        return 15
    }

    private fun getDefaultYardage(par: Int): Int = when (par) {
        3 -> 165
        4 -> 400
        5 -> 520
        else -> 400
    }

    private fun getExpectedFromMissedGreen(result: ApproachResult?, distance: Int): Double {
        return when (result) {
            ApproachResult.FRINGE -> 2.4
            ApproachResult.GREENSIDE_ROUGH -> 2.6
            ApproachResult.BUNKER -> getExpectedFromBunker(20)
            ApproachResult.SHORT,
            ApproachResult.LONG,
            ApproachResult.LEFT,
            ApproachResult.RIGHT,
            null -> 2.55
            else -> 2.55
        }
    }

    private fun getExpectedFromChipPosition(result: ApproachResult?): Double {
        return when (result) {
            ApproachResult.FRINGE -> 2.3
            ApproachResult.GREENSIDE_ROUGH -> 2.5
            ApproachResult.BUNKER -> 2.7
            else -> 2.5
        }
    }

    private fun getExpectedFromFairway(distance: Int): Double =
        StrokesGainedBenchmarks.interpolate(StrokesGainedBenchmarks.fairway, distance)

    private fun getExpectedFromRough(distance: Int): Double =
        StrokesGainedBenchmarks.interpolate(StrokesGainedBenchmarks.rough, distance)

    private fun getExpectedFromBunker(distance: Int): Double =
        StrokesGainedBenchmarks.interpolate(StrokesGainedBenchmarks.bunker, distance)

    private fun getExpectedPutts(distance: Int): Double =
        StrokesGainedBenchmarks.interpolate(StrokesGainedBenchmarks.putting, distance)

    private fun getExpectedOnGreen(distance: Int): Double =
        StrokesGainedBenchmarks.interpolate(StrokesGainedBenchmarks.onGreen, distance)

    private fun getExpectedFromTee(distance: Int): Double =
        StrokesGainedBenchmarks.interpolate(StrokesGainedBenchmarks.teeShot, distance)
}
