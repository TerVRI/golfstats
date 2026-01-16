import SwiftUI

struct ShotTrackerView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @State private var selectedClub: String = ""
    
    var currentHoleShots: [Shot] {
        roundManager.shots.filter { $0.holeNumber == roundManager.currentHole }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Shot \(currentHoleShots.count + 1)")
                    .font(.headline)
                Spacer()
                Text("Hole \(roundManager.currentHole)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Club Picker - uses synced bag from iPhone
            Picker("Club", selection: $selectedClub) {
                ForEach(roundManager.clubBag, id: \.self) { club in
                    Text(club).tag(club)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)
            .onAppear {
                // Set default selection to middle of bag (usually an iron)
                if selectedClub.isEmpty, let midClub = roundManager.clubBag.dropFirst(roundManager.clubBag.count / 2).first {
                    selectedClub = midClub
                }
            }
            .onChange(of: roundManager.clubBag) { _, newBag in
                // If current selection is not in new bag, reset to middle club
                if !newBag.contains(selectedClub), let midClub = newBag.dropFirst(newBag.count / 2).first {
                    selectedClub = midClub
                }
            }
            
            // Mark Shot Button
            Button(action: markShot) {
                HStack {
                    Image(systemName: "target")
                    Text("Mark Shot")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(gpsManager.currentLocation == nil)
            
            // Last shot distance
            if let lastDist = gpsManager.lastShotDistance {
                HStack {
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.orange)
                    Text("Last: \(lastDist) yards")
                        .font(.caption)
                }
            }
            
            // Shot count for current hole
            if !currentHoleShots.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shots this hole:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(currentHoleShots.suffix(3)) { shot in
                        HStack {
                            Text("\(shot.shotNumber).")
                                .font(.caption2)
                            Text(shot.club ?? "?")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func markShot() {
        guard let location = gpsManager.currentLocation else { return }
        
        gpsManager.markShot()
        
        roundManager.addShot(
            holeNumber: roundManager.currentHole,
            club: selectedClub,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}

#Preview {
    ShotTrackerView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
}
