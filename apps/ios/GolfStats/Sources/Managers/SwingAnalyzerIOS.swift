import Foundation
import AVFoundation
import Combine
import UIKit

/// Analyzes golf swings using camera pose detection and optional Watch motion data
class SwingAnalyzerIOS: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isAnalyzing = false
    @Published var currentPhase: CameraSwingPhase = .setup
    @Published var isSwingInProgress = false
    @Published var swingCount = 0
    
    // Current swing being captured
    @Published var currentCapture: CombinedSwingCapture?
    
    // Live metrics during swing
    @Published var liveHipRotation: Double = 0
    @Published var liveShoulderRotation: Double = 0
    @Published var liveSpineAngle: Double = 0
    
    // Session data
    @Published var currentSession: RangeSession?
    
    // MARK: - Components
    
    let poseDetector = PoseDetector()
    
    // MARK: - Configuration
    
    var settings = RangeModeSettings()
    
    /// Thresholds for swing detection
    private let swingDetectionConfig = SwingDetectionConfig()
    
    // MARK: - Private State
    
    private var poseBuffer: [PoseFrame] = []
    private let maxBufferSize = 300 // ~10 seconds at 30fps
    
    // Swing detection state
    private var setupPose: PoseFrame?
    private var swingStartTime: Date?
    private var lastPhaseChangeTime: Date?
    private var phaseHistory: [SwingPhaseMarker] = []
    
    // Watch data integration
    private var watchMotionBuffer: [MotionSample] = []
    private var watchSwingMetrics: WatchSwingMetrics?
    
    // Video recording
    private var videoWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoStartTime: CMTime?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onSwingDetected: ((CombinedSwingCapture) -> Void)?
    var onPhaseChanged: ((CameraSwingPhase) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        setupPoseDetector()
    }
    
    private func setupPoseDetector() {
        // Subscribe to pose updates
        poseDetector.$currentPose
            .compactMap { $0 }
            .sink { [weak self] pose in
                self?.processPose(pose)
            }
            .store(in: &cancellables)
        
        poseDetector.onPoseDetected = { [weak self] pose in
            self?.processPose(pose)
        }
    }
    
    // MARK: - Session Management
    
    /// Start a new range session
    func startSession() {
        currentSession = RangeSession()
        swingCount = 0
        poseBuffer.removeAll()
        watchMotionBuffer.removeAll()
        
        poseDetector.startDetecting()
        isAnalyzing = true
        
        print("🏌️ Range session started")
    }
    
    /// End the current range session
    func endSession() -> RangeSession? {
        poseDetector.stopDetecting()
        isAnalyzing = false
        
        var session = currentSession
        session?.endTime = Date()
        
        let finalSession = session
        currentSession = nil
        
        print("🏌️ Range session ended: \(finalSession?.swingCount ?? 0) swings captured")
        return finalSession
    }
    
    /// Process a camera frame
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isAnalyzing else { return }
        poseDetector.processFrame(pixelBuffer)
    }
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isAnalyzing else { return }
        poseDetector.processFrame(sampleBuffer)
    }
    
    // MARK: - Watch Data Integration
    
    /// Receive motion data from Watch
    func receiveWatchMotionSample(_ sample: MotionSample) {
        watchMotionBuffer.append(sample)
        
        // Trim buffer
        if watchMotionBuffer.count > 500 { // 5 seconds at 100Hz
            watchMotionBuffer.removeFirst(100)
        }
    }
    
    /// Receive computed swing metrics from Watch
    func receiveWatchSwingMetrics(_ metrics: WatchSwingMetrics) {
        watchSwingMetrics = metrics
        
        // If we're tracking a swing, associate this data
        if var capture = currentCapture {
            if capture.watchMotionData == nil {
                capture.watchMotionData = WatchMotionCapture(
                    startTime: swingStartTime ?? Date(),
                    endTime: Date(),
                    samples: watchMotionBuffer,
                    metrics: metrics
                )
            } else {
                capture.watchMotionData?.metrics = metrics
            }
            currentCapture = capture
        }
    }
    
    // MARK: - Pose Processing
    
    private func processPose(_ pose: PoseFrame) {
        // Add to buffer
        poseBuffer.append(pose)
        if poseBuffer.count > maxBufferSize {
            poseBuffer.removeFirst()
        }
        
        // Update live metrics
        updateLiveMetrics(pose: pose)
        
        // Detect swing phases
        detectSwingPhase(pose: pose)
    }
    
    private func updateLiveMetrics(pose: PoseFrame) {
        if let hip = pose.hipRotation {
            liveHipRotation = hip
        }
        if let shoulder = pose.shoulderRotation {
            liveShoulderRotation = shoulder
        }
        if let spine = pose.spineAngle {
            liveSpineAngle = spine
        }
    }
    
    // MARK: - Swing Phase Detection
    
    private func detectSwingPhase(pose: PoseFrame) {
        switch currentPhase {
        case .setup:
            detectTakeaway(pose: pose)
            
        case .takeaway:
            detectBackswingStart(pose: pose)
            
        case .backswing:
            detectTopOfSwing(pose: pose)
            
        case .topOfSwing:
            detectDownswingStart(pose: pose)
            
        case .downswing:
            detectImpact(pose: pose)
            
        case .impact:
            detectFollowThrough(pose: pose)
            
        case .followThrough:
            detectFinish(pose: pose)
            
        case .finish:
            // Wait for next swing
            detectReturnToSetup(pose: pose)
        }
    }
    
    private func detectTakeaway(pose: PoseFrame) {
        guard let setup = setupPose ?? poseBuffer.first,
              let currentShoulder = pose.shoulderRotation,
              let setupShoulder = setup.shoulderRotation else {
            // Store setup pose if we don't have one
            if setupPose == nil && pose.confidence > 0.8 {
                setupPose = pose
            }
            return
        }
        
        // Takeaway: shoulder rotation starts (>5 degrees from setup)
        let rotationChange = abs(currentShoulder - setupShoulder)
        if rotationChange > swingDetectionConfig.takeawayThreshold {
            startSwing(pose: pose)
            transitionToPhase(.takeaway, pose: pose)
        }
    }
    
    private func detectBackswingStart(pose: PoseFrame) {
        guard let shoulder = pose.shoulderRotation else { return }
        
        // Backswing: continued rotation past takeaway
        if shoulder > swingDetectionConfig.backswingStartThreshold {
            transitionToPhase(.backswing, pose: pose)
        }
        
        // Timeout: if no progress, reset
        checkPhaseTimeout(maxDuration: 1.0)
    }
    
    private func detectTopOfSwing(pose: PoseFrame) {
        guard let shoulder = pose.shoulderRotation,
              let hip = pose.hipRotation else { return }
        
        // Top of swing: max rotation reached, shoulder turn > hip turn (X-factor)
        let _ = shoulder - hip // xFactor - used for analysis
        
        // Check if rotation is decreasing (past the top)
        let recentRotations = poseBuffer.suffix(10).compactMap { $0.shoulderRotation }
        if recentRotations.count >= 5 {
            let isDecreasing = recentRotations.last! < recentRotations.dropLast(2).max()!
            
            if isDecreasing && shoulder > swingDetectionConfig.topOfSwingMinRotation {
                transitionToPhase(.topOfSwing, pose: pose)
            }
        }
        
        checkPhaseTimeout(maxDuration: 2.0)
    }
    
    private func detectDownswingStart(pose: PoseFrame) {
        guard pose.shoulderRotation != nil else { return }
        
        // Downswing: rapid decrease in rotation
        let recentRotations = poseBuffer.suffix(5).compactMap { $0.shoulderRotation }
        if recentRotations.count >= 3 {
            let rotationVelocity = (recentRotations.first! - recentRotations.last!) /
                                   Double(recentRotations.count) * 30 // degrees per second
            
            if rotationVelocity > swingDetectionConfig.downswingVelocityThreshold {
                transitionToPhase(.downswing, pose: pose)
            }
        }
        
        checkPhaseTimeout(maxDuration: 0.5)
    }
    
    private func detectImpact(pose: PoseFrame) {
        guard let hip = pose.hipRotation else { return }
        
        // Impact: hips nearly square, shoulders catching up
        // In a good swing, hips lead through impact
        
        // Check if we have Watch data for precise impact timing
        if let watchMetrics = watchSwingMetrics, watchMetrics.impactTimestamp != nil {
            transitionToPhase(.impact, pose: pose)
            return
        }
        
        // Otherwise use visual cues: hips nearly square (rotation < 15 degrees)
        if hip < swingDetectionConfig.impactHipRotationThreshold {
            transitionToPhase(.impact, pose: pose)
        }
        
        checkPhaseTimeout(maxDuration: 0.5)
    }
    
    private func detectFollowThrough(pose: PoseFrame) {
        guard let shoulder = pose.shoulderRotation else { return }
        
        // Follow through: continued rotation past impact
        // Shoulders now rotating toward target
        if shoulder < swingDetectionConfig.followThroughThreshold {
            transitionToPhase(.followThrough, pose: pose)
        }
        
        checkPhaseTimeout(maxDuration: 0.3)
    }
    
    private func detectFinish(pose: PoseFrame) {
        guard let startTime = swingStartTime else { return }
        
        // Finish: motion settling, roughly 1-1.5 seconds after start
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > swingDetectionConfig.minSwingDuration {
            // Check for stable finish position
            let recentPoses = poseBuffer.suffix(10)
            let rotationVariance = calculateVariance(recentPoses.compactMap { $0.shoulderRotation })
            
            if rotationVariance < swingDetectionConfig.finishStabilityThreshold || elapsed > 2.0 {
                transitionToPhase(.finish, pose: pose)
                completeSwing()
            }
        }
    }
    
    private func detectReturnToSetup(pose: PoseFrame) {
        // Wait for person to settle back to setup position
        if pose.confidence > 0.8 {
            let recentPoses = poseBuffer.suffix(15) // ~0.5 seconds
            let rotationVariance = calculateVariance(recentPoses.compactMap { $0.shoulderRotation })
            
            if rotationVariance < swingDetectionConfig.setupStabilityThreshold {
                // Ready for next swing
                setupPose = pose
                transitionToPhase(.setup, pose: pose)
            }
        }
    }
    
    // MARK: - Swing Lifecycle
    
    private func startSwing(pose: PoseFrame) {
        isSwingInProgress = true
        swingStartTime = pose.timestamp
        phaseHistory.removeAll()
        
        // Initialize capture
        var capture = CombinedSwingCapture(timestamp: pose.timestamp)
        capture.cameraCapture = CameraSwingCapture(
            startTime: pose.timestamp,
            endTime: pose.timestamp,
            poseFrames: [],
            phases: []
        )
        currentCapture = capture
        
        // Clear watch buffer for this swing
        watchMotionBuffer.removeAll()
        watchSwingMetrics = nil
        
        print("🏌️ Swing started")
    }
    
    private func completeSwing() {
        guard var capture = currentCapture else { return }
        
        let endTime = Date()
        
        // Finalize camera capture
        let swingPoses = extractSwingPoses()
        capture.cameraCapture?.endTime = endTime
        capture.cameraCapture?.poseFrames = swingPoses
        capture.cameraCapture?.phases = phaseHistory
        capture.cameraCapture?.bodyMetrics = calculateBodyMetrics(poses: swingPoses)
        
        // Finalize watch capture if available
        if !watchMotionBuffer.isEmpty {
            capture.watchMotionData = WatchMotionCapture(
                startTime: swingStartTime ?? endTime,
                endTime: endTime,
                samples: watchMotionBuffer,
                metrics: watchSwingMetrics
            )
        }
        
        // Calculate combined metrics
        capture.combinedMetrics = calculateCombinedMetrics(capture: capture)
        
        // Add to session
        currentSession?.swings.append(capture)
        swingCount += 1
        
        // Reset state
        isSwingInProgress = false
        swingStartTime = nil
        currentCapture = nil
        
        // Notify
        onSwingDetected?(capture)
        
        print("🏌️ Swing #\(swingCount) completed: " +
              "Tempo \(String(format: "%.1f", capture.combinedMetrics?.tempoRatio ?? 0)):1")
        
        // Haptic feedback if enabled
        if settings.hapticFeedback {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func cancelSwing(reason: String) {
        print("❌ Swing cancelled: \(reason)")
        isSwingInProgress = false
        swingStartTime = nil
        currentCapture = nil
        phaseHistory.removeAll()
        transitionToPhase(.setup, pose: nil)
    }
    
    // MARK: - Phase Transition
    
    private func transitionToPhase(_ newPhase: CameraSwingPhase, pose: PoseFrame?) {
        guard newPhase != currentPhase else { return }
        
        let oldPhase = currentPhase
        currentPhase = newPhase
        lastPhaseChangeTime = Date()
        
        // Record phase marker
        if let pose = pose {
            let marker = SwingPhaseMarker(
                phase: newPhase,
                timestamp: pose.timestamp,
                frameIndex: pose.frameIndex,
                confidence: pose.confidence
            )
            phaseHistory.append(marker)
        }
        
        onPhaseChanged?(newPhase)
        print("📊 Phase: \(oldPhase.rawValue) → \(newPhase.rawValue)")
    }
    
    private func checkPhaseTimeout(maxDuration: TimeInterval) {
        guard let lastChange = lastPhaseChangeTime else { return }
        
        if Date().timeIntervalSince(lastChange) > maxDuration {
            cancelSwing(reason: "Phase timeout")
        }
    }
    
    // MARK: - Metrics Calculation
    
    private func extractSwingPoses() -> [PoseFrame] {
        guard let startTime = swingStartTime else { return [] }
        
        return poseBuffer.filter { pose in
            pose.timestamp >= startTime && pose.timestamp <= Date()
        }
    }
    
    private func calculateBodyMetrics(poses: [PoseFrame]) -> BodySwingMetrics {
        var metrics = BodySwingMetrics()
        
        guard !poses.isEmpty else { return metrics }
        
        // Setup metrics (first few frames)
        let setupFrames = Array(poses.prefix(5))
        metrics.setupSpineAngle = setupFrames.compactMap { $0.spineAngle }.average
        
        // Find backswing peak (max shoulder turn)
        let shoulderTurns = poses.compactMap { $0.shoulderRotation }
        let hipTurns = poses.compactMap { $0.hipRotation }
        
        metrics.maxShoulderTurn = shoulderTurns.max()
        metrics.maxHipTurn = hipTurns.max()
        
        if let maxShoulder = metrics.maxShoulderTurn,
           let maxHip = metrics.maxHipTurn {
            metrics.shoulderHipSeparation = maxShoulder - maxHip
        }
        
        // Spine angle consistency
        let spineAngles = poses.compactMap { $0.spineAngle }
        if let setup = metrics.setupSpineAngle, !spineAngles.isEmpty {
            let maxDeviation = spineAngles.map { abs($0 - setup) }.max() ?? 0
            metrics.spineAngleMaintained = maxDeviation < 10 // Less than 10 degree deviation
        }
        
        // Head movement (track nose position)
        let nosePositions = poses.compactMap { $0.nose }
        if nosePositions.count > 2 {
            let xPositions = nosePositions.map { $0.x }
            let yPositions = nosePositions.map { $0.y }
            let xRange = (xPositions.max() ?? 0) - (xPositions.min() ?? 0)
            let yRange = (yPositions.max() ?? 0) - (yPositions.min() ?? 0)
            metrics.headMovement = sqrt(xRange * xRange + yRange * yRange)
        }
        
        return metrics
    }
    
    private func calculateCombinedMetrics(capture: CombinedSwingCapture) -> CombinedSwingMetrics {
        var metrics = CombinedSwingMetrics()
        
        metrics.hasCameraData = capture.cameraCapture != nil
        metrics.hasWatchData = capture.watchMotionData != nil
        
        // Tempo: prefer Watch data (more accurate timing)
        if let watchMetrics = capture.watchMotionData?.metrics {
            metrics.tempoRatio = watchMetrics.tempoRatio
            metrics.backswingDuration = watchMetrics.backswingDuration
            metrics.downswingDuration = watchMetrics.downswingDuration
            metrics.estimatedClubSpeed = watchMetrics.estimatedClubSpeed
            metrics.impactQuality = watchMetrics.impactQuality
            metrics.impactTimestamp = watchMetrics.impactTimestamp
        } else if let cameraCapture = capture.cameraCapture {
            // Fall back to camera-based timing
            let phases = cameraCapture.phases
            if let backswingStart = phases.first(where: { $0.phase == .backswing })?.timestamp,
               let topOfSwing = phases.first(where: { $0.phase == .topOfSwing })?.timestamp,
               let impact = phases.first(where: { $0.phase == .impact })?.timestamp {
                
                metrics.backswingDuration = topOfSwing.timeIntervalSince(backswingStart)
                metrics.downswingDuration = impact.timeIntervalSince(topOfSwing)
                
                if let bs = metrics.backswingDuration, let ds = metrics.downswingDuration, ds > 0 {
                    metrics.tempoRatio = bs / ds
                }
            }
        }
        
        // Body metrics: from camera
        if let bodyMetrics = capture.cameraCapture?.bodyMetrics {
            metrics.hipTurnDegrees = bodyMetrics.maxHipTurn
            metrics.shoulderTurnDegrees = bodyMetrics.maxShoulderTurn
            metrics.xFactor = bodyMetrics.shoulderHipSeparation
            metrics.spineAngleMaintained = bodyMetrics.spineAngleMaintained
            
            // Convert normalized head movement to approximate inches
            // Assuming person is ~6 feet tall and fills ~70% of frame height
            if let headMove = bodyMetrics.headMovement {
                metrics.headMovementInches = headMove * 72 * 0.7 // rough estimate
            }
        }
        
        // Calculate scores
        metrics.tempoScore = calculateTempoScore(ratio: metrics.tempoRatio)
        metrics.overallScore = calculateOverallScore(metrics: metrics)
        
        // Detect primary fault
        metrics.primaryFault = detectPrimaryFault(metrics: metrics, bodyMetrics: capture.cameraCapture?.bodyMetrics)
        metrics.suggestions = generateSuggestions(metrics: metrics)
        
        return metrics
    }
    
    private func calculateTempoScore(ratio: Double?) -> Double? {
        guard let ratio = ratio else { return nil }
        
        // Target tempo is configurable (default 3.0)
        let target = settings.targetTempo
        let deviation = abs(ratio - target)
        
        // Score decreases as deviation increases
        // Deviation of 0 = 100, deviation of 1 = 50, deviation of 2 = 0
        return max(0, 100 - (deviation * 50))
    }
    
    private func calculateOverallScore(metrics: CombinedSwingMetrics) -> Double? {
        var scores: [Double] = []
        
        if let tempo = metrics.tempoScore { scores.append(tempo) }
        if let impact = metrics.impactQuality { scores.append(impact * 100) }
        if metrics.spineAngleMaintained == true { scores.append(90) }
        if let xFactor = metrics.xFactor, xFactor > 30 { scores.append(80) }
        
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func detectPrimaryFault(metrics: CombinedSwingMetrics, bodyMetrics: BodySwingMetrics?) -> SwingFault? {
        // Check for common faults based on metrics
        
        if metrics.spineAngleMaintained == false {
            return .lossOfPosture
        }
        
        if let headMove = metrics.headMovementInches, headMove > 3 {
            return .swayOff
        }
        
        if let xFactor = metrics.xFactor, xFactor < 20 {
            return .flatShoulderPlane
        }
        
        if let tempo = metrics.tempoRatio, tempo < 2.0 {
            return .casting // Quick transition often means early release
        }
        
        // Check swing path from Watch data if available
        // (This would need more sophisticated analysis)
        
        return nil
    }
    
    private func generateSuggestions(metrics: CombinedSwingMetrics) -> [String] {
        var suggestions: [String] = []
        
        if let fault = metrics.primaryFault {
            suggestions.append(fault.tip)
        }
        
        if let tempo = metrics.tempoRatio {
            if tempo < 2.5 {
                suggestions.append("Slow down your transition at the top")
            } else if tempo > 3.5 {
                suggestions.append("Accelerate more smoothly into the ball")
            }
        }
        
        if let xFactor = metrics.xFactor, xFactor < 25 {
            suggestions.append("Create more separation between shoulders and hips")
        }
        
        return Array(suggestions.prefix(3)) // Max 3 suggestions
    }
    
    // MARK: - Utility
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Configuration

struct SwingDetectionConfig {
    // Takeaway: degrees of rotation to start
    var takeawayThreshold: Double = 5
    
    // Backswing start: shoulder rotation threshold
    var backswingStartThreshold: Double = 15
    
    // Top of swing: minimum rotation to consider "at top"
    var topOfSwingMinRotation: Double = 60
    
    // Downswing: rotation velocity (degrees/second)
    var downswingVelocityThreshold: Double = 100
    
    // Impact: hip rotation threshold (nearly square)
    var impactHipRotationThreshold: Double = 15
    
    // Follow through: shoulder rotation past impact
    var followThroughThreshold: Double = 10
    
    // Minimum swing duration (seconds)
    var minSwingDuration: Double = 0.8
    
    // Finish stability threshold (variance)
    var finishStabilityThreshold: Double = 5
    
    // Setup stability threshold
    var setupStabilityThreshold: Double = 3
}

// MARK: - Array Extension

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
