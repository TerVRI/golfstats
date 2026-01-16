import Foundation

actor DataService {
    static let shared = DataService()
    
    private let supabaseUrl = "https://kanvhqwrfkzqktuvpxnp.supabase.co"
    private let supabaseKey = "sb_publishable_JftEdMATFsi78Ba8rIFObg_tpOeIS2J"
    
    private init() {}
    
    // MARK: - Rounds
    
    func fetchRounds(userId: String, authHeaders: [String: String], limit: Int = 20) async throws -> [Round] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/rounds")!
        urlComponents.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "played_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Round].self, from: data)
    }
    
    func fetchRound(id: String, authHeaders: [String: String]) async throws -> Round? {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/rounds")!
        urlComponents.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        let rounds = try JSONDecoder().decode([Round].self, from: data)
        return rounds.first
    }
    
    // MARK: - Courses
    
    func fetchCourses(search: String? = nil, limit: Int = 50) async throws -> [Course] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/courses")!
        var queryItems = [
            URLQueryItem(name: "order", value: "review_count.desc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "name", value: "ilike.*\(search)*"))
        }
        
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        return try JSONDecoder().decode([Course].self, from: data)
    }
    
    func fetchCourse(id: String) async throws -> Course? {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/courses")!
        urlComponents.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        let courses = try JSONDecoder().decode([Course].self, from: data)
        return courses.first
    }
    
    func fetchNearbyCourses(latitude: Double, longitude: Double, radiusMiles: Double = 50) async throws -> [Course] {
        // For now, fetch all courses and filter client-side
        // TODO: Implement PostGIS distance query
        let allCourses = try await fetchCourses(limit: 200)
        
        return allCourses.filter { course in
            guard let courseLat = course.latitude, let courseLon = course.longitude else { return false }
            let distance = haversineDistance(lat1: latitude, lon1: longitude, lat2: courseLat, lon2: courseLon)
            return distance <= radiusMiles
        }
    }
    
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 3959.0 // Earth's radius in miles
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }
    
    // MARK: - Weather
    
    func fetchWeather(latitude: Double, longitude: Double) async throws -> Weather {
        var urlComponents = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        urlComponents.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph")
        ]
        
        let request = URLRequest(url: urlComponents.url!)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let current = json?["current"] as? [String: Any]
        
        let temp = current?["temperature_2m"] as? Double ?? 0
        let windSpeed = current?["wind_speed_10m"] as? Double ?? 0
        let windDir = current?["wind_direction_10m"] as? Double ?? 0
        let humidity = current?["relative_humidity_2m"] as? Int ?? 0
        let weatherCode = current?["weather_code"] as? Int ?? 0
        
        let (conditions, icon) = weatherConditions(for: weatherCode)
        let windDirection = windDirectionLabel(for: windDir)
        
        return Weather(
            temperature: Int(temp),
            windSpeed: Int(windSpeed),
            windDirection: windDirection,
            conditions: conditions,
            icon: icon,
            humidity: humidity,
            precipitationProbability: 0,
            isGoodForGolf: temp >= 50 && temp <= 95 && windSpeed <= 20
        )
    }
    
    private func weatherConditions(for code: Int) -> (String, String) {
        switch code {
        case 0: return ("Clear", "☀️")
        case 1, 2: return ("Partly Cloudy", "⛅")
        case 3: return ("Cloudy", "☁️")
        case 45, 48: return ("Foggy", "🌫️")
        case 51, 53, 55, 61, 63, 65, 80, 81, 82: return ("Rainy", "🌧️")
        case 71, 73, 75, 77, 85, 86: return ("Snow", "❄️")
        case 95, 96, 99: return ("Thunderstorm", "⛈️")
        default: return ("Unknown", "❓")
        }
    }
    
    private func windDirectionLabel(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    // MARK: - Stats
    
    func fetchStats(userId: String, authHeaders: [String: String]) async throws -> UserStats {
        let rounds = try await fetchRounds(userId: userId, authHeaders: authHeaders, limit: 100)
        
        guard !rounds.isEmpty else {
            return UserStats.empty
        }
        
        let scores = rounds.map { $0.totalScore }
        let sgValues = rounds.compactMap { $0.sgTotal }
        
        return UserStats(
            roundsPlayed: rounds.count,
            averageScore: Double(scores.reduce(0, +)) / Double(scores.count),
            bestScore: scores.min() ?? 0,
            averageSG: sgValues.isEmpty ? 0 : sgValues.reduce(0, +) / Double(sgValues.count),
            handicapIndex: calculateHandicap(rounds: rounds)
        )
    }
    
    private func calculateHandicap(rounds: [Round]) -> Double? {
        guard rounds.count >= 3 else { return nil }
        
        let recentRounds = Array(rounds.prefix(20))
        let differentials = recentRounds.compactMap { round -> Double? in
            guard let rating = round.courseRating, let slope = round.slopeRating else { return nil }
            return (Double(round.totalScore) - rating) * 113 / Double(slope)
        }
        
        guard !differentials.isEmpty else { return nil }
        
        let sortedDiffs = differentials.sorted()
        let countToUse = min(differentials.count, max(1, differentials.count / 2))
        let bestDiffs = Array(sortedDiffs.prefix(countToUse))
        
        return bestDiffs.reduce(0, +) / Double(bestDiffs.count) * 0.96
    }
}

struct UserStats {
    let roundsPlayed: Int
    let averageScore: Double
    let bestScore: Int
    let averageSG: Double
    let handicapIndex: Double?
    
    static let empty = UserStats(roundsPlayed: 0, averageScore: 0, bestScore: 0, averageSG: 0, handicapIndex: nil)
}

enum DataError: Error, LocalizedError {
    case fetchFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed: return "Failed to fetch data"
        case .saveFailed: return "Failed to save data"
        }
    }
}
