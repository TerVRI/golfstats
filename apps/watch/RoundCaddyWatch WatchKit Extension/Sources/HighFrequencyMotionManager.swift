import Foundation
import CoreMotion
import Combine
import Accelerate

/// High-frequency motion manager for precise golf swing analysis
/// Uses CMBatchedSensorManager for up to 800Hz sampling when available
class HighFrequencyMotionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isCollecting = false
    @Published var sampleRate: Int = 100 // Current effective sample rate
    @Published var latestAcceleration: SIMD3<Double> = .zero
    @Published var latestRotation: SIMD3<Double> = .zero
    @Published var filteredAcceleration: SIMD3<Double> = .zero
    
    // MARK: - Configuration
    
    /// Target sample rate (Hz)
    let targetSampleRate: Int = 200
    
    /// Whether high-frequency batched collection is available
    var isHighFrequencyAvailable: Bool {
        if #available(watchOS 9.0, *) {
            return CMBatchedSensorManager.isAccelerometerSupported &&
                   CMBatchedSensorManager.isDeviceMotionSupported
        }
        return false
    }
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    @available(watchOS 9.0, *)
    private lazy var batchedManager = CMBatchedSensorManager()
    
    // Kalman filter state
    private var kalmanFilter = KalmanFilter3D()
    
    // Data buffers for swing analysis
    private var accelerationHistory: [SIMD3<Double>] = []
    private var rotationHistory: [SIMD3<Double>] = []
    private var timestampHistory: [TimeInterval] = []
    private let maxHistorySize = 1000 // ~5 seconds at 200Hz
    
    // Callbacks
    var onMotionUpdate: ((SIMD3<Double>, SIMD3<Double>, TimeInterval) -> Void)?
    var onSwingDetected: (([SIMD3<Double>], [SIMD3<Double>]) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        configureSampling()
    }
    
    private func configureSampling() {
        // Configure standard motion manager as fallback
        motionManager.deviceMotionUpdateInterval = 1.0 / Double(targetSampleRate)
        motionManager.accelerometerUpdateInterval = 1.0 / Double(targetSampleRate)
        motionManager.gyroUpdateInterval = 1.0 / Double(targetSampleRate)
    }
    
    // MARK: - Collection Control
    
    /// Start high-frequency motion collection
    func startCollection() {
        guard !isCollecting else { return }
        
        clearHistory()
        kalmanFilter.reset()
        
        if #available(watchOS 9.0, *), isHighFrequencyAvailable {
            startBatchedCollection()
        } else {
            startStandardCollection()
        }
        
        isCollecting = true
        print("📊 High-frequency motion collection started (\(sampleRate)Hz)")
    }
    
    /// Stop motion collection
    func stopCollection() {
        if #available(watchOS 9.0, *) {
            batchedManager.stopAccelerometerUpdates()
            batchedManager.stopDeviceMotionUpdates()
        }
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        
        isCollecting = false
        print("📊 Motion collection stopped")
    }
    
    // MARK: - Batched Collection (watchOS 9+)
    
    @available(watchOS 9.0, *)
    private func startBatchedCollection() {
        sampleRate = 200 // Batched mode typically provides ~200Hz
        
        // Start batched device motion
        batchedManager.startDeviceMotionUpdates(handler: { [weak self] motionData, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Batched motion error: \(error)")
                return
            }
            
            guard let data = motionData else { return }
            
            // Process batch of samples
            for sample in data {
                self.processSample(
                    acceleration: SIMD3(sample.userAcceleration.x,
                                       sample.userAcceleration.y,
                                       sample.userAcceleration.z),
                    rotation: SIMD3(sample.rotationRate.x,
                                   sample.rotationRate.y,
                                   sample.rotationRate.z),
                    timestamp: sample.timestamp
                )
            }
        })
    }
    
    // MARK: - Standard Collection (Fallback)
    
    private func startStandardCollection() {
        sampleRate = targetSampleRate
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            self.processSample(
                acceleration: SIMD3(motion.userAcceleration.x,
                                   motion.userAcceleration.y,
                                   motion.userAcceleration.z),
                rotation: SIMD3(motion.rotationRate.x,
                               motion.rotationRate.y,
                               motion.rotationRate.z),
                timestamp: motion.timestamp
            )
        }
    }
    
    // MARK: - Sample Processing
    
    private func processSample(
        acceleration: SIMD3<Double>,
        rotation: SIMD3<Double>,
        timestamp: TimeInterval
    ) {
        // Apply Kalman filter to reduce noise
        let filtered = kalmanFilter.update(measurement: acceleration)
        
        // Store raw values
        latestAcceleration = acceleration
        latestRotation = rotation
        filteredAcceleration = filtered
        
        // Add to history
        accelerationHistory.append(filtered)
        rotationHistory.append(rotation)
        timestampHistory.append(timestamp)
        
        // Trim history
        if accelerationHistory.count > maxHistorySize {
            accelerationHistory.removeFirst()
            rotationHistory.removeFirst()
            timestampHistory.removeFirst()
        }
        
        // Notify callback
        onMotionUpdate?(filtered, rotation, timestamp)
        
        // Check for swing pattern
        detectSwingInHistory()
    }
    
    // MARK: - Swing Detection
    
    private func detectSwingInHistory() {
        guard accelerationHistory.count >= 50 else { return }
        
        // Look for swing signature in recent samples
        let recentAccel = Array(accelerationHistory.suffix(50))
        let magnitudes = recentAccel.map { simd_length($0) }
        
        // Detect peak (impact)
        guard let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) else { return }
        let peakMagnitude = magnitudes[maxIndex]
        
        // Swing detection: high peak followed by sharp drop
        if peakMagnitude > 8.0 && maxIndex > 10 && maxIndex < 40 {
            // Check for deceleration after peak
            let afterPeak = Array(magnitudes[(maxIndex + 1)...])
            if let minAfter = afterPeak.min(), peakMagnitude - minAfter > 5.0 {
                // Swing detected!
                let swingAccel = Array(accelerationHistory.suffix(100))
                let swingRotation = Array(rotationHistory.suffix(100))
                
                DispatchQueue.main.async {
                    self.onSwingDetected?(swingAccel, swingRotation)
                }
                
                // Clear recent history to avoid re-detection
                let keepCount = max(0, accelerationHistory.count - 100)
                accelerationHistory = Array(accelerationHistory.prefix(keepCount))
                rotationHistory = Array(rotationHistory.prefix(keepCount))
                timestampHistory = Array(timestampHistory.prefix(keepCount))
            }
        }
    }
    
    // MARK: - Analysis Methods
    
    /// Get swing data for analysis
    func getSwingData() -> (accelerations: [SIMD3<Double>], rotations: [SIMD3<Double>], timestamps: [TimeInterval]) {
        return (accelerationHistory, rotationHistory, timestampHistory)
    }
    
    /// Calculate impact metrics from swing data
    func analyzeImpact(_ accelerations: [SIMD3<Double>]) -> ImpactAnalysis {
        let magnitudes = accelerations.map { simd_length($0) }
        
        guard let peakIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) else {
            return ImpactAnalysis(detected: false, peakG: 0, decelerationG: 0, impactIndex: 0)
        }
        
        let peakG = magnitudes[peakIndex]
        
        // Calculate deceleration
        var maxDecel: Double = 0
        if peakIndex < magnitudes.count - 5 {
            for i in (peakIndex + 1)..<min(peakIndex + 10, magnitudes.count) {
                let decel = peakG - magnitudes[i]
                maxDecel = max(maxDecel, decel)
            }
        }
        
        return ImpactAnalysis(
            detected: peakG > 8.0 && maxDecel > 5.0,
            peakG: peakG,
            decelerationG: maxDecel,
            impactIndex: peakIndex
        )
    }
    
    // MARK: - Utilities
    
    private func clearHistory() {
        accelerationHistory.removeAll()
        rotationHistory.removeAll()
        timestampHistory.removeAll()
    }
}

// MARK: - Impact Analysis

struct ImpactAnalysis {
    let detected: Bool
    let peakG: Double
    let decelerationG: Double
    let impactIndex: Int
    
    var confidence: Double {
        // Higher G-force and deceleration = higher confidence
        let gScore = min(peakG / 15.0, 1.0)
        let decelScore = min(decelerationG / 8.0, 1.0)
        return (gScore + decelScore) / 2.0
    }
}

// MARK: - Kalman Filter

/// 3D Kalman filter for smoothing acceleration data
class KalmanFilter3D {
    // State estimate
    private var x: SIMD3<Double> = .zero
    
    // Estimate covariance
    private var P: Double = 1.0
    
    // Process noise
    private let Q: Double = 0.1
    
    // Measurement noise
    private let R: Double = 0.5
    
    /// Update filter with new measurement
    func update(measurement: SIMD3<Double>) -> SIMD3<Double> {
        // Predict
        // x_pred = x (no control input)
        // P_pred = P + Q
        let P_pred = P + Q
        
        // Update
        // K = P_pred / (P_pred + R)
        let K = P_pred / (P_pred + R)
        
        // x = x_pred + K * (z - x_pred)
        x = x + K * (measurement - x)
        
        // P = (1 - K) * P_pred
        P = (1 - K) * P_pred
        
        return x
    }
    
    /// Reset filter state
    func reset() {
        x = .zero
        P = 1.0
    }
}

// MARK: - Advanced Swing Analysis Extension

extension HighFrequencyMotionManager {
    
    /// Analyze swing tempo from high-frequency data
    func analyzeTempoHighPrecision(_ accelerations: [SIMD3<Double>], _ timestamps: [TimeInterval]) -> (backswing: TimeInterval, downswing: TimeInterval)? {
        guard accelerations.count >= 50, timestamps.count >= 50 else { return nil }
        
        let magnitudes = accelerations.map { simd_length($0) }
        
        // Find key points
        // 1. Backswing start: first significant acceleration
        // 2. Top of swing: velocity reversal (local minimum in acceleration)
        // 3. Impact: peak acceleration
        
        var backswingStart: Int?
        var topOfSwing: Int?
        var impact: Int?
        
        // Find backswing start (first point > 1.5G)
        for i in 0..<magnitudes.count {
            if magnitudes[i] > 1.5 {
                backswingStart = i
                break
            }
        }
        
        guard let start = backswingStart else { return nil }
        
        // Find impact (peak)
        var maxMag: Double = 0
        for i in start..<magnitudes.count {
            if magnitudes[i] > maxMag {
                maxMag = magnitudes[i]
                impact = i
            }
        }
        
        guard let impactIdx = impact, impactIdx > start + 10 else { return nil }
        
        // Find top of swing (local minimum between start and impact)
        var minMag: Double = Double.greatestFiniteMagnitude
        for i in (start + 5)..<(impactIdx - 5) {
            if magnitudes[i] < minMag {
                minMag = magnitudes[i]
                topOfSwing = i
            }
        }
        
        guard let top = topOfSwing else { return nil }
        
        // Calculate durations
        let backswingDuration = timestamps[top] - timestamps[start]
        let downswingDuration = timestamps[impactIdx] - timestamps[top]
        
        return (backswingDuration, downswingDuration)
    }
    
    /// Analyze swing path from rotation data
    func analyzeSwingPath(_ rotations: [SIMD3<Double>]) -> SwingPath {
        guard rotations.count >= 30 else { return .unknown }
        
        // Analyze rotation during downswing (last 30 samples before impact)
        let downswingRotations = Array(rotations.suffix(30))
        
        // X-axis rotation indicates in-out path
        let avgXRotation = downswingRotations.reduce(0.0) { $0 + $1.x } / Double(downswingRotations.count)
        
        if avgXRotation > 3.0 {
            return .insideOut
        } else if avgXRotation < -3.0 {
            return .overTheTop
        }
        return .neutral
    }
}

// MARK: - Debug View

import SwiftUI

struct HighFrequencyDebugView: View {
    @ObservedObject var manager: HighFrequencyMotionManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(manager.isCollecting ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("\(manager.sampleRate)Hz")
                    .font(.caption)
                    .monospacedDigit()
            }
            
            // Acceleration
            VStack(alignment: .leading, spacing: 2) {
                Text("Accel (filtered)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("X: \(String(format: "%.2f", manager.filteredAcceleration.x))")
                    Text("Y: \(String(format: "%.2f", manager.filteredAcceleration.y))")
                    Text("Z: \(String(format: "%.2f", manager.filteredAcceleration.z))")
                }
                .font(.caption)
                .monospacedDigit()
            }
            
            // Magnitude
            let mag = simd_length(manager.filteredAcceleration)
            Text("Magnitude: \(String(format: "%.2f", mag))G")
                .font(.caption)
                .foregroundColor(mag > 6 ? .red : mag > 3 ? .orange : .green)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
