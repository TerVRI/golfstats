import Foundation
import CoreGraphics

/// One-Euro Filter for smoothing noisy signals while preserving fast movements
/// Paper: "1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Interactive Systems"
/// by Géry Casiez, Nicolas Roussel, and Daniel Vogel (CHI 2012)
///
/// This is the industry-standard filter for pose estimation smoothing.
final class OneEuroFilter {
    
    // MARK: - Configuration
    
    /// Minimum cutoff frequency (Hz) - lower = more smoothing at low speeds
    private let minCutoff: Double
    
    /// Speed coefficient - higher = more smoothing reduction at high speeds
    private let beta: Double
    
    /// Derivative cutoff frequency (Hz) - for smoothing the velocity estimate
    private let dCutoff: Double
    
    // MARK: - State
    
    private var xFilter: LowPassFilter?
    private var dxFilter: LowPassFilter?
    private var lastTime: Date?
    
    // MARK: - Initialization
    
    /// Initialize the One-Euro Filter
    /// - Parameters:
    ///   - minCutoff: Minimum cutoff frequency (default 1.0 Hz). Lower = smoother at rest.
    ///   - beta: Speed coefficient (default 0.007). Higher = less smoothing during fast movements.
    ///   - dCutoff: Derivative cutoff frequency (default 1.0 Hz).
    init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    /// Filter a value
    /// - Parameters:
    ///   - value: The raw input value
    ///   - timestamp: The timestamp of this sample (default: now)
    /// - Returns: The filtered value
    func filter(_ value: Double, at timestamp: Date = Date()) -> Double {
        // Calculate time delta
        let dt: Double
        if let lastTime = lastTime {
            dt = max(timestamp.timeIntervalSince(lastTime), 0.001) // Prevent division by zero
        } else {
            // First sample - initialize filters
            xFilter = LowPassFilter(alpha: calculateAlpha(cutoff: minCutoff, dt: 1.0/30.0))
            xFilter?.filter(value)
            dxFilter = LowPassFilter(alpha: calculateAlpha(cutoff: dCutoff, dt: 1.0/30.0))
            dxFilter?.filter(0.0)
            lastTime = timestamp
            return value
        }
        
        lastTime = timestamp
        
        // Estimate velocity (derivative)
        let prevX = xFilter?.lastValue ?? value
        let dx = (value - prevX) / dt
        
        // Filter the derivative
        let edx = dxFilter?.filter(dx, alpha: calculateAlpha(cutoff: dCutoff, dt: dt)) ?? dx
        
        // Calculate adaptive cutoff based on speed
        let cutoff = minCutoff + beta * abs(edx)
        
        // Filter the value with adaptive alpha
        let alpha = calculateAlpha(cutoff: cutoff, dt: dt)
        return xFilter?.filter(value, alpha: alpha) ?? value
    }
    
    /// Reset the filter state
    func reset() {
        xFilter = nil
        dxFilter = nil
        lastTime = nil
    }
    
    // MARK: - Private
    
    private func calculateAlpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }
}

/// Simple low-pass filter used by One-Euro Filter
private final class LowPassFilter {
    var lastValue: Double?
    var alpha: Double
    
    init(alpha: Double) {
        self.alpha = alpha
    }
    
    @discardableResult
    func filter(_ value: Double, alpha: Double? = nil) -> Double {
        let a = alpha ?? self.alpha
        
        guard let lastValue = lastValue else {
            self.lastValue = value
            return value
        }
        
        let filtered = a * value + (1 - a) * lastValue
        self.lastValue = filtered
        return filtered
    }
}

// MARK: - CGPoint Extension

extension OneEuroFilter {
    /// A paired filter for 2D points
    final class Point {
        private let xFilter: OneEuroFilter
        private let yFilter: OneEuroFilter
        
        init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
            self.xFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
            self.yFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        }
        
        func filter(_ point: CGPoint, at timestamp: Date = Date()) -> CGPoint {
            return CGPoint(
                x: xFilter.filter(Double(point.x), at: timestamp),
                y: yFilter.filter(Double(point.y), at: timestamp)
            )
        }
        
        func reset() {
            xFilter.reset()
            yFilter.reset()
        }
    }
}

// MARK: - Pose Smoother

/// Smooths all joints in a pose using One-Euro Filters
final class PoseSmoother {
    
    // Filters for each joint
    private var jointFilters: [String: OneEuroFilter.Point] = [:]
    
    // Filter configuration optimized for golf swing analysis
    private let minCutoff: Double
    private let beta: Double
    private let dCutoff: Double
    
    /// Initialize the pose smoother
    /// - Parameters:
    ///   - minCutoff: Minimum cutoff frequency (default 1.5 Hz for golf swings)
    ///   - beta: Speed coefficient (default 0.5 - allows fast swing movements)
    ///   - dCutoff: Derivative cutoff frequency (default 1.0 Hz)
    init(minCutoff: Double = 1.5, beta: Double = 0.5, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    /// Smooth a pose frame
    /// - Parameter pose: The raw pose frame
    /// - Returns: A smoothed pose frame
    func smooth(_ pose: PoseFrame) -> PoseFrame {
        var smoothed = pose
        let timestamp = pose.timestamp
        
        // Smooth each joint
        smoothed.nose = smoothJoint("nose", pose.nose, at: timestamp)
        smoothed.leftShoulder = smoothJoint("leftShoulder", pose.leftShoulder, at: timestamp)
        smoothed.rightShoulder = smoothJoint("rightShoulder", pose.rightShoulder, at: timestamp)
        smoothed.leftElbow = smoothJoint("leftElbow", pose.leftElbow, at: timestamp)
        smoothed.rightElbow = smoothJoint("rightElbow", pose.rightElbow, at: timestamp)
        smoothed.leftWrist = smoothJoint("leftWrist", pose.leftWrist, at: timestamp)
        smoothed.rightWrist = smoothJoint("rightWrist", pose.rightWrist, at: timestamp)
        smoothed.leftHip = smoothJoint("leftHip", pose.leftHip, at: timestamp)
        smoothed.rightHip = smoothJoint("rightHip", pose.rightHip, at: timestamp)
        smoothed.leftKnee = smoothJoint("leftKnee", pose.leftKnee, at: timestamp)
        smoothed.rightKnee = smoothJoint("rightKnee", pose.rightKnee, at: timestamp)
        smoothed.leftAnkle = smoothJoint("leftAnkle", pose.leftAnkle, at: timestamp)
        smoothed.rightAnkle = smoothJoint("rightAnkle", pose.rightAnkle, at: timestamp)
        
        return smoothed
    }
    
    /// Reset all filters (call when tracking is lost)
    func reset() {
        jointFilters.removeAll()
    }
    
    /// Reset filter for a specific joint (when that joint is lost)
    func resetJoint(_ name: String) {
        jointFilters[name]?.reset()
    }
    
    // MARK: - Private
    
    private func smoothJoint(_ name: String, _ point: CGPoint?, at timestamp: Date) -> CGPoint? {
        guard let point = point else {
            // Joint not detected - reset its filter for next detection
            jointFilters[name]?.reset()
            return nil
        }
        
        // Get or create filter for this joint
        let filter: OneEuroFilter.Point
        if let existing = jointFilters[name] {
            filter = existing
        } else {
            filter = OneEuroFilter.Point(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
            jointFilters[name] = filter
        }
        
        return filter.filter(point, at: timestamp)
    }
}
