import Foundation

/// Loads course data from the app bundle and handles syncing with server
actor CourseBundleLoader {
    static let shared = CourseBundleLoader()
    
    private let bundleFileName = "courses-bundle"
    private let lastSyncKey = "courses_last_sync_date"
    private let coursesCacheKey = "courses_cache"
    
    private var cacheFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("courses_cache.json")
    }
    
    /// Helper to create a decoder with the correct date strategy
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // Handle both String (ISO8601) and Double (Seconds since 1970)
            // This is crucial for compatibility between API (String) and Cache (Number/String)
            if let dateString = try? container.decode(String.self) {
                // Try ISO8601 variants
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                
                let postgresFormatter = DateFormatter()
                postgresFormatter.locale = Locale(identifier: "en_US_POSIX")
                postgresFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                postgresFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                if let date = postgresFormatter.date(from: dateString) {
                    return date
                }
                
                postgresFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                if let date = postgresFormatter.date(from: dateString) {
                    return date
                }
                
                isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(dateString)"
                )
            } else if let timeInterval = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timeInterval)
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected Date as String or Double"
            )
        }
        return decoder
    }
    
    private init() {}
    
    // MARK: - Load Bundled Courses
    
    /// Load courses from app bundle
    func loadBundledCourses() -> [Course] {
        guard let url = Bundle.main.url(forResource: bundleFileName, withExtension: "json") else {
            print("⚠️ courses-bundle.json not found in app bundle")
            print("⚠️ Bundle path: \(Bundle.main.bundlePath)")
            print("⚠️ Resource path: \(Bundle.main.resourcePath ?? "nil")")
            return []
        }
        
        print("📦 Found bundle file at: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("📦 Bundle file size: \(data.count) bytes")
            
            // Decode the JSON structure manually to handle metadata and courses separately
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json = json,
                  let coursesArray = json["courses"] as? [[String: Any]],
                  let metadataDict = json["metadata"] as? [String: Any] else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid bundle structure"
                ))
            }
            
            // Decode metadata manually
            let metadata = BundleMetadata(
                exportDate: metadataDict["export_date"] as? String ?? "",
                totalCourses: metadataDict["total_courses"] as? Int ?? 0,
                version: metadataDict["version"] as? Int ?? 1
            )
            
            // Decode courses using JSONDecoder
            let courseDecoder = makeDecoder()
            
            let coursesData = try JSONSerialization.data(withJSONObject: coursesArray)
            let courses = try courseDecoder.decode([Course].self, from: coursesData)
            
            let bundleData = CourseBundle(metadata: metadata, courses: courses)
            
            print("✅ Successfully decoded bundle")
            print("✅ Loaded \(bundleData.courses.count) courses from bundle")
            print("📅 Bundle export date: \(bundleData.metadata.exportDate)")
            print("📊 Bundle version: \(bundleData.metadata.version)")
            
            // Log sample course for debugging
            if let firstCourse = bundleData.courses.first {
                print("📋 Sample course: \(firstCourse.name) in \(firstCourse.country ?? "Unknown")")
            }
            
            return bundleData.courses
        } catch {
            print("❌ Error loading bundled courses: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch: expected \(type), at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("❌ Value not found: \(type), at \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("❌ Key not found: \(key), at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            return []
        }
    }
    
    // MARK: - Sync Management
    
    /// Get the last sync date
    func getLastSyncDate() -> Date? {
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            return timestamp
        }
        return nil
    }
    
    /// Set the last sync date
    func setLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastSyncKey)
    }
    
    /// Check if sync is needed (e.g., if it's been more than 24 hours)
    func shouldSync() -> Bool {
        guard let lastSync = getLastSyncDate() else {
            return true // Never synced, should sync
        }
        
        // Sync if it's been more than 24 hours
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceSync >= 24
    }
    
    /// Get courses that have been updated since last sync
    func fetchUpdatedCourses(since date: Date, authHeaders: [String: String]) async throws -> [Course] {
        let supabaseUrl = "https://kanvhqwrfkzqktuvpxnp.supabase.co"
        let supabaseKey = "sb_publishable_JftEdMATFsi78Ba8rIFObg_tpOeIS2J"
        
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/courses")!
        urlComponents.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "updated_at", value: "gt.\(date.ISO8601Format())"),
            URLQueryItem(name: "order", value: "updated_at.desc"),
            URLQueryItem(name: "limit", value: "1000") // Get up to 1000 updated courses
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug: Log raw response for first course to check JSON keys
        if let jsonStr = String(data: data, encoding: .utf8), jsonStr.contains("Pebble Beach") {
            print("🔍 RAW JSON SNIPPET: \(jsonStr.prefix(1000))")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DataError.fetchFailed
        }
        
        let decoder = makeDecoder()
        
        do {
            let courses = try decoder.decode([Course].self, from: data)
            return courses
        } catch {
            print("❌ Error decoding updated courses: \(error)")
            // Try to decode one by one to find the culprit
            if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("ℹ️ Total courses in response: \(array.count)")
                for (index, dict) in array.prefix(3).enumerated() {
                    print("ℹ️ Course [\(index)]: \(dict["name"] ?? "Unknown")")
                    if dict["hole_data"] != nil {
                        print("ℹ️   Has hole_data in JSON")
                        // Try to decode just this course
                        do {
                            let courseData = try JSONSerialization.data(withJSONObject: dict)
                            let _ = try decoder.decode(Course.self, from: courseData)
                            print("ℹ️   Course decoded successfully")
                        } catch {
                            print("❌   Course decoding FAILED: \(error)")
                        }
                    } else {
                        print("ℹ️   No hole_data in JSON")
                    }
                }
            }
            throw error
        }
    }
    
    // MARK: - Cache Management
    
    /// Save courses to local cache (using file instead of UserDefaults for large data)
    func cacheCourses(_ courses: [Course]) {
        let encoder = JSONEncoder()
        // Use ISO8601 encoding for dates to stay consistent with the server
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let encoded = try encoder.encode(courses)
            try encoded.write(to: cacheFileURL)
            print("💾 Cached \(courses.count) courses to file (\(encoded.count) bytes)")
        } catch {
            print("⚠️ Error caching courses: \(error)")
        }
    }
    
    /// Load courses from cache
    func loadCachedCourses() -> [Course]? {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path),
              let data = try? Data(contentsOf: cacheFileURL) else {
            return nil
        }
        
        let decoder = makeDecoder()
        
        do {
            let courses = try decoder.decode([Course].self, from: data)
            print("💾 Loaded \(courses.count) courses from cache file")
            return courses
        } catch {
            print("⚠️ Error decoding cached courses: \(error)")
            return nil
        }
    }
    
    /// Clear the cache (useful when bundle is newer)
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheFileURL)
        // Also clear UserDefaults cache if it exists (for migration)
        UserDefaults.standard.removeObject(forKey: coursesCacheKey)
        print("🗑️ Cleared outdated cache")
    }
    
    /// Merge bundled courses with updated courses
    func mergeCourses(bundled: [Course], updated: [Course]) -> [Course] {
        var courseMap: [String: Course] = [:]
        
        // Start with bundled courses
        for course in bundled {
            courseMap[course.id] = course
        }
        
        // Override with updated courses (they're newer and may have hole_data)
        for course in updated {
            courseMap[course.id] = course
            // Debug: log if this course has hole_data
            if let holeData = course.holeData, !holeData.isEmpty {
                print("✅ Merged course '\(course.name)' with \(holeData.count) holes of data")
            }
        }
        
        let merged = Array(courseMap.values)
        print("🔄 Merged \(bundled.count) bundled + \(updated.count) updated = \(merged.count) total courses")
        return merged
    }
}

// MARK: - Course Bundle Data Structure

struct CourseBundle: Codable {
    let metadata: BundleMetadata
    let courses: [Course]
}

struct BundleMetadata: Codable {
    let exportDate: String
    let totalCourses: Int
    let version: Int
    
    enum CodingKeys: String, CodingKey {
        case exportDate = "export_date"
        case totalCourses = "total_courses"
        case version
    }
}

