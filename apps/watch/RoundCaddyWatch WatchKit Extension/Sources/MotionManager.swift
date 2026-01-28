import Foundation
import CoreMotion
import CoreLocation
import WatchKit
import Combine
import AVFoundation

/// Manages motion detection for automatic golf swing recognition
class MotionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isDetecting = false
    @Published var lastSwingDetected: Date?
    @Published var swingConfirmationPending = false
    @Published var currentAcceleration: Double = 0
    @Published var swingCount: Int = 0
    
    // Putting mode
    @Published var isPuttingMode = false
    @Published var puttCount: Int = 0
    @Published var lastPuttDetected: Date?
    
    // Debug/Training data
    @Published var peakGForce: Double = 0
    @Published var peakRotationRate: Double = 0
    
    // Advanced analytics
    @Published var lastSwingAnalytics: SwingAnalytics?
    @Published var currentPhase: SwingPhase = .idle
    @Published var sessionStats = SwingSessionStats()
    
    // Real-time metrics
    @Published var currentHandSpeed: Double = 0
    @Published var currentTempoRatio: Double = 0
    
    // Practice mode
    @Published var isPracticeMode = false
    
    // Swing metrics view flag (to enable analytics outside practice mode)
    @Published var isLiveMetricsEnabled = false
    
    // Error handling
    @Published var motionError: String?
    @Published var showMotionError = false
    
    // MARK: - Sub-systems
    
    let swingDetector = SwingDetector()
    let clubDistanceTracker = ClubDistanceTracker()
    let coachingEngine = CoachingEngine()
    let powerManager = PowerManager()
    let strokesGainedCalculator = StrokesGainedCalculator()
    let highFreqManager = HighFrequencyMotionManager()
    
    // User preferences
    @Published var preferences = SwingPreferences()
    
    // MARK: - Configuration
    
    /// Minimum G-force to trigger swing detection (typical golf swing: 8-15G at wrist)
    private var swingGForceThreshold: Double {
        6.0 * preferences.sensitivity
    }
    
    /// Minimum rotation rate (rad/s) to confirm it's a swing motion
    private var swingRotationThreshold: Double {
        8.0 * preferences.sensitivity
    }
    
    /// Cooldown period between swing detections (seconds)
    private let swingCooldown: TimeInterval = 3.0
    
    /// Time to wait before confirming a shot (to filter practice swings)
    private let confirmationDelay: TimeInterval = 8.0
    
    /// Maximum time between swings to consider them "practice" vs "real"
    private let practiceSwingWindow: TimeInterval = 30.0
    
    /// Maximum distance (meters) to consider swings at "same location"
    private let sameLocationThreshold: Double = 5.0
    
    // MARK: - Putting Detection Configuration
    
    /// G-force threshold for putting (much lower than full swing)
    private let puttGForceMin: Double = 0.8
    private let puttGForceMax: Double = 3.0
    
    /// Rotation threshold for putting (smooth, controlled motion)
    private let puttRotationMin: Double = 1.0
    private let puttRotationMax: Double = 5.0
    
    /// Distance to green (yards) to auto-enable putting mode
    private let puttingModeDistance: Int = 30
    
    /// Cooldown between putt detections
    private let puttCooldown: TimeInterval = 2.0
    
    // MARK: - Audio Detection (for impact)
    
    private var audioEngine: AVAudioEngine?
    private var audioDetectionEnabled = false
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private var lastSwingTime: Date?
    private var lastSwingLocation: (latitude: Double, longitude: Double)?
    private var pendingSwingLocation: (latitude: Double, longitude: Double)?
    private var practiceSwingCount: Int = 0
    private var confirmationTimer: Timer?
    
    // GPS reference for location-based filtering
    weak var gpsManager: GPSManager?
    
    // Rolling buffer for motion analysis
    private var accelerationBuffer: [Double] = []
    private var rotationBuffer: [Double] = []
    private let bufferSize = 50 // ~0.5 seconds at 100Hz
    
    // Cancellables for Combine
    private var cancellables = Set<AnyCancellable>()
    
    // Callback for when a shot is confirmed
    var onShotConfirmed: ((Double, Double) -> Void)?
    var onSwingAnalyzed: ((SwingAnalytics) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Check if motion data is available
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available on this device")
            return
        }
        
        // Configure for high-frequency updates (100Hz for swing detection)
        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        
        // Load saved preferences
        loadPreferences()
        
        // Set up swing detector callbacks
        setupSwingDetector()
    }
    
    private func setupSwingDetector() {
        // When swing detector completes a swing analysis
        swingDetector.onSwingComplete = { [weak self] analytics in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.lastSwingAnalytics = analytics
                self.currentTempoRatio = analytics.tempoRatio
                self.sessionStats = self.swingDetector.sessionStats
                
                // Add to coaching engine for pattern analysis
                self.coachingEngine.addSwing(analytics)
                
                // Notify callback
                self.onSwingAnalyzed?(analytics)
                
                print("📊 Swing analyzed: Tempo \(String(format: "%.1f", analytics.tempoRatio)):1, " +
                      "Speed \(String(format: "%.0f", analytics.peakHandSpeed)) mph")
            }
        }
        
        // Track phase changes
        swingDetector.onPhaseChange = { [weak self] phase in
            DispatchQueue.main.async {
                self?.currentPhase = phase
            }
        }
        
        // Sync preferences
        swingDetector.preferences = preferences
    }
    
    // MARK: - Public Methods
    
    /// Start detecting golf swings
    func startDetecting() {
        guard !isDetecting else { return }
        guard motionManager.isDeviceMotionAvailable else {
            motionError = "Motion sensors unavailable on this device."
            showMotionError = true
            print("⚠️ Cannot start detection - device motion unavailable")
            return
        }
        
        isDetecting = true
        accelerationBuffer.removeAll()
        rotationBuffer.removeAll()
        swingDetector.reset()
        
        // Clear any previous errors
        motionError = nil
        showMotionError = false
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self else { return }
            
            if let error = error {
                // Only show persistent errors, not transient ones
                let nsError = error as NSError
                if nsError.domain == CMErrorDomain && nsError.code == Int(CMErrorDeviceRequiresMovement.rawValue) {
                    // This is normal - device needs movement to calibrate
                    return
                }
                
                DispatchQueue.main.async {
                    self.motionError = "Swing detection error. Try restarting the app."
                    self.showMotionError = true
                    
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.showMotionError = false
                    }
                }
                print("Motion error: \(error.localizedDescription)")
                return
            }
            
            guard let motion = motion else { return }
            
            self.processMotionData(motion)
            
            // Also feed to advanced swing detector (practice or live metrics view)
            if self.isPracticeMode || self.isLiveMetricsEnabled {
                self.swingDetector.processMotion(motion)
            }
        }
        
        print("🏌️ Swing detection started (Practice mode: \(isPracticeMode))")
    }
    
    /// Enable/disable practice mode
    func setPracticeMode(_ enabled: Bool) {
        isPracticeMode = enabled
        preferences.practiceMode = enabled
        savePreferences()
        
        if enabled {
            swingDetector.reset()
            print("🎯 Practice mode enabled - detailed swing analysis active")
        } else {
            print("🏌️ Practice mode disabled")
        }
    }
    
    /// Record a shot distance for club learning
    func recordShotDistance(club: String, distance: Int) {
        let speed = lastSwingAnalytics?.estimatedClubheadSpeed
        clubDistanceTracker.recordShot(club: club, distance: distance, swingSpeed: speed)
    }
    
    /// Get suggested club for distance
    func suggestClub(forDistance distance: Int) -> String {
        return clubDistanceTracker.suggestClub(forDistance: distance)
    }
    
    /// Get coaching tips
    func getCoachingTips() -> [CoachingTip] {
        return coachingEngine.latestTips
    }
    
    /// Generate session summary
    func generateSessionSummary() -> String {
        return coachingEngine.generateSessionSummary()
    }
    
    /// Stop detecting golf swings
    func stopDetecting() {
        isDetecting = false
        motionManager.stopDeviceMotionUpdates()
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        swingConfirmationPending = false
        
        print("🛑 Swing detection stopped")
    }
    
    /// Confirm the pending shot (user tapped confirm)
    func confirmShot() {
        guard swingConfirmationPending else { return }
        
        swingConfirmationPending = false
        confirmationTimer?.invalidate()
        swingCount += 1
        
        // Trigger haptic for confirmation
        playHaptic(.success)
        
        let location = pendingSwingLocation ?? (latitude: 0, longitude: 0)
        
        // Notify callback
        onShotConfirmed?(location.latitude, location.longitude)
        
        // Reset practice swing counter
        practiceSwingCount = 0
        pendingSwingLocation = nil
        
        print("✅ Shot confirmed at (\(location.latitude), \(location.longitude))")
    }
    
    /// Dismiss the pending shot (user said it was practice/mistake)
    func dismissShot() {
        swingConfirmationPending = false
        confirmationTimer?.invalidate()
        pendingSwingLocation = nil
        
        print("❌ Shot dismissed by user")
    }
    
    /// Set the location where a potential swing occurred
    func setPendingSwingLocation(latitude: Double, longitude: Double) {
        pendingSwingLocation = (latitude, longitude)
    }
    
    // MARK: - Motion Processing
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        // Calculate total acceleration (G-force)
        let userAccel = motion.userAcceleration
        let totalAccel = sqrt(
            pow(userAccel.x, 2) +
            pow(userAccel.y, 2) +
            pow(userAccel.z, 2)
        )
        
        // Calculate total rotation rate
        let rotation = motion.rotationRate
        let totalRotation = sqrt(
            pow(rotation.x, 2) +
            pow(rotation.y, 2) +
            pow(rotation.z, 2)
        )
        
        // Update current reading (for UI/debugging)
        currentAcceleration = totalAccel
        
        // Add to rolling buffers
        accelerationBuffer.append(totalAccel)
        rotationBuffer.append(totalRotation)
        
        // Keep buffer at fixed size
        if accelerationBuffer.count > bufferSize {
            accelerationBuffer.removeFirst()
        }
        if rotationBuffer.count > bufferSize {
            rotationBuffer.removeFirst()
        }
        
        // Check for swing pattern
        detectSwing(acceleration: totalAccel, rotation: totalRotation)
    }
    
    private func detectSwing(acceleration: Double, rotation: Double) {
        // Check cooldown
        if let lastSwing = lastSwingTime,
           Date().timeIntervalSince(lastSwing) < swingCooldown {
            return
        }
        
        // Don't detect new swings while confirmation is pending
        if swingConfirmationPending {
            return
        }
        
        // Track peak values for debugging/tuning
        if acceleration > peakGForce {
            peakGForce = acceleration
        }
        if rotation > peakRotationRate {
            peakRotationRate = rotation
        }
        
        // Auto-detect putting mode based on distance to green
        updatePuttingMode()
        
        if isPuttingMode {
            // Putting detection: moderate acceleration, controlled rotation
            let isPuttMotion = acceleration >= puttGForceMin &&
                               acceleration <= puttGForceMax &&
                               rotation >= puttRotationMin &&
                               rotation <= puttRotationMax
            
            if isPuttMotion {
                handlePuttDetected()
            }
        } else {
            // Full swing detection: high acceleration + high rotation rate
            let isHighG = acceleration > swingGForceThreshold
            let isHighRotation = rotation > swingRotationThreshold
            
            if isHighG && isHighRotation {
                handleSwingDetected()
            }
        }
    }
    
    private func updatePuttingMode() {
        guard let gps = gpsManager else { return }
        
        // Enable putting mode when within 30 yards of green
        let newPuttingMode = gps.distanceToGreenCenter > 0 &&
                            gps.distanceToGreenCenter <= puttingModeDistance
        
        if newPuttingMode != isPuttingMode {
            isPuttingMode = newPuttingMode
            
            if isPuttingMode {
                print("🏌️ Entering putting mode (within \(puttingModeDistance) yards of green)")
                playHaptic(.directionUp)
            } else {
                print("🏌️ Exiting putting mode")
            }
        }
    }
    
    private func handlePuttDetected() {
        let now = Date()
        
        // Check putt cooldown
        if let lastPutt = lastPuttDetected,
           now.timeIntervalSince(lastPutt) < puttCooldown {
            return
        }
        
        lastPuttDetected = now
        puttCount += 1
        
        // Gentle haptic for putt
        playHaptic(.click)
        
        print("⛳ Putt #\(puttCount) detected!")
        
        // Note: Putts don't need the full confirmation flow
        // They're tracked automatically and can be adjusted in scorecard
    }
    
    private func handleSwingDetected() {
        let now = Date()
        
        // Get current location from GPS manager
        let currentLocation = gpsManager?.currentLocation
        let currentCoords: (Double, Double)? = currentLocation.map {
            ($0.coordinate.latitude, $0.coordinate.longitude)
        }
        
        // Check if this might be a practice swing
        var isProbablyPractice = false
        
        if let lastSwing = lastSwingTime,
           now.timeIntervalSince(lastSwing) < practiceSwingWindow {
            
            // Check if at same location (GPS-based filtering)
            if let current = currentCoords, let last = lastSwingLocation {
                let distance = calculateDistance(
                    from: last,
                    to: current
                )
                
                if distance < sameLocationThreshold {
                    // Same spot within 30 seconds = likely practice swing
                    isProbablyPractice = true
                    practiceSwingCount += 1
                    print("🔄 Practice swing #\(practiceSwingCount) (same location: \(String(format: "%.1f", distance))m)")
                    
                    // Cancel any pending confirmation - we'll wait for the "real" swing
                    confirmationTimer?.invalidate()
                    swingConfirmationPending = false
                }
            } else {
                // No GPS data - fall back to time-based detection
                practiceSwingCount += 1
                print("🔄 Possible practice swing #\(practiceSwingCount) (no GPS)")
            }
        } else {
            practiceSwingCount = 1
        }
        
        // Update tracking
        lastSwingTime = now
        lastSwingDetected = now
        lastSwingLocation = currentCoords
        pendingSwingLocation = currentCoords
        
        // Light haptic to acknowledge swing was detected
        playHaptic(.click)
        
        print("🏌️ Swing detected! G-Force: \(String(format: "%.1f", peakGForce))G, Rotation: \(String(format: "%.1f", peakRotationRate)) rad/s")
        
        // Only start confirmation timer if not clearly a practice swing
        // OR if this is the 2nd+ swing at same spot (the "real" one after practice)
        if !isProbablyPractice || practiceSwingCount >= 2 {
            startConfirmationTimer()
        }
    }
    
    /// Calculate distance between two coordinates in meters
    private func calculateDistance(from: (Double, Double), to: (Double, Double)) -> Double {
        let loc1 = CLLocation(latitude: from.0, longitude: from.1)
        let loc2 = CLLocation(latitude: to.0, longitude: to.1)
        return loc1.distance(from: loc2)
    }
    
    private func startConfirmationTimer() {
        confirmationTimer?.invalidate()
        
        confirmationTimer = Timer.scheduledTimer(withTimeInterval: confirmationDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // After delay, show confirmation UI
            DispatchQueue.main.async {
                self.swingConfirmationPending = true
                
                // Strong haptic to prompt user
                self.playHaptic(.notification)
                
                // Second buzz after short delay for emphasis
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.playHaptic(.notification)
                }
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    // MARK: - Debug/Training Methods
    
    /// Reset peak values (for calibration/testing)
    func resetPeakValues() {
        peakGForce = 0
        peakRotationRate = 0
    }
    
    /// Reset putt count for a new hole
    func resetPuttCount() {
        puttCount = 0
        lastPuttDetected = nil
    }
    
    /// Manually toggle putting mode (for user override)
    func togglePuttingMode() {
        isPuttingMode.toggle()
        playHaptic(.click)
        print("🏌️ Putting mode manually \(isPuttingMode ? "enabled" : "disabled")")
    }
    
    /// Get recent motion data for ML training export
    func getRecentMotionData() -> (accelerations: [Double], rotations: [Double]) {
        return (accelerationBuffer, rotationBuffer)
    }
}

// MARK: - Swing Analysis Helpers

extension MotionManager {
    
    /// Analyze the motion pattern to classify swing type
    /// Future: This could be replaced with a CoreML model
    func analyzeSwingPattern() -> SwingType {
        guard accelerationBuffer.count >= 20 else { return .unknown }
        
        let maxAccel = accelerationBuffer.max() ?? 0
        let avgAccel = accelerationBuffer.reduce(0, +) / Double(accelerationBuffer.count)
        
        // Very rough heuristics - would be replaced by ML model
        // Use both max and average acceleration for better classification
        if maxAccel > 12 && avgAccel > 3 {
            return .fullSwing // Driver/wood
        } else if maxAccel > 8 && avgAccel > 2 {
            return .ironSwing
        } else if maxAccel > 4 && avgAccel > 1 {
            return .chipOrPitch
        } else if maxAccel > 1.5 && avgAccel > 0.5 {
            return .putt
        }
        
        return .unknown
    }
}

// MARK: - Preferences Persistence

extension MotionManager {
    private static let preferencesKey = "swingPreferences"
    
    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
        }
        // Sync to swing detector
        swingDetector.preferences = preferences
    }
    
    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: Self.preferencesKey),
           let prefs = try? JSONDecoder().decode(SwingPreferences.self, from: data) {
            preferences = prefs
        }
    }
    
    /// Update a preference
    func updatePreference<T>(_ keyPath: WritableKeyPath<SwingPreferences, T>, value: T) {
        preferences[keyPath: keyPath] = value
        savePreferences()
    }
}

// MARK: - Audio Impact Detection

extension MotionManager {
    /// Start listening for impact sound (experimental)
    func startAudioDetection() {
        guard !audioDetectionEnabled else { return }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            audioDetectionEnabled = true
            print("🎤 Audio impact detection started")
        } catch {
            print("⚠️ Failed to start audio detection: \(error)")
        }
    }
    
    func stopAudioDetection() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        audioDetectionEnabled = false
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Analyze audio for impact signature
        // Impact sound is a sharp transient with specific frequency characteristics
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // Calculate RMS (volume level)
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameCount))
        
        // Detect sudden loud transient (potential ball impact)
        let impactThreshold: Float = 0.3
        if rms > impactThreshold {
            DispatchQueue.main.async {
                print("🔊 Potential impact sound detected (RMS: \(rms))")
                // Could be used to confirm swing detection
            }
        }
    }
}

// MARK: - Heart Rate Integration (for calm state detection)

extension MotionManager {
    /// Check if player is in calm state for putting
    func checkCalmState(heartRate: Double, restingHeartRate: Double) -> Bool {
        // Consider calm if within 15% of resting heart rate
        let threshold = restingHeartRate * 1.15
        return heartRate <= threshold
    }
    
    /// Get putting tip based on heart rate
    func getPuttingHeartRateTip(currentHR: Double, restingHR: Double) -> String? {
        let elevated = currentHR - restingHR
        
        if elevated > 20 {
            return "Heart rate elevated (+\(Int(elevated)) bpm). Take a deep breath."
        } else if elevated > 10 {
            return "Slightly elevated. Stay relaxed."
        }
        
        return nil
    }
}

// MARK: - Supporting Types

enum SwingType: String, Codable, CaseIterable {
    case fullSwing = "Full Swing"
    case ironSwing = "Iron"
    case chipOrPitch = "Chip/Pitch"
    case putt = "Putt"
    case unknown = "Unknown"
    
    var suggestedClubs: [String] {
        switch self {
        case .fullSwing:
            return ["Driver", "3W", "5W"]
        case .ironSwing:
            return ["4i", "5i", "6i", "7i", "8i", "9i"]
        case .chipOrPitch:
            return ["PW", "SW", "LW"]
        case .putt:
            return ["Putter"]
        case .unknown:
            return []
        }
    }
}
