import SwiftUI

/// AI Caddie view showing smart recommendations for the current shot
struct AICaddieView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @StateObject private var caddieManager = AICaddieManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Current recommendation
                if let recommendation = caddieManager.currentRecommendation {
                    recommendationCard(recommendation)
                } else if caddieManager.isCalculating {
                    loadingCard
                } else {
                    emptyStateCard
                }
                
                // Quick stats
                quickStatsSection
                
                // Feature toggles
                togglesSection
            }
            .padding()
        }
        .background(Color("Background"))
        .navigationTitle("AI Caddie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                AICaddieSettingsView()
            }
        }
        .onAppear {
            updateRecommendation()
        }
        .onChange(of: gpsManager.distanceToCenter) { _, _ in
            updateRecommendation()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Caddie")
                    .font(.headline)
                Text("Smart recommendations for your game")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Enable/disable toggle
            Toggle("", isOn: $caddieManager.isEnabled)
                .labelsHidden()
                .tint(.purple)
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
    
    // MARK: - Recommendation Card
    
    private func recommendationCard(_ recommendation: CaddieRecommendation) -> some View {
        VStack(spacing: 16) {
            // Distance and "Plays Like"
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance to Green")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(recommendation.distanceToTarget) yds")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if let playsLike = recommendation.playsLikeDistance {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Plays Like")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack(spacing: 4) {
                            Text("\(playsLike.playsLikeDistance) yds")
                                .font(.title2)
                                .fontWeight(.semibold)
                            if playsLike.playsLikeDistance > recommendation.distanceToTarget {
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.red)
                            } else if playsLike.playsLikeDistance < recommendation.distanceToTarget {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Club recommendation
            if let club = recommendation.club {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommended Club")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(club.primary)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        if let alternate = club.alternate {
                            Text("Alt: \(alternate)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Adjusted")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(club.adjustedDistance) yds")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(club.reasoning)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // Target recommendation
            if let target = recommendation.target {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Strategy")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.orange)
                        Text("Aim \(target.aimPoint.rawValue.capitalized)")
                            .font(.subheadline)
                    }
                    
                    if !target.reasoning.isEmpty {
                        Text(target.reasoning)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Shot probabilities
            if let probabilities = recommendation.probabilities {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score Probabilities")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        probabilityBadge(label: "Birdie", value: probabilities.birdie, color: .green)
                        probabilityBadge(label: "Par", value: probabilities.par, color: .blue)
                        probabilityBadge(label: "Bogey", value: probabilities.bogey, color: .orange)
                        probabilityBadge(label: "GIR", value: probabilities.greenInRegulation, color: .cyan)
                    }
                }
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
    
    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Calculating recommendation...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("No Recommendation Available")
                .font(.headline)
            Text("Start a round to get AI-powered suggestions")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Conditions")
                .font(.headline)
            
            HStack(spacing: 12) {
                conditionCard(icon: "thermometer", label: "Temp", value: "72°F")
                conditionCard(icon: "wind", label: "Wind", value: "8 mph")
                conditionCard(icon: "arrow.up.right", label: "Elevation", value: "+15 ft")
            }
        }
    }
    
    private func conditionCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(10)
    }
    
    // MARK: - Toggles Section
    
    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.headline)
            
            VStack(spacing: 8) {
                featureToggle("Club Recommendation", isOn: $caddieManager.settings.showClubRecommendation, icon: "figure.golf")
                featureToggle("Plays Like Distance", isOn: $caddieManager.settings.showPlaysLikeDistance, icon: "arrow.up.arrow.down")
                featureToggle("Target Strategy", isOn: $caddieManager.settings.showTargetRecommendation, icon: "target")
                featureToggle("Shot Probabilities", isOn: $caddieManager.settings.showProbabilities, icon: "percent")
            }
        }
    }
    
    private func featureToggle(_ title: String, isOn: Binding<Bool>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.purple)
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.purple)
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Views
    
    private func probabilityBadge(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value * 100))%")
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .yellow }
        return .orange
    }
    
    private func riskColor(_ risk: String) -> Color {
        switch risk.lowercased() {
        case "low": return .green
        case "medium": return .yellow
        case "high": return .red
        default: return .gray
        }
    }
    
    // MARK: - Actions
    
    private func updateRecommendation() {
        guard caddieManager.isEnabled,
              let distance = gpsManager.distanceToCenter else { return }
        
        var holeContext = HoleContext(
            holeNumber: roundManager.currentHole,
            par: roundManager.selectedCourse?.holeData?[safe: roundManager.currentHole - 1]?.par ?? 4
        )
        holeContext.currentLie = .fairway
        holeContext.greenDifficulty = .medium
        
        caddieManager.currentRecommendation = caddieManager.getRecommendation(
            distanceToTarget: distance,
            currentHole: holeContext
        )
    }
}

// MARK: - Supporting Types

// Array safe subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        AICaddieView()
            .environmentObject(GPSManager())
            .environmentObject(RoundManager())
    }
    .preferredColorScheme(.dark)
}
