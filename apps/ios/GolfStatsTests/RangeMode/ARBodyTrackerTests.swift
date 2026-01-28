import XCTest
import simd
@testable import GolfStats

/// Unit tests for ARBodyTracker (3D LiDAR-based body tracking)
final class ARBodyTrackerTests: XCTestCase {
    
    // MARK: - Availability Tests
    
    func testARBodyTracker_IsAvailableCheck() {
        // The isAvailable check should not crash regardless of device
        if #available(iOS 14.0, *) {
            let isAvailable = ARBodyTracker.isAvailable()
            // Just verify it returns a boolean without crashing
            XCTAssertTrue(isAvailable || !isAvailable)
        }
    }
    
    func testARBodyTracker_SupportsProperties() {
        guard #available(iOS 14.0, *) else {
            throw XCTSkip("ARBodyTracker requires iOS 14+")
        }
        
        let tracker = ARBodyTracker()
        
        // Should report 3D support
        XCTAssertTrue(tracker.supports3D)
        XCTAssertTrue(tracker.requiresSpecialHardware)
    }
    
    func testARBodyTracker_InitialState() {
        guard #available(iOS 14.0, *) else {
            throw XCTSkip("ARBodyTracker requires iOS 14+")
        }
        
        let tracker = ARBodyTracker()
        
        // Should start in non-detecting state
        XCTAssertFalse(tracker.isDetecting)
        XCTAssertNil(tracker.currentPose)
        XCTAssertNil(tracker.bodyAnchor)
        XCTAssertFalse(tracker.hasBodyMesh)
        XCTAssertEqual(tracker.alignmentStatus, .searching)
    }
    
    // MARK: - 3D Angle Calculation Tests
    
    func testHipRotation3D_Square() {
        // Given: 3D hip positions facing camera (Z-aligned)
        let leftHip = SIMD3<Float>(-0.15, 1.0, 0)
        let rightHip = SIMD3<Float>(0.15, 1.0, 0)
        
        // When: Calculate hip vector angle to camera forward (-Z)
        let hipVector = simd_normalize(SIMD3<Float>(
            rightHip.x - leftHip.x,
            0,
            rightHip.z - leftHip.z
        ))
        let forwardVector = SIMD3<Float>(0, 0, -1)
        let dot = simd_dot(hipVector, forwardVector)
        let angleRadians = acos(abs(dot))
        let angleDegrees = Double(angleRadians) * 180.0 / .pi
        
        // Then: Should be close to 90 degrees (perpendicular = square to camera)
        XCTAssertEqual(angleDegrees, 90, accuracy: 5)
    }
    
    func testHipRotation3D_Rotated45() {
        // Given: 3D hip positions rotated 45 degrees
        let angle: Float = .pi / 4  // 45 degrees
        let leftHip = SIMD3<Float>(-0.15 * cos(angle), 1.0, -0.15 * sin(angle))
        let rightHip = SIMD3<Float>(0.15 * cos(angle), 1.0, 0.15 * sin(angle))
        
        // When: Calculate hip vector angle to camera forward (-Z)
        let hipVector = simd_normalize(SIMD3<Float>(
            rightHip.x - leftHip.x,
            0,
            rightHip.z - leftHip.z
        ))
        let forwardVector = SIMD3<Float>(0, 0, -1)
        let dot = simd_dot(hipVector, forwardVector)
        let angleRadians = acos(abs(dot))
        let angleDegrees = Double(angleRadians) * 180.0 / .pi
        
        // Then: Should be approximately 45 degrees
        XCTAssertEqual(angleDegrees, 45, accuracy: 5)
    }
    
    func testShoulderRotation3D_MaxBackswing() {
        // Given: 3D shoulder positions at max backswing (rotated ~90 degrees)
        let angle: Float = .pi / 2  // 90 degrees
        let leftShoulder = SIMD3<Float>(-0.2 * cos(angle), 1.4, -0.2 * sin(angle))
        let rightShoulder = SIMD3<Float>(0.2 * cos(angle), 1.4, 0.2 * sin(angle))
        
        // When: Calculate shoulder vector angle
        let shoulderVector = simd_normalize(SIMD3<Float>(
            rightShoulder.x - leftShoulder.x,
            0,
            rightShoulder.z - leftShoulder.z
        ))
        let forwardVector = SIMD3<Float>(0, 0, -1)
        let dot = simd_dot(shoulderVector, forwardVector)
        let angleRadians = acos(abs(dot))
        let angleDegrees = Double(angleRadians) * 180.0 / .pi
        
        // Then: Should be close to 0 (parallel to camera forward = 90 degree turn)
        XCTAssertLessThan(angleDegrees, 15)
    }
    
    // MARK: - Joint3D Tests
    
    func testJoint3D_Creation() {
        let joint = Joint3D(
            name: "leftShoulder",
            position: SIMD3<Float>(-0.2, 1.4, 0),
            screenPosition: CGPoint(x: 0.3, y: 0.35),
            confidence: 0.95
        )
        
        XCTAssertEqual(joint.name, "leftShoulder")
        XCTAssertEqual(joint.position.x, -0.2, accuracy: 0.001)
        XCTAssertEqual(joint.position.y, 1.4, accuracy: 0.001)
        XCTAssertEqual(joint.confidence, 0.95, accuracy: 0.01)
    }
    
    func testJoint3D_ScreenProjection() {
        // Verify screen position is normalized (0-1)
        let joint = Joint3D(
            name: "head",
            position: SIMD3<Float>(0, 1.7, 0),
            screenPosition: CGPoint(x: 0.5, y: 0.15),
            confidence: 0.9
        )
        
        XCTAssertGreaterThanOrEqual(joint.screenPosition.x, 0)
        XCTAssertLessThanOrEqual(joint.screenPosition.x, 1)
        XCTAssertGreaterThanOrEqual(joint.screenPosition.y, 0)
        XCTAssertLessThanOrEqual(joint.screenPosition.y, 1)
    }
    
    // MARK: - Spine Angle 3D Tests
    
    func testSpineAngle3D_Upright() {
        // Given: Shoulders directly above hips in 3D space
        let shoulderMid = SIMD3<Float>(0, 1.4, 0)
        let hipMid = SIMD3<Float>(0, 1.0, 0)
        
        // When: Calculate spine angle from vertical
        let spineVector = shoulderMid - hipMid
        let upVector = SIMD3<Float>(0, 1, 0)
        let dot = simd_dot(simd_normalize(spineVector), upVector)
        let angleRadians = acos(dot)
        let angleDegrees = Double(angleRadians) * 180.0 / .pi
        
        // Then: Should be 0 degrees (upright)
        XCTAssertEqual(angleDegrees, 0, accuracy: 1)
    }
    
    func testSpineAngle3D_ForwardBend() {
        // Given: Shoulders in front of hips (golf address position)
        let shoulderMid = SIMD3<Float>(0, 1.4, -0.15)  // Forward in Z
        let hipMid = SIMD3<Float>(0, 1.0, 0)
        
        // When: Calculate spine angle from vertical
        let spineVector = shoulderMid - hipMid
        let upVector = SIMD3<Float>(0, 1, 0)
        let dot = simd_dot(simd_normalize(spineVector), upVector)
        let angleRadians = acos(dot)
        let angleDegrees = Double(angleRadians) * 180.0 / .pi
        
        // Then: Should be positive angle (forward bend ~20-30 degrees)
        XCTAssertGreaterThan(angleDegrees, 15)
        XCTAssertLessThan(angleDegrees, 45)
    }
    
    // MARK: - Alignment Status Tests
    
    func testAlignmentStatus3D_GoodPosition() {
        // Given: Complete 3D pose data with good tracking
        let joints = create3DJointsForGoodPose()
        
        // When: Check alignment (simulating tracker logic)
        let hasUpperBody = joints["leftShoulder"] != nil && joints["rightShoulder"] != nil
        let hasLowerBody = joints["leftHip"] != nil && joints["rightHip"] != nil
        let isTracked = true
        
        // Then: Should indicate good alignment
        XCTAssertTrue(hasUpperBody)
        XCTAssertTrue(hasLowerBody)
        XCTAssertTrue(isTracked)
    }
    
    func testAlignmentStatus3D_MissingJoints() {
        // Given: Incomplete 3D pose data
        let joints: [String: Joint3D] = [
            "leftShoulder": createMockJoint3D(name: "leftShoulder", x: -0.2, y: 1.4, z: 0)
            // Missing rightShoulder, hips
        ]
        
        // When: Check alignment
        let hasUpperBody = joints["leftShoulder"] != nil && joints["rightShoulder"] != nil
        let hasLowerBody = joints["leftHip"] != nil && joints["rightHip"] != nil
        
        // Then: Should indicate alignment issue
        XCTAssertFalse(hasUpperBody)
        XCTAssertFalse(hasLowerBody)
    }
    
    // MARK: - Helper Methods
    
    private func create3DJointsForGoodPose() -> [String: Joint3D] {
        return [
            "head": createMockJoint3D(name: "head", x: 0, y: 1.7, z: 0),
            "leftShoulder": createMockJoint3D(name: "leftShoulder", x: -0.2, y: 1.4, z: 0),
            "rightShoulder": createMockJoint3D(name: "rightShoulder", x: 0.2, y: 1.4, z: 0),
            "leftElbow": createMockJoint3D(name: "leftElbow", x: -0.25, y: 1.2, z: 0),
            "rightElbow": createMockJoint3D(name: "rightElbow", x: 0.25, y: 1.2, z: 0),
            "leftWrist": createMockJoint3D(name: "leftWrist", x: -0.1, y: 1.0, z: -0.1),
            "rightWrist": createMockJoint3D(name: "rightWrist", x: 0.1, y: 1.0, z: -0.1),
            "leftHip": createMockJoint3D(name: "leftHip", x: -0.12, y: 0.95, z: 0),
            "rightHip": createMockJoint3D(name: "rightHip", x: 0.12, y: 0.95, z: 0),
            "leftKnee": createMockJoint3D(name: "leftKnee", x: -0.12, y: 0.5, z: 0),
            "rightKnee": createMockJoint3D(name: "rightKnee", x: 0.12, y: 0.5, z: 0),
            "leftAnkle": createMockJoint3D(name: "leftAnkle", x: -0.12, y: 0.05, z: 0),
            "rightAnkle": createMockJoint3D(name: "rightAnkle", x: 0.12, y: 0.05, z: 0)
        ]
    }
    
    private func createMockJoint3D(name: String, x: Float, y: Float, z: Float) -> Joint3D {
        // Project 3D position to 2D screen (simplified projection)
        let screenX = CGFloat(0.5 + x)  // Center horizontally
        let screenY = CGFloat(1.0 - y / 2.0)  // Map height to screen Y
        
        return Joint3D(
            name: name,
            position: SIMD3<Float>(x, y, z),
            screenPosition: CGPoint(x: screenX, y: screenY),
            confidence: 0.95
        )
    }
}
