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
            
            Text("GolfStats")
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
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    ContentView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
}
