import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var roundManager: RoundManager
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if roundManager.isRoundActive {
                LiveRoundView()
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    RoundsListView()
                        .tabItem {
                            Label("Rounds", systemImage: "list.bullet")
                        }
                        .tag(1)
                    
                    CoursesView()
                        .tabItem {
                            Label("Courses", systemImage: "map.fill")
                        }
                        .tag(2)
                    
                    ContributorLeaderboardView()
                        .tabItem {
                            Label("Leaderboard", systemImage: "trophy.fill")
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
        .preferredColorScheme(.dark)
}
