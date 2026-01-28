import Foundation
import CoreLocation
import Combine
import SystemConfiguration

/// Manages offline caching of course data for play without internet
/// Automatically caches played/favorited courses and supports manual downloads
class OfflineCacheManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = OfflineCacheManager()
    
    // MARK: - Published State
    
    @Published private(set) var cachedCourses: [CachedCourse] = []
    @Published private(set) var downloadingCourseIds: Set<String> = []
    @Published private(set) var totalCacheSize: Int64 = 0
    @Published var autoDownloadEnabled = true
    @Published var autoDownloadOnWiFiOnly = true
    
    // MARK: - Private Properties
    
    private let cacheDirectory: URL
    private let metadataFile: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB
    private let maxCachedCourses = 50
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Setup cache directory
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("CourseCache", isDirectory: true)
        metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        loadMetadata()
        calculateCacheSize()
        loadPreferences()
    }
    
    // MARK: - Cache Management
    
    /// Check if a course is cached
    func isCached(_ courseId: String) -> Bool {
        return cachedCourses.contains { $0.courseId == courseId }
    }
    
    /// Get cached course data
    func getCachedCourse(_ courseId: String) -> Course? {
        guard let cached = cachedCourses.first(where: { $0.courseId == courseId }) else {
            return nil
        }
        
        return loadCourseData(cached)
    }
    
    /// Cache a course for offline use
    func cacheCourse(_ course: Course, priority: CachePriority = .normal) async throws {
        guard !isCached(course.id) else {
            // Update last accessed time
            updateAccessTime(for: course.id)
            return
        }
        
        // Check if we have space
        if cachedCourses.count >= maxCachedCourses {
            evictOldestCourse()
        }
        
        downloadingCourseIds.insert(course.id)
        defer { downloadingCourseIds.remove(course.id) }
        
        // Save course data
        let courseFile = cacheDirectory.appendingPathComponent("\(course.id).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(course)
        try data.write(to: courseFile)
        
        // Create metadata entry
        let cached = CachedCourse(
            courseId: course.id,
            courseName: course.name,
            city: course.city,
            state: course.state,
            country: course.country,
            holeCount: course.holeData?.count ?? 18,
            hasPolygons: course.holeData?.contains { $0.fairway != nil } ?? false,
            cachedAt: Date(),
            lastAccessed: Date(),
            priority: priority,
            fileSize: Int64(data.count)
        )
        
        await MainActor.run {
            cachedCourses.append(cached)
            totalCacheSize += cached.fileSize
        }
        
        saveMetadata()
        
        print("✅ Cached course: \(course.name) (\(formatBytes(cached.fileSize)))")
    }
    
    /// Remove a course from cache
    func removeCachedCourse(_ courseId: String) {
        guard let index = cachedCourses.firstIndex(where: { $0.courseId == courseId }) else {
            return
        }
        
        let cached = cachedCourses[index]
        let courseFile = cacheDirectory.appendingPathComponent("\(courseId).json")
        
        try? FileManager.default.removeItem(at: courseFile)
        
        cachedCourses.remove(at: index)
        totalCacheSize -= cached.fileSize
        
        saveMetadata()
        
        print("🗑️ Removed cached course: \(cached.courseName)")
    }
    
    /// Clear all cached courses
    func clearCache() {
        for cached in cachedCourses {
            let courseFile = cacheDirectory.appendingPathComponent("\(cached.courseId).json")
            try? FileManager.default.removeItem(at: courseFile)
        }
        
        cachedCourses.removeAll()
        totalCacheSize = 0
        saveMetadata()
        
        print("🗑️ Cache cleared")
    }
    
    // MARK: - Auto-Caching
    
    /// Called when user plays a round - auto-cache the course
    func onRoundPlayed(course: Course) {
        guard autoDownloadEnabled else { return }
        
        Task {
            try? await cacheCourse(course, priority: .played)
        }
    }
    
    /// Called when user favorites a course
    func onCourseFavorited(course: Course) {
        guard autoDownloadEnabled else { return }
        
        Task {
            try? await cacheCourse(course, priority: .favorited)
        }
    }
    
    /// Called when user views a course (lower priority caching)
    func onCourseViewed(course: Course) {
        // Only cache if we have space and it's not already cached
        guard autoDownloadEnabled,
              cachedCourses.count < maxCachedCourses / 2,
              !isCached(course.id) else {
            return
        }
        
        Task {
            try? await cacheCourse(course, priority: .viewed)
        }
    }
    
    // MARK: - Nearby Course Caching
    
    /// Pre-cache courses near a location
    func cacheNearbyCourses(location: CLLocation, radius: CLLocationDistance = 50000, limit: Int = 5) async {
        guard autoDownloadEnabled else { return }
        
        // Check WiFi-only setting
        if autoDownloadOnWiFiOnly && !isOnWiFi() {
            print("📍 Skipping nearby course caching - not on WiFi")
            return
        }
        
        do {
            // Convert radius from meters to miles for API
            let radiusMiles = radius / 1609.34
            
            // Fetch nearby courses from API
            let nearbyCourses = try await DataService.shared.fetchNearbyCourses(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusMiles: radiusMiles,
                limit: limit
            )
            
            print("📍 Found \(nearbyCourses.count) nearby courses within \(Int(radiusMiles)) miles")
            
            // Cache courses that aren't already cached (up to limit)
            var cachedCount = 0
            for course in nearbyCourses {
                guard cachedCount < limit else { break }
                guard !isCached(course.id) else { continue }
                
                // Only cache courses with hole data (more useful offline)
                if course.holeData != nil {
                    do {
                        try await cacheCourse(course, priority: .normal)
                        cachedCount += 1
                    } catch {
                        print("⚠️ Failed to cache \(course.name): \(error.localizedDescription)")
                    }
                }
            }
            
            if cachedCount > 0 {
                print("✅ Cached \(cachedCount) nearby courses for offline use")
            }
        } catch {
            print("⚠️ Failed to fetch nearby courses: \(error.localizedDescription)")
        }
    }
    
    /// Check if device is on WiFi
    private func isOnWiFi() -> Bool {
        // Use NWPathMonitor for accurate network status
        // For simplicity, we'll use a basic check
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        // Check if reachable via WiFi (not cellular)
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let isWWAN = flags.contains(.isWWAN)
        
        return isReachable && !needsConnection && !isWWAN
    }
    
    // MARK: - Private Methods
    
    private func loadCourseData(_ cached: CachedCourse) -> Course? {
        let courseFile = cacheDirectory.appendingPathComponent("\(cached.courseId).json")
        
        guard let data = try? Data(contentsOf: courseFile) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try? decoder.decode(Course.self, from: data)
    }
    
    private func updateAccessTime(for courseId: String) {
        guard let index = cachedCourses.firstIndex(where: { $0.courseId == courseId }) else {
            return
        }
        
        cachedCourses[index].lastAccessed = Date()
        saveMetadata()
    }
    
    private func evictOldestCourse() {
        // Sort by priority (lower = more evictable) then by last accessed
        let sortedCourses = cachedCourses.sorted { a, b in
            if a.priority.rawValue != b.priority.rawValue {
                return a.priority.rawValue < b.priority.rawValue
            }
            return a.lastAccessed < b.lastAccessed
        }
        
        // Remove the most evictable course
        if let toRemove = sortedCourses.first {
            removeCachedCourse(toRemove.courseId)
        }
    }
    
    private func loadMetadata() {
        guard FileManager.default.fileExists(atPath: metadataFile.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: metadataFile)
            cachedCourses = try JSONDecoder().decode([CachedCourse].self, from: data)
            
            // Verify files still exist
            cachedCourses = cachedCourses.filter { cached in
                let file = cacheDirectory.appendingPathComponent("\(cached.courseId).json")
                return FileManager.default.fileExists(atPath: file.path)
            }
        } catch {
            print("⚠️ Failed to load cache metadata: \(error)")
        }
    }
    
    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(cachedCourses)
            try data.write(to: metadataFile)
        } catch {
            print("⚠️ Failed to save cache metadata: \(error)")
        }
    }
    
    private func calculateCacheSize() {
        totalCacheSize = cachedCourses.reduce(0) { $0 + $1.fileSize }
    }
    
    private func loadPreferences() {
        autoDownloadEnabled = UserDefaults.standard.bool(forKey: "offline_auto_download")
        autoDownloadOnWiFiOnly = UserDefaults.standard.bool(forKey: "offline_wifi_only")
    }
    
    func savePreferences() {
        UserDefaults.standard.set(autoDownloadEnabled, forKey: "offline_auto_download")
        UserDefaults.standard.set(autoDownloadOnWiFiOnly, forKey: "offline_wifi_only")
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - UI Helpers
    
    var formattedCacheSize: String {
        return formatBytes(totalCacheSize)
    }
    
    var cacheUsagePercent: Double {
        return Double(totalCacheSize) / Double(maxCacheSize) * 100
    }
}

// MARK: - Supporting Types

struct CachedCourse: Codable, Identifiable {
    var id: String { courseId }
    
    let courseId: String
    let courseName: String
    let city: String?
    let state: String?
    let country: String?
    let holeCount: Int
    let hasPolygons: Bool
    let cachedAt: Date
    var lastAccessed: Date
    let priority: CachePriority
    let fileSize: Int64
    
    var locationString: String {
        [city, state, country].compactMap { $0 }.joined(separator: ", ")
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var daysSinceAccessed: Int {
        Calendar.current.dateComponents([.day], from: lastAccessed, to: Date()).day ?? 0
    }
}

enum CachePriority: Int, Codable, Comparable {
    case viewed = 0     // Lowest priority - just viewed
    case normal = 1     // Manually downloaded
    case played = 2     // Played a round here
    case favorited = 3  // User favorited - highest priority
    
    static func < (lhs: CachePriority, rhs: CachePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .viewed: return "Viewed"
        case .normal: return "Downloaded"
        case .played: return "Played"
        case .favorited: return "Favorited"
        }
    }
}

// MARK: - SwiftUI Views

import SwiftUI

/// View for managing offline course cache
struct OfflineCacheView: View {
    @ObservedObject var cacheManager = OfflineCacheManager.shared
    @State private var showClearConfirmation = false
    
    var body: some View {
        List {
            // Storage section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cache Usage")
                            .font(.headline)
                        Spacer()
                        Text(cacheManager.formattedCacheSize)
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressView(value: cacheManager.cacheUsagePercent, total: 100)
                        .tint(cacheManager.cacheUsagePercent > 80 ? .orange : .green)
                    
                    Text("\(cacheManager.cachedCourses.count) courses cached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Settings section
            Section("Settings") {
                Toggle("Auto-download courses", isOn: $cacheManager.autoDownloadEnabled)
                    .onChange(of: cacheManager.autoDownloadEnabled) { _, _ in
                        cacheManager.savePreferences()
                    }
                
                if cacheManager.autoDownloadEnabled {
                    Toggle("WiFi only", isOn: $cacheManager.autoDownloadOnWiFiOnly)
                        .onChange(of: cacheManager.autoDownloadOnWiFiOnly) { _, _ in
                            cacheManager.savePreferences()
                        }
                }
            }
            
            // Cached courses
            Section("Cached Courses") {
                if cacheManager.cachedCourses.isEmpty {
                    Text("No courses cached")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedCourses) { cached in
                        CachedCourseRow(cached: cached)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let course = sortedCourses[index]
                            cacheManager.removeCachedCourse(course.courseId)
                        }
                    }
                }
            }
            
            // Clear cache
            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Cache")
                    }
                }
                .disabled(cacheManager.cachedCourses.isEmpty)
            }
        }
        .navigationTitle("Offline Courses")
        .alert("Clear Cache?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                cacheManager.clearCache()
            }
        } message: {
            Text("This will remove all \(cacheManager.cachedCourses.count) cached courses. You'll need internet to view course maps.")
        }
    }
    
    private var sortedCourses: [CachedCourse] {
        cacheManager.cachedCourses.sorted { a, b in
            if a.priority != b.priority {
                return a.priority > b.priority
            }
            return a.lastAccessed > b.lastAccessed
        }
    }
}

struct CachedCourseRow: View {
    let cached: CachedCourse
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(cached.courseName)
                    .font(.headline)
                
                Text(cached.locationString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label(cached.priority.displayName, systemImage: priorityIcon)
                        .font(.caption2)
                        .foregroundStyle(priorityColor)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(cached.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }
    
    private var priorityIcon: String {
        switch cached.priority {
        case .viewed: return "eye"
        case .normal: return "arrow.down.circle"
        case .played: return "figure.golf"
        case .favorited: return "heart.fill"
        }
    }
    
    private var priorityColor: Color {
        switch cached.priority {
        case .viewed: return .gray
        case .normal: return .blue
        case .played: return .green
        case .favorited: return .red
        }
    }
}

/// Indicator showing if current course is cached
struct OfflineIndicator: View {
    let courseId: String
    @ObservedObject var cacheManager = OfflineCacheManager.shared
    
    var body: some View {
        if cacheManager.isCached(courseId) {
            Label("Available Offline", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if cacheManager.downloadingCourseIds.contains(courseId) {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Downloading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Button to download course for offline use
struct DownloadForOfflineButton: View {
    let course: Course
    @ObservedObject var cacheManager = OfflineCacheManager.shared
    
    var body: some View {
        if cacheManager.isCached(course.id) {
            Button(role: .destructive) {
                cacheManager.removeCachedCourse(course.id)
            } label: {
                Label("Remove Download", systemImage: "trash")
            }
        } else if cacheManager.downloadingCourseIds.contains(course.id) {
            HStack {
                ProgressView()
                Text("Downloading...")
            }
        } else {
            Button {
                Task {
                    try? await cacheManager.cacheCourse(course, priority: .normal)
                }
            } label: {
                Label("Download for Offline", systemImage: "arrow.down.circle")
            }
        }
    }
}
