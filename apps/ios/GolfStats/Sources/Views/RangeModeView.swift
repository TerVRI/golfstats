import SwiftUI
import AVFoundation
import Combine

/// Main Range Mode view with camera preview and swing analysis
struct RangeModeView: View {
    @StateObject private var viewModel = RangeModeViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            // Skeleton overlay
            if viewModel.showSkeleton, let pose = viewModel.currentPose {
                SkeletonOverlayView(pose: pose)
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
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .sheet(isPresented: $viewModel.showSessionSummary) {
            if let session = viewModel.completedSession {
                RangeSessionSummaryView(session: session)
            }
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
            if !viewModel.isWatchConnected {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch.slash")
                        .foregroundColor(.orange)
                    Text("Apple Watch not connected")
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
        .padding(.bottom, 40)
    }
}

// MARK: - View Model

class RangeModeViewModel: NSObject, ObservableObject {
    // Camera
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    
    // Analyzers
    private let swingAnalyzer = SwingAnalyzerIOS()
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
        
        // Bind pose detector state
        swingAnalyzer.poseDetector.$currentPose
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentPose)
        
        swingAnalyzer.poseDetector.$alignmentStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$alignmentStatus)
        
        swingAnalyzer.poseDetector.$alignmentMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$alignmentMessage)
        
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
        
        // Configure for 60fps if available
        do {
            try camera.lockForConfiguration()
            if let format = camera.formats.first(where: { format in
                let ranges = format.videoSupportedFrameRateRanges
                return ranges.contains { $0.maxFrameRate >= 60 }
            }) {
                camera.activeFormat = format
                camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            }
            camera.unlockForConfiguration()
        } catch {
            print("⚠️ Could not configure camera frame rate: \(error)")
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
    
    func cleanup() {
        if isSessionActive {
            endSession()
        }
        captureSession.stopRunning()
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
            // iOS 17+ uses rotation angles
            let angle: CGFloat
            switch deviceOrientation {
            case .portrait:
                angle = 90
            case .portraitUpsideDown:
                angle = 270
            case .landscapeLeft:
                angle = 180
            case .landscapeRight:
                angle = 0
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
                    orientation = .landscapeRight // Note: inverted
                case .landscapeRight:
                    orientation = .landscapeLeft // Note: inverted
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
    
    var body: some View {
        GeometryReader { geometry in
            // Draw bones
            ForEach(Array(pose.boneConnections.enumerated()), id: \.offset) { _, connection in
                Path { path in
                    let start = convertPoint(connection.0, in: geometry.size)
                    let end = convertPoint(connection.1, in: geometry.size)
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(Color.green, lineWidth: 3)
            }
            
            // Draw joints
            ForEach(Array(pose.allJoints.enumerated()), id: \.offset) { _, joint in
                let point = convertPoint(joint.point, in: geometry.size)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .position(point)
            }
        }
    }
    
    private func convertPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        // Vision coordinates are normalized (0-1), convert to view coordinates
        // Vision origin is bottom-left, SwiftUI is top-left, so we flip Y
        return CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }
}

// MARK: - Preview

#Preview {
    RangeModeView()
}
