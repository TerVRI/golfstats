import SwiftUI

struct ScorecardView: View {
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var motionManager: MotionManager
    @State private var editingHole: Int?
    
    var currentHoleScore: HoleScore? {
        roundManager.holeScores.first { $0.holeNumber == roundManager.currentHole }
    }
    
    /// Whether the auto-detected putt count differs from saved putts
    var hasUnsyncedPutts: Bool {
        motionManager.puttCount > 0 &&
        motionManager.puttCount != (currentHoleScore?.putts ?? 0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Current hole info
            HStack {
                Text("Hole \(roundManager.currentHole)")
                    .font(.headline)
                Spacer()
                Text("Par \(currentHoleScore?.par ?? 4)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Score entry
            HStack(spacing: 12) {
                Button(action: decrementScore) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
                Text("\(currentHoleScore?.score ?? 0)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(minWidth: 50)
                
                Button(action: incrementScore) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
            
            // Score relative to par
            if let score = currentHoleScore?.score, let par = currentHoleScore?.par {
                Text(scoreRelativeToPar(score: score, par: par))
                    .font(.caption)
                    .foregroundColor(scoreColor(score: score, par: par))
            }
            
            Divider()
            
            // Quick stats toggles
            HStack(spacing: 16) {
                Button(action: toggleFairway) {
                    VStack {
                        Image(systemName: currentHoleScore?.fairwayHit == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(currentHoleScore?.fairwayHit == true ? .green : .gray)
                        Text("FW")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: toggleGIR) {
                    VStack {
                        Image(systemName: currentHoleScore?.gir == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(currentHoleScore?.gir == true ? .green : .gray)
                        Text("GIR")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                
                // Putts display with auto-detect indicator
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(currentHoleScore?.putts ?? 0)")
                            .font(.headline)
                        
                        // Show auto-detected count if different
                        if hasUnsyncedPutts {
                            Text("(\(motionManager.puttCount))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    Text("Putts")
                        .font(.caption2)
                    
                    // Sync button when auto-detected putts differ
                    if hasUnsyncedPutts {
                        Button(action: syncPuttCount) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                    }
                }
                .onTapGesture {
                    incrementPutts()
                }
            }
            
            Divider()
            
            // Total score
            HStack {
                Text("Total:")
                    .font(.caption)
                Spacer()
                Text("\(roundManager.totalScore)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }
    
    private func incrementScore() {
        let current = currentHoleScore?.score ?? 0
        roundManager.updateScore(for: roundManager.currentHole, score: current + 1)
    }
    
    private func decrementScore() {
        let current = currentHoleScore?.score ?? 0
        if current > 0 {
            roundManager.updateScore(for: roundManager.currentHole, score: current - 1)
        }
    }
    
    private func incrementPutts() {
        let current = currentHoleScore?.putts ?? 0
        roundManager.updatePutts(for: roundManager.currentHole, putts: (current + 1) % 6)
    }
    
    private func syncPuttCount() {
        // Sync auto-detected putt count to scorecard
        roundManager.updatePutts(for: roundManager.currentHole, putts: motionManager.puttCount)
        motionManager.playHaptic(.success)
    }
    
    private func toggleFairway() {
        let current = currentHoleScore?.fairwayHit ?? false
        roundManager.updateFairway(for: roundManager.currentHole, hit: !current)
    }
    
    private func toggleGIR() {
        let current = currentHoleScore?.gir ?? false
        roundManager.updateGIR(for: roundManager.currentHole, hit: !current)
    }
    
    private func scoreRelativeToPar(score: Int, par: Int) -> String {
        let diff = score - par
        if diff == 0 { return "Par" }
        if diff == -1 { return "Birdie" }
        if diff == -2 { return "Eagle" }
        if diff <= -3 { return "Albatross" }
        if diff == 1 { return "Bogey" }
        if diff == 2 { return "Double" }
        return "+\(diff)"
    }
    
    private func scoreColor(score: Int, par: Int) -> Color {
        let diff = score - par
        if diff <= -2 { return .yellow }
        if diff == -1 { return .green }
        if diff == 0 { return .primary }
        if diff == 1 { return .orange }
        return .red
    }
}

#Preview {
    ScorecardView()
        .environmentObject(RoundManager())
        .environmentObject(MotionManager())
}
