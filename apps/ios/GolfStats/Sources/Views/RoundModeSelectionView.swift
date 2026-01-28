import SwiftUI

/// View for selecting round mode when starting a new round
struct RoundModeSelectionView: View {
    @Binding var selectedMode: RoundMode
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    @State private var showLockedModeSheet = false
    @State private var lockedMode: RoundMode?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Round Mode")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 12) {
                ForEach(RoundMode.allCases, id: \.self) { mode in
                    RoundModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        isLocked: !gracePeriodManager.hasAccess(to: mode),
                        onSelect: {
                            if gracePeriodManager.hasAccess(to: mode) {
                                selectedMode = mode
                            } else {
                                lockedMode = mode
                                showLockedModeSheet = true
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showLockedModeSheet) {
            if let mode = lockedMode {
                RoundModeLockedSheet(mode: mode)
            }
        }
    }
}

struct RoundModeCard: View {
    let mode: RoundMode
    let isSelected: Bool
    let isLocked: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.green : Color(.secondarySystemBackground))
                        .frame(width: 44, height: 44)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.gray)
                    } else {
                        Image(systemName: mode.icon)
                            .font(.title3)
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mode.displayName)
                            .font(.headline)
                            .foregroundStyle(isLocked ? .secondary : .primary)
                        
                        if mode.requiresPro {
                            Text("PRO")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected && !isLocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            )
            .opacity(isLocked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct RoundModeLockedSheet: View {
    let mode: RoundMode
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                    
                    Text(mode.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Pro Feature")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Includes:")
                        .font(.headline)
                    
                    ForEach(modeFeatures, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(feature)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    if gracePeriodManager.canStartTrial {
                        Button(action: startTrial) {
                            Text("Start Free Trial")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    NavigationLink {
                        ProPaywallView()
                    } label: {
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button("Use Quick Score Instead") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var modeFeatures: [String] {
        let features = mode.features
        var list: [String] = []
        
        if features.gpsEnabled { list.append("GPS Distances") }
        if features.shotTracking { list.append("Shot Tracking") }
        if features.statsTracking { list.append("Full Statistics") }
        if features.watchSync { list.append("Apple Watch Sync") }
        if features.strokeIndex { list.append("Stroke Index Display") }
        if features.handicapAdjustment { list.append("Handicap Calculation") }
        if features.attestation { list.append("Round Attestation") }
        
        return list
    }
    
    private func startTrial() {
        if gracePeriodManager.startTrial() {
            dismiss()
        }
    }
}

/// Compact round mode picker for settings
struct RoundModePickerCompact: View {
    @Binding var selectedMode: RoundMode
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    
    var body: some View {
        Picker("Default Mode", selection: $selectedMode) {
            ForEach(RoundMode.allCases, id: \.self) { mode in
                HStack {
                    Image(systemName: mode.icon)
                    Text(mode.displayName)
                    if mode.requiresPro && !gracePeriodManager.hasAccess(to: mode) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                    }
                }
                .tag(mode)
            }
        }
    }
}

/// Banner showing current access level status
struct AccessLevelBanner: View {
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        if gracePeriodManager.currentAccessLevel != .pro {
            Button(action: { showPaywall = true }) {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                    
                    Text(gracePeriodManager.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(gracePeriodManager.upgradeCallToAction)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .clipShape(Capsule())
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }
    
    private var statusIcon: String {
        switch gracePeriodManager.currentAccessLevel {
        case .pro: return "crown.fill"
        case .trial: return "clock.fill"
        case .gracePeriod: return "gift.fill"
        case .free: return "person.fill"
        }
    }
    
    private var statusColor: Color {
        switch gracePeriodManager.currentAccessLevel {
        case .pro: return .yellow
        case .trial: return .orange
        case .gracePeriod: return .green
        case .free: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var mode: RoundMode = .fullTracking
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        AccessLevelBanner()
                        RoundModeSelectionView(selectedMode: $mode)
                    }
                    .padding()
                }
                .navigationTitle("Start Round")
            }
        }
    }
    
    return PreviewWrapper()
}
