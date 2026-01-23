import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var useFullScreenRound = true // Default to full-screen map experience
    
    var body: some View {
        Group {
            if roundManager.isRoundActive {
                // Full-screen immersive round experience
                if useFullScreenRound {
                    FullScreenRoundView()
                } else {
                    LiveRoundView()
                }
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    RoundsListView()
                        .tabItem {
                            Label("Rounds", systemImage: "list.bullet")
                        }
                        .tag(1)
                    
                    // Range Mode - Camera swing analysis with Watch integration
                    RangeModeView()
                        .tabItem {
                            Label("Range", systemImage: "camera.viewfinder")
                        }
                        .tag(2)
                    
                    // Map-first course discovery
                    CoursesMapView()
                        .tabItem {
                            Label("Courses", systemImage: "map.fill")
                        }
                        .tag(3)
                    
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(4)
                }
                .tint(.green)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(WatchSyncManager())
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
