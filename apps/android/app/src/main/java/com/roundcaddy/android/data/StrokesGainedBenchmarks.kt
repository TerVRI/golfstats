package com.roundcaddy.android.data

object StrokesGainedBenchmarks {
    val teeShot = mapOf(
        100 to 2.92, 125 to 2.99, 150 to 3.08, 175 to 3.18, 200 to 3.32,
        225 to 3.45, 250 to 3.58, 275 to 3.71, 300 to 3.84, 325 to 3.97,
        350 to 4.08, 375 to 4.17, 400 to 4.28, 425 to 4.41, 450 to 4.54,
        475 to 4.69, 500 to 4.79, 525 to 4.96, 550 to 5.09, 575 to 5.24,
        600 to 5.39
    )

    val fairway = mapOf(
        25 to 2.40, 50 to 2.60, 75 to 2.72, 100 to 2.87, 125 to 2.95,
        150 to 3.00, 175 to 3.08, 200 to 3.19, 225 to 3.32, 250 to 3.48,
        275 to 3.65, 300 to 3.81
    )

    val rough = mapOf(
        25 to 2.53, 50 to 2.73, 75 to 2.86, 100 to 2.98, 125 to 3.08,
        150 to 3.17, 175 to 3.28, 200 to 3.42, 225 to 3.58, 250 to 3.75,
        275 to 3.92, 300 to 4.08
    )

    val bunker = mapOf(
        10 to 2.43, 20 to 2.53, 30 to 2.68, 40 to 2.83, 50 to 2.97,
        75 to 3.15, 100 to 3.32, 125 to 3.52, 150 to 3.72
    )

    val recovery = mapOf(
        25 to 2.77, 50 to 2.96, 75 to 3.12, 100 to 3.24, 125 to 3.38,
        150 to 3.51, 175 to 3.66, 200 to 3.82
    )

    val putting = mapOf(
        1 to 1.001, 2 to 1.009, 3 to 1.044, 4 to 1.115, 5 to 1.211,
        6 to 1.299, 7 to 1.373, 8 to 1.438, 9 to 1.495, 10 to 1.546,
        12 to 1.635, 14 to 1.710, 16 to 1.774, 18 to 1.829, 20 to 1.877,
        25 to 1.970, 30 to 2.040, 35 to 2.095, 40 to 2.140, 45 to 2.179,
        50 to 2.213, 60 to 2.267, 70 to 2.310, 80 to 2.346, 90 to 2.376
    )

    val onGreen = mapOf(
        5 to 1.26, 10 to 1.55, 15 to 1.72, 20 to 1.88, 25 to 1.97,
        30 to 2.04, 40 to 2.14, 50 to 2.22, 60 to 2.27
    )

    fun interpolate(benchmarks: Map<Int, Double>, distance: Int): Double {
        val distances = benchmarks.keys.sorted()
        if (distance <= distances.first()) return benchmarks.getValue(distances.first())
        if (distance >= distances.last()) return benchmarks.getValue(distances.last())
        val lower = distances.first { it <= distance }
        val upper = distances.first { it >= distance }
        if (lower == upper) return benchmarks.getValue(lower)
        val ratio = (distance - lower).toDouble() / (upper - lower)
        return benchmarks.getValue(lower) + ratio * (benchmarks.getValue(upper) - benchmarks.getValue(lower))
    }
}
