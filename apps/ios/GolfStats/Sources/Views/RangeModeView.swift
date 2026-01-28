import SwiftUI
import AVFoundation
import ARKit
import RealityKit
import Combine

/// Main Range Mode view with camera preview and swing analysis
struct RangeModeView: View {
    @StateObject private var viewModel = RangeModeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Camera/AR preview layer based on tracking mode
            if viewModel.trackingMode == .arkit3D {
                ARBodyPreviewViewWrapper(tracker: viewModel.swingAnalyzer.arBodyTracker)
                    .ignoresSafeArea()
            } else {
                CameraPreviewView(session: viewModel.captureSession)
                    .ignoresSafeArea()
            }
            
            // Skeleton overlay (for 2D mode or when AR skeleton is hidden)
            if viewModel.showSkeleton, let pose = viewModel.currentPose {
                SkeletonOverlayView(pose: pose, is3DMode: viewModel.trackingMode == .arkit3D)
                    .ignoresSafeArea()
            }
            
            // UI Overlay
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                Spacer()
                
                // Alignment guide (when not analyzing)
                if !viewModel.isSessionActive {
                    alignmentGuide
                }
                
                // Live metrics (when analyzing)
                if viewModel.isSessionActive {
                    liveMetricsPanel
                }
                
                // Bottom controls
                bottomControls
            }
            
            // Swing phase indicator
            if viewModel.isSwingInProgress {
                swingPhaseIndicator
            }
        }
        .statusBarHidden()
        .onAppear {
            viewModel.setupCamera()
            viewModel.startPosePreview()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .sheet(isPresented: $viewModel.showSessionSummary) {
            if let session = viewModel.completedSession {
                RangeSessionSummaryView(session: session)
            }
        }
        .sheet(isPresented: $viewModel.showClubPicker) {
            RangeClubPickerSheet(selectedClub: $viewModel.selectedClub)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showSettings) {
            RangeModeSettingsSheet()
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Session timer
            if viewModel.isSessionActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.formattedDuration)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            }
            
            Spacer()
            
            // Settings
            Button(action: { viewModel.showSettings = true }) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    // MARK: - Alignment Guide
    
    private var alignmentGuide: some View {
        VStack(spacing: 16) {
                // Camera error or alignment status
                if let error = viewModel.cameraError {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.alignmentStatus.systemImage)
                            .font(.title)
                            .foregroundColor(alignmentColor)
                        
                        Text(viewModel.alignmentMessage)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
            
            // Watch connection status
            if viewModel.isWatchConnected {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .foregroundColor(.green)
                    Text("Apple Watch ready")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .foregroundColor(.orange)
                    Text("Open RoundCaddy on Watch for motion data")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding(.bottom, 100)
    }
    
    private var alignmentColor: Color {
        switch viewModel.alignmentStatus {
        case .good: return .green
        case .searching, .lowConfidence: return .yellow
        default: return .orange
        }
    }
    
    // MARK: - Live Metrics Panel
    
    private var liveMetricsPanel: some View {
        VStack(spacing: 12) {
            // Swing count
            HStack {
                Text("Swings")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(viewModel.swingCount)")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.white.opacity(0.3))
            
            // Live body metrics
            HStack(spacing: 20) {
                metricItem(title: "Hip Turn", value: "\(Int(viewModel.liveHipRotation))°")
                metricItem(title: "Shoulder Turn", value: "\(Int(viewModel.liveShoulderRotation))°")
                metricItem(title: "Spine", value: "\(Int(viewModel.liveSpineAngle))°")
            }
            
            // Watch metrics (if connected)
            if viewModel.isWatchConnected {
                Divider().background(Color.white.opacity(0.3))
                
                HStack(spacing: 20) {
                    metricItem(title: "Accel", value: String(format: "%.1fG", viewModel.liveAcceleration))
                    metricItem(title: "Last Tempo", value: viewModel.lastTempo.map { String(format: "%.1f:1", $0) } ?? "--")
                    metricItem(title: "Speed", value: viewModel.lastSpeed.map { String(format: "%.0f", $0) } ?? "--", unit: "mph")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
        )
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    private func metricItem(title: String, value: String, unit: String? = nil) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(.white)
                if let unit = unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Swing Phase Indicator
    
    private var swingPhaseIndicator: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Text(viewModel.currentPhase.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(20)
                    .padding()
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Tracking mode toggle (only show if ARKit available)
            if viewModel.isARKitAvailable {
                trackingModeToggle
            }
            
            HStack(spacing: 40) {
                // Club selector
                Button(action: { viewModel.showClubPicker = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.golf")
                            .font(.title2)
                        Text(viewModel.selectedClub ?? "Club")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                }
                
                // Main action button
                Button(action: viewModel.toggleSession) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isSessionActive ? Color.red : Color.green)
                            .frame(width: 80, height: 80)
                        
                        if viewModel.isSessionActive {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .disabled(!viewModel.canStartSession)
                .opacity(viewModel.canStartSession ? 1 : 0.5)
                
                // Skeleton toggle
                Button(action: { viewModel.showSkeleton.toggle() }) {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.showSkeleton ? "figure.stand" : "figure.stand.line.dotted.figure.stand")
                            .font(.title2)
                        Text("Skeleton")
                            .font(.caption)
                    }
                    .foregroundColor(viewModel.showSkeleton ? .green : .white)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Tracking Mode Toggle
    
    private var trackingModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(BodyTrackingMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.trackingMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.subheadline)
                        Text(mode == .vision2D ? "2D" : "3D")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(viewModel.trackingMode == mode ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.trackingMode == mode ?
                            Color.green : Color.clear
                    )
                    .cornerRadius(8)
                }
                .disabled(mode == .arkit3D && !viewModel.isARKitAvailable)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - View Model

class RangeModeViewModel: NSObject, ObservableObject {
    // Camera (for 2D mode)
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    
    // Analyzers
    let swingAnalyzer = SwingAnalyzerIOS()
    private let watchSync = WatchSwingSync.shared
    
    // State
    @Published var isSessionActive = false
    @Published var swingCount = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var currentPhase: CameraSwingPhase = .setup
    @Published var isSwingInProgress = false
    
    // Pose data
    @Published var currentPose: PoseFrame?
    @Published var alignmentStatus: AlignmentStatus = .searching
    @Published var alignmentMessage = "Point camera at your swing position"
    
    // Live metrics
    @Published var liveHipRotation: Double = 0
    @Published var liveShoulderRotation: Double = 0
    @Published var liveSpineAngle: Double = 0
    @Published var liveAcceleration: Double = 0
    @Published var lastTempo: Double?
    @Published var lastSpeed: Double?
    
    // Tracking mode
    @Published var trackingMode: BodyTrackingMode = .vision2D {
        didSet {
            swingAnalyzer.trackingMode = trackingMode
            handleTrackingModeChange()
        }
    }
    @Published var isARKitAvailable = false
    
    // Settings
    @Published var showSkeleton = true
    @Published var selectedClub: String?
    @Published var showSettings = false
    @Published var showClubPicker = false
    @Published var showSessionSummary = false
    
    // Session result
    @Published var completedSession: RangeSession?
    
    // Watch
    @Published var isWatchConnected = false
    
    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var canStartSession: Bool {
        alignmentStatus == .good || isSessionActive
    }
    
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        isARKitAvailable = swingAnalyzer.isARKitAvailable
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind analyzer state
        swingAnalyzer.$currentPhase
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentPhase)
        
        swingAnalyzer.$isSwingInProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSwingInProgress)
        
        swingAnalyzer.$swingCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$swingCount)
        
        swingAnalyzer.$liveHipRotation
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveHipRotation)
        
        swingAnalyzer.$liveShoulderRotation
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveShoulderRotation)
        
        swingAnalyzer.$liveSpineAngle
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveSpineAngle)
        
        // Bind 2D pose detector state
        swingAnalyzer.poseDetector.$currentPose
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pose in
                guard self?.trackingMode == .vision2D else { return }
                self?.currentPose = pose
            }
            .store(in: &cancellables)
        
        swingAnalyzer.poseDetector.$alignmentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard self?.trackingMode == .vision2D else { return }
                self?.alignmentStatus = status
            }
            .store(in: &cancellables)
        
        swingAnalyzer.poseDetector.$alignmentMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard self?.trackingMode == .vision2D else { return }
                self?.alignmentMessage = message
            }
            .store(in: &cancellables)
        
        // Bind 3D AR body tracker state (if available)
        if let arTracker = swingAnalyzer.arBodyTracker {
            arTracker.$currentPose
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pose in
                    guard self?.trackingMode == .arkit3D else { return }
                    self?.currentPose = pose
                    // Debug: Log when 3D pose is received
                    if let pose = pose, pose.allJoints.count > 0 {
                        print("📱 ViewModel received 3D pose with \(pose.allJoints.count) joints")
                    }
                }
                .store(in: &cancellables)
            
            arTracker.$alignmentStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    guard self?.trackingMode == .arkit3D else { return }
                    self?.alignmentStatus = status
                }
                .store(in: &cancellables)
            
            arTracker.$alignmentMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    guard self?.trackingMode == .arkit3D else { return }
                    self?.alignmentMessage = message
                }
                .store(in: &cancellables)
        }
        
        // Bind Watch sync state
        watchSync.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWatchConnected)
        
        watchSync.$liveAcceleration
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveAcceleration)
        
        watchSync.$lastWatchSwing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] swing in
                self?.lastTempo = swing?.tempo
                self?.lastSpeed = swing?.peakSpeed
            }
            .store(in: &cancellables)
        
        // Connect Watch data to analyzer
        watchSync.onMotionSampleReceived = { [weak self] sample in
            self?.swingAnalyzer.receiveWatchMotionSample(sample)
        }
        
        watchSync.onSwingMetricsReceived = { [weak self] metrics in
            self?.swingAnalyzer.receiveWatchSwingMetrics(metrics)
        }
    }
    
    private func handleTrackingModeChange() {
        // Reset current pose when switching modes
        currentPose = nil
        alignmentStatus = .searching
        
        if trackingMode == .arkit3D {
            // Stop 2D camera when switching to 3D
            captureSession.stopRunning()
            alignmentMessage = "Point camera at person for 3D tracking"
        } else {
            // Restart 2D camera when switching back
            if !captureSession.isRunning {
                startCameraSession()
            }
            alignmentMessage = "Point camera at your swing position"
        }
    }
    
    // MARK: - Camera Setup
    
    @Published var cameraError: String?
    private var isConfigured = false
    
    func setupCamera() {
        // Avoid configuring twice
        guard !isConfigured else {
            // If already configured and not running, start it
            if !captureSession.isRunning {
                startCameraSession()
            }
            return
        }
        
        // Check authorization status first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.cameraError = "Camera access is required for swing analysis"
                        self?.alignmentMessage = "Camera access denied"
                    }
                }
            }
        case .denied, .restricted:
            cameraError = "Camera access is required. Please enable it in Settings."
            alignmentMessage = "Camera access denied"
        @unknown default:
            break
        }
    }
    
    private func configureSession() {
        // Make sure we're not already running
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        captureSession.beginConfiguration()
        
        // Remove existing inputs/outputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        // Configure for high frame rate if available
        captureSession.sessionPreset = .high
        
        // Add camera input - use rear camera (where LiDAR is for AR body tracking)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("⚠️ Could not find rear camera")
            captureSession.commitConfiguration()
            cameraError = "Could not access camera"
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                print("⚠️ Could not add camera input to session")
                captureSession.commitConfiguration()
                cameraError = "Could not configure camera"
                return
            }
        } catch {
            print("⚠️ Could not create camera input: \(error)")
            captureSession.commitConfiguration()
            cameraError = "Could not access camera: \(error.localizedDescription)"
            return
        }
        
        // Configure camera - reset zoom to 1x and set frame rate
        do {
            try camera.lockForConfiguration()
            
            // Reset zoom to 1x (wide angle, no crop)
            camera.videoZoomFactor = 1.0
            
            // Find best format: prioritize good FOV, then frame rate
            // For swing analysis we want at least 30fps (60fps preferred for fast movements)
            let currentFOV = camera.activeFormat.videoFieldOfView
            
            // Sort formats by FOV (descending) then max frame rate (descending)
            let sortedFormats = camera.formats.sorted { a, b in
                if abs(a.videoFieldOfView - b.videoFieldOfView) > 5 {
                    return a.videoFieldOfView > b.videoFieldOfView
                }
                let aMaxFPS = a.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                let bMaxFPS = b.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                return aMaxFPS > bMaxFPS
            }
            
            // Find format with similar FOV and good frame rate
            if let bestFormat = sortedFormats.first(where: { format in
                let hasSimilarFOV = format.videoFieldOfView >= currentFOV - 5
                let maxFPS = format.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.max() ?? 0
                return hasSimilarFOV && maxFPS >= 30
            }) {
                camera.activeFormat = bestFormat
                
                // Set to 30fps for smoother skeleton overlay (reduces CPU load)
                // The camera captures at 30fps, matching the pose detector rate
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                print("📹 Camera configured: \(bestFormat.videoFieldOfView)° FOV @ 30fps")
            }
            
            camera.unlockForConfiguration()
        } catch {
            print("⚠️ Could not configure camera: \(error)")
            // Continue anyway - this is not critical
        }
        
        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue", qos: .userInteractive))
        output.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        } else {
            print("⚠️ Could not add video output to session")
            captureSession.commitConfiguration()
            cameraError = "Could not configure camera output"
            return
        }
        
        captureSession.commitConfiguration()
        isConfigured = true
        
        // Start running on background thread
        startCameraSession()
    }
    
    private func startCameraSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }
    
    // MARK: - Session Control
    
    func toggleSession() {
        if isSessionActive {
            endSession()
        } else {
            startSession()
        }
    }
    
    private func startSession() {
        isSessionActive = true
        sessionDuration = 0
        
        // Start analyzer
        swingAnalyzer.startSession()
        swingAnalyzer.currentSession?.selectedClub = selectedClub
        
        // Start Watch sync
        if isWatchConnected {
            watchSync.startRangeSession()
        }
        
        // Start timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sessionDuration += 1
        }
        
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func endSession() {
        isSessionActive = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // End analyzer session
        if let session = swingAnalyzer.endSession() {
            completedSession = session
            showSessionSummary = true
        }
        
        // End Watch sync
        if isWatchConnected {
            watchSync.endRangeSession()
        }
        
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func startPosePreview() {
        swingAnalyzer.startPreview()
    }
    
    func cleanup() {
        if isSessionActive {
            endSession()
        }
        swingAnalyzer.stopDetecting()
        captureSession.stopRunning()
    }
}

// MARK: - AR Body Preview View (for 3D LiDAR mode)

@available(iOS 14.0, *)
struct ARBodyPreviewView: UIViewRepresentable {
    let tracker: ARBodyTracker?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(tracker: tracker)
    }
    
    func makeUIView(context: Context) -> ARView {
        guard let tracker = tracker else {
            // Return empty ARView if tracker not available
            print("⚠️ ARBodyPreviewView: No tracker provided, showing black screen")
            let emptyView = ARView(frame: .zero)
            emptyView.environment.background = .color(.black)
            return emptyView
        }
        
        print("🎥 ARBodyPreviewView: Creating ARView...")
        let arView = tracker.createARView(frame: .zero)
        print("🎥 ARBodyPreviewView: ARView created, scheduling startDetecting...")
        
        // Start detecting after the view is created
        // Use a small delay to ensure the view is fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !tracker.isDetecting {
                print("🎥 ARBodyPreviewView: Calling startDetecting()...")
                tracker.startDetecting()
            } else {
                print("🎥 ARBodyPreviewView: Tracker already detecting")
            }
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Ensure tracking is started if view exists but tracking isn't running
        if let tracker = tracker, !tracker.isDetecting {
            tracker.startDetecting()
        }
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        // Stop tracking when view is removed
        coordinator.tracker?.stopDetecting()
        print("🎥 3D AR body tracking stopped on view removal")
    }
    
    class Coordinator {
        let tracker: ARBodyTracker?
        
        init(tracker: ARBodyTracker?) {
            self.tracker = tracker
        }
    }
}

// Wrapper for iOS 13 compatibility
struct ARBodyPreviewViewWrapper: View {
    let tracker: ARBodyTracker?
    
    var body: some View {
        if #available(iOS 14.0, *) {
            ARBodyPreviewView(tracker: tracker)
        } else {
            Color.black
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.largeTitle)
                        Text("3D body tracking requires iOS 14+")
                    }
                    .foregroundColor(.white)
                )
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension RangeModeViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        swingAnalyzer.processFrame(sampleBuffer)
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateLayout()
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var orientationObserver: NSObjectProtocol?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
    
    private func setupPreviewLayer() {
        // Remove existing layer if any
        previewLayer?.removeFromSuperlayer()
        
        guard let session = session else { return }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer
        
        // Configure initial orientation
        configureOrientation()
        
        // Observe orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureOrientation()
        }
    }
    
    func updateLayout() {
        previewLayer?.frame = bounds
        configureOrientation()
    }
    
    private func configureOrientation() {
        guard let connection = previewLayer?.connection else { return }
        
        // Get current device orientation
        let deviceOrientation = UIDevice.current.orientation
        
        if #available(iOS 17.0, *) {
            // iOS 17+ uses rotation angles for rear camera
            // Angles are clockwise from landscape-right (home button left)
            let angle: CGFloat
            switch deviceOrientation {
            case .portrait:
                angle = 90
            case .portraitUpsideDown:
                angle = 270
            case .landscapeLeft:
                // Device rotated left (home button on right) - video needs 0° rotation
                angle = 0
            case .landscapeRight:
                // Device rotated right (home button on left) - video needs 180° rotation
                angle = 180
            default:
                // Use portrait as default for face up/down/unknown
                angle = 90
            }
            
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else {
            // iOS 16 and earlier use video orientation
            if connection.isVideoOrientationSupported {
                let orientation: AVCaptureVideoOrientation
                switch deviceOrientation {
                case .portrait:
                    orientation = .portrait
                case .portraitUpsideDown:
                    orientation = .portraitUpsideDown
                case .landscapeLeft:
                    orientation = .landscapeRight
                case .landscapeRight:
                    orientation = .landscapeLeft
                default:
                    orientation = .portrait
                }
                connection.videoOrientation = orientation
            }
        }
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Skeleton Overlay View

struct SkeletonOverlayView: View {
    let pose: PoseFrame
    var is3DMode: Bool = false
    
    // Colors based on tracking mode
    private var boneColor: Color { is3DMode ? .cyan : .green }
    private var jointColor: Color { is3DMode ? .cyan : .green }
    private var glowColor: Color { is3DMode ? .cyan.opacity(0.3) : .green.opacity(0.3) }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw bones with smooth lines
                for connection in pose.boneConnections {
                    let start = convertPoint(connection.0, in: size, flip: !is3DMode)
                    let end = convertPoint(connection.1, in: size, flip: !is3DMode)
                    
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    
                    // Draw bone shadow for depth
                    context.stroke(path, with: .color(.black.opacity(0.4)), lineWidth: is3DMode ? 6 : 5)
                    // Draw bone
                    context.stroke(path, with: .color(boneColor), lineWidth: is3DMode ? 4 : 3)
                }
                
                // Draw joints
                for joint in pose.allJoints {
                    let point = convertPoint(joint.point, in: size, flip: !is3DMode)
                    
                    // Joint glow (larger in 3D mode)
                    let glowSize: CGFloat = is3DMode ? 20 : 16
                    let glowRect = CGRect(x: point.x - glowSize/2, y: point.y - glowSize/2, width: glowSize, height: glowSize)
                    context.fill(Ellipse().path(in: glowRect), with: .color(glowColor))
                    
                    // Joint circle
                    let jointSize: CGFloat = is3DMode ? 14 : 12
                    let jointRect = CGRect(x: point.x - jointSize/2, y: point.y - jointSize/2, width: jointSize, height: jointSize)
                    context.fill(Ellipse().path(in: jointRect), with: .color(jointColor))
                    
                    // In 3D mode, add white center dot for depth perception
                    if is3DMode {
                        let centerRect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                        context.fill(Ellipse().path(in: centerRect), with: .color(.white))
                    }
                }
            }
        }
        // Note: One-Euro Filter handles smoothing mathematically, no SwiftUI animation needed
        // This prevents double-smoothing artifacts
    }
    
    private func convertPoint(_ point: CGPoint, in size: CGSize, flip: Bool) -> CGPoint {
        // Vision coordinates are normalized (0-1), convert to view coordinates
        // For Vision (2D): origin is bottom-left, SwiftUI is top-left, so we flip Y
        // For ARKit (3D): coordinates are already projected to screen space
        return CGPoint(
            x: point.x * size.width,
            y: flip ? (1 - point.y) * size.height : point.y * size.height
        )
    }
}

// MARK: - Range Club Picker Sheet

struct RangeClubPickerSheet: View {
    @Binding var selectedClub: String?
    @Environment(\.dismiss) private var dismiss
    
    private let clubs = [
        ("Woods", ["Driver", "3W", "5W", "7W"]),
        ("Hybrids", ["3H", "4H", "5H"]),
        ("Irons", ["3i", "4i", "5i", "6i", "7i", "8i", "9i"]),
        ("Wedges", ["PW", "GW", "SW", "LW"]),
        ("Putter", ["Putter"])
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(clubs, id: \.0) { category, clubList in
                    Section(category) {
                        ForEach(clubList, id: \.self) { club in
                            Button {
                                selectedClub = club
                                dismiss()
                            } label: {
                                HStack {
                                    Text(club)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedClub == club {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
                        selectedClub = nil
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Range Mode Settings Sheet

struct RangeModeSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rangeShowSkeleton") private var showSkeleton = true
    @AppStorage("rangeAutoDetectSwing") private var autoDetectSwing = true
    @AppStorage("rangeHapticFeedback") private var hapticFeedback = true
    @AppStorage("rangeRecordVideo") private var recordVideo = false
    @AppStorage("rangeTrackingMode") private var trackingModeRaw = BodyTrackingMode.vision2D.rawValue
    
    private var isARKitAvailable: Bool {
        if #available(iOS 14.0, *) {
            return ARBodyTracker.isAvailable()
        }
        return false
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Tracking Mode Section
                Section {
                    ForEach(BodyTrackingMode.allCases, id: \.self) { mode in
                        Button {
                            trackingModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Image(systemName: mode.iconName)
                                    .foregroundColor(mode == .arkit3D ? .cyan : .green)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.rawValue)
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if trackingModeRaw == mode.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .disabled(mode == .arkit3D && !isARKitAvailable)
                        .opacity(mode == .arkit3D && !isARKitAvailable ? 0.5 : 1)
                    }
                } header: {
                    Text("Tracking Mode")
                } footer: {
                    if !isARKitAvailable {
                        Text("3D tracking requires iPhone 12 Pro or later with LiDAR sensor")
                    }
                }
                
                Section("Display") {
                    Toggle("Show Skeleton Overlay", isOn: $showSkeleton)
                }
                
                Section("Detection") {
                    Toggle("Auto-Detect Swings", isOn: $autoDetectSwing)
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }
                
                Section("Recording") {
                    Toggle("Record Video Clips", isOn: $recordVideo)
                    if recordVideo {
                        Text("Videos will be saved to your photo library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Apple Watch") {
                    HStack {
                        Image(systemName: "applewatch")
                        Text("Connect Watch for motion data fusion")
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                }
            }
            .navigationTitle("Range Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RangeModeView()
}
