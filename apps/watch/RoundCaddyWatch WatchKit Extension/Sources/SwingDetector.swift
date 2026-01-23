import Foundation
import CoreMotion
import Combine

/// Advanced swing detection engine with phase tracking, tempo analysis, and impact detection
class SwingDetector: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentPhase: SwingPhase = .idle
    @Published var isSwingInProgress = false
    @Published var lastAnalytics: SwingAnalytics?
    @Published var sessionStats = SwingSessionStats()
    
    // Real-time metrics during swing
    @Published var currentHandSpeed: Double = 0
    @Published var currentRotationRate: Double = 0
    
    // MARK: - Configuration
    
    var preferences = SwingPreferences()
    
    // Phase detection thresholds (adjusted by sensitivity)
    private var backswingStartThreshold: Double { 1.5 * preferences.sensitivity }
    private var topOfSwingThreshold: Double { 0.8 * preferences.sensitivity }
    private var downswingThreshold: Double { 4.0 * preferences.sensitivity }
    private var impactThreshold: Double { 8.0 * preferences.sensitivity }
    private var impactDecelerationThreshold: Double { 6.0 * preferences.sensitivity }
    
    // Timing constraints
    private let maxBackswingDuration: TimeInterval = 2.5
    private let minBackswingDuration: TimeInterval = 0.3
    private let maxDownswingDuration: TimeInterval = 0.8
    private let minDownswingDuration: TimeInterval = 0.1
    
    // MARK: - Private State
    
    // Phase timing
    private var phaseStartTime: Date?
    private var addressStartTime: Date?
    private var backswingStartTime: Date?
    private var topOfSwingTime: Date?
    private var downswingStartTime: Date?
    private var impactTime: Date?
    
    // Motion buffers for analysis
    private var accelerationBuffer: [Double] = []
    private var rotationBuffer: [Double] = []
    private var timestampBuffer: [Date] = []
    private let maxBufferSize = 300 // 3 seconds at 100Hz
    
    // Impact detection
    private var preImpactAcceleration: Double = 0
    private var impactDetected = false
    private var impactDeceleration: Double = 0
    
    // Swing path analysis
    private var rotationXBuffer: [Double] = []
    private var rotationYBuffer: [Double] = []
    private var rotationZBuffer: [Double] = []
    
    // Current swing being built
    private var currentSwingData: SwingAnalytics?
    
    // Callbacks
    var onSwingComplete: ((SwingAnalytics) -> Void)?
    var onPhaseChange: ((SwingPhase) -> Void)?
    
    // MARK: - Public Methods
    
    /// Process incoming motion data
    func processMotion(_ motion: CMDeviceMotion, timestamp: Date = Date()) {
        // Calculate magnitudes
        let accel = motion.userAcceleration
        let totalAccel = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))
        
        let rotation = motion.rotationRate
        let totalRotation = sqrt(pow(rotation.x, 2) + pow(rotation.y, 2) + pow(rotation.z, 2))
        
        // Update real-time displays
        currentHandSpeed = accelerationToHandSpeed(totalAccel)
        currentRotationRate = totalRotation
        
        // Add to buffers
        addToBuffers(
            acceleration: totalAccel,
            rotation: totalRotation,
            rotationX: rotation.x,
            rotationY: rotation.y,
            rotationZ: rotation.z,
            timestamp: timestamp
        )
        
        // Process based on current phase
        processPhase(acceleration: totalAccel, rotation: totalRotation, timestamp: timestamp)
    }
    
    /// Reset detector state
    func reset() {
        currentPhase = .idle
        isSwingInProgress = false
        clearBuffers()
        resetTimers()
        impactDetected = false
        currentSwingData = nil
    }
    
    /// Reset session statistics (for new practice session)
    func resetSession() {
        sessionStats = SwingSessionStats()
        lastAnalytics = nil
        reset()
    }
    
    /// Force complete current swing (for manual confirmation)
    func forceComplete() {
        if isSwingInProgress {
            completeSwing()
        }
    }
    
    // MARK: - Phase Processing
    
    private func processPhase(acceleration: Double, rotation: Double, timestamp: Date) {
        switch currentPhase {
        case .idle:
            detectAddress(acceleration: acceleration, rotation: rotation, timestamp: timestamp)
            
        case .address:
            detectBackswingStart(acceleration: acceleration, rotation: rotation, timestamp: timestamp)
            
        case .backswing:
            detectTopOfSwing(acceleration: acceleration, rotation: rotation, timestamp: timestamp)
            
        case .topOfSwing, .transition:
            detectDownswingStart(acceleration: acceleration, rotation: rotation, timestamp: timestamp)
            
        case .downswing:
            detectImpact(acceleration: acceleration, rotation: rotation, timestamp: timestamp)
            
        case .impact:
            detectFollowThrough(acceleration: acceleration, rotation: rotation, timestamp: timestamp)
            
        case .followThrough:
            detectSwingEnd(acceleration: acceleration, timestamp: timestamp)
            
        case .finished:
            completeSwing()
        }
    }
    
    // MARK: - Phase Detection Methods
    
    private func detectAddress(acceleration: Double, rotation: Double, timestamp: Date) {
        // Detect player settling into address position
        // Low motion, preparing to swing
        if acceleration < 0.5 && rotation < 1.0 {
            // Stable position - could be address
            if addressStartTime == nil {
                addressStartTime = timestamp
            } else if timestamp.timeIntervalSince(addressStartTime!) > 0.5 {
                // Been stable for 0.5s - this is address
                transitionToPhase(.address, timestamp: timestamp)
            }
        } else {
            // Reset if motion detected
            addressStartTime = nil
        }
        
        // Also detect swing starting directly (skip address)
        if acceleration > backswingStartThreshold && rotation > 2.0 {
            transitionToPhase(.backswing, timestamp: timestamp)
        }
    }
    
    private func detectBackswingStart(acceleration: Double, rotation: Double, timestamp: Date) {
        // Backswing starts with controlled rotation and moderate acceleration
        if acceleration > backswingStartThreshold && rotation > 2.0 {
            transitionToPhase(.backswing, timestamp: timestamp)
            backswingStartTime = timestamp
            isSwingInProgress = true
            initializeSwingData(timestamp: timestamp)
        }
        
        // Timeout - reset if no backswing detected
        if let start = phaseStartTime, timestamp.timeIntervalSince(start) > 3.0 {
            transitionToPhase(.idle, timestamp: timestamp)
        }
    }
    
    private func detectTopOfSwing(acceleration: Double, rotation: Double, timestamp: Date) {
        guard let backswingStart = backswingStartTime else { return }
        
        let backswingDuration = timestamp.timeIntervalSince(backswingStart)
        
        // Top of swing: rotation slows/reverses, brief pause
        // Look for deceleration and direction change
        if backswingDuration >= minBackswingDuration {
            // Check for rotation slowdown (approaching top)
            if rotation < topOfSwingThreshold && acceleration < 2.0 {
                topOfSwingTime = timestamp
                transitionToPhase(.topOfSwing, timestamp: timestamp)
                
                // Record backswing duration
                currentSwingData?.backswingDuration = backswingDuration
                currentSwingData?.topOfSwingTime = timestamp
            }
        }
        
        // Timeout - incomplete backswing
        if backswingDuration > maxBackswingDuration {
            cancelSwing(reason: "Backswing too long")
        }
    }
    
    private func detectDownswingStart(acceleration: Double, rotation: Double, timestamp: Date) {
        // Downswing: rapid acceleration increase
        if acceleration > downswingThreshold {
            downswingStartTime = timestamp
            transitionToPhase(.downswing, timestamp: timestamp)
            currentSwingData?.transitionTime = timestamp
        }
        
        // Transition window between top and downswing
        if let top = topOfSwingTime, timestamp.timeIntervalSince(top) > 1.0 {
            // Took too long to start downswing - might not be a real swing
            cancelSwing(reason: "Transition too slow")
        }
    }
    
    private func detectImpact(acceleration: Double, rotation: Double, timestamp: Date) {
        guard let downswingStart = downswingStartTime else { return }
        
        let downswingDuration = timestamp.timeIntervalSince(downswingStart)
        
        // Track peak acceleration (for hand speed)
        if acceleration > (currentSwingData?.peakGForce ?? 0) {
            currentSwingData?.peakGForce = acceleration
            preImpactAcceleration = acceleration
        }
        
        if rotation > (currentSwingData?.peakRotationRate ?? 0) {
            currentSwingData?.peakRotationRate = rotation
        }
        
        // Impact detection: look for sudden deceleration spike
        // This happens when club hits ball
        if downswingDuration >= minDownswingDuration {
            // Check for impact signature:
            // 1. High acceleration followed by
            // 2. Sharp deceleration (within ~20ms)
            
            let recentAccels = Array(accelerationBuffer.suffix(5))
            if recentAccels.count >= 5 {
                let peak = recentAccels.max() ?? 0
                let current = recentAccels.last ?? 0
                let deceleration = peak - current
                
                if peak > impactThreshold && deceleration > impactDecelerationThreshold {
                    // Impact detected!
                    impactDetected = true
                    impactDeceleration = deceleration
                    impactTime = timestamp
                    
                    currentSwingData?.impactDetected = true
                    currentSwingData?.impactTimestamp = timestamp
                    currentSwingData?.impactDeceleration = deceleration
                    currentSwingData?.downswingDuration = downswingDuration
                    currentSwingData?.impactTime = timestamp
                    
                    transitionToPhase(.impact, timestamp: timestamp)
                }
            }
        }
        
        // Timeout - missed impact detection, still complete swing
        if downswingDuration > maxDownswingDuration {
            currentSwingData?.downswingDuration = downswingDuration
            transitionToPhase(.impact, timestamp: timestamp)
        }
    }
    
    private func detectFollowThrough(acceleration: Double, rotation: Double, timestamp: Date) {
        // Follow through: deceleration continues
        transitionToPhase(.followThrough, timestamp: timestamp)
        currentSwingData?.followThroughTime = timestamp
    }
    
    private func detectSwingEnd(acceleration: Double, timestamp: Date) {
        // Swing ends when motion settles
        if acceleration < 1.5 {
            transitionToPhase(.finished, timestamp: timestamp)
        }
        
        // Or after a timeout
        if let impact = impactTime, timestamp.timeIntervalSince(impact) > 1.0 {
            transitionToPhase(.finished, timestamp: timestamp)
        }
    }
    
    // MARK: - Swing Completion
    
    private func completeSwing() {
        guard var analytics = currentSwingData else {
            reset()
            return
        }
        
        // Calculate final metrics
        analytics.totalDuration = (analytics.backswingDuration) + (analytics.downswingDuration)
        analytics.peakHandSpeed = accelerationToHandSpeed(analytics.peakGForce)
        analytics.swingPath = analyzeSwingPath()
        analytics.swingType = classifySwingType(analytics)
        
        // Store raw data for ML training (optional)
        analytics.accelerationSamples = Array(accelerationBuffer.suffix(200))
        analytics.rotationSamples = Array(rotationBuffer.suffix(200))
        
        // Update session stats
        sessionStats.addSwing(analytics)
        
        // Publish
        lastAnalytics = analytics
        onSwingComplete?(analytics)
        
        print("🏌️ Swing complete: Tempo \(String(format: "%.1f", analytics.tempoRatio)):1, " +
              "Speed \(String(format: "%.0f", analytics.peakHandSpeed)) mph, " +
              "Impact: \(analytics.impactDetected ? "✓" : "✗")")
        
        reset()
    }
    
    private func cancelSwing(reason: String) {
        print("❌ Swing cancelled: \(reason)")
        reset()
    }
    
    // MARK: - Phase Transition
    
    private func transitionToPhase(_ newPhase: SwingPhase, timestamp: Date) {
        let oldPhase = currentPhase
        currentPhase = newPhase
        phaseStartTime = timestamp
        
        if oldPhase != newPhase {
            onPhaseChange?(newPhase)
            print("📊 Phase: \(oldPhase.rawValue) → \(newPhase.rawValue)")
        }
    }
    
    // MARK: - Analysis Methods
    
    /// Convert acceleration to hand speed (mph)
    private func accelerationToHandSpeed(_ acceleration: Double) -> Double {
        // Rough conversion: 1G ≈ 2.2 mph hand speed
        // This is an approximation - actual conversion depends on swing arc
        return acceleration * 2.2
    }
    
    /// Analyze swing path from rotation data
    private func analyzeSwingPath() -> SwingPath {
        guard rotationXBuffer.count >= 50 else { return .unknown }
        
        // Analyze rotation pattern during downswing
        // X rotation (around club axis) indicates path
        let downswingRotations = Array(rotationXBuffer.suffix(30))
        let avgRotation = downswingRotations.reduce(0, +) / Double(downswingRotations.count)
        
        // Positive X rotation = inside-out path
        // Negative X rotation = over-the-top
        if avgRotation > 3.0 {
            return .insideOut
        } else if avgRotation < -3.0 {
            return .overTheTop
        } else {
            return .neutral
        }
    }
    
    /// Classify swing type based on metrics
    private func classifySwingType(_ analytics: SwingAnalytics) -> SwingType {
        let gForce = analytics.peakGForce
        let tempo = analytics.tempoRatio
        
        // Full swing: high G-force, normal tempo
        if gForce > 10 && tempo > 2.0 {
            return .fullSwing
        }
        
        // Iron swing: moderate G-force
        if gForce > 6 && tempo > 2.0 {
            return .ironSwing
        }
        
        // Chip/Pitch: lower G-force, faster tempo
        if gForce > 3 && gForce <= 6 {
            return .chipOrPitch
        }
        
        // Putt: very low G-force
        if gForce <= 3 {
            return .putt
        }
        
        return .unknown
    }
    
    // MARK: - Buffer Management
    
    private func addToBuffers(
        acceleration: Double,
        rotation: Double,
        rotationX: Double,
        rotationY: Double,
        rotationZ: Double,
        timestamp: Date
    ) {
        accelerationBuffer.append(acceleration)
        rotationBuffer.append(rotation)
        rotationXBuffer.append(rotationX)
        rotationYBuffer.append(rotationY)
        rotationZBuffer.append(rotationZ)
        timestampBuffer.append(timestamp)
        
        // Trim buffers
        if accelerationBuffer.count > maxBufferSize {
            accelerationBuffer.removeFirst()
            rotationBuffer.removeFirst()
            rotationXBuffer.removeFirst()
            rotationYBuffer.removeFirst()
            rotationZBuffer.removeFirst()
            timestampBuffer.removeFirst()
        }
    }
    
    private func clearBuffers() {
        accelerationBuffer.removeAll()
        rotationBuffer.removeAll()
        rotationXBuffer.removeAll()
        rotationYBuffer.removeAll()
        rotationZBuffer.removeAll()
        timestampBuffer.removeAll()
    }
    
    private func resetTimers() {
        phaseStartTime = nil
        addressStartTime = nil
        backswingStartTime = nil
        topOfSwingTime = nil
        downswingStartTime = nil
        impactTime = nil
    }
    
    private func initializeSwingData(timestamp: Date) {
        currentSwingData = SwingAnalytics(
            timestamp: timestamp,
            swingType: .unknown
        )
        currentSwingData?.backswingStartTime = timestamp
    }
}
