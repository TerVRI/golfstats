import SwiftUI

/// Displays coaching tips and insights based on swing analysis
struct CoachingTipsView: View {
    @ObservedObject var coachingEngine: CoachingEngine
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Coaching")
                        .font(.headline)
                }
                
                if coachingEngine.latestTips.isEmpty {
                    // No tips yet
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No tips yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Take a few swings to get personalized coaching")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                } else {
                    // Tips by category
                    ForEach(CoachingTip.TipCategory.allCases, id: \.self) { category in
                        let categoryTips = coachingEngine.tips(for: category)
                        if !categoryTips.isEmpty {
                            TipCategorySection(category: category, tips: categoryTips)
                        }
                    }
                }
                
                // Session summary
                if !coachingEngine.sessionSummary.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SESSION SUMMARY")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(coachingEngine.sessionSummary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Coaching")
    }
}

// MARK: - Tip Category Section

struct TipCategorySection: View {
    let category: CoachingTip.TipCategory
    let tips: [CoachingTip]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
                Text(category.rawValue.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ForEach(tips) { tip in
                TipCard(tip: tip)
            }
        }
    }
    
    var categoryIcon: String {
        switch category {
        case .tempo: return "metronome"
        case .speed: return "speedometer"
        case .consistency: return "target"
        case .path: return "arrow.up.right"
        case .putting: return "flag.fill"
        case .general: return "lightbulb"
        }
    }
    
    var categoryColor: Color {
        switch category {
        case .tempo: return .blue
        case .speed: return .orange
        case .consistency: return .green
        case .path: return .purple
        case .putting: return .cyan
        case .general: return .yellow
        }
    }
}

// MARK: - Tip Card

struct TipCard: View {
    let tip: CoachingTip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tip.title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Priority indicator
                ForEach(0..<(4 - tip.priority), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            
            Text(tip.message)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(priorityBackground)
        .cornerRadius(8)
    }
    
    var priorityBackground: Color {
        switch tip.priority {
        case 1: return Color.orange.opacity(0.15)
        case 2: return Color.blue.opacity(0.1)
        default: return Color.green.opacity(0.1)
        }
    }
}

// MARK: - All Categories

extension CoachingTip.TipCategory: CaseIterable {
    static var allCases: [CoachingTip.TipCategory] {
        [.tempo, .speed, .consistency, .path, .putting, .general]
    }
}

// MARK: - Preview

#Preview {
    let engine = CoachingEngine()
    // Add some sample tips
    engine.latestTips = [
        CoachingTip(category: .tempo, title: "Great Tempo! 🎯", message: "Your 3.0:1 tempo is in the pro range.", priority: 3),
        CoachingTip(category: .speed, title: "Speed Variance", message: "Your swing speed varies by 8 mph. Work on consistency.", priority: 1),
        CoachingTip(category: .path, title: "Over-the-Top Pattern", message: "60% of swings are over-the-top. Focus on dropping hands.", priority: 1)
    ]
    engine.sessionSummary = "Average Tempo: 3.1:1\nAverage Speed: 22 mph\nConsistency: 75/100"
    
    return NavigationStack {
        CoachingTipsView(coachingEngine: engine)
    }
}
