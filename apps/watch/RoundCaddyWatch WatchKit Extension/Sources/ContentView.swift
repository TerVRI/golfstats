import SwiftUI

struct ContentView: View {
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        if roundManager.isRoundActive {
            ActiveRoundView()
        } else {
            HomeView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            Text("RoundCaddy")
                .font(.headline)
            
            Button(action: {
                roundManager.startRound()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Round")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
    }
}

struct ActiveRoundView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        TabView {
            // Distance View
            DistanceView()
                .tabItem {
                    Image(systemName: "location.fill")
                }
            
            // Scorecard View
            ScorecardView()
                .tabItem {
                    Image(systemName: "list.number")
                }
            
            // Shot Tracker View
            ShotTrackerView()
                .tabItem {
                    Image(systemName: "target")
                }
            
            // Round Summary / End Round View
            RoundSummaryView()
                .tabItem {
                    Image(systemName: "flag.checkered")
                }
        }
        .tabViewStyle(.page)
    }
}

// MARK: - Round Summary View

struct RoundSummaryView: View {
    @EnvironmentObject var roundManager: RoundManager
    @State private var showEndConfirmation = false
    @State private var showDiscardConfirmation = false
    
    var holesPlayed: Int {
        roundManager.holeScores.filter { $0.score != nil }.count
    }
    
    var totalPar: Int {
        roundManager.holeScores.filter { $0.score != nil }.reduce(0) { $0 + $1.par }
    }
    
    var scoreToPar: Int {
        roundManager.totalScore - totalPar
    }
    
    var scoreToParText: String {
        if scoreToPar == 0 { return "E" }
        return scoreToPar > 0 ? "+\(scoreToPar)" : "\(scoreToPar)"
    }
    
    var totalFairways: Int {
        roundManager.holeScores.filter { $0.fairwayHit == true }.count
    }
    
    var totalGIR: Int {
        roundManager.holeScores.filter { $0.gir == true }.count
    }
    
    var totalPutts: Int {
        roundManager.holeScores.compactMap { $0.putts }.reduce(0, +)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("Round Summary")
                    .font(.headline)
                
                // Main Score
                VStack(spacing: 4) {
                    Text("\(roundManager.totalScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text(scoreToParText)
                        .font(.title3)
                        .foregroundColor(scoreToPar < 0 ? .green : scoreToPar > 0 ? .red : .primary)
                }
                
                // Stats
                HStack(spacing: 16) {
                    VStack {
                        Text("\(holesPlayed)")
                            .font(.headline)
                        Text("Holes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(totalFairways)")
                            .font(.headline)
                        Text("FW")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(totalGIR)")
                            .font(.headline)
                        Text("GIR")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(totalPutts)")
                            .font(.headline)
                        Text("Putts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // End Round Button
                Button(action: {
                    showEndConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("Save Round")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                // Discard Round Button
                Button(action: {
                    showDiscardConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Discard")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()
        }
        .confirmationDialog("Save Round?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("Save \(holesPlayed) Holes") {
                roundManager.endRound()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will save your round and sync it to your iPhone.")
        }
        .confirmationDialog("Discard Round?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                roundManager.discardRound()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete all scores from this round. This cannot be undone.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
}
