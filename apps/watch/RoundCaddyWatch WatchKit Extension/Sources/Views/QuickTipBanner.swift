import SwiftUI

/// Small banner showing a quick coaching tip
struct QuickTipBanner: View {
    let tip: CoachingTip?
    
    @State private var isExpanded = false
    
    var body: some View {
        if let tip = tip {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: iconForCategory(tip.category))
                            .font(.caption2)
                            .foregroundColor(colorForPriority(tip.priority))
                        
                        Text(tip.title)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(isExpanded ? nil : 1)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if isExpanded {
                        Text(tip.message)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorForPriority(tip.priority).opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func iconForCategory(_ category: CoachingTip.TipCategory) -> String {
        switch category {
        case .tempo:
            return "metronome.fill"
        case .consistency:
            return "chart.line.uptrend.xyaxis"
        case .speed:
            return "bolt.fill"
        case .path:
            return "arrow.up.right"
        case .putting:
            return "circle.circle"
        case .general:
            return "lightbulb.fill"
        }
    }
    
    private func colorForPriority(_ priority: Int) -> Color {
        switch priority {
        case 1:
            return .red
        case 2:
            return .yellow
        default:
            return .blue
        }
    }
}

#Preview {
    VStack {
        QuickTipBanner(tip: CoachingTip(
            category: .tempo,
            title: "Improve Tempo",
            message: "Your backswing is too quick. Try counting to 3 on your backswing.",
            priority: 2
        ))
        
        QuickTipBanner(tip: CoachingTip(
            category: .putting,
            title: "Great Putting",
            message: "Your putting stroke is very consistent today!",
            priority: 3
        ))
    }
    .padding()
}
