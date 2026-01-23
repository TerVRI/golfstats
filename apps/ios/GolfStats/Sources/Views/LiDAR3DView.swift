import SwiftUI
import RealityKit
import ARKit
import Combine

/// Full 3D swing analysis view using ARKit and LiDAR
/// Provides avatar mirroring, swing plane visualization, ghost overlay, and measurements
struct LiDAR3DView: View {
    @StateObject private var viewModel = LiDAR3DViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                Spacer()
                
                // Live measurements panel (if enabled)
                if viewModel.settings.showRealMeasurements && viewModel.isPersonDetected {
                    measurementsPanel
                }
                
                // Bottom controls
                bottomControls
            }
            
            // Tracking quality indicator
            if viewModel.isTracking {
                trackingQualityBadge
            }
            
            // Ghost overlay controls
            if viewModel.settings.showGhostOverlay && viewModel.hasRecordedSwing {
                ghostOverlayControls
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            LiDAR3DSettingsView(settings: $viewModel.settings)
        }
        .sheet(isPresented: $viewModel.showProComparison) {
            ProComparisonView(viewModel: viewModel)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Mode indicator
            VStack(spacing: 2) {
                Text("3D Analysis")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isPersonDetected ? .green : .orange)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.isPersonDetected ? "Tracking" : "Searching...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: { viewModel.showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Tracking Quality Badge
    
    private var trackingQualityBadge: some View {
        VStack {
            HStack {
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(trackingQualityColor)
                        .frame(width: 10, height: 10)
                    
                    Text(viewModel.trackingQuality.description)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 70)
            
            Spacer()
        }
    }
    
    private var trackingQualityColor: Color {
        switch viewModel.trackingQuality {
        case .good: return .green
        case .limited: return .yellow
        case .poor: return .red
        case .notAvailable: return .gray
        }
    }
    
    // MARK: - Measurements Panel
    
    private var measurementsPanel: some View {
        HStack(spacing: 20) {
            if let measurements = viewModel.currentMeasurements {
                measurementItem(
                    label: "Stance",
                    value: String(format: "%.0f", measurements.stanceWidthCm),
                    unit: "cm"
                )
                
                measurementItem(
                    label: "Shoulder",
                    value: String(format: "%.0f", measurements.shoulderWidthCm),
                    unit: "cm"
                )
                
                if measurements.heightCm > 0 {
                    measurementItem(
                        label: "Height",
                        value: String(format: "%.0f", measurements.heightCm),
                        unit: "cm"
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func measurementItem(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Feature toggles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    featureToggle(
                        icon: "figure.stand",
                        label: "Avatar",
                        isActive: viewModel.settings.showAvatar,
                        action: { viewModel.toggleAvatar() }
                    )
                    
                    featureToggle(
                        icon: "square.3.layers.3d",
                        label: "Swing Plane",
                        isActive: viewModel.settings.showSwingPlane,
                        action: { viewModel.toggleSwingPlane() }
                    )
                    
                    featureToggle(
                        icon: "person.2.fill",
                        label: "Ghost",
                        isActive: viewModel.settings.showGhostOverlay,
                        action: { viewModel.toggleGhostOverlay() }
                    )
                    
                    featureToggle(
                        icon: "ruler",
                        label: "Measure",
                        isActive: viewModel.settings.showRealMeasurements,
                        action: { viewModel.toggleMeasurements() }
                    )
                    
                    if viewModel.capabilities.hasLiDAR {
                        featureToggle(
                            icon: "sparkles",
                            label: "Point Cloud",
                            isActive: viewModel.showPointCloud,
                            action: { viewModel.togglePointCloud() }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Main action buttons
            HStack(spacing: 24) {
                // Record swing button
                Button(action: { viewModel.recordSwing() }) {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(viewModel.isRecording ? .red : .white)
                        
                        Text(viewModel.isRecording ? "Stop" : "Record")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
                
                // Pro comparison button
                Button(action: { viewModel.showProComparison = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                        
                        Text("Compare")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
                .disabled(!viewModel.hasRecordedSwing)
                .opacity(viewModel.hasRecordedSwing ? 1 : 0.5)
                
                // Avatar style picker
                Menu {
                    ForEach(AvatarStyle.allCases, id: \.self) { style in
                        Button(action: { viewModel.setAvatarStyle(style) }) {
                            Label(style.rawValue, systemImage: avatarStyleIcon(style))
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                        
                        Text("Style")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func featureToggle(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isActive ? .white : .white.opacity(0.5))
            .frame(width: 60, height: 50)
            .background(isActive ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func avatarStyleIcon(_ style: AvatarStyle) -> String {
        switch style {
        case .robot: return "cpu"
        case .golfer: return "figure.golf"
        case .skeleton: return "figure.stand"
        case .points: return "sparkles"
        }
    }
    
    // MARK: - Ghost Overlay Controls
    
    private var ghostOverlayControls: some View {
        VStack {
            Spacer()
            
            HStack {
                // Playback slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghost Overlay")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Slider(value: $viewModel.ghostPlaybackPosition, in: 0...1)
                        .tint(.green)
                }
                .frame(width: 200)
                
                // Opacity slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Slider(value: $viewModel.ghostOpacity, in: 0.1...1.0)
                        .tint(.blue)
                }
                .frame(width: 120)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            .padding(.bottom, 200)
        }
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: LiDAR3DViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        
        // Configure AR view
        arView.environment.sceneUnderstanding.options = []
        
        // Setup body tracking
        viewModel.setupARView(arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled by viewModel
    }
}

// MARK: - View Model

class LiDAR3DViewModel: ObservableObject {
    // Published state
    @Published var isTracking = false
    @Published var isPersonDetected = false
    @Published var trackingQuality: TrackingQuality = .notAvailable
    @Published var currentMeasurements: BodyMeasurements?
    
    // Settings
    @Published var settings = LiDAR3DSettings()
    @Published var showSettings = false
    @Published var showProComparison = false
    
    // Recording
    @Published var isRecording = false
    @Published var hasRecordedSwing = false
    @Published var recordedSwing: RecordedSwing3D?
    
    // Ghost overlay
    @Published var ghostPlaybackPosition: Double = 0
    @Published var ghostOpacity: Double = 0.5
    
    // Point cloud
    @Published var showPointCloud = false
    
    // Capabilities
    let capabilities = LiDARCapabilities.shared
    
    // Managers
    private let bodyTrackingManager = ARBodyTrackingManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        bodyTrackingManager.$isTracking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTracking)
        
        bodyTrackingManager.$isPersonDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPersonDetected)
        
        bodyTrackingManager.$trackingQuality
            .receive(on: DispatchQueue.main)
            .assign(to: &$trackingQuality)
        
        bodyTrackingManager.$currentMeasurements
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentMeasurements)
    }
    
    func setupARView(_ arView: ARView) {
        bodyTrackingManager.setupARView(arView)
        bodyTrackingManager.settings = settings
        
        // Load default avatar if enabled
        if settings.showAvatar {
            bodyTrackingManager.loadAvatar(style: settings.avatarStyle)
        }
    }
    
    func startSession() {
        bodyTrackingManager.startTracking()
    }
    
    func stopSession() {
        bodyTrackingManager.stopTracking()
    }
    
    // MARK: - Feature Toggles
    
    func toggleAvatar() {
        settings.showAvatar.toggle()
        if settings.showAvatar {
            bodyTrackingManager.loadAvatar(style: settings.avatarStyle)
        } else {
            bodyTrackingManager.removeAvatar()
        }
    }
    
    func toggleSwingPlane() {
        settings.showSwingPlane.toggle()
        bodyTrackingManager.settings.showSwingPlane = settings.showSwingPlane
    }
    
    func toggleGhostOverlay() {
        settings.showGhostOverlay.toggle()
    }
    
    func toggleMeasurements() {
        settings.showRealMeasurements.toggle()
        bodyTrackingManager.settings.showRealMeasurements = settings.showRealMeasurements
    }
    
    func togglePointCloud() {
        showPointCloud.toggle()
        if showPointCloud {
            bodyTrackingManager.loadAvatar(style: .points)
        } else {
            bodyTrackingManager.loadAvatar(style: settings.avatarStyle)
        }
    }
    
    func setAvatarStyle(_ style: AvatarStyle) {
        settings.avatarStyle = style
        if settings.showAvatar {
            bodyTrackingManager.loadAvatar(style: style)
        }
    }
    
    // MARK: - Recording
    
    func recordSwing() {
        if isRecording {
            // Stop recording
            isRecording = false
            if let swing = bodyTrackingManager.recordSwing() {
                recordedSwing = swing
                hasRecordedSwing = true
            }
        } else {
            // Start recording
            bodyTrackingManager.clearHistory()
            isRecording = true
        }
    }
}

// MARK: - Settings View

struct LiDAR3DSettingsView: View {
    @Binding var settings: LiDAR3DSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Avatar") {
                    Toggle("Show Avatar", isOn: $settings.showAvatar)
                    
                    Picker("Style", selection: $settings.avatarStyle) {
                        ForEach(AvatarStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                
                Section("Visualization") {
                    Toggle("Swing Plane", isOn: $settings.showSwingPlane)
                    Toggle("Real Measurements", isOn: $settings.showRealMeasurements)
                    Toggle("Ghost Overlay", isOn: $settings.showGhostOverlay)
                    
                    if settings.showGhostOverlay {
                        Slider(value: $settings.ghostOpacity, in: 0.1...1.0) {
                            Text("Ghost Opacity")
                        }
                    }
                }
                
                Section("Swing Plane Color") {
                    Picker("Color", selection: $settings.swingPlaneColor) {
                        Text("Green").tag("green")
                        Text("Blue").tag("blue")
                        Text("Red").tag("red")
                        Text("Yellow").tag("yellow")
                    }
                }
            }
            .navigationTitle("3D Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Pro Comparison View

struct ProComparisonView: View {
    @ObservedObject var viewModel: LiDAR3DViewModel
    @Environment(\.dismiss) private var dismiss
    
    let proGolfers = [
        ProGolfer(name: "Tiger Woods", image: "tiger", description: "Powerful rotation, stable head"),
        ProGolfer(name: "Rory McIlroy", image: "rory", description: "Athletic turn, fast tempo"),
        ProGolfer(name: "Jon Rahm", image: "rahm", description: "Compact swing, strong impact"),
        ProGolfer(name: "Scottie Scheffler", image: "scottie", description: "Smooth tempo, consistent plane")
    ]
    
    @State private var selectedPro: ProGolfer?
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.hasRecordedSwing {
                    Text("Compare your swing with a pro")
                        .font(.headline)
                        .padding()
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(proGolfers) { golfer in
                                ProGolferCard(golfer: golfer, isSelected: selectedPro?.id == golfer.id)
                                    .onTapGesture {
                                        selectedPro = golfer
                                    }
                            }
                        }
                        .padding()
                    }
                    
                    if let selected = selectedPro {
                        Button(action: { startComparison(with: selected) }) {
                            Text("Compare with \(selected.name)")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Record a Swing First",
                        systemImage: "figure.golf",
                        description: Text("Record your swing to compare with professional golfers")
                    )
                }
            }
            .navigationTitle("Pro Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func startComparison(with pro: ProGolfer) {
        // Would load pre-recorded pro swing data and overlay
        // For now, just dismiss
        dismiss()
    }
}

struct ProGolfer: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let description: String
}

struct ProGolferCard: View {
    let golfer: ProGolfer
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Placeholder for golfer image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                
                Image(systemName: "figure.golf")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray)
            }
            
            Text(golfer.name)
                .font(.headline)
            
            Text(golfer.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
