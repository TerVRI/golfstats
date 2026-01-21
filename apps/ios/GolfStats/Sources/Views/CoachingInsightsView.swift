import SwiftUI

struct CoachingInsightsView: View {
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    @State private var selectedCategory: WatchCoachingTip.TipCategory?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Category Filter
                categoryFilter
                
                // Tips List
                if filteredTips.isEmpty {
                    emptyStateView
                } else {
                    tipsListSection
                }
                
                // Quick Actions
                if !watchSyncManager.coachingTips.isEmpty {
                    quickActionsSection
                }
            }
            .padding(.vertical)
        }
        .background(Color("Background"))
        .navigationTitle("Coaching Tips")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.largeTitle)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Personal Coach")
                        .font(.headline)
                    Text("Tips based on your swing patterns")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Stats row
            HStack(spacing: 24) {
                statBubble(
                    value: "\(watchSyncManager.coachingTips.count)",
                    label: "Tips"
                )
                
                statBubble(
                    value: "\(priorityOneTips)",
                    label: "High Priority"
                )
                
                statBubble(
                    value: "\(uniqueCategories)",
                    label: "Focus Areas"
                )
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func statBubble(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryChip(nil, label: "All", count: watchSyncManager.coachingTips.count)
                
                ForEach(WatchCoachingTip.TipCategory.allCases, id: \.self) { category in
                    let count = watchSyncManager.coachingTips.filter { $0.category == category }.count
                    if count > 0 {
                        categoryChip(category, label: category.rawValue.capitalized, count: count)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func categoryChip(_ category: WatchCoachingTip.TipCategory?, label: String, count: Int) -> some View {
        Button {
            withAnimation {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                if let cat = category {
                    Image(systemName: cat.icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline)
                
                Text("\(count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected(category) ? categoryColor(category) : Color("BackgroundSecondary"))
            .foregroundColor(isSelected(category) ? .white : .primary)
            .cornerRadius(20)
        }
    }
    
    private func isSelected(_ category: WatchCoachingTip.TipCategory?) -> Bool {
        selectedCategory == category || (selectedCategory == nil && category == nil)
    }
    
    private func categoryColor(_ category: WatchCoachingTip.TipCategory?) -> Color {
        guard let cat = category else { return .blue }
        switch cat {
        case .tempo: return .blue
        case .consistency: return .green
        case .speed: return .orange
        case .path: return .purple
        case .putting: return .teal
        case .general: return .gray
        }
    }
    
    // MARK: - Tips List
    
    private var tipsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedTips, id: \.0) { priority, tips in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        priorityBadge(priority)
                        Text(priorityLabel(priority))
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    ForEach(tips) { tip in
                        tipCard(tip)
                    }
                }
            }
        }
    }
    
    private func tipCard(_ tip: WatchCoachingTip) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor(tip.category).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: tip.category.icon)
                    .font(.title3)
                    .foregroundColor(categoryColor(tip.category))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(tip.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(tip.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Text(tip.category.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor(tip.category).opacity(0.2))
                        .foregroundColor(categoryColor(tip.category))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text(tip.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func priorityBadge(_ priority: Int) -> some View {
        let color: Color = {
            switch priority {
            case 1: return .red
            case 2: return .orange
            default: return .green
            }
        }()
        
        return Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
    
    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1: return "Focus on these first"
        case 2: return "When you're ready"
        default: return "Nice to have"
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Tips Yet")
                .font(.title2.bold())
            
            Text("Play rounds with your Apple Watch to get personalized coaching tips based on your swing patterns")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 48)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice Focus")
                .font(.headline)
                .padding(.horizontal)
            
            // Suggest practice based on tips
            if let topCategory = topPriorityCategory {
                practiceCard(for: topCategory)
            }
        }
        .padding(.vertical)
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func practiceCard(for category: WatchCoachingTip.TipCategory) -> some View {
        HStack(spacing: 16) {
            Image(systemName: practiceIcon(for: category))
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(categoryColor(category))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended Practice")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(practiceTitle(for: category))
                    .font(.headline)
                
                Text(practiceDescription(for: category))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func practiceIcon(for category: WatchCoachingTip.TipCategory) -> String {
        switch category {
        case .tempo: return "metronome"
        case .consistency: return "repeat"
        case .speed: return "hare"
        case .path: return "arrow.turn.right.down"
        case .putting: return "flag"
        case .general: return "figure.golf"
        }
    }
    
    private func practiceTitle(for category: WatchCoachingTip.TipCategory) -> String {
        switch category {
        case .tempo: return "Tempo Drills"
        case .consistency: return "Consistency Training"
        case .speed: return "Speed Work"
        case .path: return "Swing Path Practice"
        case .putting: return "Putting Practice"
        case .general: return "General Practice"
        }
    }
    
    private func practiceDescription(for category: WatchCoachingTip.TipCategory) -> String {
        switch category {
        case .tempo: return "Focus on maintaining a 3:1 backswing to downswing ratio"
        case .consistency: return "Hit 20 balls with the same club, focusing on repeatable motion"
        case .speed: return "Swing at 80% effort for better control and distance"
        case .path: return "Use alignment sticks to check your swing path"
        case .putting: return "Practice from 3-6 feet with a consistent routine"
        case .general: return "Work on your fundamentals: grip, stance, alignment"
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTips: [WatchCoachingTip] {
        if let category = selectedCategory {
            return watchSyncManager.coachingTips.filter { $0.category == category }
        }
        return watchSyncManager.coachingTips
    }
    
    private var groupedTips: [(Int, [WatchCoachingTip])] {
        let grouped = Dictionary(grouping: filteredTips) { $0.priority }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    
    private var priorityOneTips: Int {
        watchSyncManager.coachingTips.filter { $0.priority == 1 }.count
    }
    
    private var uniqueCategories: Int {
        Set(watchSyncManager.coachingTips.map { $0.category }).count
    }
    
    private var topPriorityCategory: WatchCoachingTip.TipCategory? {
        let priorityTips = watchSyncManager.coachingTips.filter { $0.priority == 1 }
        let counts = Dictionary(grouping: priorityTips) { $0.category }
        return counts.max { $0.value.count < $1.value.count }?.key
    }
}

#Preview {
    NavigationStack {
        CoachingInsightsView()
            .environmentObject(WatchSyncManager())
    }
}
