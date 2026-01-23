import SwiftUI
import AVKit

/// View for replaying recorded swings with skeleton overlay and slow-motion
struct SwingReplayView: View {
    let swing: CombinedSwingCapture
    
    @StateObject private var viewModel: SwingReplayViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(swing: CombinedSwingCapture) {
        self.swing = swing
        _viewModel = StateObject(wrappedValue: SwingReplayViewModel(swing: swing))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Video player or pose visualization
                if let videoURL = swing.videoURL {
                    VideoPlayerView(url: videoURL, viewModel: viewModel)
                        .overlay(
                            SkeletonReplayOverlay(viewModel: viewModel)
                        )
                } else if let poses = swing.cameraCapture?.poseFrames, !poses.isEmpty {
                    // No video, show skeleton animation only
                    PoseAnimationView(viewModel: viewModel)
                } else {
                    ContentUnavailableView(
                        "No Recording",
                        systemImage: "video.slash",
                        description: Text("This swing doesn't have video data")
                    )
                }
                
                // Playback controls overlay
                VStack {
                    Spacer()
                    playbackControls
                }
            }
            .navigationTitle("Swing Replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { viewModel.toggleSkeleton() }) {
                            Label(
                                viewModel.showSkeleton ? "Hide Skeleton" : "Show Skeleton",
                                systemImage: "figure.stand"
                            )
                        }
                        
                        Button(action: { viewModel.togglePhaseLabels() }) {
                            Label(
                                viewModel.showPhaseLabels ? "Hide Phases" : "Show Phases",
                                systemImage: "text.bubble"
                            )
                        }
                        
                        Divider()
                        
                        Button(action: { shareSwing() }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        VStack(spacing: 16) {
            // Phase indicator
            if viewModel.showPhaseLabels, let phase = viewModel.currentPhase {
                Text(phase.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            
            // Timeline scrubber
            VStack(spacing: 8) {
                // Progress bar with phase markers
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geo.size.width * viewModel.progress, height: 8)
                        
                        // Phase markers
                        ForEach(viewModel.phasePositions, id: \.phase) { marker in
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2, height: 16)
                                .position(x: geo.size.width * marker.position, y: 4)
                        }
                    }
                }
                .frame(height: 16)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            viewModel.scrub(to: value.location.x / UIScreen.main.bounds.width)
                        }
                )
                
                // Time display
                HStack {
                    Text(viewModel.currentTimeString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text(viewModel.totalTimeString)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)
            
            // Control buttons
            HStack(spacing: 32) {
                // Frame back
                Button(action: { viewModel.previousFrame() }) {
                    Image(systemName: "backward.frame.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                // Slow motion speed
                Button(action: { viewModel.cycleSpeed() }) {
                    Text(viewModel.speedLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 50)
                }
                
                // Play/Pause
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                }
                
                // Loop toggle
                Button(action: { viewModel.toggleLoop() }) {
                    Image(systemName: "repeat")
                        .font(.title2)
                        .foregroundStyle(viewModel.isLooping ? .green : .white.opacity(0.5))
                }
                
                // Frame forward
                Button(action: { viewModel.nextFrame() }) {
                    Image(systemName: "forward.frame.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 8)
            
            // Metrics bar
            if let metrics = swing.combinedMetrics {
                metricsBar(metrics: metrics)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func metricsBar(metrics: CombinedSwingMetrics) -> some View {
        HStack(spacing: 24) {
            if let tempo = metrics.tempoRatio {
                metricItem(label: "Tempo", value: String(format: "%.1f:1", tempo))
            }
            
            if let speed = metrics.estimatedClubSpeed {
                metricItem(label: "Speed", value: String(format: "%.0f mph", speed))
            }
            
            if let hipTurn = metrics.hipTurnDegrees {
                metricItem(label: "Hip Turn", value: String(format: "%.0f°", hipTurn))
            }
            
            if let shoulderTurn = metrics.shoulderTurnDegrees {
                metricItem(label: "Shoulder", value: String(format: "%.0f°", shoulderTurn))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    private func shareSwing() {
        // Share functionality
    }
}

// MARK: - View Model

class SwingReplayViewModel: ObservableObject {
    let swing: CombinedSwingCapture
    
    @Published var isPlaying = false
    @Published var isLooping = true
    @Published var progress: Double = 0
    @Published var currentFrameIndex = 0
    @Published var playbackSpeed: PlaybackSpeed = .normal
    @Published var showSkeleton = true
    @Published var showPhaseLabels = true
    @Published var currentPhase: CameraSwingPhase?
    
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    
    var poses: [PoseFrame] {
        swing.cameraCapture?.poseFrames ?? []
    }
    
    var currentPose: PoseFrame? {
        guard currentFrameIndex < poses.count else { return nil }
        return poses[currentFrameIndex]
    }
    
    var phasePositions: [(phase: CameraSwingPhase, position: Double)] {
        guard let phases = swing.cameraCapture?.phases, !poses.isEmpty else { return [] }
        
        return phases.map { marker in
            let position = Double(marker.frameIndex) / Double(poses.count)
            return (marker.phase, position)
        }
    }
    
    var currentTimeString: String {
        guard let first = poses.first, let current = currentPose else { return "0.00" }
        let elapsed = current.timestamp.timeIntervalSince(first.timestamp)
        return String(format: "%.2f", elapsed)
    }
    
    var totalTimeString: String {
        guard let duration = swing.cameraCapture?.duration else { return "0.00" }
        return String(format: "%.2f", duration)
    }
    
    var speedLabel: String {
        playbackSpeed.label
    }
    
    init(swing: CombinedSwingCapture) {
        self.swing = swing
        updateCurrentPhase()
    }
    
    // MARK: - Playback Control
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        isPlaying = true
        startDisplayLink()
    }
    
    func pause() {
        isPlaying = false
        stopDisplayLink()
    }
    
    func scrub(to position: Double) {
        let clampedPosition = max(0, min(1, position))
        progress = clampedPosition
        currentFrameIndex = Int(clampedPosition * Double(poses.count - 1))
        updateCurrentPhase()
    }
    
    func previousFrame() {
        pause()
        currentFrameIndex = max(0, currentFrameIndex - 1)
        progress = Double(currentFrameIndex) / Double(max(1, poses.count - 1))
        updateCurrentPhase()
    }
    
    func nextFrame() {
        pause()
        currentFrameIndex = min(poses.count - 1, currentFrameIndex + 1)
        progress = Double(currentFrameIndex) / Double(max(1, poses.count - 1))
        updateCurrentPhase()
    }
    
    func cycleSpeed() {
        playbackSpeed = playbackSpeed.next
    }
    
    func toggleLoop() {
        isLooping.toggle()
    }
    
    func toggleSkeleton() {
        showSkeleton.toggle()
    }
    
    func togglePhaseLabels() {
        showPhaseLabels.toggle()
    }
    
    // MARK: - Display Link
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
        lastUpdateTime = CACurrentMediaTime()
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateFrame() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // Calculate frame advancement based on speed
        let effectiveFPS = 30.0 * playbackSpeed.multiplier
        let framesToAdvance = deltaTime * effectiveFPS
        
        let newFrame = Double(currentFrameIndex) + framesToAdvance
        
        if newFrame >= Double(poses.count) {
            if isLooping {
                currentFrameIndex = 0
            } else {
                pause()
                currentFrameIndex = poses.count - 1
            }
        } else {
            currentFrameIndex = Int(newFrame)
        }
        
        progress = Double(currentFrameIndex) / Double(max(1, poses.count - 1))
        updateCurrentPhase()
    }
    
    private func updateCurrentPhase() {
        guard let phases = swing.cameraCapture?.phases else {
            currentPhase = nil
            return
        }
        
        // Find the most recent phase before or at current frame
        let sortedPhases = phases.sorted { $0.frameIndex < $1.frameIndex }
        currentPhase = sortedPhases.last { $0.frameIndex <= currentFrameIndex }?.phase
    }
}

// MARK: - Playback Speed

enum PlaybackSpeed: CaseIterable {
    case quarterSpeed
    case halfSpeed
    case normal
    case doubleSpeed
    
    var multiplier: Double {
        switch self {
        case .quarterSpeed: return 0.25
        case .halfSpeed: return 0.5
        case .normal: return 1.0
        case .doubleSpeed: return 2.0
        }
    }
    
    var label: String {
        switch self {
        case .quarterSpeed: return "0.25x"
        case .halfSpeed: return "0.5x"
        case .normal: return "1x"
        case .doubleSpeed: return "2x"
        }
    }
    
    var next: PlaybackSpeed {
        let allCases = PlaybackSpeed.allCases
        let currentIndex = allCases.firstIndex(of: self)!
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL
    @ObservedObject var viewModel: SwingReplayViewModel
    
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                setupPlayer()
            }
            .onChange(of: viewModel.isPlaying) { _, isPlaying in
                if isPlaying {
                    player?.play()
                } else {
                    player?.pause()
                }
            }
            .onChange(of: viewModel.progress) { _, progress in
                guard let duration = player?.currentItem?.duration.seconds,
                      !duration.isNaN else { return }
                let time = CMTime(seconds: progress * duration, preferredTimescale: 600)
                player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            .onChange(of: viewModel.playbackSpeed) { _, speed in
                player?.rate = Float(speed.multiplier)
            }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: url)
        player?.actionAtItemEnd = viewModel.isLooping ? .none : .pause
        
        // Loop notification
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            if viewModel.isLooping {
                player?.seek(to: .zero)
                player?.play()
            }
        }
    }
}

// MARK: - Skeleton Replay Overlay

struct SkeletonReplayOverlay: View {
    @ObservedObject var viewModel: SwingReplayViewModel
    
    var body: some View {
        GeometryReader { geo in
            if viewModel.showSkeleton, let pose = viewModel.currentPose {
                Canvas { context, size in
                    drawSkeleton(context: context, size: size, pose: pose)
                }
            }
        }
    }
    
    private func drawSkeleton(context: GraphicsContext, size: CGSize, pose: PoseFrame) {
        let jointRadius: CGFloat = 6
        let boneWidth: CGFloat = 3
        
        // Draw bones first (so joints appear on top)
        for bone in pose.boneConnections {
            let startPoint = CGPoint(x: bone.0.x * size.width, y: bone.0.y * size.height)
            let endPoint = CGPoint(x: bone.1.x * size.width, y: bone.1.y * size.height)
            
            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)
            
            context.stroke(path, with: .color(.green.opacity(0.8)), lineWidth: boneWidth)
        }
        
        // Draw joints
        for joint in pose.allJoints {
            let point = CGPoint(x: joint.point.x * size.width, y: joint.point.y * size.height)
            let rect = CGRect(
                x: point.x - jointRadius,
                y: point.y - jointRadius,
                width: jointRadius * 2,
                height: jointRadius * 2
            )
            
            context.fill(Circle().path(in: rect), with: .color(.green))
            context.stroke(Circle().path(in: rect), with: .color(.white), lineWidth: 1.5)
        }
    }
}

// MARK: - Pose Animation View (No Video)

struct PoseAnimationView: View {
    @ObservedObject var viewModel: SwingReplayViewModel
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.black
                
                // Skeleton
                if let pose = viewModel.currentPose {
                    Canvas { context, size in
                        drawAnimatedSkeleton(context: context, size: size, pose: pose)
                    }
                }
                
                // Frame counter
                VStack {
                    HStack {
                        Spacer()
                        Text("Frame \(viewModel.currentFrameIndex + 1)/\(viewModel.poses.count)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func drawAnimatedSkeleton(context: GraphicsContext, size: CGSize, pose: PoseFrame) {
        let jointRadius: CGFloat = 10
        let boneWidth: CGFloat = 5
        
        // Scale and center the skeleton
        let scale: CGFloat = 0.6
        let offsetX = size.width * 0.2
        let offsetY = size.height * 0.1
        
        func transform(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: offsetX + point.x * size.width * scale,
                y: offsetY + point.y * size.height * scale
            )
        }
        
        // Draw bones
        for bone in pose.boneConnections {
            let startPoint = transform(bone.0)
            let endPoint = transform(bone.1)
            
            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)
            
            // Gradient based on position
            context.stroke(path, with: .color(.green), lineWidth: boneWidth)
        }
        
        // Draw joints with glow effect
        for joint in pose.allJoints {
            let point = transform(joint.point)
            
            // Glow
            let glowRect = CGRect(
                x: point.x - jointRadius * 1.5,
                y: point.y - jointRadius * 1.5,
                width: jointRadius * 3,
                height: jointRadius * 3
            )
            context.fill(Circle().path(in: glowRect), with: .color(.green.opacity(0.3)))
            
            // Joint
            let rect = CGRect(
                x: point.x - jointRadius,
                y: point.y - jointRadius,
                width: jointRadius * 2,
                height: jointRadius * 2
            )
            context.fill(Circle().path(in: rect), with: .color(.green))
            context.stroke(Circle().path(in: rect), with: .color(.white), lineWidth: 2)
        }
        
        // Draw angle indicators if available
        if let spineAngle = pose.spineAngle {
            drawAngleIndicator(
                context: context,
                label: "Spine",
                angle: spineAngle,
                position: CGPoint(x: size.width - 80, y: 50)
            )
        }
        
        if let hipRotation = pose.hipRotation {
            drawAngleIndicator(
                context: context,
                label: "Hips",
                angle: hipRotation,
                position: CGPoint(x: size.width - 80, y: 100)
            )
        }
        
        if let shoulderRotation = pose.shoulderRotation {
            drawAngleIndicator(
                context: context,
                label: "Shoulders",
                angle: shoulderRotation,
                position: CGPoint(x: size.width - 80, y: 150)
            )
        }
    }
    
    private func drawAngleIndicator(context: GraphicsContext, label: String, angle: Double, position: CGPoint) {
        let text = Text("\(label): \(Int(angle))°")
            .font(.caption)
            .foregroundColor(.white)
        
        context.draw(text, at: position, anchor: .leading)
    }
}
