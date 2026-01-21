import SwiftUI

struct ContentView: View {
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        ZStack {
            if roundManager.isRoundActive {
                ActiveRoundView()
            } else {
                HomeView()
            }
            
            // Shot confirmation overlay
            if motionManager.swingConfirmationPending {
                ShotConfirmationView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: motionManager.swingConfirmationPending)
        .onAppear {
            // Link GPS manager to motion manager for practice swing filtering
            motionManager.gpsManager = gpsManager
        }
        .onChange(of: roundManager.isRoundActive) { _, isActive in
            if isActive {
                // Start motion detection when round begins
                motionManager.startDetecting()
                
                // Start workout session for background activity
                Task {
                    do {
                        try await workoutManager.startWorkout()
                    } catch {
                        print("Failed to start workout: \(error)")
                    }
                }
                
                // Configure callback for confirmed shots
                motionManager.onShotConfirmed = { lat, lon in
                    // Shot was confirmed - GPS tracking is handled in ShotConfirmationView
                    print("✅ Shot confirmed via motion detection")
                }
            } else {
                // Stop motion detection when round ends
                motionManager.stopDetecting()
                
                // End workout session
                Task {
                    do {
                        try await workoutManager.endWorkout()
                    } catch {
                        print("Failed to end workout: \(error)")
                    }
                }
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var motionManager: MotionManager
    @State private var showPracticeMode = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Logo
                    Image(systemName: "flag.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("RoundCaddy")
                        .font(.headline)
                    
                    // Start Round Button
                    Button(action: {
                        roundManager.startRound()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Round")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    // Practice Mode Button - navigates to dedicated view
                    NavigationLink(destination: PracticeModeView()) {
                        HStack {
                            Image(systemName: "figure.golf")
                            Text("Practice Mode")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Divider()
                    
                    // Quick Links
                    VStack(spacing: 8) {
                        NavigationLink(destination: ClubDistancesView(tracker: motionManager.clubDistanceTracker)) {
                            QuickLinkRow(icon: "ruler", title: "My Distances", color: .blue)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: CoachingTipsView(coachingEngine: motionManager.coachingEngine)) {
                            QuickLinkRow(icon: "lightbulb.fill", title: "Coaching Tips", color: .yellow)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: SettingsView()) {
                            QuickLinkRow(icon: "gearshape.fill", title: "Settings", color: .gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

struct QuickLinkRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ActiveRoundView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var motionManager: MotionManager
    
    var body: some View {
        ZStack {
            TabView {
                // Distance View
                DistanceView()
                    .tabItem {
                        Image(systemName: "location.fill")
                    }
                
                // Live Shot Distance View (walk to ball)
                LiveShotDistanceView()
                    .tabItem {
                        Image(systemName: "figure.walk")
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
                
                // Swing Metrics View
                SwingMetricsView(swingDetector: motionManager.swingDetector)
                    .tabItem {
                        Image(systemName: "waveform.path.ecg")
                    }
                
                // Strokes Gained View
                StrokesGainedView(calculator: motionManager.strokesGainedCalculator)
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                
                // Round Summary / End Round View
                RoundSummaryView()
                    .tabItem {
                        Image(systemName: "flag.checkered")
                    }
            }
            .tabViewStyle(.page)
            
            // Putting mode indicator at top
            if motionManager.isPuttingMode {
                VStack {
                    PuttCountBadge()
                        .padding(.top, 4)
                    Spacer()
                }
            }
            
            // Coaching tip banner (if available)
            if let tip = motionManager.coachingEngine.latestTips.first {
                VStack {
                    Spacer()
                    QuickTipBanner(tip: tip)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }
            }
        }
        .onChange(of: roundManager.currentHole) { _, _ in
            // Reset putt count when moving to a new hole
            motionManager.resetPuttCount()
        }
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
        .environmentObject(MotionManager())
        .environmentObject(WorkoutManager())
}
