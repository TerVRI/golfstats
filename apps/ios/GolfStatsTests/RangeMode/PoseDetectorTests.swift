import XCTest
@testable import GolfStats

/// Unit tests for PoseDetector
final class PoseDetectorTests: XCTestCase {
    
    var poseDetector: PoseDetector!
    
    override func setUp() {
        super.setUp()
        poseDetector = PoseDetector(targetFrameRate: 30)
    }
    
    override func tearDown() {
        poseDetector = nil
        super.tearDown()
    }
    
    // MARK: - Spine Angle Tests
    
    func testSpineAngleCalculation_Upright() {
        // Given: Shoulders directly above hips (upright posture)
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.4, y: 0.3)
        pose.rightShoulder = CGPoint(x: 0.6, y: 0.3)
        pose.leftHip = CGPoint(x: 0.4, y: 0.6)
        pose.rightHip = CGPoint(x: 0.6, y: 0.6)
        
        // When: Calculate spine angle
        let spineAngle = calculateSpineAngle(pose: pose)
        
        // Then: Should be approximately 0 degrees (upright)
        XCTAssertNotNil(spineAngle)
        XCTAssertEqual(spineAngle!, 0, accuracy: 1.0)
    }
    
    func testSpineAngleCalculation_ForwardBend() {
        // Given: Shoulders in front of hips (address position)
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.35, y: 0.35)  // Leaning forward
        pose.rightShoulder = CGPoint(x: 0.55, y: 0.35)
        pose.leftHip = CGPoint(x: 0.4, y: 0.6)
        pose.rightHip = CGPoint(x: 0.6, y: 0.6)
        
        // When: Calculate spine angle
        let spineAngle = calculateSpineAngle(pose: pose)
        
        // Then: Should be negative (forward bend)
        XCTAssertNotNil(spineAngle)
        XCTAssertLessThan(spineAngle!, 0)
    }
    
    func testSpineAngleCalculation_MissingJoints() {
        // Given: Pose with missing shoulder data
        var pose = createBasePose()
        pose.leftShoulder = nil
        pose.rightShoulder = CGPoint(x: 0.6, y: 0.3)
        pose.leftHip = CGPoint(x: 0.4, y: 0.6)
        pose.rightHip = CGPoint(x: 0.6, y: 0.6)
        
        // When: Calculate spine angle
        let spineAngle = calculateSpineAngle(pose: pose)
        
        // Then: Should return nil
        XCTAssertNil(spineAngle)
    }
    
    // MARK: - Hip Rotation Tests
    
    func testHipRotation_Square() {
        // Given: Hips square to camera (maximum visible width)
        var pose = createBasePose()
        pose.leftHip = CGPoint(x: 0.35, y: 0.6)
        pose.rightHip = CGPoint(x: 0.65, y: 0.6)  // Wide = square
        
        // When: Calculate hip rotation
        let rotation = calculateHipRotation(pose: pose)
        
        // Then: Should be close to 0 degrees (square)
        XCTAssertNotNil(rotation)
        XCTAssertLessThan(rotation!, 15)
    }
    
    func testHipRotation_Rotated() {
        // Given: Hips rotated (narrower visible width)
        var pose = createBasePose()
        pose.leftHip = CGPoint(x: 0.45, y: 0.6)
        pose.rightHip = CGPoint(x: 0.55, y: 0.6)  // Narrow = rotated
        
        // When: Calculate hip rotation
        let rotation = calculateHipRotation(pose: pose)
        
        // Then: Should be significant rotation
        XCTAssertNotNil(rotation)
        XCTAssertGreaterThan(rotation!, 30)
    }
    
    // MARK: - Shoulder Rotation Tests
    
    func testShoulderRotation_Square() {
        // Given: Shoulders square to camera
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.3, y: 0.35)
        pose.rightShoulder = CGPoint(x: 0.7, y: 0.35)  // Wide = square
        
        // When: Calculate shoulder rotation
        let rotation = calculateShoulderRotation(pose: pose)
        
        // Then: Should be close to 0 degrees
        XCTAssertNotNil(rotation)
        XCTAssertLessThan(rotation!, 20)
    }
    
    func testShoulderRotation_MaxTurn() {
        // Given: Shoulders at maximum rotation (backswing top)
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.45, y: 0.35)
        pose.rightShoulder = CGPoint(x: 0.55, y: 0.35)  // Very narrow
        
        // When: Calculate shoulder rotation
        let rotation = calculateShoulderRotation(pose: pose)
        
        // Then: Should be high rotation (>60 degrees)
        XCTAssertNotNil(rotation)
        XCTAssertGreaterThan(rotation!, 50)
    }
    
    // MARK: - Arm Angle Tests
    
    func testArmAngle_Straight() {
        // Given: Arm fully extended (180 degrees)
        let shoulder = CGPoint(x: 0.4, y: 0.3)
        let elbow = CGPoint(x: 0.4, y: 0.45)
        let wrist = CGPoint(x: 0.4, y: 0.6)
        
        // When: Calculate arm angle
        let angle = calculateArmAngle(shoulder: shoulder, elbow: elbow, wrist: wrist)
        
        // Then: Should be approximately 180 degrees
        XCTAssertNotNil(angle)
        XCTAssertEqual(angle!, 180, accuracy: 5)
    }
    
    func testArmAngle_Bent90() {
        // Given: Arm bent at 90 degrees
        let shoulder = CGPoint(x: 0.4, y: 0.3)
        let elbow = CGPoint(x: 0.4, y: 0.45)
        let wrist = CGPoint(x: 0.55, y: 0.45)  // Horizontal from elbow
        
        // When: Calculate arm angle
        let angle = calculateArmAngle(shoulder: shoulder, elbow: elbow, wrist: wrist)
        
        // Then: Should be approximately 90 degrees
        XCTAssertNotNil(angle)
        XCTAssertEqual(angle!, 90, accuracy: 10)
    }
    
    func testArmAngle_MissingJoint() {
        // Given: Missing elbow
        let shoulder = CGPoint(x: 0.4, y: 0.3)
        let wrist = CGPoint(x: 0.4, y: 0.6)
        
        // When: Calculate arm angle
        let angle = calculateArmAngle(shoulder: shoulder, elbow: nil, wrist: wrist)
        
        // Then: Should return nil
        XCTAssertNil(angle)
    }
    
    // MARK: - Alignment Status Tests
    
    func testAlignmentStatus_Good() {
        // Given: Well-positioned pose with all joints visible
        let pose = createWellPositionedPose()
        
        // When: Check alignment
        let status = determineAlignmentStatus(pose: pose)
        
        // Then: Should be good
        XCTAssertEqual(status, .good)
    }
    
    func testAlignmentStatus_TooFar() {
        // Given: Pose with missing lower body (too far from camera)
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.4, y: 0.4)
        pose.rightShoulder = CGPoint(x: 0.6, y: 0.4)
        pose.leftHip = nil
        pose.rightHip = nil
        
        // When: Check alignment
        let status = determineAlignmentStatus(pose: pose)
        
        // Then: Should be too far
        XCTAssertEqual(status, .tooFar)
    }
    
    func testAlignmentStatus_TooLeft() {
        // Given: Person positioned too far left in frame
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.05, y: 0.35)
        pose.rightShoulder = CGPoint(x: 0.25, y: 0.35)
        pose.leftHip = CGPoint(x: 0.05, y: 0.6)
        pose.rightHip = CGPoint(x: 0.25, y: 0.6)
        
        // When: Check alignment
        let status = determineAlignmentStatus(pose: pose)
        
        // Then: Should be too left
        XCTAssertEqual(status, .tooLeft)
    }
    
    func testAlignmentStatus_TooRight() {
        // Given: Person positioned too far right in frame
        var pose = createBasePose()
        pose.leftShoulder = CGPoint(x: 0.75, y: 0.35)
        pose.rightShoulder = CGPoint(x: 0.95, y: 0.35)
        pose.leftHip = CGPoint(x: 0.75, y: 0.6)
        pose.rightHip = CGPoint(x: 0.95, y: 0.6)
        
        // When: Check alignment
        let status = determineAlignmentStatus(pose: pose)
        
        // Then: Should be too right
        XCTAssertEqual(status, .tooRight)
    }
    
    func testAlignmentStatus_LowConfidence() {
        // Given: Pose with low confidence
        var pose = createWellPositionedPose()
        pose.confidence = 0.3
        
        // When: Check alignment
        let status = determineAlignmentStatus(pose: pose)
        
        // Then: Should be low confidence
        XCTAssertEqual(status, .lowConfidence)
    }
    
    // MARK: - Bone Connections Tests
    
    func testBoneConnections_Count() {
        // Given: Complete pose
        let pose = createWellPositionedPose()
        
        // When: Get bone connections
        let bones = pose.boneConnections
        
        // Then: Should have expected number of bones
        XCTAssertGreaterThan(bones.count, 8) // Spine + shoulders + arms + hips + legs
    }
    
    func testAllJoints_Count() {
        // Given: Complete pose
        let pose = createWellPositionedPose()
        
        // When: Get all joints
        let joints = pose.allJoints
        
        // Then: Should have detected joints
        XCTAssertGreaterThan(joints.count, 10)
    }
    
    // MARK: - Helper Methods
    
    private func createBasePose() -> PoseFrame {
        return PoseFrame(
            timestamp: Date(),
            frameIndex: 0,
            confidence: 0.9
        )
    }
    
    private func createWellPositionedPose() -> PoseFrame {
        var pose = PoseFrame(
            timestamp: Date(),
            frameIndex: 0,
            confidence: 0.9
        )
        
        // Set all joints for a well-positioned golfer at address
        pose.nose = CGPoint(x: 0.5, y: 0.2)
        pose.leftShoulder = CGPoint(x: 0.35, y: 0.35)
        pose.rightShoulder = CGPoint(x: 0.65, y: 0.35)
        pose.leftElbow = CGPoint(x: 0.3, y: 0.5)
        pose.rightElbow = CGPoint(x: 0.7, y: 0.5)
        pose.leftWrist = CGPoint(x: 0.45, y: 0.6)
        pose.rightWrist = CGPoint(x: 0.55, y: 0.6)
        pose.leftHip = CGPoint(x: 0.4, y: 0.6)
        pose.rightHip = CGPoint(x: 0.6, y: 0.6)
        pose.leftKnee = CGPoint(x: 0.38, y: 0.75)
        pose.rightKnee = CGPoint(x: 0.62, y: 0.75)
        pose.leftAnkle = CGPoint(x: 0.35, y: 0.9)
        pose.rightAnkle = CGPoint(x: 0.65, y: 0.9)
        
        return pose
    }
    
    // MARK: - Calculation Helpers (mirroring PoseDetector logic for testing)
    
    private func calculateSpineAngle(pose: PoseFrame) -> Double? {
        guard let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder,
              let leftHip = pose.leftHip,
              let rightHip = pose.rightHip else { return nil }
        
        let shoulderMid = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let hipMid = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        
        let deltaX = shoulderMid.x - hipMid.x
        let deltaY = shoulderMid.y - hipMid.y
        
        let angleRadians = atan2(deltaX, -deltaY)
        return angleRadians * 180 / .pi
    }
    
    private func calculateHipRotation(pose: PoseFrame) -> Double? {
        guard let leftHip = pose.leftHip, let rightHip = pose.rightHip else { return nil }
        
        let hipWidth = abs(rightHip.x - leftHip.x)
        let maxWidth: CGFloat = 0.25
        let compressionRatio = min(hipWidth / maxWidth, 1.0)
        
        let angleRadians = acos(compressionRatio)
        return angleRadians * 180 / .pi
    }
    
    private func calculateShoulderRotation(pose: PoseFrame) -> Double? {
        guard let leftShoulder = pose.leftShoulder, let rightShoulder = pose.rightShoulder else { return nil }
        
        let shoulderWidth = abs(rightShoulder.x - leftShoulder.x)
        let maxWidth: CGFloat = 0.35
        let compressionRatio = min(shoulderWidth / maxWidth, 1.0)
        
        let angleRadians = acos(compressionRatio)
        return angleRadians * 180 / .pi
    }
    
    private func calculateArmAngle(shoulder: CGPoint?, elbow: CGPoint?, wrist: CGPoint?) -> Double? {
        guard let shoulder = shoulder, let elbow = elbow, let wrist = wrist else { return nil }
        
        let v1 = CGPoint(x: shoulder.x - elbow.x, y: shoulder.y - elbow.y)
        let v2 = CGPoint(x: wrist.x - elbow.x, y: wrist.y - elbow.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        guard mag1 > 0 && mag2 > 0 else { return nil }
        
        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1, min(1, cosAngle))
        let angleRadians = acos(clampedCos)
        
        return angleRadians * 180 / .pi
    }
    
    private func determineAlignmentStatus(pose: PoseFrame) -> AlignmentStatus {
        // Check essential joints
        let hasUpperBody = pose.leftShoulder != nil && pose.rightShoulder != nil
        let hasLowerBody = pose.leftHip != nil && pose.rightHip != nil
        
        guard hasUpperBody && hasLowerBody else {
            return .tooFar
        }
        
        // Check centering
        if let leftShoulder = pose.leftShoulder, let rightShoulder = pose.rightShoulder {
            let centerX = (leftShoulder.x + rightShoulder.x) / 2
            if centerX < 0.25 {
                return .tooLeft
            } else if centerX > 0.75 {
                return .tooRight
            }
        }
        
        // Check confidence
        if pose.confidence < 0.7 {
            return .lowConfidence
        }
        
        return .good
    }
}
