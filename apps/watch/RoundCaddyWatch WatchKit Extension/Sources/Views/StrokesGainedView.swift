import SwiftUI

/// Displays Strokes Gained analytics during the round
struct StrokesGainedView: View {
    @ObservedObject var calculator: StrokesGainedCalculator
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("Strokes Gained")
                    .font(.headline)
                
                // Total SG
                VStack(spacing: 4) {
                    Text(sgFormatted(calculator.totalStrokesGained))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(calculator.totalStrokesGained >= 0 ? .green : .red)
                    
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Breakdown
                VStack(spacing: 8) {
                    SGCategoryRow(
                        category: "Off Tee",
                        value: calculator.strokesGainedOffTee,
                        icon: "figure.golf"
                    )
                    
                    SGCategoryRow(
                        category: "Approach",
                        value: calculator.strokesGainedApproach,
                        icon: "target"
                    )
                    
                    SGCategoryRow(
                        category: "Around Green",
                        value: calculator.strokesGainedAroundGreen,
                        icon: "flag.fill"
                    )
                    
                    SGCategoryRow(
                        category: "Putting",
                        value: calculator.strokesGainedPutting,
                        icon: "circle.circle"
                    )
                }
                
                // Shot count
                if calculator.shotHistory.count > 0 {
                    Divider()
                    
                    HStack {
                        Text("Shots Tracked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(calculator.shotHistory.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
        }
    }
    
    private func sgFormatted(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", value))"
    }
}

struct SGCategoryRow: View {
    let category: String
    let value: Double
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(value >= 0 ? .green : .red)
                .frame(width: 20)
            
            Text(category)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(sgFormatted(value))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(value >= 0 ? .green : .red)
        }
        .padding(.horizontal, 4)
    }
    
    private func sgFormatted(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", value))"
    }
}

#Preview {
    StrokesGainedView(calculator: StrokesGainedCalculator())
}
