import SwiftUI

struct ContributorLeaderboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var leaderboard: [ContributorStats] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sortBy: SortOption = .reputation
    
    enum SortOption: String, CaseIterable {
        case reputation = "Reputation"
        case contributions = "Contributions"
        case verified = "Verified"
    }
    
    var sortedLeaderboard: [ContributorStats] {
        switch sortBy {
        case .reputation:
            return leaderboard.sorted { $0.reputationScore > $1.reputationScore }
        case .contributions:
            return leaderboard.sorted { $0.contributionsCount > $1.contributionsCount }
        case .verified:
            return leaderboard.sorted { $0.verifiedContributionsCount > $1.verifiedContributionsCount }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if leaderboard.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No contributors yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Be the first to contribute a course!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        // Sort Picker
                        Picker("Sort by", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        List {
                            ForEach(Array(sortedLeaderboard.enumerated()), id: \.element.id) { index, contributor in
                                LeaderboardRow(
                                    rank: index + 1,
                                    contributor: contributor,
                                    sortBy: sortBy
                                )
                                .listRowBackground(Color("BackgroundSecondary"))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .background(Color("Background"))
            .navigationTitle("Top Contributors")
            .task {
                await loadLeaderboard()
            }
            .refreshable {
                await loadLeaderboard()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            leaderboard = try await DataService.shared.fetchContributorLeaderboard(
                authHeaders: authManager.authHeaders
            )
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let contributor: ContributorStats
    let sortBy: ContributorLeaderboardView.SortOption
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(rankColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Contributor #\(rank)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if contributor.isTrustedContributor {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "star.fill",
                        value: String(format: "%.1f", contributor.reputationScore),
                        color: .yellow
                    )
                    
                    StatBadge(
                        icon: "plus.circle.fill",
                        value: "\(contributor.contributionsCount)",
                        color: .green
                    )
                    
                    StatBadge(
                        icon: "checkmark.circle.fill",
                        value: "\(contributor.verifiedContributionsCount)",
                        color: .blue
                    )
                }
                .font(.caption)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .white
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
        }
        .foregroundColor(color)
    }
}

#Preview {
    ContributorLeaderboardView()
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
