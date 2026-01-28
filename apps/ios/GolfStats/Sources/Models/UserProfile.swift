import Foundation

// MARK: - User Profile Model

/// Complete user profile with all personalization settings
struct UserProfile: Codable, Equatable {
    var id: String
    var userId: String
    
    // Personal Information
    var birthday: Date?
    var gender: Gender?
    var handedness: Handedness = .right
    
    // Golf-Specific Info
    var handicapIndex: Double?
    var targetHandicap: Double?
    var skillLevel: SkillLevel = .intermediate
    var driverDistance: Int = 220
    var playingFrequency: PlayingFrequency = .occasional
    var preferredTees: TeeColor = .white
    
    // App Preferences
    var distanceUnit: DistanceUnit = .yards
    var temperatureUnit: TemperatureUnit = .fahrenheit
    var speedUnit: SpeedUnit = .mph
    
    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var onboardingCompleted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case birthday
        case gender
        case handedness
        case handicapIndex = "handicap_index"
        case targetHandicap = "target_handicap"
        case skillLevel = "skill_level"
        case driverDistance = "driver_distance"
        case playingFrequency = "playing_frequency"
        case preferredTees = "preferred_tees"
        case distanceUnit = "distance_unit"
        case temperatureUnit = "temperature_unit"
        case speedUnit = "speed_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case onboardingCompleted = "onboarding_completed"
    }
    
    /// Create a new profile for a user
    static func new(userId: String) -> UserProfile {
        return UserProfile(
            id: UUID().uuidString,
            userId: userId
        )
    }
    
    /// Calculate age from birthday
    var age: Int? {
        guard let birthday = birthday else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year], from: birthday, to: now)
        return components.year
    }
    
    /// Returns average score based on handicap index
    var estimatedAverageScore: Int? {
        guard let handicap = handicapIndex else { return nil }
        // Par 72 + handicap is a rough estimate
        return 72 + Int(handicap.rounded())
    }
}

// MARK: - Enums

enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
    
    /// For comparison/analytics grouping
    var comparisonGroup: String {
        switch self {
        case .male: return "Male Golfers"
        case .female: return "Female Golfers"
        case .other, .preferNotToSay: return "All Golfers"
        }
    }
}

enum Handedness: String, Codable, CaseIterable {
    case right = "right"
    case left = "left"
    
    var displayName: String {
        switch self {
        case .right: return "Right-Handed"
        case .left: return "Left-Handed"
        }
    }
    
    var shortName: String {
        switch self {
        case .right: return "RH"
        case .left: return "LH"
        }
    }
}

enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case casual = "casual"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    case tourPro = "tour_pro"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .casual: return "Casual"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        case .tourPro: return "Tour Pro"
        }
    }
    
    var description: String {
        switch self {
        case .beginner: return "New to golf, still learning basics"
        case .casual: return "Play occasionally for fun"
        case .intermediate: return "Regular golfer, working on improvement"
        case .advanced: return "Serious golfer, single-digit handicap"
        case .expert: return "Scratch or better"
        case .tourPro: return "Professional golfer"
        }
    }
    
    /// Approximate handicap range for this skill level
    var handicapRange: ClosedRange<Double> {
        switch self {
        case .beginner: return 30...54
        case .casual: return 20...30
        case .intermediate: return 10...20
        case .advanced: return 5...10
        case .expert: return 0...5
        case .tourPro: return -5...0
        }
    }
    
    /// Initialize from handicap
    static func from(handicap: Double) -> SkillLevel {
        for level in SkillLevel.allCases {
            if level.handicapRange.contains(handicap) {
                return level
            }
        }
        return .intermediate
    }
}

enum PlayingFrequency: String, Codable, CaseIterable {
    case rarely = "rarely"          // 1-5 rounds/year
    case occasional = "occasional"   // 6-15 rounds/year
    case regular = "regular"         // 16-30 rounds/year
    case frequent = "frequent"       // 31-50 rounds/year
    case veryFrequent = "very_frequent" // 51+ rounds/year
    
    var displayName: String {
        switch self {
        case .rarely: return "Rarely"
        case .occasional: return "Occasionally"
        case .regular: return "Regularly"
        case .frequent: return "Frequently"
        case .veryFrequent: return "Very Frequently"
        }
    }
    
    var description: String {
        switch self {
        case .rarely: return "1-5 rounds per year"
        case .occasional: return "6-15 rounds per year"
        case .regular: return "16-30 rounds per year"
        case .frequent: return "31-50 rounds per year"
        case .veryFrequent: return "51+ rounds per year"
        }
    }
    
    var roundsPerYear: Int {
        switch self {
        case .rarely: return 3
        case .occasional: return 10
        case .regular: return 23
        case .frequent: return 40
        case .veryFrequent: return 60
        }
    }
    
    /// Slider value (0-100)
    var sliderValue: Double {
        switch self {
        case .rarely: return 10
        case .occasional: return 30
        case .regular: return 50
        case .frequent: return 70
        case .veryFrequent: return 90
        }
    }
    
    static func from(sliderValue: Double) -> PlayingFrequency {
        switch sliderValue {
        case 0..<20: return .rarely
        case 20..<40: return .occasional
        case 40..<60: return .regular
        case 60..<80: return .frequent
        default: return .veryFrequent
        }
    }
}

enum TeeColor: String, Codable, CaseIterable {
    case black = "black"
    case blue = "blue"
    case white = "white"
    case yellow = "yellow"
    case red = "red"
    case gold = "gold"
    case green = "green"
    
    var displayName: String {
        switch self {
        case .black: return "Black (Championship)"
        case .blue: return "Blue (Back)"
        case .white: return "White (Middle)"
        case .yellow: return "Yellow (Forward-Middle)"
        case .red: return "Red (Forward)"
        case .gold: return "Gold (Senior)"
        case .green: return "Green (Junior)"
        }
    }
    
    var shortName: String {
        rawValue.capitalized
    }
    
    var color: String {
        rawValue
    }
}

enum DistanceUnit: String, Codable, CaseIterable {
    case yards = "yards"
    case meters = "meters"
    
    var displayName: String {
        switch self {
        case .yards: return "Yards"
        case .meters: return "Meters"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .yards: return "yd"
        case .meters: return "m"
        }
    }
    
    /// Convert yards to this unit
    func convert(yards: Double) -> Double {
        switch self {
        case .yards: return yards
        case .meters: return yards * 0.9144
        }
    }
    
    /// Format a distance value
    func format(_ yards: Double) -> String {
        let value = convert(yards: yards)
        return "\(Int(value.rounded()))\(abbreviation)"
    }
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"
    
    var displayName: String {
        switch self {
        case .fahrenheit: return "Fahrenheit (°F)"
        case .celsius: return "Celsius (°C)"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }
    
    /// Convert fahrenheit to this unit
    func convert(fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: return fahrenheit
        case .celsius: return (fahrenheit - 32) * 5/9
        }
    }
    
    func format(_ fahrenheit: Double) -> String {
        let value = convert(fahrenheit: fahrenheit)
        return "\(Int(value.rounded()))\(abbreviation)"
    }
}

enum SpeedUnit: String, Codable, CaseIterable {
    case mph = "mph"
    case kph = "kph"
    case mps = "mps"
    
    var displayName: String {
        switch self {
        case .mph: return "Miles per hour"
        case .kph: return "Kilometers per hour"
        case .mps: return "Meters per second"
        }
    }
    
    var abbreviation: String {
        rawValue
    }
    
    /// Convert mph to this unit
    func convert(mph: Double) -> Double {
        switch self {
        case .mph: return mph
        case .kph: return mph * 1.60934
        case .mps: return mph * 0.44704
        }
    }
    
    func format(_ mph: Double) -> String {
        let value = convert(mph: mph)
        return "\(Int(value.rounded())) \(abbreviation)"
    }
}

// MARK: - App Settings Model

/// Global app settings (separate from user profile)
struct AppSettings: Codable, Equatable {
    // Notification Preferences
    var roundReminderEnabled: Bool = true
    var weatherAlertEnabled: Bool = true
    var teeTimeReminderEnabled: Bool = true
    var achievementNotificationsEnabled: Bool = true
    var socialNotificationsEnabled: Bool = true
    var marketingNotificationsEnabled: Bool = false
    
    // Sound & Haptics
    var soundEnabled: Bool = true
    var hapticFeedbackEnabled: Bool = true
    var voiceAnnouncementsEnabled: Bool = false
    
    // Privacy
    var shareRoundsPublicly: Bool = false
    var showOnLeaderboards: Bool = true
    var allowFriendRequests: Bool = true
    
    // Display
    var keepScreenOnDuringRound: Bool = true
    var autoAdvanceHole: Bool = false
    var showYardageMarkers: Bool = true
    var showHazardWarnings: Bool = true
    var mapStylePreference: MapStylePreference = .satellite
    
    // Data & Storage
    var autoBackupEnabled: Bool = true
    var offlineDownloadOnWiFiOnly: Bool = true
    
    static let `default` = AppSettings()
}

/// User's preferred map style (renamed to avoid conflict with MapKit.MapStyle)
enum MapStylePreference: String, Codable, CaseIterable {
    case satellite = "satellite"
    case standard = "standard"
    case hybrid = "hybrid"
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Issue Report Model

/// For reporting course/shot detection issues
struct IssueReport: Codable {
    var id: String = UUID().uuidString
    var userId: String
    var roundId: String?
    var courseId: String?
    var holeNumber: Int?
    var issueTypes: [IssueType]
    var additionalDetails: String?
    var createdAt: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case roundId = "round_id"
        case courseId = "course_id"
        case holeNumber = "hole_number"
        case issueTypes = "issue_types"
        case additionalDetails = "additional_details"
        case createdAt = "created_at"
    }
}

enum IssueType: String, Codable, CaseIterable {
    case clubRecommendationsWrong = "club_recommendations_wrong"
    case smartTargetsWrong = "smart_targets_wrong"
    case dispersionTooBig = "dispersion_too_big"
    case dispersionTooSmall = "dispersion_too_small"
    case scorePercentagesWrong = "score_percentages_wrong"
    case courseMappingIssue = "course_mapping_issue"
    case batteryDrain = "battery_drain"
    case missingPutts = "missing_putts"
    case missingShots = "missing_shots"
    case noShotsDetected = "no_shots_detected"
    case tooManyShotsDeleted = "too_many_shots_deleted"
    case shotsOnWrongHole = "shots_on_wrong_hole"
    case gpsInaccurate = "gps_inaccurate"
    case appCrash = "app_crash"
    case syncIssues = "sync_issues"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .clubRecommendationsWrong: return "Club recommendations are wrong"
        case .smartTargetsWrong: return "Smart targets are wrong (course mapping issue)"
        case .dispersionTooBig: return "Dispersion ellipse sizes feel too big"
        case .dispersionTooSmall: return "Dispersion ellipse sizes feel too small"
        case .scorePercentagesWrong: return "Score percentages are wrong"
        case .courseMappingIssue: return "Course mapping issue"
        case .batteryDrain: return "Battery drain"
        case .missingPutts: return "Missing some putts"
        case .missingShots: return "Missing too many shots"
        case .noShotsDetected: return "No shots detected"
        case .tooManyShotsDeleted: return "Had to delete too many shots"
        case .shotsOnWrongHole: return "Shots on the wrong hole"
        case .gpsInaccurate: return "GPS distances inaccurate"
        case .appCrash: return "App crashed"
        case .syncIssues: return "Watch/phone sync issues"
        case .other: return "Other issue"
        }
    }
}
