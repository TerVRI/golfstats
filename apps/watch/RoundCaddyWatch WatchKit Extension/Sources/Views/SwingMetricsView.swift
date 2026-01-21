import SwiftUI

/// Displays real-time swing metrics and analytics
struct SwingMetricsView: View {
    @EnvironmentObject var motionManager: MotionManager
    @ObservedObject var swingDetector: SwingDetector
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.green)
                    Text("Swing Metrics")
                        .font(.headline)
                }
                
                if let analytics = swingDetector.lastAnalytics {
                    // Tempo Display
                    TempoCard(analytics: analytics)
                    
                    // Speed Display
                    SpeedCard(analytics: analytics)
                    
                    // Impact Indicator
                    ImpactCard(analytics: analytics)
                    
                    // Path Display
                    PathCard(analytics: analytics)
                    
                } else {
                    // No swing recorded yet
                    VStack(spacing: 8) {
                        Image(systemName: "figure.golf")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Take a swing!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Metrics will appear here")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                }
                
                // Session Stats
                if swingDetector.sessionStats.totalSwings > 0 {
                    SessionStatsCard(stats: swingDetector.sessionStats)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Tempo Card

struct TempoCard: View {
    let analytics: SwingAnalytics
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("TEMPO")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(analytics.tempoRating.emoji)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", analytics.tempoRatio))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(tempoColor)
                
                Text(": 1")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Breakdown
            HStack(spacing: 12) {
                VStack {
                    Text(String(format: "%.2fs", analytics.backswingDuration))
                        .font(.caption)
                        .monospacedDigit()
                    Text("Back")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("→")
                    .foregroundColor(.secondary)
                
                VStack {
                    Text(String(format: "%.2fs", analytics.downswingDuration))
                        .font(.caption)
                        .monospacedDigit()
                    Text("Down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(analytics.tempoRating.rawValue)
                .font(.caption2)
                .foregroundColor(tempoColor)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    var tempoColor: Color {
        switch analytics.tempoRating {
        case .excellent: return .green
        case .good: return .blue
        case .needsWork: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Speed Card

struct SpeedCard: View {
    let analytics: SwingAnalytics
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("SPEED")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "speedometer")
                    .foregroundColor(.orange)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", analytics.peakHandSpeed))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                Text("mph")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Hand Speed")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Divider()
            
            HStack {
                VStack {
                    Text("~\(String(format: "%.0f", analytics.estimatedClubheadSpeed))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Club mph")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(String(format: "%.1fG", analytics.peakGForce))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Peak G")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Impact Card

struct ImpactCard: View {
    let analytics: SwingAnalytics
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("IMPACT")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: analytics.impactDetected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(analytics.impactDetected ? .green : .gray)
                    
                    Text(analytics.impactDetected ? "Ball Strike Detected" : "No Impact Detected")
                        .font(.caption)
                }
            }
            
            Spacer()
            
            if analytics.impactDetected, let decel = analytics.impactDeceleration {
                VStack {
                    Text(String(format: "%.1fG", decel))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Impact")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Path Card

struct PathCard: View {
    let analytics: SwingAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SWING PATH")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: pathIcon)
                    .foregroundColor(pathColor)
                
                Text(analytics.swingPath.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if !analytics.swingPath.tip.isEmpty {
                Text(analytics.swingPath.tip)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    var pathIcon: String {
        switch analytics.swingPath {
        case .insideOut: return "arrow.up.right"
        case .neutral: return "arrow.up"
        case .overTheTop: return "arrow.up.left"
        case .unknown: return "questionmark"
        }
    }
    
    var pathColor: Color {
        switch analytics.swingPath {
        case .insideOut: return .blue
        case .neutral: return .green
        case .overTheTop: return .orange
        case .unknown: return .gray
        }
    }
}

// MARK: - Session Stats Card

struct SessionStatsCard: View {
    let stats: SwingSessionStats
    
    var body: some View {
        VStack(spacing: 8) {
            Text("SESSION")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack {
                    Text("\(stats.totalSwings)")
                        .font(.headline)
                    Text("Swings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(String(format: "%.1f", stats.averageTempo))
                        .font(.headline)
                    Text("Avg Tempo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(stats.overallConsistency)")
                        .font(.headline)
                        .foregroundColor(consistencyColor)
                    Text("Consistency")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    var consistencyColor: Color {
        if stats.overallConsistency >= 80 { return .green }
        if stats.overallConsistency >= 60 { return .blue }
        if stats.overallConsistency >= 40 { return .orange }
        return .red
    }
}

// MARK: - Preview

#Preview {
    let detector = SwingDetector()
    detector.lastAnalytics = SwingAnalytics(
        timestamp: Date(),
        totalDuration: 1.2,
        backswingDuration: 0.9,
        downswingDuration: 0.3,
        peakHandSpeed: 22,
        peakGForce: 10.5,
        peakRotationRate: 12.0,
        impactDetected: true,
        swingPath: .neutral,
        swingType: .fullSwing
    )
    detector.lastAnalytics?.impactDeceleration = 7.2
    
    return SwingMetricsView(swingDetector: detector)
        .environmentObject(MotionManager())
}
