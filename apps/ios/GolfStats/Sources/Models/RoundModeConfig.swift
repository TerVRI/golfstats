import Foundation

/// Configuration for different round tracking modes
/// Allows users to choose their preferred level of detail
enum RoundMode: String, CaseIterable, Codable {
    case quickScore = "quick_score"
    case fullTracking = "full_tracking"
    case tournament = "tournament"
    
    var displayName: String {
        switch self {
        case .quickScore: return "Quick Score"
        case .fullTracking: return "Full Tracking"
        case .tournament: return "Tournament"
        }
    }
    
    var description: String {
        switch self {
        case .quickScore:
            return "Just track scores. No GPS, no shot tracking - fastest way to log a round."
        case .fullTracking:
            return "GPS distances, shot tracking, and detailed statistics. Recommended for practice."
        case .tournament:
            return "Competition-ready with handicap tracking, attestation, and stroke index display."
        }
    }
    
    var icon: String {
        switch self {
        case .quickScore: return "pencil.and.list.clipboard"
        case .fullTracking: return "location.fill"
        case .tournament: return "trophy.fill"
        }
    }
    
    var features: RoundModeFeatures {
        switch self {
        case .quickScore:
            return RoundModeFeatures(
                gpsEnabled: false,
                shotTracking: false,
                clubSelection: false,
                statsTracking: false,
                puttsTracking: true,
                fairwayTracking: false,
                girTracking: false,
                watchSync: false,
                strokeIndex: false,
                handicapAdjustment: false,
                attestation: false
            )
        case .fullTracking:
            return RoundModeFeatures(
                gpsEnabled: true,
                shotTracking: true,
                clubSelection: true,
                statsTracking: true,
                puttsTracking: true,
                fairwayTracking: true,
                girTracking: true,
                watchSync: true,
                strokeIndex: false,
                handicapAdjustment: false,
                attestation: false
            )
        case .tournament:
            return RoundModeFeatures(
                gpsEnabled: true,
                shotTracking: true,
                clubSelection: true,
                statsTracking: true,
                puttsTracking: true,
                fairwayTracking: true,
                girTracking: true,
                watchSync: true,
                strokeIndex: true,
                handicapAdjustment: true,
                attestation: true
            )
        }
    }
    
    /// Whether this mode requires Pro subscription
    var requiresPro: Bool {
        switch self {
        case .quickScore: return false
        case .fullTracking: return false  // Available in grace period
        case .tournament: return true
        }
    }
    
    /// Minimum access level required
    var minimumAccessLevel: AccessLevel {
        switch self {
        case .quickScore: return .free
        case .fullTracking: return .gracePeriod
        case .tournament: return .pro
        }
    }
}

/// Features available in each round mode
struct RoundModeFeatures {
    let gpsEnabled: Bool
    let shotTracking: Bool
    let clubSelection: Bool
    let statsTracking: Bool
    let puttsTracking: Bool
    let fairwayTracking: Bool
    let girTracking: Bool
    let watchSync: Bool
    let strokeIndex: Bool           // Show stroke index on scorecard
    let handicapAdjustment: Bool    // Calculate playing handicap
    let attestation: Bool           // Require signature/attestation
}

/// User's preferred round settings
struct RoundPreferences: Codable {
    var defaultMode: RoundMode = .fullTracking
    var preferredTees: String = "White"
    var enableShotReminders: Bool = true
    var autoAdvanceHole: Bool = false
    var showYardageMarkers: Bool = true
    var showHazardWarnings: Bool = true
    var enableVoiceDistances: Bool = false
    var keepScreenOn: Bool = true
}

/// Access levels for tiered subscription model
enum AccessLevel: Int, Comparable, Codable {
    case free = 0           // After grace period, basic features only
    case gracePeriod = 1    // First 2 weeks, most features unlocked
    case trial = 2          // Free trial of Pro
    case pro = 3            // Full subscription
    
    static func < (lhs: AccessLevel, rhs: AccessLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .gracePeriod: return "Grace Period"
        case .trial: return "Pro Trial"
        case .pro: return "Pro"
        }
    }
}

/// Grace period configuration
struct GracePeriodConfig {
    static let durationDays: Int = 14
    static let trialDurationDays: Int = 7
    
    /// Features available during grace period (first 2 weeks)
    static let gracePeriodFeatures: Set<AppFeature> = [
        .gpsDistances,
        .fullScorecard,
        .basicStats,
        .shotTracking,
        .handicapEstimate,
        .watchGPS,
        .coursePreview,
        .roundStorage(limit: 3)
    ]
    
    /// Features available in permanent free tier
    static let freeFeatures: Set<AppFeature> = [
        .gpsDistances,
        .basicScorecard,
        .watchDistancesOnly,
        .roundStorage(limit: 3)
    ]
    
    /// Features only available with Pro
    static let proOnlyFeatures: Set<AppFeature> = [
        .strokesGained,
        .aiStrategy,
        .playsLikeDistances,
        .clubRecommendations,
        .unlimitedRounds,
        .advancedStats,
        .tournamentMode,
        .rangeMode,
        .dataExport
    ]
}

/// App features for access control
enum AppFeature: Hashable {
    case gpsDistances
    case fullScorecard
    case basicScorecard
    case basicStats
    case advancedStats
    case shotTracking
    case handicapEstimate
    case watchGPS
    case watchDistancesOnly
    case coursePreview
    case roundStorage(limit: Int)
    case unlimitedRounds
    case strokesGained
    case aiStrategy
    case playsLikeDistances
    case clubRecommendations
    case tournamentMode
    case rangeMode
    case dataExport
    
    var displayName: String {
        switch self {
        case .gpsDistances: return "GPS Distances"
        case .fullScorecard: return "Full Scorecard"
        case .basicScorecard: return "Basic Scorecard"
        case .basicStats: return "Basic Stats"
        case .advancedStats: return "Advanced Stats"
        case .shotTracking: return "Shot Tracking"
        case .handicapEstimate: return "Handicap Estimate"
        case .watchGPS: return "Apple Watch GPS"
        case .watchDistancesOnly: return "Watch Distances"
        case .coursePreview: return "Course Preview"
        case .roundStorage(let limit): return "Store \(limit) Rounds"
        case .unlimitedRounds: return "Unlimited Rounds"
        case .strokesGained: return "Strokes Gained"
        case .aiStrategy: return "AI Strategy"
        case .playsLikeDistances: return "Plays Like Distances"
        case .clubRecommendations: return "Club Recommendations"
        case .tournamentMode: return "Tournament Mode"
        case .rangeMode: return "Range Mode"
        case .dataExport: return "Data Export"
        }
    }
    
    var requiresPro: Bool {
        return GracePeriodConfig.proOnlyFeatures.contains(self)
    }
}
