import SwiftUI

/// Displays AI Caddie recommendations on the Watch
/// Syncs club recommendations from iPhone's AICaddieManager
struct AICaddieWatchView: View {
    @ObservedObject var roundManager = RoundManager.shared
    @ObservedObject var gpsManager = GPSManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("AI Caddie")
                        .font(.headline)
                    Spacer()
                }
                
                if let recommendation = roundManager.currentAIRecommendation {
                    // Club recommendation
                    clubRecommendationCard(recommendation)
                    
                    // Plays Like distance
                    if let playsLike = recommendation.playsLikeDistance {
                        playsLikeCard(playsLike)
                    }
                    
                    // Risk indicator
                    if let risk = recommendation.riskLevel {
                        riskCard(risk)
                    }
                } else if roundManager.isRoundActive {
                    // Waiting for recommendation
                    waitingCard
                } else {
                    // No round active
                    noRoundCard
                }
            }
            .padding()
        }
        .navigationTitle("AI Caddie")
    }
    
    // MARK: - Club Recommendation Card
    
    private func clubRecommendationCard(_ recommendation: WatchAIRecommendation) -> some View {
        VStack(spacing: 8) {
            Text("Recommended")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(recommendation.club)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            
            if let alternate = recommendation.alternateClub {
                Text("or \(alternate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if !recommendation.reasoning.isEmpty {
                Text(recommendation.reasoning)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.darkGray).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Plays Like Card
    
    private func playsLikeCard(_ playsLike: WatchPlaysLikeDistance) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Plays Like")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(playsLike.adjustedDistance)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("yds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Difference
                let diff = playsLike.adjustedDistance - playsLike.actualDistance
                if diff != 0 {
                    Text(diff > 0 ? "+\(diff)" : "\(diff)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(diff > 0 ? .red : .green)
                }
            }
            
            // Factors
            if !playsLike.factors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(playsLike.factors, id: \.name) { factor in
                        HStack {
                            Text(factor.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(factor.adjustment > 0 ? "+\(factor.adjustment)" : "\(factor.adjustment)")
                                .font(.caption2)
                                .foregroundStyle(factor.adjustment > 0 ? .red : .green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Risk Card
    
    private func riskCard(_ risk: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(riskColor(risk))
            
            Text("Risk: \(risk)")
                .font(.caption)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(riskColor(risk).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func riskColor(_ risk: String) -> Color {
        switch risk.lowercased() {
        case "low", "very low":
            return .green
        case "medium":
            return .yellow
        case "high", "very high":
            return .red
        default:
            return .gray
        }
    }
    
    // MARK: - Waiting Card
    
    private var waitingCard: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.purple)
            
            Text("Calculating...")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if gpsManager.distanceToGreenCenter > 0 {
                let distance = gpsManager.distanceToGreenCenter
                Text("\(distance) yards to center")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - No Round Card
    
    private var noRoundCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.golf")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Start a round to get AI recommendations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Watch AI Recommendation Models

struct WatchAIRecommendation: Codable {
    let club: String
    let alternateClub: String?
    let reasoning: String
    let playsLikeDistance: WatchPlaysLikeDistance?
    let riskLevel: String?
    
    init(club: String, alternateClub: String? = nil, reasoning: String = "", playsLikeDistance: WatchPlaysLikeDistance? = nil, riskLevel: String? = nil) {
        self.club = club
        self.alternateClub = alternateClub
        self.reasoning = reasoning
        self.playsLikeDistance = playsLikeDistance
        self.riskLevel = riskLevel
    }
}

struct WatchPlaysLikeDistance: Codable {
    let actualDistance: Int
    let adjustedDistance: Int
    let factors: [WatchDistanceFactor]
    
    init(actualDistance: Int, adjustedDistance: Int, factors: [WatchDistanceFactor] = []) {
        self.actualDistance = actualDistance
        self.adjustedDistance = adjustedDistance
        self.factors = factors
    }
}

struct WatchDistanceFactor: Codable {
    let name: String
    let adjustment: Int
    
    init(name: String, adjustment: Int) {
        self.name = name
        self.adjustment = adjustment
    }
}

// MARK: - RoundManager Extension for AI Recommendations

extension RoundManager {
    /// Current AI recommendation synced from iPhone
    var currentAIRecommendation: WatchAIRecommendation? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "currentAIRecommendation"),
                  let recommendation = try? JSONDecoder().decode(WatchAIRecommendation.self, from: data) else {
                return nil
            }
            return recommendation
        }
        set {
            if let newValue = newValue,
               let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "currentAIRecommendation")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentAIRecommendation")
            }
            objectWillChange.send()
        }
    }
    
    /// Handle AI recommendation message from iPhone
    func handleAIRecommendation(_ message: [String: Any]) {
        guard let club = message["club"] as? String else { return }
        
        var playsLike: WatchPlaysLikeDistance?
        if let actual = message["actualDistance"] as? Int,
           let adjusted = message["adjustedDistance"] as? Int {
            var factors: [WatchDistanceFactor] = []
            if let factorsData = message["factors"] as? [[String: Any]] {
                factors = factorsData.compactMap { dict in
                    guard let name = dict["name"] as? String,
                          let adjustment = dict["adjustment"] as? Int else { return nil }
                    return WatchDistanceFactor(name: name, adjustment: adjustment)
                }
            }
            playsLike = WatchPlaysLikeDistance(actualDistance: actual, adjustedDistance: adjusted, factors: factors)
        }
        
        let recommendation = WatchAIRecommendation(
            club: club,
            alternateClub: message["alternateClub"] as? String,
            reasoning: message["reasoning"] as? String ?? "",
            playsLikeDistance: playsLike,
            riskLevel: message["riskLevel"] as? String
        )
        
        DispatchQueue.main.async {
            self.currentAIRecommendation = recommendation
        }
    }
}

#Preview {
    AICaddieWatchView()
}
