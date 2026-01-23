import SwiftUI
import WatchKit

struct ShotTrackerView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var motionManager: MotionManager
    
    @State private var selectedClub: String = ""
    @State private var showManualEntry = false
    
    var currentHoleShots: [Shot] {
        roundManager.shots.filter { $0.holeNumber == roundManager.currentHole }
    }
    
    /// Suggested club based on distance, using personalized data
    var suggestedClub: String {
        let distance = gpsManager.distanceToGreenCenter
        return motionManager.clubDistanceTracker.suggestClub(forDistance: distance)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with shot count
                headerSection
                
                // Quick suggestion based on learned distances
                if gpsManager.distanceToGreenCenter > 0 {
                    clubSuggestionBanner
                }
                
                // Club Picker
                clubPickerSection
                
                // Action Buttons
                actionButtonsSection
                
                // Last shot info
                lastShotInfo
                
                // Shot history for this hole
                shotHistorySection
            }
            .padding()
        }
        .sheet(isPresented: $showManualEntry) {
            ManualShotEntrySheet(
                selectedClub: $selectedClub,
                clubs: roundManager.clubBag,
                onConfirm: addManualShot
            )
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shot \(currentHoleShots.count + 1)")
                    .font(.headline)
                Text("Hole \(roundManager.currentHole)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Manual add button
            Button(action: { showManualEntry = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add shot manually")
        }
    }
    
    // MARK: - Club Suggestion
    
    private var clubSuggestionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested: \(suggestedClub)")
                    .font(.caption.bold())
                
                // Show if it's from learned data or defaults
                let clubStats = motionManager.clubDistanceTracker.getStats(for: suggestedClub)
                if let stats = clubStats, stats.totalShots >= 3 {
                    Text("Your avg: \(Int(stats.averageDistance)) yds")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("Based on typical distances")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                selectedClub = suggestedClub
                WKInterfaceDevice.current().play(.click)
            }) {
                Text("Use")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - Club Picker
    
    private var clubPickerSection: some View {
        VStack(spacing: 4) {
            Picker("Club", selection: $selectedClub) {
                ForEach(roundManager.clubBag, id: \.self) { club in
                    clubPickerRow(club).tag(club)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)
            .onAppear {
                // Pre-select suggested club on appear
                if selectedClub.isEmpty {
                    selectedClub = suggestedClub
                }
            }
            .onChange(of: roundManager.clubBag) { _, newBag in
                if !newBag.contains(selectedClub), let first = newBag.first {
                    selectedClub = first
                }
            }
        }
    }
    
    private func clubPickerRow(_ club: String) -> some View {
        HStack {
            Text(club)
            
            // Show learned distance if available
            if let stats = motionManager.clubDistanceTracker.getStats(for: club),
               stats.totalShots >= 1 {
                Text("(\(Int(stats.averageDistance)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 8) {
            // Primary: Mark shot with GPS
            Button(action: markShot) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Mark Shot Here")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(gpsManager.currentLocation == nil)
            
            // Secondary: Quick add without GPS
            Button(action: quickAddShot) {
                HStack {
                    Image(systemName: "plus")
                    Text("Quick Add (No GPS)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .font(.caption)
        }
    }
    
    // MARK: - Last Shot Info
    
    private var lastShotInfo: some View {
        Group {
            if let lastDist = gpsManager.lastShotDistance {
                HStack {
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.orange)
                    Text("Last shot: \(lastDist) yards")
                        .font(.caption)
                    
                    Spacer()
                    
                    // Learn this distance
                    if let lastShot = currentHoleShots.last, let club = lastShot.club {
                        Button(action: {
                            learnDistance(club: club, distance: lastDist)
                        }) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Learn this distance")
                    }
                }
                .padding(.vertical, 4)
            } else if let lastShot = currentHoleShots.last,
                      lastShot.locationIsEstimated == true ||
                      (lastShot.latitude == 0 && lastShot.longitude == 0) {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.orange)
                    Text(lastShot.locationIsEstimated == true ? "Last shot logged (estimated location)" : "Last shot logged (no GPS)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Shot History
    
    private var shotHistorySection: some View {
        Group {
            if !currentHoleShots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("This Hole")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentHoleShots.count) shots")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(Array(currentHoleShots.suffix(4)), id: \.id) { shot in
                        HStack {
                            Text("\(shot.shotNumber).")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .leading)
                            
                            Text(shot.club ?? "?")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            if shot.locationIsEstimated == true {
                                Text("Est")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else if shot.latitude == 0 && shot.longitude == 0 {
                                Text("No GPS")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func markShot() {
        guard let location = gpsManager.currentLocation else { return }
        
        gpsManager.markShot()
        
        roundManager.addShot(
            holeNumber: roundManager.currentHole,
            club: selectedClub,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
    }
    
    private func quickAddShot() {
        roundManager.addShot(
            holeNumber: roundManager.currentHole,
            club: selectedClub,
            latitude: 0,
            longitude: 0
        )
        
        WKInterfaceDevice.current().play(.click)
    }
    
    private func addManualShot() {
        if let location = gpsManager.currentLocation {
            roundManager.addShot(
                holeNumber: roundManager.currentHole,
                club: selectedClub,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        } else {
            roundManager.addShot(
                holeNumber: roundManager.currentHole,
                club: selectedClub,
                latitude: 0,
                longitude: 0
            )
        }
        
        WKInterfaceDevice.current().play(.success)
    }
    
    private func learnDistance(club: String, distance: Int) {
        motionManager.clubDistanceTracker.recordShot(club: club, distance: distance)
        WKInterfaceDevice.current().play(.notification)
    }
}

// MARK: - Manual Shot Entry Sheet

struct ManualShotEntrySheet: View {
    @Binding var selectedClub: String
    let clubs: [String]
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Add Missed Shot")
                    .font(.headline)
                
                Text("Detection didn't catch this one?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Club", selection: $selectedClub) {
                    ForEach(clubs, id: \.self) { club in
                        Text(club).tag(club)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 80)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    
                    Button("Add Shot") {
                        onConfirm()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ShotTrackerView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(MotionManager())
}

#Preview {
    ShotTrackerView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
}
