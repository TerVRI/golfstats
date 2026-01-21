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
    
    func fetchCourses(search: String? = nil, country: String? = nil, limit: Int = 50) async throws -> [Course] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/courses")!
        var queryItems = [
            URLQueryItem(name: "order", value: "review_count.desc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        // Filter by country if provided (for performance)
        if let country = country, !country.isEmpty {
            queryItems.append(URLQueryItem(name: "country", value: "eq.\(country)"))
        }
        
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
    
    func fetchNearbyCourses(latitude: Double, longitude: Double, radiusMiles: Double = 50, limit: Int = 50) async throws -> [Course] {
        // Use PostGIS function for efficient distance-based queries
        let urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/rpc/get_nearby_courses")!
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "p_latitude": latitude,
            "p_longitude": longitude,
            "p_radius_miles": radiusMiles,
            "p_limit": limit
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DataError.fetchFailed
        }
        
        // If PostGIS function not available, fall back to client-side filtering
        if httpResponse.statusCode == 404 {
            print("⚠️ PostGIS function not found, falling back to client-side filtering")
            return try await fetchNearbyCoursesFallback(latitude: latitude, longitude: longitude, radiusMiles: radiusMiles)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        // Decode the response - includes distance_miles field
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        struct NearbyCoursesResponse: Decodable {
            let id: String
            let name: String
            let city: String?
            let state: String?
            let country: String?
            let courseRating: Double?
            let slopeRating: Int?
            let par: Int?
            let holes: Int?
            let latitude: Double?
            let longitude: Double?
            let address: String?
            let phone: String?
            let website: String?
            let holeData: [HoleData]?
            let avgRating: Double?
            let reviewCount: Int?
            let distanceMiles: Double?
        }
        
        let nearbyCourses = try decoder.decode([NearbyCoursesResponse].self, from: data)
        
        return nearbyCourses.map { course in
            Course(
                id: course.id,
                name: course.name,
                city: course.city,
                state: course.state,
                country: course.country,
                address: course.address,
                phone: course.phone,
                website: course.website,
                courseRating: course.courseRating,
                slopeRating: course.slopeRating,
                par: course.par,
                holes: course.holes,
                latitude: course.latitude,
                longitude: course.longitude,
                avgRating: course.avgRating,
                reviewCount: course.reviewCount,
                holeData: course.holeData,
                updatedAt: nil,
                createdAt: nil
            )
        }
    }
    
    /// Fallback to client-side filtering if PostGIS function not available
    private func fetchNearbyCoursesFallback(latitude: Double, longitude: Double, radiusMiles: Double) async throws -> [Course] {
        let allCourses = try await fetchCourses(limit: 200)
        
        return allCourses.filter { course in
            guard let courseLat = course.latitude, let courseLon = course.longitude else { return false }
            let distance = haversineDistance(lat1: latitude, lon1: longitude, lat2: courseLat, lon2: courseLon)
            return distance <= radiusMiles
        }.sorted { course1, course2 in
            guard let lat1 = course1.latitude, let lon1 = course1.longitude,
                  let lat2 = course2.latitude, let lon2 = course2.longitude else { return false }
            let dist1 = haversineDistance(lat1: latitude, lon1: longitude, lat2: lat1, lon2: lon1)
            let dist2 = haversineDistance(lat1: latitude, lon1: longitude, lat2: lat2, lon2: lon2)
            return dist1 < dist2
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
        let sgTotals = rounds.compactMap { $0.sgTotal }
        let sgOffTeeValues = rounds.compactMap { $0.sgOffTee }
        let sgApproachValues = rounds.compactMap { $0.sgApproach }
        let sgAroundGreenValues = rounds.compactMap { $0.sgAroundGreen }
        let sgPuttingValues = rounds.compactMap { $0.sgPutting }
        
        // Calculate fairway percentage
        let fairwayData = rounds.compactMap { round -> (hit: Int, total: Int)? in
            guard let hit = round.fairwaysHit, let total = round.fairwaysTotal, total > 0 else { return nil }
            return (hit, total)
        }
        let totalFairwaysHit = fairwayData.reduce(0) { $0 + $1.hit }
        let totalFairways = fairwayData.reduce(0) { $0 + $1.total }
        let fairwayPercentage = totalFairways > 0 ? Double(totalFairwaysHit) / Double(totalFairways) * 100 : 0
        
        // Calculate GIR percentage (assume 18 greens per round)
        let girData = rounds.compactMap { $0.gir }
        let totalGIR = girData.reduce(0, +)
        let totalGreens = girData.count * 18
        let girPercentage = totalGreens > 0 ? Double(totalGIR) / Double(totalGreens) * 100 : 0
        
        // Calculate putts per hole
        let puttsData = rounds.compactMap { $0.totalPutts }
        let totalPutts = puttsData.reduce(0, +)
        let totalHoles = puttsData.count * 18
        let puttsPerHole = totalHoles > 0 ? Double(totalPutts) / Double(totalHoles) : 0
        
        // Scrambling percentage (estimate based on GIR and score)
        // Real scrambling would need hole-by-hole data
        let scramblingPercentage = max(0, min(100, 50 + (sgAroundGreenValues.isEmpty ? 0 : sgAroundGreenValues.reduce(0, +) / Double(sgAroundGreenValues.count) * 10)))
        
        return UserStats(
            roundsPlayed: rounds.count,
            averageScore: Double(scores.reduce(0, +)) / Double(scores.count),
            bestScore: scores.min() ?? 0,
            averageSG: sgTotals.isEmpty ? 0 : sgTotals.reduce(0, +) / Double(sgTotals.count),
            sgOffTee: sgOffTeeValues.isEmpty ? 0 : sgOffTeeValues.reduce(0, +) / Double(sgOffTeeValues.count),
            sgApproach: sgApproachValues.isEmpty ? 0 : sgApproachValues.reduce(0, +) / Double(sgApproachValues.count),
            sgAroundGreen: sgAroundGreenValues.isEmpty ? 0 : sgAroundGreenValues.reduce(0, +) / Double(sgAroundGreenValues.count),
            sgPutting: sgPuttingValues.isEmpty ? 0 : sgPuttingValues.reduce(0, +) / Double(sgPuttingValues.count),
            fairwayPercentage: fairwayPercentage,
            girPercentage: girPercentage,
            puttsPerHole: puttsPerHole,
            scramblingPercentage: scramblingPercentage,
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
    
    // MARK: - Course Confirmations
    
    func confirmCourse(
        courseId: String,
        userId: String,
        authHeaders: [String: String],
        dimensionsMatch: Bool = true,
        teeLocationsMatch: Bool = true,
        greenLocationsMatch: Bool = true,
        hazardLocationsMatch: Bool = true,
        confidenceLevel: Int = 3,
        discrepancyNotes: String? = nil,
        holeConfirmations: [Int: [String: Any]]? = nil
    ) async throws {
        let urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/course_confirmations")!
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        var body: [String: Any] = [
            "course_id": courseId,
            "user_id": userId,
            "dimensions_match": dimensionsMatch,
            "tee_locations_match": teeLocationsMatch,
            "green_locations_match": greenLocationsMatch,
            "hazard_locations_match": hazardLocationsMatch,
            "confidence_level": confidenceLevel
        ]
        
        if let notes = discrepancyNotes {
            body["discrepancy_notes"] = notes
        }
        
        if let holeConfirmations = holeConfirmations {
            body["hole_confirmations"] = Array(holeConfirmations.values)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw DataError.saveFailed
        }
    }
    
    // MARK: - Leaderboard
    
    func fetchContributorLeaderboard(authHeaders: [String: String], limit: Int = 50) async throws -> [ContributorStats] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/contributor_reputation")!
        urlComponents.queryItems = [
            URLQueryItem(name: "order", value: "reputation_score.desc"),
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([ContributorStats].self, from: data)
    }
    
    // MARK: - Storage
    
    func uploadPhoto(
        data: Data,
        fileName: String,
        authHeaders: [String: String],
        bucket: String = "course-photos",
        folder: String = "contributions"
    ) async throws -> String {
        let filePath = "\(folder)/\(fileName)"
        let url = URL(string: "\(supabaseUrl)/storage/v1/object/\(bucket)/\(filePath)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        
        // Determine content type from file extension
        let contentType: String
        if fileName.lowercased().hasSuffix(".jpg") || fileName.lowercased().hasSuffix(".jpeg") {
            contentType = "image/jpeg"
        } else if fileName.lowercased().hasSuffix(".png") {
            contentType = "image/png"
        } else if fileName.lowercased().hasSuffix(".webp") {
            contentType = "image/webp"
        } else if fileName.lowercased().hasSuffix(".gif") {
            contentType = "image/gif"
        } else {
            contentType = "image/jpeg"
        }
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw DataError.saveFailed
        }
        
        // Get public URL
        let publicUrl = "\(supabaseUrl)/storage/v1/object/public/\(bucket)/\(filePath)"
        return publicUrl
    }
    
    // MARK: - Notifications
    
    func fetchNotifications(
        userId: String,
        authHeaders: [String: String],
        limit: Int = 50
    ) async throws -> [Notification] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/notifications")!
        urlComponents.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Notification].self, from: data)
    }
    
    func markNotificationAsRead(
        notificationId: String,
        authHeaders: [String: String]
    ) async throws {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/notifications")!
        urlComponents.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(notificationId)")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let body: [String: Any] = [
            "read": true,
            "read_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw DataError.saveFailed
        }
    }
    
    func markAllNotificationsAsRead(
        userId: String,
        authHeaders: [String: String]
    ) async throws {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/notifications")!
        urlComponents.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "read", value: "eq.false")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let body: [String: Any] = [
            "read": true,
            "read_at": ISO8601DateFormatter().string(from: Date())
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw DataError.saveFailed
        }
    }
    
    // MARK: - Course Discussions
    
    func fetchCourseDiscussions(
        courseId: String,
        authHeaders: [String: String]
    ) async throws -> [CourseDiscussion] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/course_discussions")!
        urlComponents.queryItems = [
            URLQueryItem(name: "course_id", value: "eq.\(courseId)"),
            URLQueryItem(name: "order", value: "created_at.desc")
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([CourseDiscussion].self, from: data)
    }
    
    func createCourseDiscussion(
        courseId: String,
        userId: String,
        authHeaders: [String: String],
        title: String,
        content: String
    ) async throws {
        let urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/course_discussions")!
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let body: [String: Any] = [
            "course_id": courseId,
            "user_id": userId,
            "title": title,
            "content": content
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Discussion creation failed: \(errorBody)")
            throw DataError.saveFailed
        }
        
        print("Discussion created successfully")
    }
    
    func fetchDiscussionReplies(
        discussionId: String,
        authHeaders: [String: String]
    ) async throws -> [DiscussionReply] {
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/discussion_replies")!
        urlComponents.queryItems = [
            URLQueryItem(name: "discussion_id", value: "eq.\(discussionId)"),
            URLQueryItem(name: "order", value: "created_at.asc")
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([DiscussionReply].self, from: data)
    }
    
    func replyToDiscussion(
        discussionId: String,
        userId: String,
        authHeaders: [String: String],
        content: String
    ) async throws {
        let urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/discussion_replies")!
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let body: [String: Any] = [
            "discussion_id": discussionId,
            "user_id": userId,
            "content": content
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw DataError.saveFailed
        }
    }
    
    // MARK: - OSM Integration
    
    func searchOSMCourses(
        latitude: Double,
        longitude: Double,
        radius: Double = 5000
    ) async throws -> [OSMCourse] {
        // Overpass API query
        let query = """
        [out:json][timeout:25];
        (
          way["leisure"="golf_course"](around:\(Int(radius)),\(latitude),\(longitude));
          relation["leisure"="golf_course"](around:\(Int(radius)),\(latitude),\(longitude));
          node["leisure"="golf_course"](around:\(Int(radius)),\(latitude),\(longitude));
        );
        out center meta;
        """
        
        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let elements = json?["elements"] as? [[String: Any]] ?? []
        
        return elements.compactMap { element -> OSMCourse? in
            guard let tags = element["tags"] as? [String: Any] else { return nil }
            
            let lat: Double
            let lon: Double
            
            if let elementLat = element["lat"] as? Double, let elementLon = element["lon"] as? Double {
                lat = elementLat
                lon = elementLon
            } else if let center = element["center"] as? [String: Any],
                      let centerLat = center["lat"] as? Double,
                      let centerLon = center["lon"] as? Double {
                lat = centerLat
                lon = centerLon
            } else {
                return nil
            }
            
            return OSMCourse(
                id: element["id"] as? Int ?? 0,
                name: tags["name"] as? String ?? "Unnamed Golf Course",
                latitude: lat,
                longitude: lon,
                city: tags["addr:city"] as? String,
                state: tags["addr:state"] as? String,
                country: tags["addr:country"] as? String,
                address: [
                    tags["addr:housenumber"] as? String,
                    tags["addr:street"] as? String
                ].compactMap { $0 }.joined(separator: " "),
                phone: tags["phone"] as? String ?? tags["contact:phone"] as? String,
                website: tags["website"] as? String ?? tags["contact:website"] as? String
            )
        }
    }
    
    // MARK: - Course Contributions
    
    func contributeCourse(
        userId: String,
        authHeaders: [String: String],
        name: String,
        city: String?,
        state: String?,
        country: String,
        address: String?,
        phone: String?,
        website: String?,
        courseRating: Double?,
        slopeRating: Int?,
        par: Int?,
        holes: Int,
        latitude: Double,
        longitude: Double,
        photoUrls: [String] = [],
        holeData: [[String: Any]]? = nil
    ) async throws {
        let urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/course_contributions")!
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        var body: [String: Any] = [
            "contributor_id": userId,
            "name": name,
            "country": country,
            "holes": holes,
            "latitude": latitude,
            "longitude": longitude,
            "status": "pending"
        ]
        
        if let city = city { body["city"] = city }
        if let state = state { body["state"] = state }
        if let address = address { body["address"] = address }
        if let phone = phone { body["phone"] = phone }
        if let website = website { body["website"] = website }
        if let courseRating = courseRating { body["course_rating"] = courseRating }
        if let slopeRating = slopeRating { body["slope_rating"] = slopeRating }
        if let par = par { body["par"] = par }
        if !photoUrls.isEmpty {
            body["photo_urls"] = photoUrls
            body["photos"] = photoUrls.map { ["url": $0, "uploaded_at": ISO8601DateFormatter().string(from: Date())] }
        }
        if let holeData = holeData {
            body["hole_data"] = holeData
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw DataError.saveFailed
        }
    }
}

struct UserStats {
    let roundsPlayed: Int
    let averageScore: Double
    let bestScore: Int
    let averageSG: Double
    let sgOffTee: Double
    let sgApproach: Double
    let sgAroundGreen: Double
    let sgPutting: Double
    let fairwayPercentage: Double
    let girPercentage: Double
    let puttsPerHole: Double
    let scramblingPercentage: Double
    let handicapIndex: Double?
    
    static let empty = UserStats(
        roundsPlayed: 0,
        averageScore: 0,
        bestScore: 0,
        averageSG: 0,
        sgOffTee: 0,
        sgApproach: 0,
        sgAroundGreen: 0,
        sgPutting: 0,
        fairwayPercentage: 0,
        girPercentage: 0,
        puttsPerHole: 0,
        scramblingPercentage: 0,
        handicapIndex: nil
    )
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
