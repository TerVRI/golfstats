import SwiftUI

struct DistanceView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Hole Number
            HStack {
                Button(action: { roundManager.previousHole() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(roundManager.currentHole == 1)
                
                Text("Hole \(roundManager.currentHole)")
                    .font(.headline)
                
                Button(action: { roundManager.nextHole() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(roundManager.currentHole == 18)
            }
            
            Divider()
            
            // Main Distance Display
            VStack(spacing: 4) {
                Text("CENTER")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if gpsManager.distanceToGreenCenter > 0 {
                    Text("\(gpsManager.distanceToGreenCenter)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text("yards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("---")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("No GPS data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Front/Back distances
            HStack(spacing: 20) {
                VStack {
                    Text("FRONT")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(gpsManager.distanceToGreenFront > 0 ? "\(gpsManager.distanceToGreenFront)" : "--")")
                        .font(.headline)
                }
                
                VStack {
                    Text("BACK")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(gpsManager.distanceToGreenBack > 0 ? "\(gpsManager.distanceToGreenBack)" : "--")")
                        .font(.headline)
                }
            }
            
            // Last shot distance
            if let lastShot = gpsManager.lastShotDistance {
                Divider()
                HStack {
                    Image(systemName: "figure.golf")
                        .foregroundColor(.orange)
                    Text("Last shot: \(lastShot) yds")
                        .font(.caption)
                }
            }
        }
        .padding()
        .onAppear {
            gpsManager.startTracking()
        }
    }
}

#Preview {
    DistanceView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
}
