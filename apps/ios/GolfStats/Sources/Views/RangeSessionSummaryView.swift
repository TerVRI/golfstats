import SwiftUI
import Charts

/// Summary view displayed after completing a Range Mode session
struct RangeSessionSummaryView: View {
    let session: RangeSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header stats
                    headerStats
                    
                    // Tempo chart
                    if session.swings.count >= 2 {
                        tempoChart
                    }
                    
                    // Key metrics
                    keyMetrics
                    
                    // Swing list
                    swingsList
                    
                    // Insights
                    if !insights.isEmpty {
                        insightsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Practice Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Stats
    
    private var headerStats: some View {
        HStack(spacing: 20) {
            statCard(
                title: "Swings",
                value: "\(session.swingCount)",
                icon: "figure.golf"
            )
            
            statCard(
                title: "Duration",
                value: formattedDuration,
                icon: "clock"
            )
            
            statCard(
                title: "Consistency",
                value: session.consistencyScore.map { "\(Int($0))%" } ?? "--",
                icon: "chart.bar.fill",
                color: consistencyColor
            )
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color = .green) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var formattedDuration: String {
        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        return "\(minutes)m \(seconds)s"
    }
    
    private var consistencyColor: Color {
        guard let score = session.consistencyScore else { return .gray }
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .orange
    }
    
    // MARK: - Tempo Chart
    
    private var tempoChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tempo Over Session")
                .font(.headline)
            
            Chart {
                // Target tempo line
                RuleMark(y: .value("Target", 3.0))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Target")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                
                // Tempo values
                ForEach(Array(session.swings.enumerated()), id: \.element.id) { index, swing in
                    if let tempo = swing.combinedMetrics?.tempoRatio {
                        LineMark(
                            x: .value("Swing", index + 1),
                            y: .value("Tempo", tempo)
                        )
                        .foregroundStyle(.blue)
                        
                        PointMark(
                            x: .value("Swing", index + 1),
                            y: .value("Tempo", tempo)
                        )
                        .foregroundStyle(tempoColor(tempo))
                    }
                }
            }
            .chartYScale(domain: 1.5...4.5)
            .chartYAxis {
                AxisMarks(values: [2.0, 2.5, 3.0, 3.5, 4.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(String(format: "%.1f", v)):1")
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func tempoColor(_ tempo: Double) -> Color {
        let deviation = abs(tempo - 3.0)
        if deviation < 0.3 { return .green }
        if deviation < 0.6 { return .yellow }
        return .orange
    }
    
    // MARK: - Key Metrics
    
    private var keyMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricRow(
                    title: "Avg Tempo",
                    value: session.averageTempo.map { String(format: "%.1f:1", $0) } ?? "--",
                    target: "Target: 3.0:1",
                    isGood: session.averageTempo.map { abs($0 - 3.0) < 0.3 } ?? false
                )
                
                metricRow(
                    title: "Avg Club Speed",
                    value: session.averageClubSpeed.map { String(format: "%.0f mph", $0) } ?? "--",
                    target: nil,
                    isGood: true
                )
                
                if let bestSwing = bestSwing {
                    metricRow(
                        title: "Best Tempo",
                        value: bestSwing.combinedMetrics?.tempoRatio.map { String(format: "%.1f:1", $0) } ?? "--",
                        target: "Swing #\(swingIndex(bestSwing) + 1)",
                        isGood: true
                    )
                }
                
                if let avgHipTurn = averageHipTurn {
                    metricRow(
                        title: "Avg Hip Turn",
                        value: "\(Int(avgHipTurn))°",
                        target: "Target: 45-55°",
                        isGood: avgHipTurn >= 40 && avgHipTurn <= 60
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func metricRow(title: String, value: String, target: String?, isGood: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                
                if isGood {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            if let target = target {
                Text(target)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var bestSwing: CombinedSwingCapture? {
        session.swings.min { swing1, swing2 in
            let t1 = swing1.combinedMetrics?.tempoRatio ?? 10
            let t2 = swing2.combinedMetrics?.tempoRatio ?? 10
            return abs(t1 - 3.0) < abs(t2 - 3.0)
        }
    }
    
    private func swingIndex(_ swing: CombinedSwingCapture) -> Int {
        session.swings.firstIndex(where: { $0.id == swing.id }) ?? 0
    }
    
    private var averageHipTurn: Double? {
        let hipTurns = session.swings.compactMap { $0.combinedMetrics?.hipTurnDegrees }
        guard !hipTurns.isEmpty else { return nil }
        return hipTurns.reduce(0, +) / Double(hipTurns.count)
    }
    
    // MARK: - Swings List
    
    private var swingsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Swings")
                .font(.headline)
            
            ForEach(Array(session.swings.enumerated()), id: \.element.id) { index, swing in
                swingRow(swing: swing, index: index)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func swingRow(swing: CombinedSwingCapture, index: Int) -> some View {
        HStack {
            Text("#\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                if let tempo = swing.combinedMetrics?.tempoRatio {
                    HStack(spacing: 4) {
                        Text("Tempo: \(String(format: "%.1f:1", tempo))")
                            .font(.subheadline)
                        
                        Circle()
                            .fill(tempoColor(tempo))
                            .frame(width: 8, height: 8)
                    }
                }
                
                if let speed = swing.combinedMetrics?.estimatedClubSpeed {
                    Text("Speed: \(String(format: "%.0f mph", speed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Source indicators
            HStack(spacing: 4) {
                if swing.combinedMetrics?.hasCameraData == true {
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                if swing.combinedMetrics?.hasWatchData == true {
                    Image(systemName: "applewatch")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            // Fault indicator
            if let fault = swing.combinedMetrics?.primaryFault {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help(fault.rawValue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Insights
    
    private var insights: [String] {
        var result: [String] = []
        
        // Tempo consistency
        if let consistency = session.consistencyScore {
            if consistency >= 80 {
                result.append("Great tempo consistency! You're repeating your swing well.")
            } else if consistency < 50 {
                result.append("Work on tempo consistency. Try counting \"1-2-3\" during your backswing.")
            }
        }
        
        // Tempo average
        if let avgTempo = session.averageTempo {
            if avgTempo < 2.5 {
                result.append("Your tempo is quick. Try slowing your backswing for better control.")
            } else if avgTempo > 3.5 {
                result.append("Your tempo is slow. Focus on accelerating smoothly through the ball.")
            }
        }
        
        // Common faults
        let faults = session.swings.compactMap { $0.combinedMetrics?.primaryFault }
        let faultCounts = Dictionary(grouping: faults, by: { $0 }).mapValues { $0.count }
        if let (mostCommonFault, count) = faultCounts.max(by: { $0.value < $1.value }),
           count >= session.swingCount / 3 {
            result.append("Detected \(mostCommonFault.rawValue) in \(count) swings. \(mostCommonFault.tip)")
        }
        
        return result
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Insights")
                    .font(.headline)
            }
            
            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(insight)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    let session = RangeSession(startTime: Date().addingTimeInterval(-600))
    // Add some mock swings here for preview
    
    return RangeSessionSummaryView(session: session)
}
