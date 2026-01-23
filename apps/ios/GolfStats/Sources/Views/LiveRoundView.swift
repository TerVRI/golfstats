import SwiftUI
import CoreLocation

struct LiveRoundView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    
    @State private var selectedTab = 0
    @State private var showEndRoundAlert = false
    @State private var showClubPicker = false
    @State private var selectedClub: ClubType = .sevenIron
    @State private var isSaving = false
    @State private var showFreeLimitAlert = false
    @State private var freeLimitMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("End") {
                    showEndRoundAlert = true
                }
                .foregroundColor(.red)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(roundManager.selectedCourse?.name ?? "Round in Progress")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Score: \(roundManager.totalScore)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Watch status with sync indicator
                VStack(spacing: 2) {
                    if authManager.hasProAccess {
                        if watchSyncManager.isWatchConnected {
                            Image(systemName: "applewatch")
                                .foregroundColor(.green)
                            if watchSyncManager.lastWatchUpdate != nil {
                                Text("Synced")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        } else {
                            Image(systemName: "applewatch.slash")
                                .foregroundColor(.gray)
                        }
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        Text("Watch Pro")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color("BackgroundSecondary"))
            
            // Hole Navigator
            HoleNavigator()
            
            // Main Content
            TabView(selection: $selectedTab) {
                // Distance View
                DistanceTab()
                    .tag(0)
                
                // Scorecard
                ScorecardTab()
                    .tag(1)
                
                // Shot Tracker
                ShotTrackerTab(showClubPicker: $showClubPicker, selectedClub: $selectedClub)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(Color("Background"))
        .onAppear {
            gpsManager.startTracking()
            if authManager.hasProAccess {
                setupWatchSync()
            }
            updateGreenLocationsForCurrentHole()
        }
        .onChange(of: roundManager.currentHole) { _, _ in
            updateGreenLocationsForCurrentHole()
        }
        .onDisappear {
            gpsManager.stopTracking()
            roundManager.onStateChanged = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRoundStateUpdate)) { notification in
            guard authManager.hasProAccess else { return }
            if let userInfo = notification.userInfo as? [String: Any] {
                roundManager.applyWatchUpdate(userInfo)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRoundEnded)) { _ in
            guard authManager.hasProAccess else { return }
            // Watch ended the round - save it if we can
            Task {
                await saveAndEndRound()
            }
        }
        .alert("End Round?", isPresented: $showEndRoundAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save & End", role: .destructive) {
                Task {
                    await saveAndEndRound()
                }
            }
            Button("Discard", role: .destructive) {
                roundManager.endRound()
            }
        } message: {
            Text("Would you like to save this round or discard it?")
        }
        .alert("Free Plan Limit", isPresented: $showFreeLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(freeLimitMessage)
        }
        .sheet(isPresented: $showClubPicker) {
            ClubPickerSheet(selectedClub: $selectedClub) {
                markShot()
            }
        }
    }
    
    private func saveAndEndRound() async {
        guard let user = authManager.currentUser else { return }
        isSaving = true
        
        do {
            if !authManager.hasProAccess {
                let roundCount = try await DataService.shared.fetchRoundCount(
                    userId: user.id,
                    authHeaders: authManager.authHeaders,
                    limit: SubscriptionConfig.freeRoundLimit
                )
                if roundCount >= SubscriptionConfig.freeRoundLimit {
                    freeLimitMessage = "Free plan limit reached (\(SubscriptionConfig.freeRoundLimit) rounds). Delete a round or upgrade to Pro to save more."
                    showFreeLimitAlert = true
                    isSaving = false
                    return
                }
            }

            try await roundManager.saveRound(userId: user.id, authHeaders: authManager.authHeaders)
            if authManager.hasProAccess {
                watchSyncManager.sendEndRoundToWatch()
            }
        } catch {
            print("Error saving round: \(error)")
        }
        
        isSaving = false
    }
    
    private func markShot() {
        gpsManager.markShot()
        roundManager.addShot(
            club: selectedClub,
            location: gpsManager.currentLocation?.coordinate
        )
    }
    
    private func setupWatchSync() {
        // Set up callback to sync state to watch when changes are made on iPhone
        roundManager.onStateChanged = { [self] in
            syncStateToWatch()
        }
        
        // Send course data to watch if available
        if let course = roundManager.selectedCourse {
            watchSyncManager.sendCourseToWatch(course: course)
        }
        
        // Send initial state to watch
        syncStateToWatch()
        
        // Send round start to watch
        if let course = roundManager.selectedCourse, let holeData = course.holeData {
            let pars = holeData.sorted { $0.holeNumber < $1.holeNumber }.map { $0.par }
            watchSyncManager.sendStartRoundToWatch(
                courseName: course.name,
                pars: pars
            )
        } else {
            watchSyncManager.sendRoundStart()
        }
        
        // Also send the golf bag to watch
        watchSyncManager.sendBagToWatch(clubs: GolfBag.shared.clubNames)
    }
    
    private func syncStateToWatch() {
        watchSyncManager.sendRoundStateToWatch(
            isActive: roundManager.isRoundActive,
            currentHole: roundManager.currentHole,
            courseName: roundManager.selectedCourse?.name ?? "Unknown Course",
            holeScores: roundManager.holeScores
        )
    }
    
    private func updateGreenLocationsForCurrentHole() {
        guard let course = roundManager.selectedCourse,
              let holeData = course.holeData,
              let currentHoleData = holeData.first(where: { $0.holeNumber == roundManager.currentHole }) else {
            gpsManager.clearGreenLocations()
            return
        }
        
        let front = currentHoleData.greenFront.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let center = currentHoleData.greenCenter.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let back = currentHoleData.greenBack.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        
        gpsManager.setGreenLocations(front: front, center: center, back: back)
    }
}

// MARK: - Hole Navigator

struct HoleNavigator: View {
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        HStack {
            Button {
                roundManager.previousHole()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(roundManager.currentHole > 1 ? .green : .gray)
            }
            .disabled(roundManager.currentHole == 1)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Hole \(roundManager.currentHole)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let hole = roundManager.currentHoleScore {
                    Text("Par \(hole.par)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button {
                roundManager.nextHole()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(roundManager.currentHole < 18 ? .green : .gray)
            }
            .disabled(roundManager.currentHole == 18)
        }
        .padding()
        .background(Color("BackgroundSecondary").opacity(0.5))
    }
}

// MARK: - Distance Tab

struct DistanceTab: View {
    @EnvironmentObject var gpsManager: GPSManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Main distance display
            VStack(spacing: 8) {
                Text("CENTER")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let distance = gpsManager.distanceToCenter {
                    Text("\(distance)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("yards")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Text("---")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Text("No GPS data")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Front/Back
            HStack(spacing: 60) {
                VStack(spacing: 4) {
                    Text("FRONT")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(gpsManager.distanceToFront.map { "\($0)" } ?? "--")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("BACK")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(gpsManager.distanceToBack.map { "\($0)" } ?? "--")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            
            // Last shot distance
            if let lastShot = gpsManager.lastShotDistance {
                Divider().background(Color.gray)
                
                HStack {
                    Image(systemName: "figure.golf")
                        .foregroundColor(.orange)
                    Text("Last shot: \(lastShot) yards")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color("BackgroundSecondary"))
                .cornerRadius(12)
            }
            
            // GPS Status and Current Location
            VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(gpsManager.isTracking ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(gpsManager.isTracking ? "GPS Active" : "GPS Inactive")
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                if let location = gpsManager.currentLocation {
                    Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else if gpsManager.isTracking {
                    Text("Waiting for GPS signal...")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text("GPS not started")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Scorecard Tab

struct ScorecardTab: View {
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Score entry
            HStack(spacing: 24) {
                Button {
                    roundManager.decrementScore()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 4) {
                    Text("\(roundManager.currentHoleScore?.score ?? roundManager.currentHoleScore?.par ?? 4)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let hole = roundManager.currentHoleScore, let diff = hole.relativeToPar {
                        Text(hole.scoreDescription)
                            .font(.subheadline)
                            .foregroundColor(scoreColor(for: diff))
                    }
                }
                .frame(minWidth: 100)
                
                Button {
                    roundManager.incrementScore()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                }
            }
            
            // Quick toggles
            HStack(spacing: 32) {
                ToggleButton(
                    title: "FW",
                    isOn: roundManager.currentHoleScore?.fairwayHit ?? false
                ) {
                    roundManager.toggleFairway()
                }
                
                ToggleButton(
                    title: "GIR",
                    isOn: roundManager.currentHoleScore?.gir ?? false
                ) {
                    roundManager.toggleGIR()
                }
                
                // Putts stepper
                VStack(spacing: 4) {
                    Text("\(roundManager.currentHoleScore?.putts ?? 0)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Putts")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    let current = roundManager.currentHoleScore?.putts ?? 0
                    roundManager.updatePutts((current + 1) % 6)
                }
            }
            
            Divider().background(Color.gray)
            
            // Running totals
            HStack(spacing: 40) {
                VStack {
                    Text("\(roundManager.totalScore)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(roundManager.totalPutts)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Putts")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(roundManager.fairwaysHit)/\(roundManager.currentHole)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("FW")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(roundManager.greensInRegulation)/\(roundManager.currentHole)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("GIR")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func scoreColor(for diff: Int) -> Color {
        switch diff {
        case ...(-2): return .yellow
        case -1: return .green
        case 0: return .white
        case 1: return .orange
        default: return .red
        }
    }
}

struct ToggleButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundColor(isOn ? .green : .gray)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Shot Tracker Tab

struct ShotTrackerTab: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @Binding var showClubPicker: Bool
    @Binding var selectedClub: ClubType
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Shot count
            Text("Shot \(roundManager.shotsForCurrentHole().count + 1)")
                .font(.headline)
                .foregroundColor(.gray)
            
            // Mark Shot Button
            Button {
                showClubPicker = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 50))
                    Text("Mark Shot")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(width: 150, height: 150)
                .background(Color.green)
                .clipShape(Circle())
            }
            
            // Last shot info
            if let lastShot = gpsManager.lastShotDistance {
                HStack {
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.orange)
                    Text("Last: \(lastShot) yards")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color("BackgroundSecondary"))
                .cornerRadius(12)
            }
            
            // Recent shots
            if !roundManager.shotsForCurrentHole().isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shots this hole")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    ForEach(roundManager.shotsForCurrentHole()) { shot in
                        HStack {
                            Text("\(shot.shotNumber).")
                                .foregroundColor(.gray)
                            Text(shot.club ?? "Unknown")
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color("BackgroundSecondary"))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Club Picker Sheet

struct ClubPickerSheet: View {
    @Binding var selectedClub: ClubType
    let onSelect: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(ClubType.allCases, id: \.self) { club in
                Button {
                    selectedClub = club
                    onSelect()
                    dismiss()
                } label: {
                    HStack {
                        Text(club.rawValue)
                            .foregroundColor(.white)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    LiveRoundView()
        .environmentObject(AuthManager())
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(WatchSyncManager())
        .preferredColorScheme(.dark)
}
