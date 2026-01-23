import SwiftUI
import WatchKit

/// Range Mode view for Apple Watch
struct RangeModeWatchView: View {
    @ObservedObject var rangeModeManager = RangeModeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status header
                statusHeader
                
                if rangeModeManager.isRangeModeActive {
                    // Active session view
                    activeSessionView
                } else {
                    // Start session view
                    startSessionView
                }
            }
            .padding()
        }
        .navigationTitle("Range Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack {
            // Phone connection status
            HStack(spacing: 4) {
                Image(systemName: rangeModeManager.isConnectedToPhone ? "iphone" : "iphone.slash")
                    .foregroundColor(rangeModeManager.isConnectedToPhone ? .green : .red)
                Text(rangeModeManager.isConnectedToPhone ? "Connected" : "No Phone")
                    .font(.caption2)
            }
            
            Spacer()
            
            // Recording indicator
            if rangeModeManager.isRangeModeActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text(formattedDuration)
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var formattedDuration: String {
        let minutes = Int(rangeModeManager.sessionDuration) / 60
        let seconds = Int(rangeModeManager.sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Start Session View
    
    private var startSessionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.golf")
                .font(.system(size: 44))
                .foregroundColor(.green)
            
            Text("Practice Mode")
                .font(.headline)
            
            Text("Track your swings and analyze tempo on the range")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: startSession) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!rangeModeManager.isConnectedToPhone)
            
            if !rangeModeManager.isConnectedToPhone {
                Text("Open Range Mode on iPhone first")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Active Session View
    
    private var activeSessionView: some View {
        VStack(spacing: 16) {
            // Swing count (large)
            VStack(spacing: 4) {
                Text("\(rangeModeManager.swingCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("Swings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Live metrics
            HStack(spacing: 16) {
                metricView(
                    label: "Accel",
                    value: String(format: "%.1fG", rangeModeManager.currentAcceleration)
                )
                
                if let tempo = rangeModeManager.lastSwingTempo {
                    metricView(
                        label: "Tempo",
                        value: String(format: "%.1f:1", tempo)
                    )
                }
            }
            
            // Session stats
            if let avgTempo = rangeModeManager.averageTempo {
                HStack(spacing: 16) {
                    metricView(
                        label: "Avg Tempo",
                        value: String(format: "%.1f:1", avgTempo)
                    )
                    
                    if let avgSpeed = rangeModeManager.averageClubSpeed {
                        metricView(
                            label: "Avg Speed",
                            value: String(format: "%.0f", avgSpeed)
                        )
                    }
                }
            }
            
            // Stop button
            Button(action: endSession) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("End Session")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
    
    private func metricView(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func startSession() {
        WKInterfaceDevice.current().play(.start)
        rangeModeManager.startSession()
    }
    
    private func endSession() {
        WKInterfaceDevice.current().play(.stop)
        rangeModeManager.endSession()
    }
}

// MARK: - Preview

#Preview {
    RangeModeWatchView()
}
