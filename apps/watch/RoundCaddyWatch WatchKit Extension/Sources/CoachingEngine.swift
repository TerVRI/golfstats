import Foundation
import Combine

/// Analyzes swing patterns and generates coaching tips
class CoachingEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var latestTips: [CoachingTip] = []
    @Published var sessionSummary: String = ""
    
    // MARK: - Private State
    
    private var swingHistory: [SwingAnalytics] = []
    private var maxHistory = 50
    
    // Pattern thresholds
    private let targetTempoRatio = 3.0
    private let tempoVarianceThreshold = 0.3
    private let speedVarianceThreshold = 3.0 // mph
    
    // MARK: - Public Methods
    
    /// Add a swing to history and analyze
    func addSwing(_ analytics: SwingAnalytics) {
        swingHistory.insert(analytics, at: 0)
        
        // Trim history
        if swingHistory.count > maxHistory {
            swingHistory = Array(swingHistory.prefix(maxHistory))
        }
        
        // Generate tips based on patterns
        analyzePatterns()
    }
    
    /// Get tips for a specific category
    func tips(for category: CoachingTip.TipCategory) -> [CoachingTip] {
        return latestTips.filter { $0.category == category }
    }
    
    /// Clear all tips
    func clearTips() {
        latestTips.removeAll()
    }
    
    /// Generate end-of-session summary
    func generateSessionSummary() -> String {
        guard swingHistory.count >= 3 else {
            return "Need at least 3 swings for analysis."
        }
        
        var summary: [String] = []
        
        // Tempo analysis
        let avgTempo = swingHistory.map { $0.tempoRatio }.reduce(0, +) / Double(swingHistory.count)
        summary.append("Average Tempo: \(String(format: "%.1f", avgTempo)):1")
        
        // Speed analysis
        let avgSpeed = swingHistory.map { $0.peakHandSpeed }.reduce(0, +) / Double(swingHistory.count)
        summary.append("Average Hand Speed: \(String(format: "%.0f", avgSpeed)) mph")
        
        // Consistency
        let tempos = swingHistory.map { $0.tempoRatio }
        let tempoStdDev = standardDeviation(tempos)
        let consistencyScore = max(0, 100 - Int(tempoStdDev * 50))
        summary.append("Consistency Score: \(consistencyScore)/100")
        
        // Impact rate
        let impactCount = swingHistory.filter { $0.impactDetected }.count
        let impactRate = Double(impactCount) / Double(swingHistory.count) * 100
        summary.append("Solid Contact Rate: \(String(format: "%.0f", impactRate))%")
        
        sessionSummary = summary.joined(separator: "\n")
        return sessionSummary
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzePatterns() {
        latestTips.removeAll()
        
        guard swingHistory.count >= 3 else { return }
        
        analyzeTempo()
        analyzeSpeed()
        analyzeConsistency()
        analyzeSwingPath()
        analyzePressure()
        
        // Sort by priority
        latestTips.sort { $0.priority < $1.priority }
    }
    
    private func analyzeTempo() {
        let recentSwings = Array(swingHistory.prefix(10))
        let avgTempo = recentSwings.map { $0.tempoRatio }.reduce(0, +) / Double(recentSwings.count)
        
        // Check if tempo is too fast
        if avgTempo < 2.5 {
            latestTips.append(CoachingTip(
                category: .tempo,
                title: "Rushed Tempo",
                message: "Your tempo is \(String(format: "%.1f", avgTempo)):1. Try slowing your backswing. Pro tempo is around 3:1.",
                priority: 1
            ))
        }
        // Check if tempo is too slow
        else if avgTempo > 4.0 {
            latestTips.append(CoachingTip(
                category: .tempo,
                title: "Slow Tempo",
                message: "Your tempo is \(String(format: "%.1f", avgTempo)):1. A slightly faster transition may add power.",
                priority: 2
            ))
        }
        // Good tempo
        else if avgTempo >= 2.8 && avgTempo <= 3.2 {
            latestTips.append(CoachingTip(
                category: .tempo,
                title: "Great Tempo! 🎯",
                message: "Your \(String(format: "%.1f", avgTempo)):1 tempo is in the pro range (3:1). Keep it up!",
                priority: 3
            ))
        }
    }
    
    private func analyzeSpeed() {
        let recentSwings = Array(swingHistory.prefix(10))
        let speeds = recentSwings.map { $0.peakHandSpeed }
        guard !speeds.isEmpty else { return }
        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        let minSpeed = speeds.min() ?? 0
        
        // Large speed variance
        let variance = maxSpeed - minSpeed
        if variance > 8 {
            latestTips.append(CoachingTip(
                category: .speed,
                title: "Speed Variance",
                message: "Your swing speed varies by \(String(format: "%.0f", variance)) mph (avg: \(String(format: "%.0f", avgSpeed)) mph). Consistent speed = consistent distance.",
                priority: 1
            ))
        }
        
        // Speed trending down
        if swingHistory.count >= 10 {
            let first5Speed = Array(swingHistory[0..<5]).map { $0.peakHandSpeed }.reduce(0, +) / 5
            let last5Speed = Array(swingHistory[5..<10]).map { $0.peakHandSpeed }.reduce(0, +) / 5
            
            if first5Speed < last5Speed - 3 {
                latestTips.append(CoachingTip(
                    category: .speed,
                    title: "Fatigue Detected",
                    message: "Your recent swings are \(String(format: "%.0f", last5Speed - first5Speed)) mph slower. Take a break?",
                    priority: 2
                ))
            }
        }
    }
    
    private func analyzeConsistency() {
        guard swingHistory.count >= 5 else { return }
        
        let tempos = swingHistory.prefix(10).map { $0.tempoRatio }
        let stdDev = standardDeviation(Array(tempos))
        
        if stdDev > tempoVarianceThreshold {
            latestTips.append(CoachingTip(
                category: .consistency,
                title: "Tempo Inconsistency",
                message: "Your tempo varies swing to swing. Try a consistent pre-shot routine.",
                priority: 1
            ))
        } else if stdDev < 0.15 {
            latestTips.append(CoachingTip(
                category: .consistency,
                title: "Consistent Tempo! 🎯",
                message: "Excellent tempo consistency. This leads to predictable shots.",
                priority: 3
            ))
        }
    }
    
    private func analyzeSwingPath() {
        let recentSwings = Array(swingHistory.prefix(10))
        let overTheTopCount = recentSwings.filter { $0.swingPath == .overTheTop }.count
        let insideOutCount = recentSwings.filter { $0.swingPath == .insideOut }.count
        
        if overTheTopCount >= 6 {
            latestTips.append(CoachingTip(
                category: .path,
                title: "Over-the-Top Pattern",
                message: "\(overTheTopCount * 10)% of swings are over-the-top. This causes slices. Focus on dropping hands in transition.",
                priority: 1
            ))
        }
        
        if insideOutCount >= 8 {
            latestTips.append(CoachingTip(
                category: .path,
                title: "Strong Inside-Out",
                message: "Your path promotes a draw. Watch for hooks on fast swings.",
                priority: 2
            ))
        }
    }
    
    private func analyzePressure() {
        // Analyze if tempo changes under "pressure" (last few holes)
        // This requires hole context which we may not have
        // Placeholder for future integration
        
        guard swingHistory.count >= 15 else { return }
        
        // Compare first half vs second half of session
        let firstHalf = Array(swingHistory.suffix(swingHistory.count / 2))
        let secondHalf = Array(swingHistory.prefix(swingHistory.count / 2))
        
        let firstTempo = firstHalf.map { $0.tempoRatio }.reduce(0, +) / Double(firstHalf.count)
        let secondTempo = secondHalf.map { $0.tempoRatio }.reduce(0, +) / Double(secondHalf.count)
        
        if secondTempo < firstTempo - 0.3 {
            latestTips.append(CoachingTip(
                category: .general,
                title: "Late-Round Rush",
                message: "Your tempo sped up later in the session. Stay patient!",
                priority: 2
            ))
        }
    }
    
    // MARK: - Utility
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumOfSquares = values.reduce(0) { $0 + pow($1 - mean, 2) }
        return sqrt(sumOfSquares / Double(values.count - 1))
    }
}

// MARK: - Pre-shot Tips

extension CoachingEngine {
    
    /// Get a pre-shot tip based on current context
    func preShotTip(
        distanceToGreen: Int,
        suggestedClub: String,
        recentMisses: [SwingPath]
    ) -> String? {
        // If recent misses are all one direction, suggest compensation
        if recentMisses.suffix(3).allSatisfy({ $0 == .overTheTop }) {
            return "Focus on an inside takeaway"
        }
        
        // Distance-based tips
        if distanceToGreen < 100 {
            return "Smooth tempo for control"
        }
        
        if distanceToGreen > 200 {
            return "Stay balanced through the swing"
        }
        
        return nil
    }
    
    /// Get a putting tip based on recent putts
    func puttingTip(puttCount: Int, distanceToHole: Int) -> String? {
        if puttCount >= 2 && distanceToHole < 5 {
            return "Commit to the line"
        }
        
        if distanceToHole > 30 {
            return "Focus on speed control"
        }
        
        return nil
    }
}
