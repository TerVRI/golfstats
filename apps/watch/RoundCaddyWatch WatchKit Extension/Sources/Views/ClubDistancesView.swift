import SwiftUI

/// Displays personalized club distances and statistics
struct ClubDistancesView: View {
    @ObservedObject var tracker: ClubDistanceTracker
    @State private var selectedClub: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(.blue)
                    Text("My Distances")
                        .font(.headline)
                }
                
                // Club list
                ForEach(tracker.clubsByDistance(), id: \.club) { item in
                    ClubDistanceRow(
                        club: item.club,
                        distance: item.distance,
                        stats: tracker.getStats(for: item.club),
                        isSelected: selectedClub == item.club
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedClub = selectedClub == item.club ? nil : item.club
                        }
                    }
                }
                
                // Insights
                let insights = tracker.generateInsights()
                if !insights.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INSIGHTS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        ForEach(insights, id: \.self) { insight in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(insight)
                                    .font(.caption2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Distances")
    }
}

// MARK: - Club Distance Row

struct ClubDistanceRow: View {
    let club: String
    let distance: Int
    let stats: ClubStatistics?
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack {
                Text(club)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 50, alignment: .leading)
                
                Spacer()
                
                // Distance bar
                GeometryReader { geo in
                    let maxWidth = geo.size.width
                    let barWidth = maxWidth * CGFloat(min(distance, 300)) / 300
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(clubColor)
                            .frame(width: barWidth, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
                
                Text("\(distance)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 35, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            
            // Expanded details
            if isSelected, let stats = stats, stats.totalShots > 0 {
                VStack(spacing: 6) {
                    Divider()
                    
                    HStack(spacing: 16) {
                        StatItem(label: "Shots", value: "\(stats.totalShots)")
                        StatItem(label: "Max", value: "\(stats.maxDistance)")
                        StatItem(label: "Min", value: "\(stats.minDistance)")
                        StatItem(label: "Consistency", value: "\(stats.consistencyScore)%")
                    }
                    
                    // Distance range indicator
                    if stats.totalShots >= 3 {
                        HStack {
                            Text("Range:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(stats.minDistance) - \(stats.maxDistance) yards")
                                .font(.caption2)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    var clubColor: Color {
        // Color code by club type
        if club.contains("W") || club == "Driver" {
            return .green
        } else if club.contains("i") {
            return .blue
        } else if club.contains("W") || club.contains("S") || club.contains("L") {
            return .orange
        } else if club == "Putter" {
            return .purple
        }
        return .gray
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Club Selection for Shot

struct ClubSelectionView: View {
    @ObservedObject var tracker: ClubDistanceTracker
    @Binding var selectedClub: String
    let distanceToGreen: Int
    @Environment(\.dismiss) private var dismiss
    
    var suggestedClub: String {
        tracker.suggestClub(forDistance: distanceToGreen)
    }
    
    var body: some View {
        List {
            // Suggested club
            if distanceToGreen > 0 {
                Section {
                    Button(action: {
                        selectedClub = suggestedClub
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(suggestedClub)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Suggested for \(distanceToGreen) yards")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                } header: {
                    Text("Recommended")
                }
            }
            
            // All clubs
            Section {
                ForEach(tracker.clubsByDistance(), id: \.club) { item in
                    Button(action: {
                        selectedClub = item.club
                        dismiss()
                    }) {
                        HStack {
                            Text(item.club)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(item.distance) yds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if item.club == selectedClub {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("All Clubs")
            }
        }
        .navigationTitle("Select Club")
    }
}

// MARK: - Preview

#Preview {
    let tracker = ClubDistanceTracker()
    // Add some sample data
    tracker.recordShot(club: "Driver", distance: 245)
    tracker.recordShot(club: "Driver", distance: 252)
    tracker.recordShot(club: "Driver", distance: 238)
    tracker.recordShot(club: "7i", distance: 155)
    tracker.recordShot(club: "7i", distance: 148)
    
    return NavigationStack {
        ClubDistancesView(tracker: tracker)
    }
}
