import SwiftUI
import Charts

struct SwingAnalyticsView: View {
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    @State private var selectedTab = 0
    @State private var selectedTimeRange: TimeRange = .lastRound
    
    enum TimeRange: String, CaseIterable {
        case lastRound = "Last Round"
        case last7Days = "7 Days"
        case last30Days = "30 Days"
        case allTime = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection Status
                    connectionStatusBanner
                    
                    // Live Metrics (if in round)
                    if watchSyncManager.watchRoundActive, let metrics = watchSyncManager.liveSwingMetrics {
                        liveMetricsCard(metrics)
                    }
                    
                    // Quick Stats
                    quickStatsGrid
                    
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Tempo Trend Chart
                    if !filteredSwings.isEmpty {
                        tempoTrendChart
                    }
                    
                    // Recent Swings List
                    recentSwingsList
                    
                    // Session Summary (if available)
                    if let summary = watchSyncManager.currentSessionSummary {
                        sessionSummaryCard(summary)
                    }
                }
                .padding(.vertical)
            }
            .background(Color("Background"))
            .navigationTitle("Swing Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ClubDistancesIOSView()) {
                        Image(systemName: "ruler")
                    }
                }
            }
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: watchSyncManager.isWatchConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                .font(.title2)
                .foregroundColor(watchSyncManager.isWatchConnected ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(watchSyncManager.isWatchConnected ? "Watch Connected" : "Watch Not Connected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if watchSyncManager.isWatchConnected {
                    if let lastUpdate = watchSyncManager.lastWatchUpdate {
                        Text("Last sync: \(lastUpdate, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Open the app on your Apple Watch to sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if watchSyncManager.watchRoundActive {
                Text("LIVE")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Live Metrics Card
    
    private func liveMetricsCard(_ metrics: LiveSwingMetrics) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Live Swing Metrics")
                    .font(.headline)
                Spacer()
                if metrics.isSwingInProgress {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Swing in progress")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            HStack(spacing: 20) {
                liveMetricItem(
                    title: "Tempo",
                    value: metrics.tempoRatio,
                    icon: "metronome",
                    color: .blue
                )
                
                liveMetricItem(
                    title: "Hand Speed",
                    value: metrics.handSpeedFormatted,
                    icon: "gauge.with.needle",
                    color: .orange
                )
                
                liveMetricItem(
                    title: "Impact",
                    value: metrics.impactFormatted,
                    icon: "target",
                    color: .green
                )
            }
            
            if let path = metrics.swingPath {
                HStack {
                    Image(systemName: "arrow.turn.right.down")
                        .foregroundColor(.purple)
                    Text("Path: \(path.displayName)")
                        .font(.subheadline)
                    Spacer()
                    Text(path.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
    }
    
    private func liveMetricItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Quick Stats Grid
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            statCard(
                title: "Avg Tempo",
                value: averageTempo,
                subtitle: "3:1 is ideal",
                icon: "metronome",
                color: .blue
            )
            
            statCard(
                title: "Avg Hand Speed",
                value: averageHandSpeed,
                subtitle: "Peak velocity",
                icon: "gauge.with.needle",
                color: .orange
            )
            
            statCard(
                title: "Impact Quality",
                value: averageImpact,
                subtitle: "Center strike %",
                icon: "target",
                color: .green
            )
            
            statCard(
                title: "Total Swings",
                value: "\(filteredSwings.count)",
                subtitle: selectedTimeRange.rawValue,
                icon: "figure.golf",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
    
    // MARK: - Tempo Trend Chart
    
    private var tempoTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tempo Trend")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(Array(filteredSwings.prefix(20).enumerated()), id: \.element.id) { index, swing in
                    if let tempo = swing.tempo {
                        LineMark(
                            x: .value("Swing", index),
                            y: .value("Tempo", tempo)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        
                        PointMark(
                            x: .value("Swing", index),
                            y: .value("Tempo", tempo)
                        )
                        .foregroundStyle(tempoColor(tempo))
                    }
                }
                
                // Ideal tempo line
                RuleMark(y: .value("Ideal", 3.0))
                    .foregroundStyle(Color.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Ideal")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
            }
            .frame(height: 200)
            .chartYScale(domain: 1.5...4.5)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func tempoColor(_ tempo: Double) -> Color {
        if tempo >= 2.8 && tempo <= 3.2 {
            return .green
        } else if tempo >= 2.5 && tempo <= 3.5 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // MARK: - Recent Swings List
    
    private var recentSwingsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Swings")
                    .font(.headline)
                Spacer()
                Text("\(filteredSwings.count) swings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if filteredSwings.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredSwings.prefix(10)) { swing in
                    swingRow(swing)
                }
            }
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func swingRow(_ swing: SwingRecord) -> some View {
        HStack(spacing: 12) {
            // Club icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(swing.club ?? "?")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(swing.club ?? "Unknown Club")
                        .font(.subheadline.bold())
                    
                    if let distance = swing.distance {
                        Text("• \(distance) yds")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    if let tempo = swing.tempo {
                        Label(String(format: "%.1f:1", tempo), systemImage: "metronome")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let speed = swing.peakHandSpeed {
                        Label(String(format: "%.0f mph", speed), systemImage: "gauge.with.needle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if let impact = swing.impactQuality {
                        Label(String(format: "%.0f%%", impact), systemImage: "target")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            Text(swing.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.golf")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Swings Recorded")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Start a round with your Apple Watch to track your swings automatically")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
    
    // MARK: - Session Summary Card
    
    private func sessionSummaryCard(_ summary: SwingSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Session Summary")
                    .font(.headline)
                Spacer()
                Text(summary.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 24) {
                VStack {
                    Text("\(summary.totalSwings)")
                        .font(.title2.bold())
                    Text("Swings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(summary.totalPutts)")
                        .font(.title2.bold())
                    Text("Putts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let tempo = summary.averageTempo {
                    VStack {
                        Text(String(format: "%.1f:1", tempo))
                            .font(.title2.bold())
                        Text("Avg Tempo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let impact = summary.bestImpactQuality {
                    VStack {
                        Text(String(format: "%.0f%%", impact))
                            .font(.title2.bold())
                        Text("Best Impact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !summary.tips.isEmpty {
                Divider()
                
                Text("Tips from this session")
                    .font(.subheadline.bold())
                
                ForEach(summary.tips.prefix(3)) { tip in
                    HStack(spacing: 8) {
                        Image(systemName: tip.category.icon)
                            .foregroundColor(tipColor(tip.category))
                        Text(tip.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func tipColor(_ category: WatchCoachingTip.TipCategory) -> Color {
        switch category {
        case .tempo: return .blue
        case .consistency: return .green
        case .speed: return .orange
        case .path: return .purple
        case .putting: return .teal
        case .general: return .gray
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredSwings: [SwingRecord] {
        let now = Date()
        switch selectedTimeRange {
        case .lastRound:
            // If there's an active round, show all today's swings
            if watchSyncManager.watchRoundActive {
                return watchSyncManager.recentSwings.filter { 
                    Calendar.current.isDateInToday($0.timestamp)
                }
            }
            // Otherwise show last 18 swings
            return Array(watchSyncManager.recentSwings.prefix(18))
            
        case .last7Days:
            return watchSyncManager.recentSwings.filter {
                $0.timestamp > Calendar.current.date(byAdding: .day, value: -7, to: now)!
            }
            
        case .last30Days:
            return watchSyncManager.recentSwings.filter {
                $0.timestamp > Calendar.current.date(byAdding: .day, value: -30, to: now)!
            }
            
        case .allTime:
            return watchSyncManager.recentSwings
        }
    }
    
    private var averageTempo: String {
        let tempos = filteredSwings.compactMap { $0.tempo }
        guard !tempos.isEmpty else { return "--" }
        let avg = tempos.reduce(0, +) / Double(tempos.count)
        return String(format: "%.1f:1", avg)
    }
    
    private var averageHandSpeed: String {
        let speeds = filteredSwings.compactMap { $0.peakHandSpeed }
        guard !speeds.isEmpty else { return "--" }
        let avg = speeds.reduce(0, +) / Double(speeds.count)
        return String(format: "%.0f mph", avg)
    }
    
    private var averageImpact: String {
        let impacts = filteredSwings.compactMap { $0.impactQuality }
        guard !impacts.isEmpty else { return "--" }
        let avg = impacts.reduce(0, +) / Double(impacts.count)
        return String(format: "%.0f%%", avg)
    }
}

#Preview {
    SwingAnalyticsView()
        .environmentObject(WatchSyncManager())
}
