import SwiftUI

/// Small badge showing putt count when in putting mode
struct PuttCountBadge: View {
    @EnvironmentObject var motionManager: MotionManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
            
            Text("\(motionManager.puttCount)")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("putts")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            Capsule()
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    PuttCountBadge()
        .environmentObject(MotionManager())
}
