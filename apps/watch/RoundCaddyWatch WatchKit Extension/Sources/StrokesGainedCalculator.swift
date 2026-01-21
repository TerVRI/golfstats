import Foundation
import CoreLocation

/// Calculates Strokes Gained metrics based on PGA Tour benchmarks
/// Strokes Gained measures how many strokes better/worse a player performs compared to baseline
class StrokesGainedCalculator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var totalStrokesGained: Double = 0
    @Published var strokesGainedOffTee: Double = 0
    @Published var strokesGainedApproach: Double = 0
    @Published var strokesGainedAroundGreen: Double = 0
    @Published var strokesGainedPutting: Double = 0
    
    @Published var shotHistory: [StrokesGainedShot] = []
    
    // MARK: - PGA Tour Benchmark Data
    
    /// Expected strokes to hole out from various distances (yards) from fairway
    /// Based on PGA Tour averages
    static let fairwayBenchmarks: [Int: Double] = [
        450: 4.08, 425: 3.99, 400: 3.89, 375: 3.79, 350: 3.70,
        325: 3.60, 300: 3.50, 275: 3.40, 250: 3.30, 225: 3.19,
        200: 3.05, 190: 2.99, 180: 2.92, 170: 2.86, 160: 2.80,
        150: 2.75, 140: 2.70, 130: 2.65, 120: 2.60, 110: 2.55,
        100: 2.50, 90: 2.43, 80: 2.37, 70: 2.30, 60: 2.23,
        50: 2.17, 40: 2.10, 30: 2.03, 20: 2.00
    ]
    
    /// Expected strokes from rough (add penalty)
    static let roughPenalty: Double = 0.15
    
    /// Expected strokes from sand
    static let sandPenalty: Double = 0.40
    
    /// Expected putts from various distances (feet) on green
    static let puttingBenchmarks: [Int: Double] = [
        1: 1.00, 2: 1.01, 3: 1.04, 4: 1.08, 5: 1.13,
        6: 1.18, 7: 1.24, 8: 1.30, 9: 1.35, 10: 1.41,
        12: 1.50, 15: 1.61, 20: 1.74, 25: 1.84, 30: 1.92,
        35: 1.98, 40: 2.03, 50: 2.11, 60: 2.18, 90: 2.30
    ]
    
    // MARK: - Shot Categories
    
    enum ShotCategory: String, Codable {
        case teeShot = "Tee Shot"
        case approach = "Approach"
        case aroundGreen = "Around Green"  // < 30 yards
        case putting = "Putting"
        
        static func categorize(distanceToHole: Int, isOnGreen: Bool, isTeeShot: Bool) -> ShotCategory {
            if isOnGreen { return .putting }
            if isTeeShot { return .teeShot }
            if distanceToHole <= 30 { return .aroundGreen }
            return .approach
        }
    }
    
    enum LieType: String, Codable {
        case tee = "Tee"
        case fairway = "Fairway"
        case rough = "Rough"
        case sand = "Sand"
        case green = "Green"
        case recovery = "Recovery"
        
        var penalty: Double {
            switch self {
            case .tee, .fairway, .green: return 0
            case .rough: return StrokesGainedCalculator.roughPenalty
            case .sand: return StrokesGainedCalculator.sandPenalty
            case .recovery: return 0.50
            }
        }
    }
    
    // MARK: - Shot Record
    
    struct StrokesGainedShot: Identifiable, Codable {
        let id: UUID
        let holeNumber: Int
        let shotNumber: Int
        let category: ShotCategory
        let lie: LieType
        let distanceBefore: Int // yards (or feet for putting)
        let distanceAfter: Int
        let expectedBefore: Double
        let expectedAfter: Double
        let strokesGained: Double
        let timestamp: Date
        
        init(
            holeNumber: Int,
            shotNumber: Int,
            category: ShotCategory,
            lie: LieType,
            distanceBefore: Int,
            distanceAfter: Int,
            timestamp: Date = Date()
        ) {
            self.id = UUID()
            self.holeNumber = holeNumber
            self.shotNumber = shotNumber
            self.category = category
            self.lie = lie
            self.distanceBefore = distanceBefore
            self.distanceAfter = distanceAfter
            self.timestamp = timestamp
            
            // Calculate expected strokes
            self.expectedBefore = StrokesGainedCalculator.expectedStrokes(
                distance: distanceBefore,
                lie: lie,
                isOnGreen: category == .putting
            )
            
            // After shot, determine new lie (assume fairway unless we know better)
            let newLie: LieType = category == .putting ? .green : .fairway
            self.expectedAfter = distanceAfter == 0 ? 0 : StrokesGainedCalculator.expectedStrokes(
                distance: distanceAfter,
                lie: newLie,
                isOnGreen: distanceAfter <= 0 || category == .putting
            )
            
            // Strokes Gained = Expected Before - (1 + Expected After)
            // Positive = better than average, Negative = worse than average
            self.strokesGained = expectedBefore - 1 - expectedAfter
        }
    }
    
    // MARK: - Calculation Methods
    
    /// Calculate expected strokes to hole out
    static func expectedStrokes(distance: Int, lie: LieType, isOnGreen: Bool) -> Double {
        if distance <= 0 { return 0 }
        
        if isOnGreen {
            // Putting - distance is in feet
            return interpolatePutting(feet: distance)
        } else {
            // Full shots - distance is in yards
            let baseline = interpolateFairway(yards: distance)
            return baseline + lie.penalty
        }
    }
    
    /// Interpolate fairway benchmark
    private static func interpolateFairway(yards: Int) -> Double {
        let distances = fairwayBenchmarks.keys.sorted(by: >)
        
        // Find surrounding values
        var lower: Int?
        var upper: Int?
        
        for d in distances {
            if d >= yards {
                upper = d
            }
            if d <= yards && lower == nil {
                lower = d
            }
        }
        
        if let l = lower, let u = upper, l != u {
            // Interpolate
            let lVal = fairwayBenchmarks[l]!
            let uVal = fairwayBenchmarks[u]!
            let ratio = Double(yards - l) / Double(u - l)
            return lVal + (uVal - lVal) * ratio
        } else if let exact = fairwayBenchmarks[yards] {
            return exact
        } else if yards > 450 {
            // Extrapolate for long distances
            return 4.08 + Double(yards - 450) * 0.004
        } else if yards < 20 {
            return 2.0
        }
        
        return 2.5 // Default fallback
    }
    
    /// Interpolate putting benchmark
    private static func interpolatePutting(feet: Int) -> Double {
        let distances = puttingBenchmarks.keys.sorted()
        
        var lower: Int?
        var upper: Int?
        
        for d in distances {
            if d <= feet {
                lower = d
            }
            if d >= feet && upper == nil {
                upper = d
            }
        }
        
        if let l = lower, let u = upper, l != u {
            let lVal = puttingBenchmarks[l]!
            let uVal = puttingBenchmarks[u]!
            let ratio = Double(feet - l) / Double(u - l)
            return lVal + (uVal - lVal) * ratio
        } else if let exact = puttingBenchmarks[feet] {
            return exact
        } else if feet > 90 {
            return 2.30 + Double(feet - 90) * 0.01
        }
        
        return 1.0
    }
    
    // MARK: - Recording Shots
    
    /// Record a shot and calculate strokes gained
    func recordShot(
        holeNumber: Int,
        shotNumber: Int,
        distanceBefore: Int,
        distanceAfter: Int,
        lie: LieType,
        isOnGreen: Bool,
        isTeeShot: Bool
    ) -> StrokesGainedShot {
        let category = ShotCategory.categorize(
            distanceToHole: distanceBefore,
            isOnGreen: isOnGreen,
            isTeeShot: isTeeShot
        )
        
        let shot = StrokesGainedShot(
            holeNumber: holeNumber,
            shotNumber: shotNumber,
            category: category,
            lie: lie,
            distanceBefore: distanceBefore,
            distanceAfter: distanceAfter
        )
        
        shotHistory.append(shot)
        updateTotals()
        
        return shot
    }
    
    /// Record a holed putt
    func recordHoledPutt(holeNumber: Int, shotNumber: Int, distanceInFeet: Int) -> StrokesGainedShot {
        return recordShot(
            holeNumber: holeNumber,
            shotNumber: shotNumber,
            distanceBefore: distanceInFeet,
            distanceAfter: 0,
            lie: .green,
            isOnGreen: true,
            isTeeShot: false
        )
    }
    
    // MARK: - Totals
    
    private func updateTotals() {
        strokesGainedOffTee = shotHistory.filter { $0.category == .teeShot }.reduce(0) { $0 + $1.strokesGained }
        strokesGainedApproach = shotHistory.filter { $0.category == .approach }.reduce(0) { $0 + $1.strokesGained }
        strokesGainedAroundGreen = shotHistory.filter { $0.category == .aroundGreen }.reduce(0) { $0 + $1.strokesGained }
        strokesGainedPutting = shotHistory.filter { $0.category == .putting }.reduce(0) { $0 + $1.strokesGained }
        
        totalStrokesGained = strokesGainedOffTee + strokesGainedApproach + strokesGainedAroundGreen + strokesGainedPutting
    }
    
    /// Reset for new round
    func reset() {
        shotHistory.removeAll()
        totalStrokesGained = 0
        strokesGainedOffTee = 0
        strokesGainedApproach = 0
        strokesGainedAroundGreen = 0
        strokesGainedPutting = 0
    }
    
    // MARK: - Analysis
    
    /// Get shots for a specific hole
    func shots(forHole hole: Int) -> [StrokesGainedShot] {
        return shotHistory.filter { $0.holeNumber == hole }
    }
    
    /// Get average strokes gained per shot for a category
    func average(for category: ShotCategory) -> Double {
        let shots = shotHistory.filter { $0.category == category }
        guard !shots.isEmpty else { return 0 }
        return shots.reduce(0) { $0 + $1.strokesGained } / Double(shots.count)
    }
    
    /// Get best/worst shot
    var bestShot: StrokesGainedShot? {
        return shotHistory.max { $0.strokesGained < $1.strokesGained }
    }
    
    var worstShot: StrokesGainedShot? {
        return shotHistory.min { $0.strokesGained < $1.strokesGained }
    }
    
    /// Strength/weakness analysis
    var strongestCategory: ShotCategory? {
        let categories: [ShotCategory] = [.teeShot, .approach, .aroundGreen, .putting]
        return categories.max { average(for: $0) < average(for: $1) }
    }
    
    var weakestCategory: ShotCategory? {
        let categories: [ShotCategory] = [.teeShot, .approach, .aroundGreen, .putting]
        return categories.min { average(for: $0) < average(for: $1) }
    }
}
