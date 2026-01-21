import SwiftUI
import WatchKit

/// Dedicated practice mode view with real-time swing feedback
struct PracticeModeView: View {
    @EnvironmentObject var motionManager: MotionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isActive = false
    @State private var swingCount = 0
    @State private var showingSettings = false
    
    // Target tempo from settings
    @AppStorage("targetTempo") private var targetTempo = 3.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status Indicator
                    statusSection
                    
                    if isActive {
                        // Real-time metrics display
                        if let analytics = motionManager.swingDetector.lastAnalytics {
                            liveMetricsSection(analytics)
                        } else {
                            waitingForSwingView
                        }
                        
                        // Session stats
                        sessionStatsSection
                        
                    } else {
                        // Inactive state - instructions
                        instructionsSection
                    }
                    
                    // Control buttons
                    controlButtons
                }
                .padding()
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                PracticeSettingsSheet(targetTempo: $targetTempo)
            }
        }
        .onAppear {
            motionManager.setPracticeMode(true)
        }
        .onDisappear {
            if isActive {
                stopPractice()
            }
            motionManager.setPracticeMode(false)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            Text(isActive ? "Recording Swings" : "Ready")
                .font(.caption)
                .foregroundColor(isActive ? .green : .secondary)
            
            Spacer()
            
            if isActive {
                Text("\(swingCount)")
                    .font(.title3.bold())
                    .foregroundColor(.green)
                + Text(" swings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - Waiting View
    
    private var waitingForSwingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.golf")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .symbolEffect(.pulse, isActive: isActive)
            
            Text("Take a swing!")
                .font(.headline)
            
            Text("Metrics will appear instantly")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Live Metrics
    
    private func liveMetricsSection(_ analytics: SwingAnalytics) -> some View {
        VStack(spacing: 12) {
            // Tempo with visual feedback
            tempoFeedback(analytics)
            
            // Speed meter
            speedMeter(analytics)
            
            // Quick stats row
            HStack(spacing: 16) {
                miniStat(
                    value: String(format: "%.1fG", analytics.peakGForce),
                    label: "G-Force"
                )
                
                miniStat(
                    value: analytics.impactDetected ? "✓" : "✗",
                    label: "Impact",
                    color: analytics.impactDetected ? .green : .orange
                )
                
                miniStat(
                    value: pathEmoji(analytics.swingPath),
                    label: "Path"
                )
            }
        }
    }
    
    private func tempoFeedback(_ analytics: SwingAnalytics) -> some View {
        VStack(spacing: 8) {
            // Tempo value with color coding
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", analytics.tempoRatio))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(tempoColor(analytics.tempoRatio))
                
                Text(": 1")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Target indicator
            HStack {
                Text("Target: \(String(format: "%.1f", targetTempo)):1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let diff = abs(analytics.tempoRatio - targetTempo)
                if diff < 0.2 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if diff < 0.5 {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            
            // Tempo bar visualization
            tempoBar(analytics.tempoRatio)
            
            // Timing breakdown
            HStack(spacing: 4) {
                Text(String(format: "%.2fs", analytics.backswingDuration))
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("→")
                    .foregroundColor(.secondary)
                Text(String(format: "%.2fs", analytics.downswingDuration))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func tempoBar(_ tempo: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                
                // Ideal zone (2.8 - 3.2)
                let idealStart = (2.8 - 2.0) / 2.0 * geo.size.width
                let idealEnd = (3.2 - 2.0) / 2.0 * geo.size.width
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.3))
                    .frame(width: idealEnd - idealStart)
                    .offset(x: idealStart)
                
                // Current position marker
                let position = min(max((tempo - 2.0) / 2.0, 0), 1) * geo.size.width
                RoundedRectangle(cornerRadius: 2)
                    .fill(tempoColor(tempo))
                    .frame(width: 4)
                    .offset(x: position - 2)
            }
        }
        .frame(height: 16)
    }
    
    private func speedMeter(_ analytics: SwingAnalytics) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("HAND SPEED")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", analytics.peakHandSpeed))
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                    Text("mph")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Estimated clubhead speed
            VStack(alignment: .trailing, spacing: 4) {
                Text("EST. CLUB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("~\(String(format: "%.0f", analytics.estimatedClubheadSpeed))")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("mph")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func miniStat(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Session Stats
    
    private var sessionStatsSection: some View {
        let stats = motionManager.swingDetector.sessionStats
        
        return VStack(spacing: 8) {
            Divider()
            
            Text("SESSION")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                VStack {
                    Text("\(stats.totalSwings)")
                        .font(.headline)
                    Text("Total")
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
                    Text("\(stats.overallConsistency)%")
                        .font(.headline)
                        .foregroundColor(consistencyColor(stats.overallConsistency))
                    Text("Consist.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Instructions
    
    private var instructionsSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("Practice Mode")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                instructionRow("figure.golf", "Take full swings")
                instructionRow("waveform.path.ecg", "See real-time metrics")
                instructionRow("target", "Match your target tempo")
                instructionRow("chart.bar", "Track consistency")
            }
            .font(.caption)
        }
        .padding()
    }
    
    private func instructionRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        VStack(spacing: 8) {
            if isActive {
                Button(action: stopPractice) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop Practice")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button(action: startPractice) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Practice")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            
            Button(action: { dismiss() }) {
                Text("Exit Practice")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }
    
    // MARK: - Actions
    
    private func startPractice() {
        isActive = true
        swingCount = 0
        motionManager.swingDetector.resetSession()
        motionManager.startDetecting()
        
        // Play haptic to confirm start
        WKInterfaceDevice.current().play(.start)
    }
    
    private func stopPractice() {
        isActive = false
        swingCount = motionManager.swingDetector.sessionStats.totalSwings
        motionManager.stopDetecting()
        
        // Play haptic to confirm stop
        WKInterfaceDevice.current().play(.stop)
    }
    
    // MARK: - Helpers
    
    private func tempoColor(_ tempo: Double) -> Color {
        if tempo >= 2.8 && tempo <= 3.2 {
            return .green
        } else if tempo >= 2.5 && tempo <= 3.5 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    private func consistencyColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }
    
    private func pathEmoji(_ path: SwingPath) -> String {
        switch path {
        case .insideOut: return "↗️"
        case .neutral: return "⬆️"
        case .overTheTop: return "↖️"
        case .unknown: return "❓"
        }
    }
}

// MARK: - Practice Settings Sheet

struct PracticeSettingsSheet: View {
    @Binding var targetTempo: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Tempo")
                            Spacer()
                            Text("\(String(format: "%.1f", targetTempo)):1")
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                        }
                        
                        Slider(value: $targetTempo, in: 2.0...4.0, step: 0.1)
                            .tint(.green)
                        
                        Text("Pro average: 3.0:1")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Tempo Target")
                }
                
                Section {
                    HStack {
                        Text("2.5:1")
                        Spacer()
                        Text("Fast tempo (power)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("3.0:1")
                        Spacer()
                        Text("Pro average")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("3.5:1")
                        Spacer()
                        Text("Smooth tempo")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                } header: {
                    Text("Reference")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PracticeModeView()
        .environmentObject(MotionManager())
}
