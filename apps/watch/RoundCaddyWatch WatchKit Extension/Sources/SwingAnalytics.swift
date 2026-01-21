import Foundation
import CoreMotion

// MARK: - Swing Analytics Data Model

/// Complete analytics for a single golf swing
struct SwingAnalytics: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // MARK: - Timing & Tempo
    
    /// Total swing duration (address to follow-through) in seconds
    var totalDuration: TimeInterval
    
    /// Backswing duration in seconds
    var backswingDuration: TimeInterval
    
    /// Downswing duration in seconds (top to impact)
    var downswingDuration: TimeInterval
    
    /// Tempo ratio (backswing / downswing) - Pro average is ~3.0
    var tempoRatio: Double {
        guard downswingDuration > 0 else { return 0 }
        return backswingDuration / downswingDuration
    }
    
    /// Tempo rating based on ratio
    var tempoRating: TempoRating {
        switch tempoRatio {
        case 2.5..<3.5: return .excellent
        case 2.0..<2.5, 3.5..<4.0: return .good
        case 1.5..<2.0, 4.0..<4.5: return .needsWork
        default: return .poor
        }
    }
    
    // MARK: - Speed & Power
    
    /// Peak hand speed in mph (estimated from acceleration)
    var peakHandSpeed: Double
    
    /// Estimated clubhead speed in mph (hand speed * ~4 for driver)
    var estimatedClubheadSpeed: Double {
        // Clubhead speed is roughly 4x hand speed for driver, less for irons
        return peakHandSpeed * 4.0
    }
    
    /// Peak G-force during swing
    var peakGForce: Double
    
    /// Peak rotation rate (rad/s)
    var peakRotationRate: Double
    
    // MARK: - Impact Detection
    
    /// Whether ball impact was detected
    var impactDetected: Bool
    
    /// Timestamp of detected impact
    var impactTimestamp: Date?
    
    /// Deceleration spike at impact (G)
    var impactDeceleration: Double?
    
    // MARK: - Swing Path
    
    /// Swing path classification
    var swingPath: SwingPath
    
    /// Swing plane angle (degrees from vertical)
    var swingPlaneAngle: Double?
    
    // MARK: - Phase Timestamps
    
    var addressTime: Date?
    var backswingStartTime: Date?
    var topOfSwingTime: Date?
    var transitionTime: Date?
    var impactTime: Date?
    var followThroughTime: Date?
    
    // MARK: - Context
    
    /// Club used (if known)
    var club: String?
    
    /// Shot result distance (if measured)
    var resultDistance: Int?
    
    /// Swing type classification
    var swingType: SwingType
    
    // MARK: - Raw Data (for ML training)
    
    /// Raw acceleration samples during swing
    var accelerationSamples: [Double]?
    
    /// Raw rotation samples during swing
    var rotationSamples: [Double]?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        totalDuration: TimeInterval = 0,
        backswingDuration: TimeInterval = 0,
        downswingDuration: TimeInterval = 0,
        peakHandSpeed: Double = 0,
        peakGForce: Double = 0,
        peakRotationRate: Double = 0,
        impactDetected: Bool = false,
        swingPath: SwingPath = .neutral,
        swingType: SwingType = .unknown
    ) {
        self.id = id
        self.timestamp = timestamp
        self.totalDuration = totalDuration
        self.backswingDuration = backswingDuration
        self.downswingDuration = downswingDuration
        self.peakHandSpeed = peakHandSpeed
        self.peakGForce = peakGForce
        self.peakRotationRate = peakRotationRate
        self.impactDetected = impactDetected
        self.swingPath = swingPath
        self.swingType = swingType
    }
}

// MARK: - Tempo Rating

enum TempoRating: String, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case needsWork = "Needs Work"
    case poor = "Poor"
    
    var emoji: String {
        switch self {
        case .excellent: return "🎯"
        case .good: return "👍"
        case .needsWork: return "⚠️"
        case .poor: return "❌"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .needsWork: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - Swing Path

enum SwingPath: String, Codable, CaseIterable {
    case insideOut = "Inside-Out"
    case neutral = "Neutral"
    case overTheTop = "Over-the-Top"
    case unknown = "Unknown"
    
    var tip: String {
        switch self {
        case .insideOut:
            return "Promotes a draw. Watch for hooks."
        case .neutral:
            return "Great path! Promotes straight shots."
        case .overTheTop:
            return "Common slice cause. Try dropping hands in transition."
        case .unknown:
            return ""
        }
    }
}

// MARK: - Swing Phase

enum SwingPhase: String, Codable, CaseIterable {
    case idle = "Idle"
    case address = "Address"
    case backswing = "Backswing"
    case topOfSwing = "Top"
    case transition = "Transition"
    case downswing = "Downswing"
    case impact = "Impact"
    case followThrough = "Follow Through"
    case finished = "Finished"
    
    var next: SwingPhase? {
        switch self {
        case .idle: return .address
        case .address: return .backswing
        case .backswing: return .topOfSwing
        case .topOfSwing: return .transition
        case .transition: return .downswing
        case .downswing: return .impact
        case .impact: return .followThrough
        case .followThrough: return .finished
        case .finished: return nil
        }
    }
}

// MARK: - Club Distance Record

struct ClubDistanceRecord: Identifiable, Codable {
    let id: UUID
    let club: String
    let distance: Int // yards
    let timestamp: Date
    let swingSpeed: Double? // estimated clubhead speed
    
    init(club: String, distance: Int, swingSpeed: Double? = nil) {
        self.id = UUID()
        self.club = club
        self.distance = distance
        self.timestamp = Date()
        self.swingSpeed = swingSpeed
    }
}

// MARK: - Club Statistics

struct ClubStatistics: Codable {
    let club: String
    var totalShots: Int
    var averageDistance: Double
    var maxDistance: Int
    var minDistance: Int
    var standardDeviation: Double
    var distances: [Int]
    
    init(club: String) {
        self.club = club
        self.totalShots = 0
        self.averageDistance = 0
        self.maxDistance = 0
        self.minDistance = Int.max
        self.standardDeviation = 0
        self.distances = []
    }
    
    mutating func addDistance(_ distance: Int) {
        distances.append(distance)
        totalShots = distances.count
        
        // Calculate average
        averageDistance = Double(distances.reduce(0, +)) / Double(totalShots)
        
        // Update min/max
        maxDistance = distances.max() ?? 0
        minDistance = distances.min() ?? 0
        
        // Calculate standard deviation
        if totalShots > 1 {
            let sumOfSquaredDiffs = distances.reduce(0.0) { sum, dist in
                let diff = Double(dist) - averageDistance
                return sum + (diff * diff)
            }
            standardDeviation = sqrt(sumOfSquaredDiffs / Double(totalShots - 1))
        }
    }
    
    /// Consistency score (0-100) based on standard deviation
    var consistencyScore: Int {
        // Lower std dev = higher consistency
        // Assume 20 yards std dev is poor (0), 5 yards is excellent (100)
        let normalized = max(0, min(1, (20 - standardDeviation) / 15))
        return Int(normalized * 100)
    }
}

// MARK: - Session Statistics

struct SwingSessionStats: Codable {
    var totalSwings: Int = 0
    var averageTempo: Double = 0
    var averageHandSpeed: Double = 0
    var tempoConsistency: Double = 0 // std dev of tempo
    var speedConsistency: Double = 0 // std dev of hand speed
    
    private var tempoValues: [Double] = []
    private var speedValues: [Double] = []
    
    mutating func addSwing(_ analytics: SwingAnalytics) {
        totalSwings += 1
        
        // Add tempo
        if analytics.tempoRatio > 0 {
            tempoValues.append(analytics.tempoRatio)
            averageTempo = tempoValues.reduce(0, +) / Double(tempoValues.count)
            
            if tempoValues.count > 1 {
                let sumSquares = tempoValues.reduce(0.0) { $0 + pow($1 - averageTempo, 2) }
                tempoConsistency = sqrt(sumSquares / Double(tempoValues.count - 1))
            }
        }
        
        // Add speed
        if analytics.peakHandSpeed > 0 {
            speedValues.append(analytics.peakHandSpeed)
            averageHandSpeed = speedValues.reduce(0, +) / Double(speedValues.count)
            
            if speedValues.count > 1 {
                let sumSquares = speedValues.reduce(0.0) { $0 + pow($1 - averageHandSpeed, 2) }
                speedConsistency = sqrt(sumSquares / Double(speedValues.count - 1))
            }
        }
    }
    
    /// Overall consistency score (0-100)
    var overallConsistency: Int {
        guard totalSwings >= 3 else { return 0 }
        
        // Combine tempo and speed consistency
        // Lower variance = higher score
        let tempoScore = max(0, 100 - (tempoConsistency * 50))
        let speedScore = max(0, 100 - (speedConsistency * 5))
        
        return Int((tempoScore + speedScore) / 2)
    }
}

// MARK: - User Swing Preferences

struct SwingPreferences: Codable {
    /// Which wrist the watch is worn on
    var watchWrist: WatchWrist = .left
    
    /// Player's dominant hand (for lead wrist calculation)
    var dominantHand: DominantHand = .right
    
    /// Whether watch is on lead wrist (ideal for detection)
    var isWatchOnLeadWrist: Bool {
        // Lead wrist for right-handed = left wrist
        // Lead wrist for left-handed = right wrist
        switch (dominantHand, watchWrist) {
        case (.right, .left), (.left, .right):
            return true
        default:
            return false
        }
    }
    
    /// Detection sensitivity (0.5 = less sensitive, 1.5 = more sensitive)
    var sensitivity: Double = 1.0
    
    /// Enable audio feedback
    var audioFeedbackEnabled: Bool = false
    
    /// Enable haptic feedback
    var hapticFeedbackEnabled: Bool = true
    
    /// Auto-detect putts when near green
    var autoPuttingMode: Bool = true
    
    /// Practice mode (no shot counting, detailed metrics)
    var practiceMode: Bool = false
    
    /// Target tempo ratio (default: 3.0 like pros)
    var targetTempoRatio: Double = 3.0
    
    enum WatchWrist: String, Codable, CaseIterable {
        case left = "Left"
        case right = "Right"
    }
    
    enum DominantHand: String, Codable, CaseIterable {
        case left = "Left-Handed"
        case right = "Right-Handed"
    }
}

// MARK: - Coaching Tip

struct CoachingTip: Identifiable, Codable {
    let id: UUID
    let category: TipCategory
    let title: String
    let message: String
    let priority: Int // 1 = high, 3 = low
    let timestamp: Date
    
    enum TipCategory: String, Codable {
        case tempo = "Tempo"
        case speed = "Speed"
        case consistency = "Consistency"
        case path = "Path"
        case putting = "Putting"
        case general = "General"
    }
    
    init(category: TipCategory, title: String, message: String, priority: Int = 2) {
        self.id = UUID()
        self.category = category
        self.title = title
        self.message = message
        self.priority = priority
        self.timestamp = Date()
    }
}
