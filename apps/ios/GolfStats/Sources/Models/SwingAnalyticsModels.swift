import Foundation

// MARK: - Swing Analytics Models for iOS
// These models receive and store swing data synced from the Apple Watch

// MARK: - Swing Data

struct SwingRecord: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let club: String?
    let distance: Int?
    let tempo: Double?        // Backswing:Downswing ratio (e.g., 3.0 = 3:1)
    let peakHandSpeed: Double? // mph
    let impactQuality: Double? // 0-100
    let swingPath: SwingPath?
    let peakGForce: Double?
    let peakRotationRate: Double?
    
    init(id: String = UUID().uuidString,
         timestamp: Date = Date(),
         club: String? = nil,
         distance: Int? = nil,
         tempo: Double? = nil,
         peakHandSpeed: Double? = nil,
         impactQuality: Double? = nil,
         swingPath: SwingPath? = nil,
         peakGForce: Double? = nil,
         peakRotationRate: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.club = club
        self.distance = distance
        self.tempo = tempo
        self.peakHandSpeed = peakHandSpeed
        self.impactQuality = impactQuality
        self.swingPath = swingPath
        self.peakGForce = peakGForce
        self.peakRotationRate = peakRotationRate
    }
}

enum SwingPath: String, Codable {
    case inToOut = "in-to-out"
    case straight = "straight"
    case outToIn = "out-to-in"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .inToOut: return "In-to-Out"
        case .straight: return "Straight"
        case .outToIn: return "Out-to-In"
        case .unknown: return "Unknown"
        }
    }
    
    var description: String {
        switch self {
        case .inToOut: return "Draw bias - good for distance"
        case .straight: return "Neutral path - ideal"
        case .outToIn: return "Fade/slice tendency"
        case .unknown: return "Could not determine"
        }
    }
}

// MARK: - Club Distance Stats

struct ClubDistanceStats: Codable, Identifiable {
    let id: String
    let club: String
    var averageDistance: Int
    var minDistance: Int
    var maxDistance: Int
    var shotCount: Int
    var consistencyScore: Double // 0-100, higher = more consistent
    var lastUpdated: Date
    
    init(club: String,
         averageDistance: Int = 0,
         minDistance: Int = 0,
         maxDistance: Int = 0,
         shotCount: Int = 0,
         consistencyScore: Double = 0,
         lastUpdated: Date = Date()) {
        self.id = club
        self.club = club
        self.averageDistance = averageDistance
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.shotCount = shotCount
        self.consistencyScore = consistencyScore
        self.lastUpdated = lastUpdated
    }
    
    var range: Int {
        maxDistance - minDistance
    }
    
    var formattedAverage: String {
        "\(averageDistance) yds"
    }
}

// MARK: - Coaching Tip

struct WatchCoachingTip: Codable, Identifiable {
    let id: String
    let category: TipCategory
    let title: String
    let message: String
    let priority: Int // 1-3, 1 being highest
    let timestamp: Date
    
    enum TipCategory: String, Codable, CaseIterable {
        case tempo = "tempo"
        case consistency = "consistency"
        case speed = "speed"
        case path = "path"
        case putting = "putting"
        case general = "general"
        
        var icon: String {
            switch self {
            case .tempo: return "metronome"
            case .consistency: return "chart.bar"
            case .speed: return "gauge.with.needle"
            case .path: return "arrow.turn.right.down"
            case .putting: return "flag"
            case .general: return "lightbulb"
            }
        }
        
        var color: String {
            switch self {
            case .tempo: return "blue"
            case .consistency: return "green"
            case .speed: return "orange"
            case .path: return "purple"
            case .putting: return "teal"
            case .general: return "gray"
            }
        }
    }
    
    init(id: String = UUID().uuidString,
         category: TipCategory,
         title: String,
         message: String,
         priority: Int = 2,
         timestamp: Date = Date()) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.priority = priority
        self.timestamp = timestamp
    }
}

// MARK: - Session Summary

struct SwingSessionSummary: Codable, Identifiable {
    let id: String
    let roundId: String?
    let date: Date
    let totalSwings: Int
    let totalPutts: Int
    let averageTempo: Double?
    let averageHandSpeed: Double?
    let bestImpactQuality: Double?
    let clubsUsed: [String]
    let tips: [WatchCoachingTip]
    
    init(id: String = UUID().uuidString,
         roundId: String? = nil,
         date: Date = Date(),
         totalSwings: Int = 0,
         totalPutts: Int = 0,
         averageTempo: Double? = nil,
         averageHandSpeed: Double? = nil,
         bestImpactQuality: Double? = nil,
         clubsUsed: [String] = [],
         tips: [WatchCoachingTip] = []) {
        self.id = id
        self.roundId = roundId
        self.date = date
        self.totalSwings = totalSwings
        self.totalPutts = totalPutts
        self.averageTempo = averageTempo
        self.averageHandSpeed = averageHandSpeed
        self.bestImpactQuality = bestImpactQuality
        self.clubsUsed = clubsUsed
        self.tips = tips
    }
}

// MARK: - Strokes Gained from Watch

struct WatchStrokesGained: Codable {
    let offTee: Double
    let approach: Double
    let aroundGreen: Double
    let putting: Double
    
    var total: Double {
        offTee + approach + aroundGreen + putting
    }
    
    init(offTee: Double = 0, approach: Double = 0, aroundGreen: Double = 0, putting: Double = 0) {
        self.offTee = offTee
        self.approach = approach
        self.aroundGreen = aroundGreen
        self.putting = putting
    }
}

// MARK: - Live Swing Metrics (Real-time during swing)

struct LiveSwingMetrics: Codable {
    let tempo: Double?
    let backswingTime: Double?
    let downswingTime: Double?
    let peakHandSpeed: Double?
    let impactQuality: Double?
    let swingPath: SwingPath?
    let isSwingInProgress: Bool
    
    init(tempo: Double? = nil,
         backswingTime: Double? = nil,
         downswingTime: Double? = nil,
         peakHandSpeed: Double? = nil,
         impactQuality: Double? = nil,
         swingPath: SwingPath? = nil,
         isSwingInProgress: Bool = false) {
        self.tempo = tempo
        self.backswingTime = backswingTime
        self.downswingTime = downswingTime
        self.peakHandSpeed = peakHandSpeed
        self.impactQuality = impactQuality
        self.swingPath = swingPath
        self.isSwingInProgress = isSwingInProgress
    }
    
    var tempoRatio: String {
        guard let tempo = tempo else { return "--" }
        return String(format: "%.1f:1", tempo)
    }
    
    var handSpeedFormatted: String {
        guard let speed = peakHandSpeed else { return "--" }
        return String(format: "%.0f mph", speed)
    }
    
    var impactFormatted: String {
        guard let impact = impactQuality else { return "--" }
        return String(format: "%.0f%%", impact)
    }
}
