import Foundation
import CoreGraphics
import Combine

/// Protocol defining common interface for body pose detection
/// Both 2D (Vision) and 3D (ARKit/LiDAR) implementations conform to this
protocol BodyPoseProvider: AnyObject {
    
    // MARK: - State Publishers
    
    var isDetecting: Bool { get }
    var currentPosePublisher: AnyPublisher<PoseFrame?, Never> { get }
    var alignmentStatusPublisher: AnyPublisher<AlignmentStatus, Never> { get }
    var alignmentMessagePublisher: AnyPublisher<String, Never> { get }
    
    // MARK: - Lifecycle
    
    func startDetecting()
    func stopDetecting()
    
    // MARK: - Capabilities
    
    /// Whether this provider supports 3D pose data
    var supports3D: Bool { get }
    
    /// Whether this provider requires specific hardware (e.g., LiDAR)
    var requiresSpecialHardware: Bool { get }
    
    /// Check if this provider is available on the current device
    static func isAvailable() -> Bool
}

// Note: BodyTrackingMode and Joint3D are defined in RangeModeModels.swift

/// Mutable pose frame builder for providers
struct PoseFrameBuilder {
    var timestamp: Date
    var frameIndex: Int
    var confidence: Float
    
    // 2D joints
    var nose: CGPoint?
    var leftShoulder: CGPoint?
    var rightShoulder: CGPoint?
    var leftElbow: CGPoint?
    var rightElbow: CGPoint?
    var leftWrist: CGPoint?
    var rightWrist: CGPoint?
    var leftHip: CGPoint?
    var rightHip: CGPoint?
    var leftKnee: CGPoint?
    var rightKnee: CGPoint?
    var leftAnkle: CGPoint?
    var rightAnkle: CGPoint?
    
    // Derived angles
    var spineAngle: Double?
    var hipRotation: Double?
    var shoulderRotation: Double?
    var leftArmAngle: Double?
    var rightArmAngle: Double?
    
    // 3D joints (ARKit mode only)
    var joints3D: [PoseJoint3D]?
    
    func build() -> PoseFrame {
        var frame = PoseFrame(
            timestamp: timestamp,
            frameIndex: frameIndex,
            confidence: confidence
        )
        
        frame.nose = nose
        frame.leftShoulder = leftShoulder
        frame.rightShoulder = rightShoulder
        frame.leftElbow = leftElbow
        frame.rightElbow = rightElbow
        frame.leftWrist = leftWrist
        frame.rightWrist = rightWrist
        frame.leftHip = leftHip
        frame.rightHip = rightHip
        frame.leftKnee = leftKnee
        frame.rightKnee = rightKnee
        frame.leftAnkle = leftAnkle
        frame.rightAnkle = rightAnkle
        
        frame.spineAngle = spineAngle
        frame.hipRotation = hipRotation
        frame.shoulderRotation = shoulderRotation
        frame.leftArmAngle = leftArmAngle
        frame.rightArmAngle = rightArmAngle
        
        frame.joints3D = joints3D
        
        return frame
    }
}
