import Foundation
import WatchConnectivity
import Combine

/// Manages Watch-iPhone synchronization for Range Mode
/// Handles receiving motion data and syncing with camera frames
class WatchSwingSync: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WatchSwingSync()
    
    // MARK: - Published State
    
    @Published var isWatchConnected = false
    @Published var isWatchReachable = false
    @Published var isRangeSessionActive = false
    @Published var watchSwingCount = 0
    
    // Live motion data from Watch
    @Published var liveAcceleration: Double = 0
    @Published var liveRotation: Double = 0
    
    // Swing data from Watch
    @Published var lastWatchSwing: WatchSwingData?
    @Published var watchSessionSummary: WatchRangeSessionSummary?
    
    // MARK: - Private Properties
    
    private var session: WCSession?
    
    // Motion buffer for sensor fusion
    private var motionBuffer: [MotionSample] = []
    private let maxBufferSize = 1000 // 10 seconds at 100Hz
    
    // Timestamp synchronization
    private var clockOffset: TimeInterval = 0 // iPhone time - Watch time
    private var lastClockSync: Date?
    
    // Callbacks for SwingAnalyzerIOS
    var onMotionSampleReceived: ((MotionSample) -> Void)?
    var onSwingMetricsReceived: ((WatchSwingMetrics) -> Void)?
    var onSessionEnded: ((WatchRangeSessionSummary) -> Void)?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⚠️ WatchConnectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Session Control
    
    /// Start Range Mode session on Watch
    func startRangeSession() {
        guard let session = session, session.isReachable else {
            print("⚠️ Watch not reachable")
            return
        }
        
        isRangeSessionActive = true
        watchSwingCount = 0
        motionBuffer.removeAll()
        
        // Sync clocks first
        syncClocks()
        
        let message: [String: Any] = [
            "action": "startRangeSession",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("⚠️ Error starting range session: \(error.localizedDescription)")
        }
        
        print("📱 Started Range Session on Watch")
    }
    
    /// End Range Mode session on Watch
    func endRangeSession() {
        guard let session = session else { return }
        
        let message: [String: Any] = [
            "action": "endRangeSession",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
        
        isRangeSessionActive = false
        print("📱 Ended Range Session on Watch")
    }
    
    // MARK: - Clock Synchronization
    
    /// Synchronize clocks between iPhone and Watch for accurate timestamp alignment
    private func syncClocks() {
        guard let session = session, session.isReachable else { return }
        
        let sendTime = Date()
        let message: [String: Any] = [
            "action": "clockSync",
            "iPhoneTime": sendTime.timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            guard let watchTime = reply["watchTime"] as? TimeInterval else { return }
            
            let receiveTime = Date()
            let roundTripTime = receiveTime.timeIntervalSince(sendTime)
            let estimatedWatchTime = watchTime + (roundTripTime / 2)
            
            self?.clockOffset = receiveTime.timeIntervalSince1970 - estimatedWatchTime
            self?.lastClockSync = receiveTime
            
            print("🕐 Clock sync: offset = \(String(format: "%.3f", self?.clockOffset ?? 0))s")
        }, errorHandler: { error in
            print("⚠️ Clock sync failed: \(error.localizedDescription)")
        })
    }
    
    /// Convert Watch timestamp to iPhone timestamp
    private func convertWatchTimestamp(_ watchTimestamp: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: watchTimestamp + clockOffset)
    }
    
    // MARK: - Motion Data Retrieval
    
    /// Get motion samples within a time range (for sensor fusion)
    func getMotionSamples(from startTime: Date, to endTime: Date) -> [MotionSample] {
        return motionBuffer.filter { sample in
            sample.timestamp >= startTime && sample.timestamp <= endTime
        }
    }
    
    /// Get the most recent motion sample
    func getLatestMotionSample() -> MotionSample? {
        return motionBuffer.last
    }
    
    /// Get motion sample closest to a specific timestamp
    func getMotionSample(nearestTo timestamp: Date) -> MotionSample? {
        guard !motionBuffer.isEmpty else { return nil }
        
        return motionBuffer.min(by: { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) })
    }
    
    /// Get interpolated motion data at a specific timestamp
    func getInterpolatedMotion(at timestamp: Date) -> MotionSample? {
        guard motionBuffer.count >= 2 else { return getLatestMotionSample() }
        
        // Find samples before and after timestamp
        let before = motionBuffer.last { $0.timestamp <= timestamp }
        let after = motionBuffer.first { $0.timestamp > timestamp }
        
        guard let b = before, let a = after else {
            return getMotionSample(nearestTo: timestamp)
        }
        
        // Linear interpolation
        let totalInterval = a.timestamp.timeIntervalSince(b.timestamp)
        guard totalInterval > 0 else { return b }
        
        let t = timestamp.timeIntervalSince(b.timestamp) / totalInterval
        
        return MotionSample(
            timestamp: timestamp,
            index: b.index,
            acceleration: (
                x: lerp(b.accelerationX, a.accelerationX, t),
                y: lerp(b.accelerationY, a.accelerationY, t),
                z: lerp(b.accelerationZ, a.accelerationZ, t)
            ),
            rotation: (
                x: lerp(b.rotationX, a.rotationX, t),
                y: lerp(b.rotationY, a.rotationY, t),
                z: lerp(b.rotationZ, a.rotationZ, t)
            )
        )
    }
    
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
}

// MARK: - WCSessionDelegate

extension WatchSwingSync: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
            self.isWatchReachable = session.isReachable
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for new Watch
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            
            // Re-sync clocks when connection restored
            if session.isReachable {
                self.syncClocks()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleMessage(message)
        replyHandler(["received": true])
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Handle user info transfers (used for background data transfer)
        handleMessage(userInfo)
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle application context updates
        handleMessage(applicationContext)
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        case "rangeMotionBatch":
            handleMotionBatch(message)
            
        case "rangeSwingComplete":
            handleSwingComplete(message)
            
        case "rangeSessionSummary":
            handleSessionSummary(message)
            
        case "clockSync":
            // Reply with watch time for clock sync
            break
            
        default:
            break
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleMotionBatch(_ message: [String: Any]) {
        guard let samplesData = message["samples"] as? [[String: Any]] else { return }
        
        for sampleDict in samplesData {
            guard let timestamp = sampleDict["t"] as? TimeInterval,
                  let index = sampleDict["i"] as? Int,
                  let ax = sampleDict["ax"] as? Double,
                  let ay = sampleDict["ay"] as? Double,
                  let az = sampleDict["az"] as? Double,
                  let rx = sampleDict["rx"] as? Double,
                  let ry = sampleDict["ry"] as? Double,
                  let rz = sampleDict["rz"] as? Double else { continue }
            
            let sample = MotionSample(
                timestamp: convertWatchTimestamp(timestamp),
                index: index,
                acceleration: (x: ax, y: ay, z: az),
                rotation: (x: rx, y: ry, z: rz)
            )
            
            // Add to buffer
            motionBuffer.append(sample)
            if motionBuffer.count > maxBufferSize {
                motionBuffer.removeFirst(100)
            }
            
            // Update live display
            DispatchQueue.main.async {
                self.liveAcceleration = sample.totalAcceleration
                self.liveRotation = sample.totalRotation
            }
            
            // Notify callback
            onMotionSampleReceived?(sample)
        }
    }
    
    private func handleSwingComplete(_ message: [String: Any]) {
        guard let timestamp = message["timestamp"] as? TimeInterval,
              let tempo = message["tempo"] as? Double,
              let peakSpeed = message["peakSpeed"] as? Double else { return }
        
        let swingData = WatchSwingData(
            id: message["id"] as? String ?? UUID().uuidString,
            timestamp: convertWatchTimestamp(timestamp),
            tempo: tempo,
            peakSpeed: peakSpeed,
            impactQuality: message["impactQuality"] as? Double,
            swingPath: message["swingPath"] as? String,
            backswingDuration: message["backswingDuration"] as? TimeInterval,
            downswingDuration: message["downswingDuration"] as? TimeInterval,
            peakGForce: message["peakGForce"] as? Double,
            peakRotationRate: message["peakRotationRate"] as? Double,
            impactDetected: message["impactDetected"] as? Bool ?? false
        )
        
        DispatchQueue.main.async {
            self.lastWatchSwing = swingData
            self.watchSwingCount += 1
        }
        
        // Convert to WatchSwingMetrics for SwingAnalyzerIOS
        let metrics = WatchSwingMetrics(
            backswingDuration: swingData.backswingDuration,
            downswingDuration: swingData.downswingDuration,
            totalSwingDuration: (swingData.backswingDuration ?? 0) + (swingData.downswingDuration ?? 0),
            tempoRatio: swingData.tempo,
            peakWristAcceleration: swingData.peakGForce,
            estimatedClubSpeed: swingData.peakSpeed,
            peakRotationRate: swingData.peakRotationRate,
            impactTimestamp: swingData.impactDetected ? swingData.timestamp : nil,
            impactQuality: swingData.impactQuality,
            impactDeceleration: nil,
            lagRetained: nil,
            smoothnessScore: nil,
            consistencyWithPrevious: nil
        )
        
        onSwingMetricsReceived?(metrics)
        
        print("📱 Received swing from Watch: Tempo \(String(format: "%.1f", tempo)):1, Speed \(String(format: "%.0f", peakSpeed)) mph")
    }
    
    private func handleSessionSummary(_ message: [String: Any]) {
        let summary = WatchRangeSessionSummary(
            duration: message["duration"] as? TimeInterval ?? 0,
            swingCount: message["swingCount"] as? Int ?? 0,
            averageTempo: message["averageTempo"] as? Double,
            averageSpeed: message["averageSpeed"] as? Double,
            bestTempo: message["bestTempo"] as? Double,
            bestSpeed: message["bestSpeed"] as? Double,
            tempoConsistency: message["tempoConsistency"] as? Double,
            speedConsistency: message["speedConsistency"] as? Double
        )
        
        DispatchQueue.main.async {
            self.watchSessionSummary = summary
            self.isRangeSessionActive = false
        }
        
        onSessionEnded?(summary)
        
        print("📱 Range session complete: \(summary.swingCount) swings, avg tempo \(String(format: "%.1f", summary.averageTempo ?? 0)):1")
    }
}

// MARK: - Data Types

/// Swing data received from Watch
struct WatchSwingData: Identifiable {
    let id: String
    let timestamp: Date
    let tempo: Double
    let peakSpeed: Double
    let impactQuality: Double?
    let swingPath: String?
    let backswingDuration: TimeInterval?
    let downswingDuration: TimeInterval?
    let peakGForce: Double?
    let peakRotationRate: Double?
    let impactDetected: Bool
}

/// Session summary from Watch
struct WatchRangeSessionSummary {
    let duration: TimeInterval
    let swingCount: Int
    let averageTempo: Double?
    let averageSpeed: Double?
    let bestTempo: Double?
    let bestSpeed: Double?
    let tempoConsistency: Double?
    let speedConsistency: Double?
}

// MARK: - Sensor Fusion Helpers

extension WatchSwingSync {
    
    /// Align camera pose with nearest Watch motion sample
    func alignPoseWithMotion(pose: PoseFrame) -> (pose: PoseFrame, motion: MotionSample?)? {
        let motion = getMotionSample(nearestTo: pose.timestamp)
        return (pose, motion)
    }
    
    /// Calculate combined confidence from camera and Watch
    func calculateCombinedConfidence(cameraConfidence: Float, hasWatchData: Bool, timeDelta: TimeInterval) -> Float {
        var confidence = cameraConfidence
        
        // Boost confidence if Watch data is available
        if hasWatchData {
            confidence += 0.1
        }
        
        // Reduce confidence if timestamp delta is large
        if timeDelta > 0.05 { // More than 50ms apart
            confidence -= Float(timeDelta * 2)
        }
        
        return min(1.0, max(0, confidence))
    }
    
    /// Determine if camera and Watch detected the same swing
    func isMatchingSwing(cameraSwingStart: Date, watchSwingStart: Date, tolerance: TimeInterval = 0.5) -> Bool {
        return abs(cameraSwingStart.timeIntervalSince(watchSwingStart)) < tolerance
    }
}
