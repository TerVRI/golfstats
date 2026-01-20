import SwiftUI

struct RoundsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var rounds: [Round] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    var filteredRounds: [Round] {
        if searchText.isEmpty {
            return rounds
        }
        return rounds.filter { $0.courseName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rounds.isEmpty {
                    VStack(spacing: 20) {
                        EmptyStateCard(
                            icon: "list.bullet.rectangle",
                            title: "No rounds yet",
                            subtitle: "Start logging your rounds to track your progress"
                        )
                        
                        VStack(spacing: 12) {
                            Text("💡 Tip: Use the Dashboard to start a Live GPS Round")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            NavigationLink(destination: NewRoundView()) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Add Manual Round")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredRounds) { round in
                            NavigationLink(destination: RoundDetailView(round: round)) {
                                RoundListRow(round: round)
                            }
                            .listRowBackground(Color("BackgroundSecondary"))
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search courses")
                }
            }
            .background(Color("Background"))
            .navigationTitle("Rounds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink(destination: NewRoundView()) {
                            Label("Manual Round", systemImage: "pencil")
                        }
                        Button {
                            // Note: Live GPS rounds are started from Dashboard
                        } label: {
                            Label("Live GPS Round", systemImage: "location.fill")
                        }
                        .disabled(true)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .task {
            await loadRounds()
        }
        .refreshable {
            await loadRounds()
        }
    }
    
    private func loadRounds() async {
        guard let user = authManager.currentUser else { return }
        isLoading = true
        
        do {
            rounds = try await DataService.shared.fetchRounds(
                userId: user.id,
                authHeaders: authManager.authHeaders,
                limit: 50
            )
        } catch {
            print("Error loading rounds: \(error)")
        }
        
        isLoading = false
    }
}

struct RoundListRow: View {
    let round: Round
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(round.courseName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(round.totalScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text(round.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if let sg = round.sgTotal {
                    Text(sg >= 0 ? "+\(String(format: "%.1f", sg))" : String(format: "%.1f", sg))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(sg >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RoundDetailView: View {
    let round: Round
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(round.courseName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(round.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                
                // Score Card
                HStack(spacing: 20) {
                    ScoreBox(title: "Score", value: "\(round.totalScore)")
                    ScoreBox(title: "To Par", value: round.scoreToPar, color: scoreColor)
                    if let sg = round.sgTotal {
                        ScoreBox(title: "SG", value: String(format: "%+.1f", sg), color: sg >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    if let putts = round.totalPutts {
                        StatBox(title: "Putts", value: "\(putts)")
                    }
                    if let fw = round.fairwaysHit, let total = round.fairwaysTotal {
                        StatBox(title: "Fairways", value: "\(fw)/\(total)")
                    }
                    if let gir = round.gir {
                        StatBox(title: "GIR", value: "\(gir)/18")
                    }
                    if let penalties = round.penalties {
                        StatBox(title: "Penalties", value: "\(penalties)")
                    }
                }
                .padding(.horizontal)
                
                // Course Info
                if round.courseRating != nil || round.slopeRating != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Info")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            if let rating = round.courseRating {
                                VStack {
                                    Text("Rating")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(String(format: "%.1f", rating))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Spacer()
                            
                            if let slope = round.slopeRating {
                                VStack {
                                    Text("Slope")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(slope)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Strokes Gained Breakdown
                if round.sgTotal != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Strokes Gained")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            if let sg = round.sgOffTee {
                                SGRow(title: "Off Tee", value: sg)
                            }
                            if let sg = round.sgApproach {
                                SGRow(title: "Approach", value: sg)
                            }
                            if let sg = round.sgAroundGreen {
                                SGRow(title: "Around Green", value: sg)
                            }
                            if let sg = round.sgPutting {
                                SGRow(title: "Putting", value: sg)
                            }
                        }
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color("Background"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var scoreColor: Color {
        let diff = round.totalScore - 72
        if diff < 0 { return .green }
        if diff == 0 { return .white }
        return .red
    }
}

struct ScoreBox: View {
    let title: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct SGRow: View {
    let title: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(String(format: "%+.2f", value))
                .fontWeight(.semibold)
                .foregroundColor(value >= 0 ? .green : .red)
        }
    }
}

#Preview {
    RoundsListView()
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
