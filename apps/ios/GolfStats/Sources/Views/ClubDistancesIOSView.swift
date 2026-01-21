import SwiftUI
import Charts

struct ClubDistancesIOSView: View {
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    @State private var selectedClub: ClubDistanceStats?
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                headerCard
                
                // Distance Chart
                if !watchSyncManager.clubDistances.isEmpty {
                    distanceChart
                }
                
                // Club List
                clubDistancesList
                
                // Tips Section
                if !watchSyncManager.clubDistances.isEmpty {
                    tipsSection
                }
            }
            .padding(.vertical)
        }
        .background(Color("Background"))
        .navigationTitle("Club Distances")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Reset Club Distances?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                // TODO: Implement reset
            }
        } message: {
            Text("This will clear all learned club distances. This cannot be undone.")
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "ruler")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Personal Yardages")
                        .font(.headline)
                    Text("Learned from \(totalShots) tracked shots")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if watchSyncManager.clubDistances.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No club data yet")
                        .font(.headline)
                    
                    Text("Play rounds with your Apple Watch to automatically learn your distances for each club")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Distance Chart
    
    private var distanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distance Overview")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(watchSyncManager.clubDistances) { stats in
                    BarMark(
                        x: .value("Club", stats.club),
                        yStart: .value("Min", stats.minDistance),
                        yEnd: .value("Max", stats.maxDistance)
                    )
                    .foregroundStyle(Color.blue.opacity(0.3))
                    
                    PointMark(
                        x: .value("Club", stats.club),
                        y: .value("Average", stats.averageDistance)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(100)
                }
            }
            .frame(height: 250)
            .chartYAxisLabel("Distance (yards)")
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Club List
    
    private var clubDistancesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Club Breakdown")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(clubsByCategory, id: \.0) { category, clubs in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category)
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(clubs) { club in
                        clubRow(club)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func clubRow(_ stats: ClubDistanceStats) -> some View {
        HStack(spacing: 16) {
            // Club name
            VStack(alignment: .leading, spacing: 2) {
                Text(stats.club)
                    .font(.headline)
                Text("\(stats.shotCount) shots")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .leading)
            
            // Distance bar
            GeometryReader { geo in
                let maxDistance = watchSyncManager.clubDistances.map { $0.maxDistance }.max() ?? 300
                let barWidth = CGFloat(stats.averageDistance) / CGFloat(maxDistance) * geo.size.width
                
                ZStack(alignment: .leading) {
                    // Range background
                    let rangeStart = CGFloat(stats.minDistance) / CGFloat(maxDistance) * geo.size.width
                    let rangeEnd = CGFloat(stats.maxDistance) / CGFloat(maxDistance) * geo.size.width
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: rangeEnd - rangeStart, height: 24)
                        .offset(x: rangeStart)
                    
                    // Average marker
                    RoundedRectangle(cornerRadius: 4)
                        .fill(consistencyColor(stats.consistencyScore))
                        .frame(width: 4, height: 32)
                        .offset(x: barWidth - 2)
                }
            }
            .frame(height: 32)
            
            // Distance value
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stats.averageDistance)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("yds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func consistencyColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    // MARK: - Tips Section
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .padding(.horizontal)
            
            // Most consistent club
            if let mostConsistent = watchSyncManager.clubDistances.max(by: { $0.consistencyScore < $1.consistencyScore }) {
                insightRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "Most Consistent",
                    value: mostConsistent.club,
                    detail: String(format: "%.0f%% consistency", mostConsistent.consistencyScore)
                )
            }
            
            // Longest club
            if let longest = watchSyncManager.clubDistances.filter({ $0.club != "Putter" }).max(by: { $0.averageDistance < $1.averageDistance }) {
                insightRow(
                    icon: "arrow.up.circle.fill",
                    color: .blue,
                    title: "Longest Club",
                    value: longest.club,
                    detail: "\(longest.averageDistance) yards average"
                )
            }
            
            // Club needing work (lowest consistency, excluding putter)
            if let needsWork = watchSyncManager.clubDistances
                .filter({ $0.club != "Putter" && $0.shotCount >= 5 })
                .min(by: { $0.consistencyScore < $1.consistencyScore }) {
                insightRow(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "Needs Work",
                    value: needsWork.club,
                    detail: "Range: \(needsWork.range) yards"
                )
            }
            
            // Gap finder
            if let gapClubs = findDistanceGaps() {
                insightRow(
                    icon: "arrow.left.arrow.right",
                    color: .purple,
                    title: "Distance Gap",
                    value: "\(gapClubs.0) → \(gapClubs.1)",
                    detail: "\(gapClubs.2) yard gap"
                )
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func insightRow(icon: String, color: Color, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }
            
            Spacer()
            
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var totalShots: Int {
        watchSyncManager.clubDistances.reduce(0) { $0 + $1.shotCount }
    }
    
    private var clubsByCategory: [(String, [ClubDistanceStats])] {
        let categories: [(String, [String])] = [
            ("Woods", ["Driver", "3W", "5W", "7W"]),
            ("Hybrids", ["2H", "3H", "4H", "5H"]),
            ("Irons", ["2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i"]),
            ("Wedges", ["PW", "GW", "52°", "54°", "SW", "56°", "58°", "LW", "60°"]),
            ("Putter", ["Putter"])
        ]
        
        return categories.compactMap { category, clubNames in
            let clubs = watchSyncManager.clubDistances.filter { clubNames.contains($0.club) }
            if clubs.isEmpty {
                return nil
            }
            return (category, clubs)
        }
    }
    
    private func findDistanceGaps() -> (String, String, Int)? {
        let sortedClubs = watchSyncManager.clubDistances
            .filter { $0.club != "Putter" }
            .sorted { $0.averageDistance > $1.averageDistance }
        
        var maxGap = 0
        var gapClubs: (String, String, Int)?
        
        for i in 0..<(sortedClubs.count - 1) {
            let gap = sortedClubs[i].averageDistance - sortedClubs[i + 1].averageDistance
            if gap > maxGap && gap > 15 { // Only report gaps > 15 yards
                maxGap = gap
                gapClubs = (sortedClubs[i].club, sortedClubs[i + 1].club, gap)
            }
        }
        
        return gapClubs
    }
}

#Preview {
    NavigationStack {
        ClubDistancesIOSView()
            .environmentObject(WatchSyncManager())
    }
}
