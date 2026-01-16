import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var gpsManager: GPSManager
    
    @State private var stats: UserStats = .empty
    @State private var recentRounds: [Round] = []
    @State private var isLoading = true
    @State private var showNewRound = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(authManager.currentUser?.displayName ?? "Golfer")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        
                        // Profile image
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Text(authManager.currentUser?.initials ?? "G")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick Stats
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(title: "Rounds", value: "\(stats.roundsPlayed)")
                        StatCard(title: "Avg Score", value: stats.roundsPlayed > 0 ? String(format: "%.0f", stats.averageScore) : "-")
                        StatCard(title: "Best", value: stats.bestScore > 0 ? "\(stats.bestScore)" : "-")
                        StatCard(title: "Avg SG", value: formatSG(stats.averageSG), color: stats.averageSG >= 0 ? .green : .red)
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            showNewRound = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("New Round")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            roundManager.startRound()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Live GPS")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("BackgroundTertiary"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recent Rounds
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Rounds")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        if recentRounds.isEmpty {
                            EmptyStateCard(
                                icon: "flag.fill",
                                title: "No rounds yet",
                                subtitle: "Start logging your rounds to see stats"
                            )
                            .padding(.horizontal)
                        } else {
                            ForEach(recentRounds.prefix(5)) { round in
                                NavigationLink(destination: RoundDetailView(round: round)) {
                                    RoundRow(round: round)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Handicap Card
                    if let handicap = stats.handicapIndex {
                        HandicapCard(handicap: handicap)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color("Background"))
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewRound) {
                NewRoundView()
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let user = authManager.currentUser else { return }
        isLoading = true
        
        do {
            stats = try await DataService.shared.fetchStats(
                userId: user.id,
                authHeaders: authManager.authHeaders
            )
            recentRounds = try await DataService.shared.fetchRounds(
                userId: user.id,
                authHeaders: authManager.authHeaders,
                limit: 10
            )
        } catch {
            print("Error loading data: \(error)")
        }
        
        isLoading = false
    }
    
    private func formatSG(_ value: Double) -> String {
        if value == 0 { return "-" }
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", value))"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct RoundRow: View {
    let round: Round
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.courseName)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(round.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(round.totalScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let sg = round.sgTotal {
                    Text(sg >= 0 ? "+\(String(format: "%.1f", sg))" : String(format: "%.1f", sg))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(sg >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct HandicapCard: View {
    let handicap: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Handicap Index")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(String(format: "%.1f", handicap))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
            Spacer()
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.green.opacity(0.3))
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
        .environmentObject(RoundManager())
        .environmentObject(GPSManager())
        .preferredColorScheme(.dark)
}
