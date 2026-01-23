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
    let address: String?
    let phone: String?
    let website: String?
    let courseRating: Double?
    let slopeRating: Int?
    let par: Int?
    let holes: Int?
    let latitude: Double?
    let longitude: Double?
    let avgRating: Double?
    let reviewCount: Int?
    let holeData: [HoleData]?
    let updatedAt: Date?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, city, state, country, address, phone, website
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case par, holes, latitude, longitude
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case holeData = "hole_data"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
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
    
    // Polygon data for visualization
    let teeLocations: [TeeLocation]?
    let fairway: [Coordinate]?
    let green: [Coordinate]?
    let rough: [Coordinate]?
    let bunkers: [Bunker]?
    let waterHazards: [WaterHazard]?
    let trees: [TreeArea]?
    let yardageMarkers: [YardageMarker]?
    
    enum CodingKeys: String, CodingKey {
        case holeNumber = "hole_number"
        case par, yardages
        case greenCenter = "green_center"
        case greenFront = "green_front"
        case greenBack = "green_back"
        case teeLocations = "tee_locations"
        case fairway
        case green
        case rough
        case bunkers
        case waterHazards = "water_hazards"
        case trees
        case yardageMarkers = "yardage_markers"
    }

    init(
        holeNumber: Int,
        par: Int,
        yardages: [String: Int]? = nil,
        greenCenter: Coordinate? = nil,
        greenFront: Coordinate? = nil,
        greenBack: Coordinate? = nil,
        teeLocations: [TeeLocation]? = nil,
        fairway: [Coordinate]? = nil,
        green: [Coordinate]? = nil,
        rough: [Coordinate]? = nil,
        bunkers: [Bunker]? = nil,
        waterHazards: [WaterHazard]? = nil,
        trees: [TreeArea]? = nil,
        yardageMarkers: [YardageMarker]? = nil
    ) {
        self.holeNumber = holeNumber
        self.par = par
        self.yardages = yardages
        self.greenCenter = greenCenter
        self.greenFront = greenFront
        self.greenBack = greenBack
        self.teeLocations = teeLocations
        self.fairway = fairway
        self.green = green
        self.rough = rough
        self.bunkers = bunkers
        self.waterHazards = waterHazards
        self.trees = trees
        self.yardageMarkers = yardageMarkers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            holeNumber = try container.decode(Int.self, forKey: .holeNumber)
            par = try container.decode(Int.self, forKey: .par)
            yardages = try container.decodeIfPresent([String: Int].self, forKey: .yardages)
            greenCenter = try container.decodeIfPresent(Coordinate.self, forKey: .greenCenter)
            greenFront = try container.decodeIfPresent(Coordinate.self, forKey: .greenFront)
            greenBack = try container.decodeIfPresent(Coordinate.self, forKey: .greenBack)
            teeLocations = try container.decodeIfPresent([TeeLocation].self, forKey: .teeLocations)
            fairway = try container.decodeIfPresent([Coordinate].self, forKey: .fairway)
            green = try container.decodeIfPresent([Coordinate].self, forKey: .green)
            rough = try container.decodeIfPresent([Coordinate].self, forKey: .rough)
            bunkers = try container.decodeIfPresent([Bunker].self, forKey: .bunkers)
            waterHazards = try container.decodeIfPresent([WaterHazard].self, forKey: .waterHazards)
            trees = try container.decodeIfPresent([TreeArea].self, forKey: .trees)
            yardageMarkers = try container.decodeIfPresent([YardageMarker].self, forKey: .yardageMarkers)
        } catch {
            print("❌ HoleData decoding error: \(error)")
            throw error
        }
    }
}

struct TeeLocation: Codable {
    let tee: String  // "black", "blue", "white", "gold", "red"
    let lat: Double
    let lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Bunker: Codable {
    let type: String
    let polygon: [Coordinate]
    let center: Coordinate?

    enum CodingKeys: String, CodingKey {
        case type
        case polygon
        case center
    }

    init(type: String = "bunker", polygon: [Coordinate], center: Coordinate?) {
        self.type = type
        self.polygon = polygon
        self.center = center
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "bunker"
        polygon = try container.decode([Coordinate].self, forKey: .polygon)
        center = try container.decodeIfPresent(Coordinate.self, forKey: .center)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(polygon, forKey: .polygon)
        try container.encodeIfPresent(center, forKey: .center)
    }
}

struct WaterHazard: Codable {
    let polygon: [Coordinate]
    let center: Coordinate?
}

struct TreeArea: Codable {
    let polygon: [Coordinate]
    let center: Coordinate?
}

struct YardageMarker: Codable {
    let distance: Int
    let lat: Double
    let lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Coordinate: Codable {
    let lat: Double
    let lon: Double
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
    }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    init(from decoder: Decoder) throws {
        // Support both object { lat, lon } and array [lat, lon]
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            lat = try container.decode(Double.self, forKey: .lat)
            lon = try container.decode(Double.self, forKey: .lon)
            return
        }

        do {
            var unkeyed = try decoder.unkeyedContainer()
            let first = try unkeyed.decode(Double.self)
            let second = try unkeyed.decode(Double.self)
            // Support GeoJSON [lon, lat] as well as [lat, lon]
            if abs(first) > 90, abs(second) <= 90 {
                lat = second
                lon = first
            } else {
                lat = first
                lon = second
            }
        } catch {
            print("❌ Coordinate decoding error: \(error)")
            throw error
        }
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

enum ClubType: String, CaseIterable, Codable, Identifiable {
    case driver = "Driver"
    case threeWood = "3W"
    case fiveWood = "5W"
    case sevenWood = "7W"
    case hybrid2 = "2H"
    case hybrid3 = "3H"
    case hybrid4 = "4H"
    case hybrid5 = "5H"
    case twoIron = "2i"
    case threeIron = "3i"
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
    case wedge52 = "52°"
    case wedge54 = "54°"
    case wedge56 = "56°"
    case wedge58 = "58°"
    case wedge60 = "60°"
    case putter = "Putter"
    
    var id: String { rawValue }
    
    var category: ClubCategory {
        switch self {
        case .driver: return .driver
        case .threeWood, .fiveWood, .sevenWood: return .woods
        case .hybrid2, .hybrid3, .hybrid4, .hybrid5: return .hybrids
        case .twoIron, .threeIron, .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron: return .irons
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge, .wedge52, .wedge54, .wedge56, .wedge58, .wedge60: return .wedges
        case .putter: return .putter
        }
    }
    
    static var defaultBag: [ClubType] {
        [.driver, .threeWood, .fiveWood, .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron, .pitchingWedge, .sandWedge, .putter]
    }
}

enum ClubCategory: String, CaseIterable {
    case driver = "Driver"
    case woods = "Woods"
    case hybrids = "Hybrids"
    case irons = "Irons"
    case wedges = "Wedges"
    case putter = "Putter"
}

// MARK: - Contributor Stats

struct ContributorStats: Codable, Identifiable {
    let id: String
    let userId: String
    let reputationScore: Double
    let contributionsCount: Int
    let verifiedContributionsCount: Int
    let confirmationsReceived: Int
    let isTrustedContributor: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case reputationScore = "reputation_score"
        case contributionsCount = "contributions_count"
        case verifiedContributionsCount = "verified_contributions_count"
        case confirmationsReceived = "confirmations_received"
        case isTrustedContributor = "is_trusted_contributor"
    }
}

// MARK: - Notifications

struct Notification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let message: String
    let courseId: String?
    let contributionId: String?
    let relatedUserId: String?
    let isRead: Bool
    let readAt: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case message
        case courseId = "course_id"
        case contributionId = "contribution_id"
        case relatedUserId = "related_user_id"
        case isRead = "read"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

// MARK: - Course Discussions

struct CourseDiscussion: Codable, Identifiable {
    let id: String
    let courseId: String
    let userId: String
    let title: String
    let content: String
    let createdAt: String
    let replyCount: Int?
    let authorName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case userId = "user_id"
        case title
        case content
        case createdAt = "created_at"
        case replyCount = "reply_count"
        case authorName = "author_name"
    }
}

struct DiscussionReply: Codable, Identifiable {
    let id: String
    let discussionId: String
    let userId: String
    let content: String
    let createdAt: String
    let authorName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case discussionId = "discussion_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case authorName = "author_name"
    }
}

// MARK: - OSM Course Data

struct OSMCourse: Codable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let city: String?
    let state: String?
    let country: String?
    let address: String
    let phone: String?
    let website: String?
}

// MARK: - Golf Bag

class GolfBag: ObservableObject {
    static let shared = GolfBag()
    
    @Published var clubs: [ClubType] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "userGolfBag"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedClubs = try? JSONDecoder().decode([ClubType].self, from: data) {
            self.clubs = savedClubs
        } else {
            self.clubs = ClubType.defaultBag
        }
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(clubs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func addClub(_ club: ClubType) {
        if !clubs.contains(club) {
            clubs.append(club)
            clubs.sort { $0.sortOrder < $1.sortOrder }
        }
    }
    
    func removeClub(_ club: ClubType) {
        clubs.removeAll { $0 == club }
    }
    
    func isInBag(_ club: ClubType) -> Bool {
        clubs.contains(club)
    }
    
    var clubNames: [String] {
        clubs.map { $0.rawValue }
    }
}

extension ClubType {
    var sortOrder: Int {
        switch self {
        case .driver: return 0
        case .threeWood: return 1
        case .fiveWood: return 2
        case .sevenWood: return 3
        case .hybrid2: return 4
        case .hybrid3: return 5
        case .hybrid4: return 6
        case .hybrid5: return 7
        case .twoIron: return 8
        case .threeIron: return 9
        case .fourIron: return 10
        case .fiveIron: return 11
        case .sixIron: return 12
        case .sevenIron: return 13
        case .eightIron: return 14
        case .nineIron: return 15
        case .pitchingWedge: return 16
        case .gapWedge: return 17
        case .wedge52: return 18
        case .wedge54: return 19
        case .sandWedge: return 20
        case .wedge56: return 21
        case .wedge58: return 22
        case .lobWedge: return 23
        case .wedge60: return 24
        case .putter: return 25
        }
    }
}
