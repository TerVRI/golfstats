import SwiftUI

/// View that appears when a swing is detected, prompting the user to confirm or dismiss
struct ShotConfirmationView: View {
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var gpsManager: GPSManager
    
    @State private var selectedClub: String = ""
    @State private var showingClubPicker = false
    @State private var autoDismissTimer: Timer?
    
    /// Time before auto-dismissing if no action taken (seconds)
    private let autoDismissDelay: TimeInterval = 30.0
    
    /// Suggested club based on distance to green - uses personalized distances
    private var suggestedClub: String {
        let distance = gpsManager.distanceToGreenCenter
        // Use the ClubDistanceTracker for personalized suggestions
        return motionManager.clubDistanceTracker.suggestClub(forDistance: distance)
    }
    
    /// Whether the suggestion is from learned data
    private var isLearnedSuggestion: Bool {
        if let stats = motionManager.clubDistanceTracker.getStats(for: suggestedClub) {
            return stats.totalShots >= 3
        }
        return false
    }
    
    /// Current shot number for this hole
    private var shotNumber: Int {
        roundManager.shots.filter { $0.holeNumber == roundManager.currentHole }.count + 1
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with swing icon
                HStack {
                    Image(systemName: "figure.golf")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Shot Detected!")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.top, 8)
                
                // Shot info
                VStack(spacing: 4) {
                    Text("Hole \(roundManager.currentHole) • Shot \(shotNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if gpsManager.distanceToGreenCenter > 0 {
                        Text("\(gpsManager.distanceToGreenCenter) yds to green")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Club selection
                VStack(spacing: 8) {
                    HStack {
                        Text("Club used:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if isLearnedSuggestion {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                    
                    Button(action: { showingClubPicker = true }) {
                        HStack {
                            Text(selectedClub.isEmpty ? suggestedClub : selectedClub)
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Show personalized distance if available
                    if let stats = motionManager.clubDistanceTracker.getStats(for: selectedClub.isEmpty ? suggestedClub : selectedClub),
                       stats.totalShots >= 1 {
                        Text("Your avg: \(Int(stats.averageDistance)) yds")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                // Action buttons
                VStack(spacing: 8) {
                    // Confirm button
                    Button(action: confirmShot) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Shot")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    // Dismiss button
                    Button(action: dismissShot) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Practice Swing")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
        .applyShotConfirmationBackground()
        .sheet(isPresented: $showingClubPicker) {
            ClubPickerSheet(selectedClub: $selectedClub, clubs: roundManager.clubBag)
        }
        .onAppear {
            // Pre-select suggested club
            if selectedClub.isEmpty {
                selectedClub = suggestedClub
            }
            
            // Start auto-dismiss timer
            startAutoDismissTimer()
        }
        .onDisappear {
            autoDismissTimer?.invalidate()
        }
    }
    
    // MARK: - Actions
    
    private func confirmShot() {
        autoDismissTimer?.invalidate()
        
        let club = selectedClub.isEmpty ? suggestedClub : selectedClub
        
        // Add the shot to round manager
        if let location = gpsManager.currentLocation {
            roundManager.addShot(
                holeNumber: roundManager.currentHole,
                club: club,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            // Mark shot location in GPS manager for distance tracking
            gpsManager.markShot()
        }
        
        // Confirm with motion manager (triggers haptic)
        motionManager.confirmShot()
    }
    
    private func dismissShot() {
        autoDismissTimer?.invalidate()
        motionManager.dismissShot()
    }
    
    private func startAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissDelay, repeats: false) { _ in
            // Auto-dismiss as practice swing after timeout
            dismissShot()
        }
    }
    
}

private extension View {
    @ViewBuilder
    func applyShotConfirmationBackground() -> some View {
        if #available(watchOS 10.0, *) {
            self.containerBackground(Color.black, for: .navigation)
        } else {
            self.background(Color.black.ignoresSafeArea())
        }
    }
}

// MARK: - Club Picker Sheet

struct ClubPickerSheet: View {
    @Binding var selectedClub: String
    let clubs: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(clubs, id: \.self) { club in
                Button(action: {
                    selectedClub = club
                    dismiss()
                }) {
                    HStack {
                        Text(club)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if club == selectedClub {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Select Club")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    ShotConfirmationView()
        .environmentObject(MotionManager())
        .environmentObject(RoundManager())
        .environmentObject(GPSManager())
}
