import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var gpsManager: GPSManager
    
    @State private var stats: UserStats = .empty
    @State private var recentRounds: [Round] = []
    @State private var isLoading = true
    @State private var showNewRound = false
    @State private var selectedTimeRange: TimeRange = .last10
    
    enum TimeRange: String, CaseIterable {
        case last5 = "Last 5"
        case last10 = "Last 10"
        case last20 = "Last 20"
        case allTime = "All Time"
        
        var limit: Int? {
            switch self {
            case .last5: return 5
            case .last10: return 10
            case .last20: return 20
            case .allTime: return nil
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    headerSection
                    
                    // Quick Stats Grid
                    quickStatsSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Score Trend Chart
                    if recentRounds.count >= 2 {
                        scoreTrendSection
                    }
                    
                    // Strokes Gained Breakdown
                    if stats.roundsPlayed > 0 {
                        strokesGainedSection
                    }
                    
                    // Game Profile Radar
                    if stats.roundsPlayed > 0 {
                        gameProfileSection
                    }
                    
                    // Stats Breakdown
                    if stats.roundsPlayed > 0 {
                        statsBreakdownSection
                    }
                    
                    // Focus Area Insight
                    if let insight = getInsight() {
                        insightSection(insight: insight)
                    }
                    
                    // Recent Rounds
                    recentRoundsSection
                    
                    // Handicap Card
                    if let handicap = stats.handicapIndex {
                        handicapSection(handicap: handicap)
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
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
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(spacing: 12) {
            // Top row - 4 stats
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Rounds", value: "\(stats.roundsPlayed)", icon: "flag.fill")
                StatCard(
                    title: "Avg Score",
                    value: stats.roundsPlayed > 0 ? String(format: "%.0f", stats.averageScore) : "-",
                    icon: "chart.bar.fill"
                )
                StatCard(
                    title: "Best",
                    value: stats.bestScore > 0 ? "\(stats.bestScore)" : "-",
                    icon: "trophy.fill",
                    color: .yellow
                )
                StatCard(
                    title: "Avg SG",
                    value: formatSG(stats.averageSG),
                    icon: "arrow.up.right",
                    color: stats.averageSG >= 0 ? .green : .red
                )
            }
            
            // Bottom row - Improvement + Handicap
            HStack(spacing: 12) {
                let improvement = calculateImprovement()
                StatCard(
                    title: "Trend",
                    value: improvement != 0 ? formatSG(improvement) : "-",
                    icon: improvement >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                    color: improvement >= 0 ? .green : .red
                )
                
                if let handicap = stats.handicapIndex {
                    StatCard(
                        title: "Handicap",
                        value: String(format: "%.1f", handicap),
                        icon: "number.circle.fill",
                        color: .purple
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func calculateImprovement() -> Double {
        guard recentRounds.count >= 6 else { return 0 }
        let recent3 = recentRounds.prefix(3).compactMap { $0.sgTotal }.reduce(0, +) / 3.0
        let previous3 = recentRounds.dropFirst(3).prefix(3).compactMap { $0.sgTotal }.reduce(0, +) / 3.0
        return recent3 - previous3
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
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
    }
    
    // MARK: - Score Trend Section
    
    private var scoreTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Score Trend")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                // Time range picker
                Menu {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            selectedTimeRange = range
                            Task { await loadData() }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedTimeRange.rawValue)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            Chart {
                ForEach(Array(recentRounds.reversed().enumerated()), id: \.element.id) { index, round in
                    LineMark(
                        x: .value("Round", index + 1),
                        y: .value("Score", round.totalScore)
                    )
                    .foregroundStyle(Color.green)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Round", index + 1),
                        y: .value("Score", round.totalScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.green.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // Par line
                RuleMark(y: .value("Par", 72))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Par 72")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
            }
            .chartYScale(domain: (recentRounds.map(\.totalScore).min() ?? 70) - 5 ... (recentRounds.map(\.totalScore).max() ?? 90) + 5)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.gray)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(Color.gray)
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Strokes Gained Section
    
    private var strokesGainedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strokes Gained Breakdown")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                SGBarRow(label: "Off Tee", value: stats.sgOffTee, icon: "figure.golf")
                SGBarRow(label: "Approach", value: stats.sgApproach, icon: "target")
                SGBarRow(label: "Around Green", value: stats.sgAroundGreen, icon: "circle.dashed")
                SGBarRow(label: "Putting", value: stats.sgPutting, icon: "circle.fill")
            }
            .padding(.horizontal)
            
            // Legend
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                    Text("Gaining").font(.caption).foregroundColor(.gray)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Text("Losing").font(.caption).foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Game Profile Section (Radar-like)
    
    private var gameProfileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game Profile")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 0) {
                // Left column - Off Tee & Approach
                VStack(spacing: 20) {
                    GameProfileItem(
                        label: "Off Tee",
                        value: stats.sgOffTee,
                        icon: "figure.golf",
                        position: .left
                    )
                    GameProfileItem(
                        label: "Approach",
                        value: stats.sgApproach,
                        icon: "scope",
                        position: .left
                    )
                }
                .frame(maxWidth: .infinity)
                
                // Center - Total SG
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: min(max((stats.averageSG + 5) / 10, 0), 1))
                            .stroke(
                                stats.averageSG >= 0 ? Color.green : Color.red,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text(formatSG(stats.averageSG))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(stats.averageSG >= 0 ? .green : .red)
                            Text("Total SG")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right column - Around Green & Putting
                VStack(spacing: 20) {
                    GameProfileItem(
                        label: "Short Game",
                        value: stats.sgAroundGreen,
                        icon: "circle.dashed",
                        position: .right
                    )
                    GameProfileItem(
                        label: "Putting",
                        value: stats.sgPutting,
                        icon: "circle.fill",
                        position: .right
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Stats Breakdown Section
    
    private var statsBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Stats")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PercentageCard(
                    title: "Fairways Hit",
                    value: stats.fairwayPercentage,
                    icon: "arrow.up.forward",
                    color: .blue
                )
                PercentageCard(
                    title: "Greens in Reg",
                    value: stats.girPercentage,
                    icon: "target",
                    color: .green
                )
                PercentageCard(
                    title: "Scrambling",
                    value: stats.scramblingPercentage,
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange
                )
                PercentageCard(
                    title: "Putts/Hole",
                    value: stats.puttsPerHole,
                    icon: "circle.fill",
                    color: .purple,
                    isPercentage: false
                )
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Insight Section
    
    private func insightSection(insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Area: \(insight.title)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color("BackgroundSecondary"), Color.orange.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Recent Rounds Section
    
    private var recentRoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rounds")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                NavigationLink(destination: RoundsListView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }
            }
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
    }
    
    // MARK: - Handicap Section
    
    private func handicapSection(handicap: Double) -> some View {
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
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundColor(.green.opacity(0.3))
                Text(handicap < 10 ? "Single Digit!" : handicap < 18 ? "Bogey Golfer" : "Keep Improving!")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Data Loading
    
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
                limit: selectedTimeRange.limit ?? 100
            )
        } catch {
            print("Error loading data: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func formatSG(_ value: Double) -> String {
        if value == 0 { return "0.0" }
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", value))"
    }
    
    private func getInsight() -> Insight? {
        guard stats.roundsPlayed > 0 else { return nil }
        
        let categories: [(String, Double, String, String)] = [
            ("Off Tee", stats.sgOffTee, "figure.golf", "Your tee shots are costing you strokes. Focus on accuracy off the tee."),
            ("Approach", stats.sgApproach, "scope", "Your approach shots need work. Practice distance control with irons."),
            ("Short Game", stats.sgAroundGreen, "circle.dashed", "Around the green is hurting your score. Work on chipping and pitching."),
            ("Putting", stats.sgPutting, "circle.fill", "The flatstick is your weakness. Practice lag putting and short putts.")
        ]
        
        if let worst = categories.min(by: { $0.1 < $1.1 }), worst.1 < -0.5 {
            return Insight(
                title: worst.0,
                icon: worst.2,
                message: "\(worst.3) You're losing \(String(format: "%.1f", abs(worst.1))) strokes per round here."
            )
        }
        
        return nil
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    var icon: String = ""
    var color: Color = .white
    
    var body: some View {
        VStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color.opacity(0.7))
            }
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

struct SGBarRow: View {
    let label: String
    let value: Double
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 90, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: value >= 0 ? .leading : .trailing) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 24)
                        .cornerRadius(4)
                    
                    // Center line
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1, height: 24)
                        .position(x: geo.size.width / 2, y: 12)
                    
                    // Value bar
                    let maxValue = 3.0
                    let barWidth = min(abs(value) / maxValue, 1.0) * (geo.size.width / 2)
                    
                    Rectangle()
                        .fill(value >= 0 ? Color.green : Color.red)
                        .frame(width: barWidth, height: 24)
                        .cornerRadius(4)
                        .offset(x: value >= 0 ? geo.size.width / 2 : geo.size.width / 2 - barWidth)
                }
            }
            .frame(height: 24)
            
            Text(formatSG(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(value >= 0 ? .green : .red)
                .frame(width: 50, alignment: .trailing)
        }
    }
    
    private func formatSG(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))"
    }
}

struct GameProfileItem: View {
    let label: String
    let value: Double
    let icon: String
    let position: HorizontalAlignment
    
    enum HorizontalAlignment {
        case left, right
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if position == .right {
                Spacer()
            }
            
            VStack(alignment: position == .left ? .leading : .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if position == .left {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.gray)
                    if position == .right {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(formatSG(value))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(value >= 0 ? .green : .red)
            }
            
            if position == .left {
                Spacer()
            }
        }
    }
    
    private func formatSG(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))"
    }
}

struct PercentageCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    var isPercentage: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(isPercentage ? "\(Int(value))" : String(format: "%.1f", value))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                if isPercentage {
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 3)
                }
            }
            
            if isPercentage {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geo.size.width * (value / 100), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(Color("BackgroundTertiary"))
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

struct Insight {
    let title: String
    let icon: String
    let message: String
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
        .environmentObject(RoundManager())
        .environmentObject(GPSManager())
        .preferredColorScheme(.dark)
}
