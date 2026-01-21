import Foundation
import CoreMotion
import Combine

/// Manages power consumption for motion detection
/// Uses event-driven sampling: low-power idle → high-frequency when motion detected
class PowerManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentMode: PowerMode = .idle
    @Published var batteryLevel: Float = 1.0
    @Published var estimatedRemainingTime: TimeInterval = 0 // seconds
    
    // Statistics
    @Published var totalHighFreqSeconds: TimeInterval = 0
    @Published var totalIdleSeconds: TimeInterval = 0
    
    // MARK: - Configuration
    
    /// Sampling rates for different modes
    struct SamplingConfig {
        static let idleRate: TimeInterval = 1.0 / 10.0      // 10Hz when idle
        static let activeRate: TimeInterval = 1.0 / 100.0   // 100Hz during swing
        static let highFreqRate: TimeInterval = 1.0 / 200.0 // 200Hz for precise impact
    }
    
    /// Motion threshold to wake from idle (G-force)
    private let wakeThreshold: Double = 1.5
    
    /// Motion threshold to enter high-frequency mode
    private let highFreqThreshold: Double = 4.0
    
    /// Time to stay in active mode after motion stops (seconds)
    private let activeTimeout: TimeInterval = 5.0
    
    /// Time to stay in high-freq mode after peak (seconds)
    private let highFreqTimeout: TimeInterval = 2.0
    
    // MARK: - Private State
    
    private let motionManager = CMMotionManager()
    private var lastMotionTime: Date?
    private var lastHighMotionTime: Date?
    private var modeTimer: Timer?
    private var statsTimer: Timer?
    private var modeStartTime: Date?
    
    // Callback when motion is detected (to trigger swing detection)
    var onMotionDetected: ((CMDeviceMotion) -> Void)?
    var onModeChange: ((PowerMode) -> Void)?
    
    // MARK: - Power Modes
    
    enum PowerMode: String {
        case idle = "Idle"           // Very low power, minimal sampling
        case listening = "Listening" // Low power, watching for motion
        case active = "Active"       // Medium power, tracking motion
        case highFrequency = "High"  // Full power, precise tracking
        case paused = "Paused"       // No sampling (battery critical)
        
        var samplingInterval: TimeInterval {
            switch self {
            case .idle, .paused:
                return SamplingConfig.idleRate
            case .listening:
                return SamplingConfig.idleRate
            case .active:
                return SamplingConfig.activeRate
            case .highFrequency:
                return SamplingConfig.highFreqRate
            }
        }
        
        var description: String {
            switch self {
            case .idle: return "Conserving battery"
            case .listening: return "Listening for swings"
            case .active: return "Tracking motion"
            case .highFrequency: return "Precise tracking"
            case .paused: return "Paused (low battery)"
            }
        }
        
        var powerDraw: Double { // Relative power consumption
            switch self {
            case .idle, .paused: return 0.1
            case .listening: return 0.2
            case .active: return 0.6
            case .highFrequency: return 1.0
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        startStatsTimer()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// Start power-managed motion detection
    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available")
            return
        }
        
        transitionTo(.listening)
        print("🔋 Power manager started in listening mode")
    }
    
    /// Stop all motion detection
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        modeTimer?.invalidate()
        modeTimer = nil
        transitionTo(.idle)
        print("🔋 Power manager stopped")
    }
    
    /// Pause detection (for battery saving)
    func pause() {
        motionManager.stopDeviceMotionUpdates()
        transitionTo(.paused)
    }
    
    /// Resume detection
    func resume() {
        transitionTo(.listening)
    }
    
    /// Force high-frequency mode (e.g., user is about to swing)
    func forceHighFrequency(duration: TimeInterval = 3.0) {
        transitionTo(.highFrequency)
        
        // Auto-return to active after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if self?.currentMode == .highFrequency {
                self?.transitionTo(.active)
            }
        }
    }
    
    // MARK: - Mode Transitions
    
    private func transitionTo(_ newMode: PowerMode) {
        guard newMode != currentMode else { return }
        
        let oldMode = currentMode
        
        // Update stats for old mode
        if let start = modeStartTime {
            let duration = Date().timeIntervalSince(start)
            if oldMode == .highFrequency {
                totalHighFreqSeconds += duration
            } else if oldMode == .idle || oldMode == .listening {
                totalIdleSeconds += duration
            }
        }
        
        currentMode = newMode
        modeStartTime = Date()
        
        // Update sampling rate
        motionManager.deviceMotionUpdateInterval = newMode.samplingInterval
        
        // Start/restart motion updates if needed
        if newMode != .idle && newMode != .paused {
            startMotionUpdates()
        }
        
        // Start mode timeout timer
        startModeTimer(for: newMode)
        
        onModeChange?(newMode)
        print("🔋 Mode: \(oldMode.rawValue) → \(newMode.rawValue) (\(Int(1/newMode.samplingInterval))Hz)")
    }
    
    private func startMotionUpdates() {
        // Stop existing updates first
        motionManager.stopDeviceMotionUpdates()
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
    }
    
    private func startModeTimer(for mode: PowerMode) {
        modeTimer?.invalidate()
        
        switch mode {
        case .active:
            // Return to listening if no motion for activeTimeout
            modeTimer = Timer.scheduledTimer(withTimeInterval: activeTimeout, repeats: false) { [weak self] _ in
                self?.checkForIdleTransition()
            }
            
        case .highFrequency:
            // Return to active after highFreqTimeout
            modeTimer = Timer.scheduledTimer(withTimeInterval: highFreqTimeout, repeats: false) { [weak self] _ in
                self?.transitionTo(.active)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Motion Processing
    
    private func processMotion(_ motion: CMDeviceMotion) {
        let accel = motion.userAcceleration
        let totalAccel = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))
        
        let now = Date()
        
        // Check for mode transitions based on motion
        switch currentMode {
        case .listening:
            if totalAccel > wakeThreshold {
                lastMotionTime = now
                transitionTo(.active)
            }
            
        case .active:
            if totalAccel > highFreqThreshold {
                lastHighMotionTime = now
                transitionTo(.highFrequency)
            } else if totalAccel > wakeThreshold {
                lastMotionTime = now
            }
            
        case .highFrequency:
            if totalAccel > highFreqThreshold {
                lastHighMotionTime = now
                // Extend high-freq mode
                startModeTimer(for: .highFrequency)
            }
            
        default:
            break
        }
        
        // Forward motion data to callback
        if currentMode == .active || currentMode == .highFrequency {
            onMotionDetected?(motion)
        }
    }
    
    private func checkForIdleTransition() {
        guard let lastMotion = lastMotionTime else {
            transitionTo(.listening)
            return
        }
        
        let timeSinceMotion = Date().timeIntervalSince(lastMotion)
        if timeSinceMotion > activeTimeout {
            transitionTo(.listening)
        } else {
            // Check again later
            let remaining = activeTimeout - timeSinceMotion
            modeTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                self?.checkForIdleTransition()
            }
        }
    }
    
    // MARK: - Battery Estimation
    
    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateBatteryEstimate()
        }
    }
    
    private func updateBatteryEstimate() {
        // Get actual battery level from device
        #if os(watchOS)
        // WatchOS doesn't expose battery level directly
        // We estimate based on usage patterns
        #endif
        
        // Estimate remaining time based on power draw
        let totalTime = totalHighFreqSeconds + totalIdleSeconds
        guard totalTime > 60 else { return } // Need at least 1 min of data
        
        let avgPowerDraw = (totalHighFreqSeconds * PowerMode.highFrequency.powerDraw +
                          totalIdleSeconds * PowerMode.idle.powerDraw) / totalTime
        
        // Assume 8 hours at full power draw
        let fullPowerHours: TimeInterval = 8 * 3600
        estimatedRemainingTime = (fullPowerHours / avgPowerDraw) * Double(batteryLevel)
    }
    
    // MARK: - Statistics
    
    var powerEfficiency: Double {
        let total = totalHighFreqSeconds + totalIdleSeconds
        guard total > 0 else { return 1.0 }
        return totalIdleSeconds / total
    }
    
    var formattedEfficiency: String {
        return String(format: "%.0f%%", powerEfficiency * 100)
    }
    
    var formattedRemainingTime: String {
        let hours = Int(estimatedRemainingTime) / 3600
        let minutes = (Int(estimatedRemainingTime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Battery Status View

import SwiftUI

struct BatteryStatusView: View {
    @ObservedObject var powerManager: PowerManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                Text(powerManager.currentMode.rawValue)
                    .font(.caption)
            }
            
            Text(powerManager.currentMode.description)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack {
                    Text(powerManager.formattedEfficiency)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Efficiency")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(powerManager.formattedRemainingTime)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Est. Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var batteryIcon: String {
        switch powerManager.currentMode {
        case .idle, .paused: return "battery.100"
        case .listening: return "battery.75"
        case .active: return "battery.50"
        case .highFrequency: return "battery.25"
        }
    }
    
    var batteryColor: Color {
        switch powerManager.currentMode {
        case .idle, .listening: return .green
        case .active: return .yellow
        case .highFrequency: return .orange
        case .paused: return .red
        }
    }
}
