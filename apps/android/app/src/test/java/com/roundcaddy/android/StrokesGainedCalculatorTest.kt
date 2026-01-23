package com.roundcaddy.android

import com.roundcaddy.android.data.ApproachResult
import com.roundcaddy.android.data.HoleEntryData
import com.roundcaddy.android.data.StrokesGainedCalculator
import org.junit.Assert.assertEquals
import org.junit.Test

class StrokesGainedCalculatorTest {
    @Test
    fun calculateHoleStrokesGained_returnsTotals() {
        val hole = HoleEntryData(
            holeNumber = 1,
            par = 4,
            score = 4,
            putts = 2,
            fairwayHit = true,
            gir = true,
            penalties = 0,
            teeClub = "Driver",
            approachDistance = 150,
            approachClub = "7 Iron",
            approachResult = ApproachResult.GREEN,
            firstPuttDistance = 20
        )

        val result = StrokesGainedCalculator.calculateHoleStrokesGained(hole, 400)
        assertEquals(result.sgTotal, result.sgOffTee + result.sgApproach + result.sgAroundGreen + result.sgPutting, 0.01)
    }

    @Test
    fun calculateRoundStrokesGained_sumsHoles() {
        val hole = HoleEntryData(
            holeNumber = 1,
            par = 4,
            score = 5,
            putts = 2,
            fairwayHit = false,
            gir = false,
            penalties = 0,
            teeClub = "Driver",
            approachDistance = 140,
            approachClub = "8 Iron",
            approachResult = ApproachResult.GREENSIDE_ROUGH,
            firstPuttDistance = 10
        )
        val round = StrokesGainedCalculator.calculateRoundStrokesGained(listOf(hole, hole))
        assertEquals(round.sgTotal, round.sgOffTee + round.sgApproach + round.sgAroundGreen + round.sgPutting, 0.01)
    }
}
