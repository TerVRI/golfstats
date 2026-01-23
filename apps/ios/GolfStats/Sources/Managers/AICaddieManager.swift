import Foundation
import CoreLocation
import Combine

/// AI Caddie that provides smart recommendations based on player data and conditions
/// Features can be toggled on/off based on user preference and subscription level
class AICaddieManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AICaddieManager()
    
    // MARK: - Published State
    
    @Published var isEnabled = true
    @Published var settings = AICaddieSettings()
    @Published var currentRecommendation: CaddieRecommendation?
    @Published var isCalculating = false
    
    // MARK: - Private Properties
    
    private var playerProfile: PlayerProfile?
    private var clubDistances: [String: ClubStats] = [:]
    private var shotHistory: [HistoricalShot] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
        loadPlayerData()
    }
    
    // MARK: - Configuration
    
    func configure(playerProfile: PlayerProfile?, clubDistances: [String: ClubStats]) {
        self.playerProfile = playerProfile
        self.clubDistances = clubDistances
    }
    
    func loadShotHistory(_ shots: [HistoricalShot]) {
        self.shotHistory = shots
    }
    
    // MARK: - Recommendation Generation
    
    /// Get recommendation for current situation
    func getRecommendation(
        distanceToTarget: Int,
        currentHole: HoleContext,
        conditions: EnvironmentalConditions? = nil
    ) -> CaddieRecommendation {
        isCalculating = true
        defer { isCalculating = false }
        
        var recommendation = CaddieRecommendation()
        recommendation.distanceToTarget = distanceToTarget
        
        // 1. Club recommendation
        if settings.showClubRecommendation {
            recommendation.club = recommendClub(
                distance: distanceToTarget,
                conditions: conditions,
                lie: currentHole.currentLie
            )
        }
        
        // 2. "Plays Like" distance
        if settings.showPlaysLikeDistance, let conditions = conditions {
            recommendation.playsLikeDistance = calculatePlaysLikeDistance(
                actual: distanceToTarget,
                conditions: conditions,
                hole: currentHole
            )
        }
        
        // 3. Target recommendation
        if settings.showTargetRecommendation {
            recommendation.target = recommendTarget(
                distance: distanceToTarget,
                hole: currentHole
            )
        }
        
        // 4. Risk assessment
        if settings.showRiskAssessment {
            recommendation.riskAssessment = assessRisk(
                distance: distanceToTarget,
                hole: currentHole,
                club: recommendation.club
            )
        }
        
        // 5. Probability analysis
        if settings.showProbabilities {
            recommendation.probabilities = calculateProbabilities(
                distance: distanceToTarget,
                hole: currentHole,
                club: recommendation.club
            )
        }
        
        // 6. What-if scenarios
        if settings.showWhatIfAnalysis {
            recommendation.whatIfScenarios = generateWhatIfScenarios(
                distance: distanceToTarget,
                hole: currentHole
            )
        }
        
        // 7. Dispersion pattern
        if settings.showDispersionPattern, let club = recommendation.club {
            recommendation.dispersion = getDispersionPattern(for: club)
        }
        
        currentRecommendation = recommendation
        return recommendation
    }
    
    // MARK: - Club Recommendation
    
    private func recommendClub(
        distance: Int,
        conditions: EnvironmentalConditions?,
        lie: LieType
    ) -> ClubRecommendation {
        var adjustedDistance = Double(distance)
        
        // Apply environmental adjustments
        if let conditions = conditions, settings.adjustForWind {
            adjustedDistance = applyWindAdjustment(distance: adjustedDistance, conditions: conditions)
        }
        
        if let conditions = conditions, settings.adjustForElevation {
            adjustedDistance = applyElevationAdjustment(distance: adjustedDistance, elevation: conditions.elevationChange)
        }
        
        if let conditions = conditions, settings.adjustForTemperature {
            adjustedDistance = applyTemperatureAdjustment(distance: adjustedDistance, temp: conditions.temperature)
        }
        
        // Apply lie adjustment
        adjustedDistance = applyLieAdjustment(distance: adjustedDistance, lie: lie)
        
        // Find best club
        let (primaryClub, alternateClub) = findBestClubs(for: Int(adjustedDistance))
        
        return ClubRecommendation(
            primary: primaryClub,
            alternate: alternateClub,
            adjustedDistance: Int(adjustedDistance),
            reasoning: generateClubReasoning(
                original: distance,
                adjusted: Int(adjustedDistance),
                club: primaryClub
            )
        )
    }
    
    private func findBestClubs(for distance: Int) -> (String, String?) {
        var bestClub = "7 Iron"
        var bestDiff = Int.max
        var secondBest: String?
        var secondBestDiff = Int.max
        
        for (club, stats) in clubDistances {
            let diff = abs(stats.averageDistance - distance)
            
            if diff < bestDiff {
                secondBest = bestClub
                secondBestDiff = bestDiff
                bestClub = club
                bestDiff = diff
            } else if diff < secondBestDiff {
                secondBest = club
                secondBestDiff = diff
            }
        }
        
        return (bestClub, secondBest)
    }
    
    // MARK: - "Plays Like" Distance
    
    private func calculatePlaysLikeDistance(
        actual: Int,
        conditions: EnvironmentalConditions,
        hole: HoleContext
    ) -> PlaysLikeDistance {
        var adjusted = Double(actual)
        var factors: [DistanceFactor] = []
        
        // Wind adjustment
        let windAdjustment = calculateWindEffect(
            distance: Double(actual),
            windSpeed: conditions.windSpeed,
            windDirection: conditions.windDirection,
            shotDirection: hole.shotDirection
        )
        if abs(windAdjustment) > 0 {
            adjusted += windAdjustment
            factors.append(DistanceFactor(
                name: "Wind",
                adjustment: Int(windAdjustment),
                description: windAdjustment > 0 ? "Into wind" : "Downwind"
            ))
        }
        
        // Elevation
        let elevationAdjustment = conditions.elevationChange * 0.5 // ~1 yard per 2 feet
        if abs(elevationAdjustment) > 1 {
            adjusted += elevationAdjustment
            factors.append(DistanceFactor(
                name: "Elevation",
                adjustment: Int(elevationAdjustment),
                description: elevationAdjustment > 0 ? "Uphill" : "Downhill"
            ))
        }
        
        // Temperature (ball flies ~2 yards less per 10° below 70°F)
        let tempDiff = 70 - conditions.temperature
        let tempAdjustment = (tempDiff / 10) * 2
        if abs(tempAdjustment) > 1 {
            adjusted += tempAdjustment
            factors.append(DistanceFactor(
                name: "Temperature",
                adjustment: Int(tempAdjustment),
                description: tempAdjustment > 0 ? "Cold air" : "Warm air"
            ))
        }
        
        // Altitude
        if conditions.altitude > 3000 {
            let altitudeBonus = Double(actual) * 0.02 * (conditions.altitude / 3000)
            adjusted -= altitudeBonus // Ball goes farther at altitude
            factors.append(DistanceFactor(
                name: "Altitude",
                adjustment: -Int(altitudeBonus),
                description: "Higher altitude"
            ))
        }
        
        return PlaysLikeDistance(
            actualDistance: actual,
            playsLikeDistance: Int(adjusted),
            factors: factors
        )
    }
    
    private func calculateWindEffect(
        distance: Double,
        windSpeed: Double,
        windDirection: Double,
        shotDirection: Double
    ) -> Double {
        // Calculate relative wind angle
        let relativeAngle = (windDirection - shotDirection + 360).truncatingRemainder(dividingBy: 360)
        let radians = relativeAngle * .pi / 180
        
        // Headwind/tailwind component
        let headwindComponent = cos(radians) * windSpeed
        
        // ~1 yard per mph of headwind for 150 yard shot, scales with distance
        let effect = headwindComponent * (distance / 150) * 1.0
        
        return effect
    }
    
    // MARK: - Target Recommendation
    
    private func recommendTarget(distance: Int, hole: HoleContext) -> TargetRecommendation {
        var target = TargetRecommendation()
        
        // Default to center of green/fairway
        target.aimPoint = .center
        target.reasoning = "Aim for the center for best margin of error"
        
        // Analyze hazards
        if let hazards = hole.hazards {
            let leftHazards = hazards.filter { $0.side == .left }
            let rightHazards = hazards.filter { $0.side == .right }
            
            if !leftHazards.isEmpty && rightHazards.isEmpty {
                target.aimPoint = .right
                target.reasoning = "Favor the right side to avoid hazards on the left"
            } else if !rightHazards.isEmpty && leftHazards.isEmpty {
                target.aimPoint = .left
                target.reasoning = "Favor the left side to avoid hazards on the right"
            }
        }
        
        // Consider pin position
        if let pinPosition = hole.pinPosition {
            target.pinPosition = pinPosition
            
            // Only go at pin if within comfortable range
            if distance < 150 && !hole.hasNearbyHazards(to: pinPosition) {
                target.aimPoint = pinPosition
                target.reasoning = "Pin is accessible - aim at it"
            }
        }
        
        return target
    }
    
    // MARK: - Risk Assessment
    
    private func assessRisk(distance: Int, hole: HoleContext, club: ClubRecommendation?) -> RiskAssessment {
        var assessment = RiskAssessment()
        
        // Base risk on distance
        if distance > 200 {
            assessment.overallRisk = .high
            assessment.factors.append("Long approach increases miss probability")
        } else if distance > 150 {
            assessment.overallRisk = .medium
        } else {
            assessment.overallRisk = .low
        }
        
        // Hazard risk
        if let hazards = hole.hazards {
            for hazard in hazards {
                if hazard.distanceToCarry < (distance + 20) {
                    assessment.factors.append("Water/bunker in play at \(hazard.distanceToCarry) yards")
                    assessment.overallRisk = .high
                }
            }
        }
        
        // Green complexity
        if hole.greenDifficulty == .hard {
            assessment.factors.append("Difficult green - consider laying up short")
        }
        
        return assessment
    }
    
    // MARK: - Probability Analysis
    
    private func calculateProbabilities(
        distance: Int,
        hole: HoleContext,
        club: ClubRecommendation?
    ) -> ShotProbabilities {
        // Base probabilities on historical data or defaults
        let profile = playerProfile ?? PlayerProfile.average
        
        // GIR probability decreases with distance
        let girBase: Double
        switch distance {
        case 0..<100: girBase = 0.70
        case 100..<150: girBase = 0.50
        case 150..<175: girBase = 0.35
        case 175..<200: girBase = 0.25
        default: girBase = 0.15
        }
        
        // Adjust for player skill
        let girProbability = girBase * profile.approachSkillMultiplier
        
        // Score probabilities based on GIR
        let birdieChance = girProbability * 0.15
        let parChance = girProbability * 0.65 + (1 - girProbability) * 0.35
        let bogeyChance = (1 - girProbability) * 0.45
        let otherChance = 1 - birdieChance - parChance - bogeyChance
        
        return ShotProbabilities(
            birdie: birdieChance,
            par: parChance,
            bogey: bogeyChance,
            doublePlus: max(0, otherChance),
            greenInRegulation: girProbability
        )
    }
    
    // MARK: - What-If Analysis
    
    private func generateWhatIfScenarios(distance: Int, hole: HoleContext) -> [WhatIfScenario] {
        var scenarios: [WhatIfScenario] = []
        
        // Scenario 1: Aggressive (go for it)
        let aggressive = WhatIfScenario(
            name: "Aggressive",
            description: "Go for the pin/green",
            expectedScore: calculateExpectedScore(distance: distance, aggressive: true, hole: hole),
            riskLevel: .high,
            potentialUpside: "Birdie chance",
            potentialDownside: "Risk of bogey or worse"
        )
        scenarios.append(aggressive)
        
        // Scenario 2: Conservative (play safe)
        let conservative = WhatIfScenario(
            name: "Conservative",
            description: "Play to safe area",
            expectedScore: calculateExpectedScore(distance: distance, aggressive: false, hole: hole),
            riskLevel: .low,
            potentialUpside: "High par probability",
            potentialDownside: "Fewer birdie chances"
        )
        scenarios.append(conservative)
        
        // Scenario 3: Layup (if applicable)
        if distance > 220 || hole.hasSignificantHazards {
            let layup = WhatIfScenario(
                name: "Layup",
                description: "Lay up to preferred yardage",
                expectedScore: calculateExpectedScore(distance: 100, aggressive: false, hole: hole) + 0.1,
                riskLevel: .veryLow,
                potentialUpside: "Eliminate big numbers",
                potentialDownside: "Adds a stroke"
            )
            scenarios.append(layup)
        }
        
        return scenarios
    }
    
    private func calculateExpectedScore(distance: Int, aggressive: Bool, hole: HoleContext) -> Double {
        let probs = calculateProbabilities(distance: distance, hole: hole, club: nil)
        
        // Weight scores: birdie=3, par=4, bogey=5, double=6
        var expected = probs.birdie * 3 + probs.par * 4 + probs.bogey * 5 + probs.doublePlus * 6
        
        // Adjust for aggressive play
        if aggressive {
            expected -= 0.1 // Slightly better when it works
        } else {
            expected += 0.05 // Slightly worse but safer
        }
        
        return expected
    }
    
    // MARK: - Dispersion Pattern
    
    private func getDispersionPattern(for club: ClubRecommendation) -> DispersionPattern {
        guard let stats = clubDistances[club.primary] else {
            return DispersionPattern.default
        }
        
        return DispersionPattern(
            centerDistance: stats.averageDistance,
            longDistance: stats.maxDistance,
            shortDistance: stats.minDistance,
            leftMiss: stats.leftMissPercentage,
            rightMiss: stats.rightMissPercentage,
            dispersionWidth: stats.dispersionWidth
        )
    }
    
    // MARK: - Adjustment Calculations
    
    private func applyWindAdjustment(distance: Double, conditions: EnvironmentalConditions) -> Double {
        // Simplified - would need shot direction for accuracy
        return distance + (conditions.windSpeed * 0.5)
    }
    
    private func applyElevationAdjustment(distance: Double, elevation: Double) -> Double {
        // ~1 yard per 3 feet of elevation change
        return distance + (elevation / 3)
    }
    
    private func applyTemperatureAdjustment(distance: Double, temp: Double) -> Double {
        let baseline: Double = 70
        let diff = baseline - temp
        // ~2% per 20 degrees
        return distance * (1 + (diff / 20) * 0.02)
    }
    
    private func applyLieAdjustment(distance: Double, lie: LieType) -> Double {
        switch lie {
        case .tee, .fairway:
            return distance
        case .rough:
            return distance * 0.9 // 10% reduction
        case .deepRough:
            return distance * 0.75 // 25% reduction
        case .bunker:
            return distance * 0.85 // 15% reduction
        case .other:
            return distance * 0.95
        }
    }
    
    private func generateClubReasoning(original: Int, adjusted: Int, club: String) -> String {
        let diff = adjusted - original
        
        if diff == 0 {
            return "Your \(club) averages the perfect distance"
        } else if diff > 0 {
            return "Playing \(diff) yards longer due to conditions"
        } else {
            return "Playing \(abs(diff)) yards shorter due to conditions"
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "ai_caddie_settings"),
           let settings = try? JSONDecoder().decode(AICaddieSettings.self, from: data) {
            self.settings = settings
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "ai_caddie_settings")
        }
    }
    
    private func loadPlayerData() {
        // Would load from persistent storage
    }
}

// MARK: - Data Models

struct AICaddieSettings: Codable {
    // Feature toggles
    var showClubRecommendation = true
    var showPlaysLikeDistance = true
    var showTargetRecommendation = true
    var showRiskAssessment = false
    var showProbabilities = false
    var showWhatIfAnalysis = false
    var showDispersionPattern = false
    
    // Adjustment toggles
    var adjustForWind = true
    var adjustForElevation = true
    var adjustForTemperature = false
    var adjustForAltitude = false
    
    // Display preferences
    var autoShowRecommendation = true
    var showOnlyWhenAsked = false
    var experienceLevel: CaddieExperienceLevel = .moderate
}

enum CaddieExperienceLevel: String, Codable, CaseIterable {
    case basic = "Basic"
    case moderate = "Moderate"
    case advanced = "Advanced"
    
    var description: String {
        switch self {
        case .basic: return "Club + distance only"
        case .moderate: return "Club, distance, and basic strategy"
        case .advanced: return "Full analysis with probabilities"
        }
    }
}

struct CaddieRecommendation {
    var distanceToTarget: Int = 0
    var club: ClubRecommendation?
    var playsLikeDistance: PlaysLikeDistance?
    var target: TargetRecommendation?
    var riskAssessment: RiskAssessment?
    var probabilities: ShotProbabilities?
    var whatIfScenarios: [WhatIfScenario] = []
    var dispersion: DispersionPattern?
}

struct ClubRecommendation {
    let primary: String
    let alternate: String?
    let adjustedDistance: Int
    let reasoning: String
}

struct PlaysLikeDistance {
    let actualDistance: Int
    let playsLikeDistance: Int
    let factors: [DistanceFactor]
    
    var difference: Int {
        playsLikeDistance - actualDistance
    }
}

struct DistanceFactor {
    let name: String
    let adjustment: Int
    let description: String
}

struct TargetRecommendation {
    var aimPoint: AimPoint = .center
    var pinPosition: AimPoint?
    var reasoning: String = ""
}

enum AimPoint: String {
    case left, center, right, frontLeft, frontRight, backLeft, backRight
}

struct RiskAssessment {
    var overallRisk: RiskLevel = .medium
    var factors: [String] = []
}

enum RiskLevel: String {
    case veryLow = "Very Low"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"
    
    var color: String {
        switch self {
        case .veryLow, .low: return "green"
        case .medium: return "yellow"
        case .high, .veryHigh: return "red"
        }
    }
}

struct ShotProbabilities {
    let birdie: Double
    let par: Double
    let bogey: Double
    let doublePlus: Double
    let greenInRegulation: Double
}

struct WhatIfScenario {
    let name: String
    let description: String
    let expectedScore: Double
    let riskLevel: RiskLevel
    let potentialUpside: String
    let potentialDownside: String
}

struct DispersionPattern {
    let centerDistance: Int
    let longDistance: Int
    let shortDistance: Int
    let leftMiss: Double
    let rightMiss: Double
    let dispersionWidth: Int
    
    static let `default` = DispersionPattern(
        centerDistance: 150,
        longDistance: 160,
        shortDistance: 140,
        leftMiss: 0.3,
        rightMiss: 0.3,
        dispersionWidth: 30
    )
}

struct ClubStats {
    let averageDistance: Int
    let maxDistance: Int
    let minDistance: Int
    let leftMissPercentage: Double
    let rightMissPercentage: Double
    let dispersionWidth: Int
}

struct EnvironmentalConditions {
    var windSpeed: Double = 0
    var windDirection: Double = 0
    var temperature: Double = 70
    var humidity: Double = 50
    var altitude: Double = 0
    var elevationChange: Double = 0
}

struct HoleContext {
    var holeNumber: Int
    var par: Int
    var shotDirection: Double = 0
    var currentLie: LieType = .fairway
    var pinPosition: AimPoint?
    var hazards: [HazardInfo]?
    var greenDifficulty: Difficulty = .medium
    var hasSignificantHazards: Bool = false
    
    func hasNearbyHazards(to position: AimPoint) -> Bool {
        guard let hazards = hazards else { return false }
        return hazards.contains { $0.side == position.side }
    }
}

extension AimPoint {
    var side: HazardSide? {
        switch self {
        case .left, .frontLeft, .backLeft: return .left
        case .right, .frontRight, .backRight: return .right
        case .center: return nil
        }
    }
}

struct HazardInfo {
    let type: HazardType
    let side: HazardSide
    let distanceToCarry: Int
}

enum HazardSide {
    case left, right, front, back
}

enum Difficulty {
    case easy, medium, hard
}

enum LieType: String {
    case tee, fairway, rough, deepRough, bunker, other
}

struct HistoricalShot {
    let club: String
    let distance: Int
    let result: ShotResult
    let conditions: EnvironmentalConditions?
}

enum ShotResult {
    case good, average, poor
}

struct PlayerProfile {
    var handicap: Double = 15
    var approachSkillMultiplier: Double = 1.0
    var drivingAccuracy: Double = 0.5
    var puttingSkill: Double = 1.0
    
    static let average = PlayerProfile()
}

// MARK: - SwiftUI Views

import SwiftUI

struct AICaddieSettingsView: View {
    @ObservedObject var caddieManager = AICaddieManager.shared
    @State private var settings: AICaddieSettings
    
    init() {
        _settings = State(initialValue: AICaddieManager.shared.settings)
    }
    
    var body: some View {
        Form {
            Section("Experience Level") {
                Picker("Level", selection: $settings.experienceLevel) {
                    ForEach(CaddieExperienceLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.rawValue)
                            Text(level.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(level)
                    }
                }
                .onChange(of: settings.experienceLevel) { _, level in
                    applyExperiencePreset(level)
                }
            }
            
            Section("Features") {
                Toggle("Club Recommendation", isOn: $settings.showClubRecommendation)
                Toggle("\"Plays Like\" Distance", isOn: $settings.showPlaysLikeDistance)
                Toggle("Target Recommendation", isOn: $settings.showTargetRecommendation)
                Toggle("Risk Assessment", isOn: $settings.showRiskAssessment)
                Toggle("Score Probabilities", isOn: $settings.showProbabilities)
                Toggle("What-If Analysis", isOn: $settings.showWhatIfAnalysis)
                Toggle("Dispersion Pattern", isOn: $settings.showDispersionPattern)
            }
            
            Section("Distance Adjustments") {
                Toggle("Adjust for Wind", isOn: $settings.adjustForWind)
                Toggle("Adjust for Elevation", isOn: $settings.adjustForElevation)
                Toggle("Adjust for Temperature", isOn: $settings.adjustForTemperature)
                Toggle("Adjust for Altitude", isOn: $settings.adjustForAltitude)
            }
            
            Section("Display") {
                Toggle("Auto-show Recommendations", isOn: $settings.autoShowRecommendation)
                Toggle("Only Show When Asked", isOn: $settings.showOnlyWhenAsked)
            }
            
            Section {
                Text("The AI Caddie analyzes your game and conditions to provide smart recommendations. More features can be enabled as you become comfortable with the analysis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AI Caddie")
        .onDisappear {
            caddieManager.settings = settings
            caddieManager.saveSettings()
        }
    }
    
    private func applyExperiencePreset(_ level: CaddieExperienceLevel) {
        switch level {
        case .basic:
            settings.showClubRecommendation = true
            settings.showPlaysLikeDistance = true
            settings.showTargetRecommendation = false
            settings.showRiskAssessment = false
            settings.showProbabilities = false
            settings.showWhatIfAnalysis = false
            settings.showDispersionPattern = false
            
        case .moderate:
            settings.showClubRecommendation = true
            settings.showPlaysLikeDistance = true
            settings.showTargetRecommendation = true
            settings.showRiskAssessment = true
            settings.showProbabilities = false
            settings.showWhatIfAnalysis = false
            settings.showDispersionPattern = false
            
        case .advanced:
            settings.showClubRecommendation = true
            settings.showPlaysLikeDistance = true
            settings.showTargetRecommendation = true
            settings.showRiskAssessment = true
            settings.showProbabilities = true
            settings.showWhatIfAnalysis = true
            settings.showDispersionPattern = true
        }
    }
}

/// Compact AI Caddie recommendation card
struct AICaddieCard: View {
    let recommendation: CaddieRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    
                    Text("AI Caddie")
                        .font(.headline)
                    
                    Spacer()
                    
                    if let club = recommendation.club {
                        Text(club.primary)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 16) {
                    // Plays Like Distance
                    if let playsLike = recommendation.playsLikeDistance {
                        PlaysLikeRow(playsLike: playsLike)
                    }
                    
                    // Club recommendation detail
                    if let club = recommendation.club {
                        ClubRecommendationRow(club: club)
                    }
                    
                    // Risk assessment
                    if let risk = recommendation.riskAssessment {
                        RiskAssessmentRow(risk: risk)
                    }
                    
                    // Probabilities
                    if let probs = recommendation.probabilities {
                        ProbabilityRow(probabilities: probs)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PlaysLikeRow: View {
    let playsLike: PlaysLikeDistance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Plays Like")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(playsLike.playsLikeDistance)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if playsLike.difference != 0 {
                        Text("(\(playsLike.difference > 0 ? "+" : "")\(playsLike.difference))")
                            .font(.caption)
                            .foregroundStyle(playsLike.difference > 0 ? .red : .green)
                    }
                }
            }
            
            // Factors
            ForEach(playsLike.factors, id: \.name) { factor in
                HStack {
                    Text(factor.name)
                        .font(.caption)
                    Spacer()
                    Text("\(factor.adjustment > 0 ? "+" : "")\(factor.adjustment)")
                        .font(.caption)
                        .foregroundStyle(factor.adjustment > 0 ? .red : .green)
                }
            }
        }
    }
}

struct ClubRecommendationRow: View {
    let club: ClubRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recommended")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(club.primary)
                    .fontWeight(.bold)
            }
            
            Text(club.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let alternate = club.alternate {
                Text("Alternative: \(alternate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RiskAssessmentRow: View {
    let risk: RiskAssessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Risk Level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(risk.overallRisk.rawValue)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(riskColor)
            }
            
            ForEach(risk.factors, id: \.self) { factor in
                Text("• \(factor)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    var riskColor: Color {
        switch risk.overallRisk {
        case .veryLow, .low: return .green
        case .medium: return .yellow
        case .high, .veryHigh: return .red
        }
    }
}

struct ProbabilityRow: View {
    let probabilities: ShotProbabilities
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Probabilities")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                ProbabilityChip(label: "Birdie", value: probabilities.birdie, color: .red)
                ProbabilityChip(label: "Par", value: probabilities.par, color: .white)
                ProbabilityChip(label: "Bogey", value: probabilities.bogey, color: .blue)
            }
        }
    }
}

struct ProbabilityChip: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value * 100))%")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
