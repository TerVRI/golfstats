import SwiftUI

/// View displayed when player is in putting mode (near the green)
struct PuttingView: View {
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var gpsManager: GPSManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.green)
                Text("On Green")
                    .font(.headline)
            }
            
            // Distance to pin
            if gpsManager.distanceToGreenCenter > 0 {
                Text("\(gpsManager.distanceToGreenCenter) yds to pin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Putt counter
            VStack(spacing: 4) {
                Text("PUTTS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(motionManager.puttCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
            
            // Hole info
            HStack {
                Text("Hole \(roundManager.currentHole)")
                    .font(.caption)
                
                if let holeScore = roundManager.holeScores.first(where: { $0.holeNumber == roundManager.currentHole }) {
                    Text("• Par \(holeScore.par)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Manual adjustment buttons
            HStack(spacing: 20) {
                Button(action: {
                    if motionManager.puttCount > 0 {
                        motionManager.puttCount -= 1
                        motionManager.playHaptic(.click)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    motionManager.puttCount += 1
                    motionManager.playHaptic(.click)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
            
            // Exit putting mode button
            Button(action: {
                motionManager.togglePuttingMode()
            }) {
                Text("Exit Putting Mode")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    PuttingView()
        .environmentObject(MotionManager())
        .environmentObject(RoundManager())
        .environmentObject(GPSManager())
}
