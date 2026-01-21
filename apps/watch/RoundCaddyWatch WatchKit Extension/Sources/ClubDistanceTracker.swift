import Foundation
import Combine

/// Tracks and learns personalized club distances over time
class ClubDistanceTracker: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var clubStats: [String: ClubStatistics] = [:]
    @Published var recentShots: [ClubDistanceRecord] = []
    
    // MARK: - Storage
    
    private let statsKey = "clubDistanceStats"
    private let recentShotsKey = "recentClubShots"
    private let maxRecentShots = 100
    
    // MARK: - Default Distances (before learning)
    
    static let defaultDistances: [String: Int] = [
        "Driver": 230,
        "3W": 210,
        "5W": 195,
        "4i": 180,
        "5i": 170,
        "6i": 160,
        "7i": 150,
        "8i": 140,
        "9i": 130,
        "PW": 115,
        "GW": 100,
        "SW": 85,
        "LW": 65,
        "Putter": 0
    ]
    
    // MARK: - Initialization
    
    init() {
        loadData()
    }
    
    // MARK: - Public Methods
    
    /// Record a shot distance for a club
    func recordShot(club: String, distance: Int, swingSpeed: Double? = nil) {
        // Create record
        let record = ClubDistanceRecord(club: club, distance: distance, swingSpeed: swingSpeed)
        recentShots.insert(record, at: 0)
        
        // Trim recent shots
        if recentShots.count > maxRecentShots {
            recentShots = Array(recentShots.prefix(maxRecentShots))
        }
        
        // Update statistics
        if clubStats[club] == nil {
            clubStats[club] = ClubStatistics(club: club)
        }
        clubStats[club]?.addDistance(distance)
        
        // Save
        saveData()
        
        print("📏 Recorded \(club): \(distance) yards (avg: \(String(format: "%.0f", clubStats[club]?.averageDistance ?? 0)))")
    }
    
    /// Get the suggested club for a given distance
    func suggestClub(forDistance distance: Int) -> String {
        // First, try to find best match from learned distances
        var bestClub = "7i"
        var bestDiff = Int.max
        
        for (club, stats) in clubStats where stats.totalShots >= 3 {
            let diff = abs(Int(stats.averageDistance) - distance)
            if diff < bestDiff {
                bestDiff = diff
                bestClub = club
            }
        }
        
        // If we found a good match (within 15 yards), use it
        if bestDiff <= 15 {
            return bestClub
        }
        
        // Fall back to defaults
        return suggestClubFromDefaults(forDistance: distance)
    }
    
    /// Get average distance for a club
    func averageDistance(for club: String) -> Int {
        if let stats = clubStats[club], stats.totalShots >= 1 {
            return Int(stats.averageDistance)
        }
        return Self.defaultDistances[club] ?? 150
    }
    
    /// Get statistics for a club
    func getStats(for club: String) -> ClubStatistics? {
        return clubStats[club]
    }
    
    /// Get all clubs sorted by average distance
    func clubsByDistance() -> [(club: String, distance: Int)] {
        var result: [(String, Int)] = []
        
        // Add learned clubs
        for (club, stats) in clubStats where stats.totalShots >= 1 {
            result.append((club, Int(stats.averageDistance)))
        }
        
        // Add defaults for clubs not yet tracked
        for (club, distance) in Self.defaultDistances {
            if !result.contains(where: { $0.0 == club }) {
                result.append((club, distance))
            }
        }
        
        return result.sorted { $0.1 > $1.1 }
    }
    
    /// Clear all data
    func clearAllData() {
        clubStats.removeAll()
        recentShots.removeAll()
        saveData()
    }
    
    /// Clear data for a specific club
    func clearClub(_ club: String) {
        clubStats.removeValue(forKey: club)
        recentShots.removeAll { $0.club == club }
        saveData()
    }
    
    // MARK: - Private Methods
    
    private func suggestClubFromDefaults(forDistance distance: Int) -> String {
        var bestClub = "7i"
        var bestDiff = Int.max
        
        for (club, avgDist) in Self.defaultDistances where club != "Putter" {
            let diff = abs(avgDist - distance)
            if diff < bestDiff {
                bestDiff = diff
                bestClub = club
            }
        }
        
        return bestClub
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        // Save stats
        if let statsData = try? JSONEncoder().encode(clubStats) {
            UserDefaults.standard.set(statsData, forKey: statsKey)
        }
        
        // Save recent shots
        if let shotsData = try? JSONEncoder().encode(recentShots) {
            UserDefaults.standard.set(shotsData, forKey: recentShotsKey)
        }
    }
    
    private func loadData() {
        // Load stats
        if let statsData = UserDefaults.standard.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode([String: ClubStatistics].self, from: statsData) {
            clubStats = stats
        }
        
        // Load recent shots
        if let shotsData = UserDefaults.standard.data(forKey: recentShotsKey),
           let shots = try? JSONDecoder().decode([ClubDistanceRecord].self, from: shotsData) {
            recentShots = shots
        }
    }
}

// MARK: - Club Distance Insights

extension ClubDistanceTracker {
    
    /// Generate insights based on tracked data
    func generateInsights() -> [String] {
        var insights: [String] = []
        
        // Find most consistent club
        var mostConsistent: (club: String, score: Int)? = nil
        for (club, stats) in clubStats where stats.totalShots >= 5 {
            let score = stats.consistencyScore
            if mostConsistent == nil || score > mostConsistent!.score {
                mostConsistent = (club, score)
            }
        }
        if let consistent = mostConsistent {
            insights.append("Most consistent: \(consistent.club) (\(consistent.score)% consistency)")
        }
        
        // Find club that performs above/below average
        for (club, stats) in clubStats where stats.totalShots >= 5 {
            let defaultDist = Self.defaultDistances[club] ?? 0
            let diff = Int(stats.averageDistance) - defaultDist
            
            if diff > 10 {
                insights.append("You hit \(club) \(diff) yards longer than average!")
            } else if diff < -10 {
                insights.append("Your \(club) is \(-diff) yards shorter than typical. Consider club up.")
            }
        }
        
        // Yardage gaps
        let sorted = clubsByDistance()
        for i in 0..<(sorted.count - 1) {
            let gap = sorted[i].distance - sorted[i+1].distance
            if gap > 25 {
                insights.append("Large \(gap) yard gap between \(sorted[i].club) and \(sorted[i+1].club)")
            }
        }
        
        return insights
    }
}
