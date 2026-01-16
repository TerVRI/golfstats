import SwiftUI

struct ShotTrackerView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @State private var selectedClub: String = "7i"
    
    let clubs = ["Driver", "3W", "5W", "4i", "5i", "6i", "7i", "8i", "9i", "PW", "SW", "Putter"]
    
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
            
            // Club Picker
            Picker("Club", selection: $selectedClub) {
                ForEach(clubs, id: \.self) { club in
                    Text(club).tag(club)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)
            
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
