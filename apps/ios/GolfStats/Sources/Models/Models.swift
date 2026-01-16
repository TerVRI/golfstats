import Foundation
import CoreLocation

// MARK: - User & Auth

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let fullName: String?
    let avatarUrl: String?
    
    var displayName: String {
        fullName ?? email?.components(separatedBy: "@").first ?? "Golfer"
    }
    
    var initials: String {
        String(displayName.prefix(1)).uppercased()
    }
}

// MARK: - Round

struct Round: Codable, Identifiable {
    let id: String
    let userId: String
    let courseName: String
    let playedAt: String
    let totalScore: Int
    let totalPutts: Int?
    let fairwaysHit: Int?
    let fairwaysTotal: Int?
    let gir: Int?
    let penalties: Int?
    let courseRating: Double?
    let slopeRating: Int?
    let sgTotal: Double?
    let sgOffTee: Double?
    let sgApproach: Double?
    let sgAroundGreen: Double?
    let sgPutting: Double?
    let scoringFormat: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseName = "course_name"
        case playedAt = "played_at"
        case totalScore = "total_score"
        case totalPutts = "total_putts"
        case fairwaysHit = "fairways_hit"
        case fairwaysTotal = "fairways_total"
        case gir
        case penalties
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case sgTotal = "sg_total"
        case sgOffTee = "sg_off_tee"
        case sgApproach = "sg_approach"
        case sgAroundGreen = "sg_around_green"
        case sgPutting = "sg_putting"
        case scoringFormat = "scoring_format"
        case createdAt = "created_at"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: playedAt) else { return playedAt }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var scoreToPar: String {
        let par = 72 // Default
        let diff = totalScore - par
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }
}

// MARK: - Hole Score

struct HoleScore: Codable, Identifiable {
    var id: Int { holeNumber }
    var holeNumber: Int
    var par: Int
    var score: Int?
    var putts: Int?
    var fairwayHit: Bool?
    var gir: Bool?
    var penalties: Int?
    
    var relativeToPar: Int? {
        guard let score = score else { return nil }
        return score - par
    }
    
    var scoreDescription: String {
        guard let diff = relativeToPar else { return "" }
        switch diff {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        default: return "+\(diff)"
        }
    }
}

// MARK: - Shot

struct Shot: Codable, Identifiable {
    let id: String
    let roundId: String
    let holeNumber: Int
    let shotNumber: Int
    let club: String?
    let latitude: Double?
    let longitude: Double?
    let distanceToPin: Int?
    let lie: String?
    let result: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case roundId = "round_id"
        case holeNumber = "hole_number"
        case shotNumber = "shot_number"
        case club
        case latitude
        case longitude
        case distanceToPin = "distance_to_pin"
        case lie
        case result
        case timestamp = "shot_time"
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Course

struct Course: Codable, Identifiable {
    let id: String
    let name: String
    let city: String?
    let state: String?
    let country: String?
    let courseRating: Double?
    let slopeRating: Int?
    let par: Int?
    let latitude: Double?
    let longitude: Double?
    let avgRating: Double?
    let reviewCount: Int?
    let holeData: [HoleData]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, city, state, country
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case par, latitude, longitude
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case holeData = "hole_data"
    }
    
    var location: String {
        [city, state, country].compactMap { $0 }.joined(separator: ", ")
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct HoleData: Codable {
    let holeNumber: Int
    let par: Int
    let yardages: [String: Int]?
    let greenCenter: Coordinate?
    let greenFront: Coordinate?
    let greenBack: Coordinate?
    
    enum CodingKeys: String, CodingKey {
        case holeNumber = "hole_number"
        case par, yardages
        case greenCenter = "green_center"
        case greenFront = "green_front"
        case greenBack = "green_back"
    }
}

struct Coordinate: Codable {
    let lat: Double
    let lon: Double
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Weather

struct Weather: Codable {
    let temperature: Int
    let windSpeed: Int
    let windDirection: String
    let conditions: String
    let icon: String
    let humidity: Int
    let precipitationProbability: Int
    let isGoodForGolf: Bool
}

// MARK: - Clubs

enum ClubType: String, CaseIterable {
    case driver = "Driver"
    case threeWood = "3W"
    case fiveWood = "5W"
    case hybrid = "Hybrid"
    case fourIron = "4i"
    case fiveIron = "5i"
    case sixIron = "6i"
    case sevenIron = "7i"
    case eightIron = "8i"
    case nineIron = "9i"
    case pitchingWedge = "PW"
    case gapWedge = "GW"
    case sandWedge = "SW"
    case lobWedge = "LW"
    case putter = "Putter"
}
