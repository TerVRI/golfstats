import XCTest
@testable import GolfStats

/// Unit tests for LiDARCapabilities and tracking modes
final class LiDARCapabilitiesTests: XCTestCase {
    
    // MARK: - Tracking Mode Tests
    
    func testTrackingMode_JointCounts() {
        // ARKit modes have 91 joints
        XCTAssertEqual(TrackingMode.arKitBodyTracking3D.jointCount, 91)
        XCTAssertEqual(TrackingMode.arKitBodyTracking2D.jointCount, 91)
        
        // Vision modes have fewer joints
        XCTAssertEqual(TrackingMode.vision3DPose.jointCount, 17)
        XCTAssertEqual(TrackingMode.vision2DPose.jointCount, 19)
    }
    
    func testTrackingMode_DepthSupport() {
        // Only LiDAR 3D mode has true depth
        XCTAssertTrue(TrackingMode.arKitBodyTracking3D.supportsDepth)
        XCTAssertFalse(TrackingMode.arKitBodyTracking2D.supportsDepth)
        XCTAssertFalse(TrackingMode.vision3DPose.supportsDepth)
        XCTAssertFalse(TrackingMode.vision2DPose.supportsDepth)
    }
    
    // MARK: - Feature Availability Tests
    
    func testFeature_BasicSwingAnalysis_AlwaysAvailable() {
        // Basic swing analysis should work on all devices
        XCTAssertFalse(RangeModeFeature.basicSwingAnalysis.requiresLiDAR)
        XCTAssertFalse(RangeModeFeature.basicSwingAnalysis.requiresProDevice)
    }
    
    func testFeature_PointCloud_RequiresLiDAR() {
        XCTAssertTrue(RangeModeFeature.pointCloud.requiresLiDAR)
        XCTAssertTrue(RangeModeFeature.pointCloud.requiresProDevice)
    }
    
    func testFeature_RealMeasurements_RequiresLiDAR() {
        XCTAssertTrue(RangeModeFeature.realMeasurements.requiresLiDAR)
    }
    
    func testFeature_Avatar3D_NoLiDARRequired() {
        // 3D avatar works with ARKit body tracking (no LiDAR needed)
        XCTAssertFalse(RangeModeFeature.avatar3D.requiresLiDAR)
    }
    
    func testFeature_Descriptions() {
        // All features should have descriptions
        for feature in RangeModeFeature.allCases {
            XCTAssertFalse(feature.description.isEmpty, "\(feature.rawValue) should have a description")
        }
    }
    
    // MARK: - Tracking Mode Determination Tests
    
    func testTrackingModeDetermination_WithLiDAR() {
        // Given: Device with LiDAR and body tracking
        let mode = determineTrackingMode(hasLiDAR: true, supportsBodyTracking: true, supports3DPose: true)
        
        // Then: Should use ARKit 3D (best mode)
        XCTAssertEqual(mode, .arKitBodyTracking3D)
    }
    
    func testTrackingModeDetermination_NoLiDAR_WithBodyTracking() {
        // Given: Device without LiDAR but with body tracking (A12+)
        let mode = determineTrackingMode(hasLiDAR: false, supportsBodyTracking: true, supports3DPose: true)
        
        // Then: Should use ARKit 2D
        XCTAssertEqual(mode, .arKitBodyTracking2D)
    }
    
    func testTrackingModeDetermination_NoBodyTracking_With3DPose() {
        // Given: Device without ARKit body tracking but with iOS 17+ 3D pose
        let mode = determineTrackingMode(hasLiDAR: false, supportsBodyTracking: false, supports3DPose: true)
        
        // Then: Should use Vision 3D
        XCTAssertEqual(mode, .vision3DPose)
    }
    
    func testTrackingModeDetermination_BasicDevice() {
        // Given: Basic device (older iPhone)
        let mode = determineTrackingMode(hasLiDAR: false, supportsBodyTracking: false, supports3DPose: false)
        
        // Then: Should use Vision 2D
        XCTAssertEqual(mode, .vision2DPose)
    }
    
    // MARK: - Tracking Quality Tests
    
    func testTrackingQuality_Descriptions() {
        XCTAssertEqual(TrackingQuality.good.description, "Good")
        XCTAssertEqual(TrackingQuality.limited.description, "Limited")
        XCTAssertEqual(TrackingQuality.poor.description, "Poor")
        XCTAssertEqual(TrackingQuality.notAvailable.description, "Not Available")
    }
    
    func testTrackingQuality_Colors() {
        XCTAssertEqual(TrackingQuality.good.color, "green")
        XCTAssertEqual(TrackingQuality.limited.color, "yellow")
        XCTAssertEqual(TrackingQuality.poor.color, "red")
        XCTAssertEqual(TrackingQuality.notAvailable.color, "gray")
    }
    
    // MARK: - Avatar Style Tests
    
    func testAvatarStyles_AllCases() {
        let styles = AvatarStyle.allCases
        
        XCTAssertEqual(styles.count, 4)
        XCTAssertTrue(styles.contains(.robot))
        XCTAssertTrue(styles.contains(.golfer))
        XCTAssertTrue(styles.contains(.skeleton))
        XCTAssertTrue(styles.contains(.points))
    }
    
    // MARK: - Settings Tests
    
    func testSettings_DefaultValues() {
        let settings = LiDAR3DSettings()
        
        XCTAssertTrue(settings.showAvatar)
        XCTAssertTrue(settings.showSwingPlane)
        XCTAssertTrue(settings.showRealMeasurements)
        XCTAssertFalse(settings.showGhostOverlay)
        XCTAssertEqual(settings.ghostOpacity, 0.5)
        XCTAssertEqual(settings.swingPlaneColor, "green")
    }
    
    func testSettings_Encoding() throws {
        // Given: Settings with custom values
        var settings = LiDAR3DSettings()
        settings.showAvatar = false
        settings.ghostOpacity = 0.8
        settings.swingPlaneColor = "blue"
        
        // When: Encode and decode
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(LiDAR3DSettings.self, from: data)
        
        // Then: Values should match
        XCTAssertEqual(decoded.showAvatar, false)
        XCTAssertEqual(decoded.ghostOpacity, 0.8, accuracy: 0.01)
        XCTAssertEqual(decoded.swingPlaneColor, "blue")
    }
    
    // MARK: - Body Measurements Tests
    
    func testBodyMeasurements_Initialization() {
        let measurements = BodyMeasurements(
            stanceWidthCm: 50,
            shoulderWidthCm: 45,
            armSpanCm: 175,
            heightCm: 180
        )
        
        XCTAssertEqual(measurements.stanceWidthCm, 50)
        XCTAssertEqual(measurements.shoulderWidthCm, 45)
        XCTAssertEqual(measurements.armSpanCm, 175)
        XCTAssertEqual(measurements.heightCm, 180)
    }
    
    // MARK: - Skeleton3D Tests
    
    func testSkeleton3D_AngleCalculation() {
        // Given: Skeleton with known joint positions
        let joints: [String: Joint3D] = [
            "left_shoulder": createJoint(x: -0.2, y: 1.4, z: 0),
            "left_elbow": createJoint(x: -0.2, y: 1.2, z: 0),
            "left_wrist": createJoint(x: 0, y: 1.2, z: 0)  // 90 degree bend
        ]
        
        let skeleton = Skeleton3D(
            timestamp: Date(),
            joints: joints,
            rootTransform: matrix_identity_float4x4,
            estimatedHeight: 1.0
        )
        
        // When: Calculate angle
        let angle = skeleton.angle(from: "left_shoulder", through: "left_elbow", to: "left_wrist")
        
        // Then: Should be approximately 90 degrees
        XCTAssertNotNil(angle)
        XCTAssertEqual(angle!, 90, accuracy: 5)
    }
    
    func testSkeleton3D_PositionRetrieval() {
        let joints: [String: Joint3D] = [
            "head": createJoint(x: 0, y: 1.7, z: 0)
        ]
        
        let skeleton = Skeleton3D(
            timestamp: Date(),
            joints: joints,
            rootTransform: matrix_identity_float4x4,
            estimatedHeight: 1.0
        )
        
        // Should find existing joint
        let headPos = skeleton.position(of: "head")
        XCTAssertNotNil(headPos)
        XCTAssertEqual(headPos!.y, 1.7, accuracy: 0.001)
        
        // Should return nil for missing joint
        let missingPos = skeleton.position(of: "nonexistent")
        XCTAssertNil(missingPos)
    }
    
    // MARK: - Recorded Swing Tests
    
    func testRecordedSwing_Initialization() {
        let swing = RecordedSwing3D(
            id: UUID(),
            timestamp: Date(),
            skeletons: [],
            duration: 1.5
        )
        
        XCTAssertEqual(swing.duration, 1.5)
        XCTAssertEqual(swing.skeletons.count, 0)
    }
    
    // MARK: - Helper Methods
    
    private func determineTrackingMode(
        hasLiDAR: Bool,
        supportsBodyTracking: Bool,
        supports3DPose: Bool
    ) -> TrackingMode {
        if hasLiDAR && supportsBodyTracking {
            return .arKitBodyTracking3D
        } else if supportsBodyTracking {
            return .arKitBodyTracking2D
        } else if supports3DPose {
            return .vision3DPose
        } else {
            return .vision2DPose
        }
    }
    
    private func createJoint(x: Float, y: Float, z: Float) -> Joint3D {
        return Joint3D(
            name: "test",
            position: SIMD3<Float>(x, y, z),
            rotation: simd_float3x3(1),
            localTransform: matrix_identity_float4x4,
            worldTransform: matrix_identity_float4x4,
            isTracked: true
        )
    }
}
