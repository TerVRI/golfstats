import Foundation
import CoreMotion
import WatchConnectivity
import WatchKit
import Combine

/// Manages Range Mode on Apple Watch - streams high-frequency motion data to iPhone
class RangeModeManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = RangeModeManager()
    
    // MARK: - Published State
    
    @Published var isRangeModeActive = false
    @Published var isConnectedToPhone = false
    @Published var swingCount = 0
    @Published var sessionDuration: TimeInterval = 0
    
    // Live metrics
    @Published var currentAcceleration: Double = 0
    @Published var currentRotation: Double = 0
    @Published var isSwingInProgress = false
    @Published var lastSwingTempo: Double?
    
    // Session stats
    @Published var averageTempo: Double?
    @Published var averageClubSpeed: Double?
    @Published var sessionSwings: [RangeModeSwing] = []
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var requiresPhoneConnection = true
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    
    // Motion buffer for batch sending
    private var motionBuffer: [RangeMotionSample] = []
    private let batchSize = 10 // Send every 10 samples (~100ms at 100Hz)
    private var sampleIndex = 0
    
    // Swing detection
    private let swingDetector = SwingDetector()
    private var swingStartTime: Date?
    private var swingMotionBuffer: [RangeMotionSample] = []
    
    // WatchConnectivity
    private var wcSession: WCSession?
    
    // Configuration
    private let motionUpdateInterval: TimeInterval = 1.0 / 100.0 // 100Hz
    private let swingGForceThreshold: Double = 6.0
    private let swingCooldown: TimeInterval = 2.0
    private var lastSwingTime: Date?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupSwingDetector()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }
    
    private func setupSwingDetector() {
        // Configure swing detector for range mode
        swingDetector.onSwingComplete = { [weak self] analytics in
            self?.handleSwingComplete(analytics)
        }
        
        swingDetector.onPhaseChange = { [weak self] phase in
            DispatchQueue.main.async {
                self?.isSwingInProgress = phase != .idle && phase != .finished
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Start Range Mode session
    func startSession() {
        guard !isRangeModeActive else { return }
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available")
            return
        }
        
        isRangeModeActive = true
        sessionStartTime = Date()
        swingCount = 0
        sessionSwings.removeAll()
        motionBuffer.removeAll()
        sampleIndex = 0
        
        // Start motion updates at 100Hz
        motionManager.deviceMotionUpdateInterval = motionUpdateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
        
        // Start session timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.sessionStartTime else { return }
            self.sessionDuration = Date().timeIntervalSince(start)
        }
        
        // Notify iPhone
        sendToPhone(action: "startRangeSession", data: [
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.start)
        
        print("🎯 Range Mode started")
    }
    
    /// End Range Mode session
    func endSession() {
        guard isRangeModeActive else { return }
        
        isRangeModeActive = false
        motionManager.stopDeviceMotionUpdates()
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Calculate session stats
        calculateSessionStats()
        
        // Send session summary to iPhone
        sendSessionSummary()
        
        // Notify iPhone session ended
        sendToPhone(action: "endRangeSession", data: [
            "timestamp": Date().timeIntervalSince1970,
            "swingCount": swingCount,
            "duration": sessionDuration
        ])
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.stop)
        
        print("🎯 Range Mode ended: \(swingCount) swings in \(Int(sessionDuration))s")
    }
    
    // MARK: - Motion Processing
    
    private func processMotion(_ motion: CMDeviceMotion) {
        let now = Date()
        
        // Create sample
        let sample = RangeMotionSample(
            timestamp: now,
            index: sampleIndex,
            accelerationX: motion.userAcceleration.x,
            accelerationY: motion.userAcceleration.y,
            accelerationZ: motion.userAcceleration.z,
            rotationX: motion.rotationRate.x,
            rotationY: motion.rotationRate.y,
            rotationZ: motion.rotationRate.z
        )
        sampleIndex += 1
        
        // Calculate magnitudes for display
        let totalAccel = sqrt(
            pow(motion.userAcceleration.x, 2) +
            pow(motion.userAcceleration.y, 2) +
            pow(motion.userAcceleration.z, 2)
        )
        let totalRotation = sqrt(
            pow(motion.rotationRate.x, 2) +
            pow(motion.rotationRate.y, 2) +
            pow(motion.rotationRate.z, 2)
        )
        
        DispatchQueue.main.async {
            self.currentAcceleration = totalAccel
            self.currentRotation = totalRotation
        }
        
        // Add to batch buffer
        motionBuffer.append(sample)
        
        // If swing is in progress, also buffer for swing analysis
        if isSwingInProgress || totalAccel > swingGForceThreshold * 0.5 {
            swingMotionBuffer.append(sample)
        }
        
        // Send batch to iPhone when buffer is full
        if motionBuffer.count >= batchSize {
            sendMotionBatch()
        }
        
        // Feed to swing detector
        swingDetector.processMotion(motion, timestamp: now)
        
        // Simple swing detection for count
        detectSwing(acceleration: totalAccel)
    }
    
    private func detectSwing(acceleration: Double) {
        guard acceleration > swingGForceThreshold else { return }
        
        // Check cooldown
        if let lastSwing = lastSwingTime,
           Date().timeIntervalSince(lastSwing) < swingCooldown {
            return
        }
        
        lastSwingTime = Date()
        
        DispatchQueue.main.async {
            self.swingCount += 1
        }
        
        // Haptic for swing detected
        WKInterfaceDevice.current().play(.click)
    }
    
    private func handleSwingComplete(_ analytics: SwingAnalytics) {
        let swing = RangeModeSwing(
            id: UUID(),
            timestamp: analytics.timestamp,
            tempo: analytics.tempoRatio,
            peakSpeed: analytics.peakHandSpeed,
            impactQuality: analytics.impactDetected ? 0.8 : 0.5, // Simplified
            swingPath: analytics.swingPath.rawValue,
            motionSamples: swingMotionBuffer
        )
        
        DispatchQueue.main.async {
            self.sessionSwings.append(swing)
            self.lastSwingTempo = analytics.tempoRatio
            self.swingMotionBuffer.removeAll()
        }
        
        // Send swing data to iPhone
        sendSwingData(swing: swing, analytics: analytics)
    }
    
    // MARK: - Phone Communication
    
    private func sendMotionBatch() {
        guard !motionBuffer.isEmpty else { return }
        guard let session = wcSession, session.isReachable else {
            // If phone not reachable, just clear buffer to avoid memory buildup
            motionBuffer.removeAll()
            return
        }
        
        // Convert samples to dictionary array for sending
        let samplesData = motionBuffer.map { sample -> [String: Any] in
            return [
                "t": sample.timestamp.timeIntervalSince1970,
                "i": sample.index,
                "ax": sample.accelerationX,
                "ay": sample.accelerationY,
                "az": sample.accelerationZ,
                "rx": sample.rotationX,
                "ry": sample.rotationY,
                "rz": sample.rotationZ
            ]
        }
        
        let message: [String: Any] = [
            "action": "rangeMotionBatch",
            "samples": samplesData
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            // Silent fail - motion data is high volume, some drops are ok
        }
        
        motionBuffer.removeAll()
    }
    
    private func sendSwingData(swing: RangeModeSwing, analytics: SwingAnalytics) {
        let data: [String: Any] = [
            "id": swing.id.uuidString,
            "timestamp": swing.timestamp.timeIntervalSince1970,
            "tempo": swing.tempo,
            "peakSpeed": swing.peakSpeed,
            "impactQuality": swing.impactQuality,
            "swingPath": swing.swingPath,
            "backswingDuration": analytics.backswingDuration,
            "downswingDuration": analytics.downswingDuration,
            "peakGForce": analytics.peakGForce,
            "peakRotationRate": analytics.peakRotationRate,
            "impactDetected": analytics.impactDetected
        ]
        
        sendToPhone(action: "rangeSwingComplete", data: data)
    }
    
    private func sendSessionSummary() {
        guard !sessionSwings.isEmpty else { return }
        
        let tempos = sessionSwings.map { $0.tempo }
        let speeds = sessionSwings.map { $0.peakSpeed }
        
        let data: [String: Any] = [
            "duration": sessionDuration,
            "swingCount": swingCount,
            "averageTempo": tempos.reduce(0, +) / Double(tempos.count),
            "averageSpeed": speeds.reduce(0, +) / Double(speeds.count),
            "bestTempo": tempos.min(by: { abs($0 - 3.0) < abs($1 - 3.0) }) ?? 0,
            "bestSpeed": speeds.max() ?? 0,
            "tempoConsistency": calculateConsistency(tempos),
            "speedConsistency": calculateConsistency(speeds)
        ]
        
        sendToPhone(action: "rangeSessionSummary", data: data)
    }
    
    private func sendToPhone(action: String, data: [String: Any]) {
        guard let session = wcSession, session.isReachable else {
            // For non-critical data, silently fail
            // For important actions like session summary, queue for later
            if action == "rangeSessionSummary" {
                DispatchQueue.main.async {
                    self.errorMessage = "iPhone not connected. Session data saved locally."
                    self.showError = true
                    
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.showError = false
                    }
                }
                // Queue via transferUserInfo for later delivery
                var message = data
                message["action"] = action
                wcSession?.transferUserInfo(message)
            }
            return
        }
        
        var message = data
        message["action"] = action
        
        session.sendMessage(message, replyHandler: nil) { [weak self] error in
            // For swing data, don't show errors (high volume, some loss is ok)
            // For session summaries, show error
            if action == "rangeSessionSummary" {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to sync session. Data saved for later."
                    self?.showError = true
                    
                    // Queue for background transfer
                    self?.wcSession?.transferUserInfo(message)
                    
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self?.showError = false
                    }
                }
            }
            print("⚠️ Error sending to phone: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Statistics
    
    private func calculateSessionStats() {
        guard !sessionSwings.isEmpty else { return }
        
        let tempos = sessionSwings.map { $0.tempo }
        let speeds = sessionSwings.map { $0.peakSpeed }
        
        averageTempo = tempos.reduce(0, +) / Double(tempos.count)
        averageClubSpeed = speeds.reduce(0, +) / Double(speeds.count)
    }
    
    private func calculateConsistency(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 100 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        // Convert to 0-100 score (lower std dev = higher score)
        return max(0, min(100, 100 - (stdDev * 20)))
    }
}

// MARK: - WCSessionDelegate

extension RangeModeManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnectedToPhone = activationState == .activated && session.isReachable
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnectedToPhone = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        
        DispatchQueue.main.async {
            switch action {
            case "startRangeSession":
                self.startSession()
                
            case "endRangeSession":
                self.endSession()
                
            default:
                break
            }
        }
    }
}

// MARK: - Data Models

/// A single motion sample for Range Mode
struct RangeMotionSample: Codable {
    let timestamp: Date
    let index: Int
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    
    var totalAcceleration: Double {
        sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2))
    }
    
    var totalRotation: Double {
        sqrt(pow(rotationX, 2) + pow(rotationY, 2) + pow(rotationZ, 2))
    }
}

/// A swing captured during Range Mode
struct RangeModeSwing: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let tempo: Double
    let peakSpeed: Double
    let impactQuality: Double
    let swingPath: String
    let motionSamples: [RangeMotionSample]
}
