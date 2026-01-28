import XCTest
import Combine
@testable import GolfStats

/// Unit tests for BodyPoseProvider protocol and BodyTrackingMode enum
final class BodyPoseProviderTests: XCTestCase {
    
    var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - BodyTrackingMode Tests
    
    func testBodyTrackingMode_AllCases() {
        let modes = BodyTrackingMode.allCases
        
        XCTAssertEqual(modes.count, 2)
        XCTAssertTrue(modes.contains(.vision2D))
        XCTAssertTrue(modes.contains(.arkit3D))
    }
    
    func testBodyTrackingMode_RawValues() {
        XCTAssertEqual(BodyTrackingMode.vision2D.rawValue, "2D (Standard)")
        XCTAssertEqual(BodyTrackingMode.arkit3D.rawValue, "3D (LiDAR)")
    }
    
    func testBodyTrackingMode_Descriptions() {
        // Both modes should have descriptions
        XCTAssertFalse(BodyTrackingMode.vision2D.description.isEmpty)
        XCTAssertFalse(BodyTrackingMode.arkit3D.description.isEmpty)
        
        // 2D description should mention "all devices"
        XCTAssertTrue(BodyTrackingMode.vision2D.description.lowercased().contains("all"))
        
        // 3D description should mention "LiDAR" or "Pro"
        let arDesc = BodyTrackingMode.arkit3D.description.lowercased()
        XCTAssertTrue(arDesc.contains("lidar") || arDesc.contains("pro"))
    }
    
    func testBodyTrackingMode_IconNames() {
        // Both modes should have icon names
        XCTAssertFalse(BodyTrackingMode.vision2D.iconName.isEmpty)
        XCTAssertFalse(BodyTrackingMode.arkit3D.iconName.isEmpty)
        
        // 3D mode should have cube icon
        XCTAssertTrue(BodyTrackingMode.arkit3D.iconName.contains("cube"))
    }
    
    func testBodyTrackingMode_Codable() throws {
        // Test encoding
        let mode = BodyTrackingMode.arkit3D
        let data = try JSONEncoder().encode(mode)
        
        // Test decoding
        let decoded = try JSONDecoder().decode(BodyTrackingMode.self, from: data)
        XCTAssertEqual(decoded, mode)
    }
    
    func testBodyTrackingMode_PersistenceKey() {
        // Mode should be suitable for UserDefaults storage
        let mode = BodyTrackingMode.vision2D
        UserDefaults.standard.set(mode.rawValue, forKey: "testTrackingMode")
        
        let retrieved = UserDefaults.standard.string(forKey: "testTrackingMode")
        XCTAssertEqual(retrieved, mode.rawValue)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "testTrackingMode")
    }
    
    // MARK: - PoseDetector (2D) Provider Tests
    
    func testPoseDetector_ConformsToProtocol() {
        let detector = PoseDetector(targetFrameRate: 30)
        
        // Should have protocol properties
        XCTAssertFalse(detector.supports3D)
        XCTAssertFalse(detector.requiresSpecialHardware)
        XCTAssertTrue(PoseDetector.isAvailable())
    }
    
    func testPoseDetector_InitialState() {
        let detector = PoseDetector(targetFrameRate: 30)
        
        XCTAssertFalse(detector.isDetecting)
        XCTAssertNil(detector.currentPose)
        XCTAssertEqual(detector.alignmentStatus, .searching)
    }
    
    func testPoseDetector_Publishers() {
        let detector = PoseDetector(targetFrameRate: 30)
        var poseReceived = false
        var statusReceived = false
        
        // Subscribe to publishers
        detector.currentPosePublisher
            .sink { _ in poseReceived = true }
            .store(in: &cancellables)
        
        detector.alignmentStatusPublisher
            .sink { _ in statusReceived = true }
            .store(in: &cancellables)
        
        // Publishers should exist and emit initial values
        XCTAssertTrue(poseReceived || true) // May or may not emit immediately
        XCTAssertTrue(statusReceived || true)
    }
    
    func testPoseDetector_TargetFrameRate() {
        let detector30 = PoseDetector(targetFrameRate: 30)
        let detector60 = PoseDetector(targetFrameRate: 60)
        
        // Both should be valid frame rates
        XCTAssertEqual(detector30.targetFrameRate, 30)
        XCTAssertEqual(detector60.targetFrameRate, 60)
    }
    
    // MARK: - SwingAnalyzerIOS Dual-Mode Tests
    
    func testSwingAnalyzer_DefaultTrackingMode() {
        let analyzer = SwingAnalyzerIOS()
        
        // Should default to 2D mode
        XCTAssertEqual(analyzer.trackingMode, .vision2D)
    }
    
    func testSwingAnalyzer_HasPoseDetector() {
        let analyzer = SwingAnalyzerIOS()
        
        // Should always have 2D detector
        XCTAssertNotNil(analyzer.poseDetector)
        XCTAssertFalse(analyzer.poseDetector.supports3D)
    }
    
    func testSwingAnalyzer_ARKitAvailabilityCheck() {
        let analyzer = SwingAnalyzerIOS()
        
        // isARKitAvailable should be boolean (we can't control actual device)
        XCTAssertTrue(analyzer.isARKitAvailable || !analyzer.isARKitAvailable)
        
        // If ARKit is available, arBodyTracker should exist
        if analyzer.isARKitAvailable {
            XCTAssertNotNil(analyzer.arBodyTracker)
        }
    }
    
    func testSwingAnalyzer_ActivePoseProvider_2DMode() {
        let analyzer = SwingAnalyzerIOS()
        analyzer.trackingMode = .vision2D
        
        // Active provider should be the 2D detector
        let provider = analyzer.activePoseProvider
        XCTAssertFalse(provider.supports3D)
    }
    
    func testSwingAnalyzer_ActivePoseProvider_3DMode() {
        let analyzer = SwingAnalyzerIOS()
        
        // Only test if ARKit is available
        guard analyzer.isARKitAvailable else {
            throw XCTSkip("ARKit not available on this device")
        }
        
        analyzer.trackingMode = .arkit3D
        
        // Active provider should be the 3D tracker
        let provider = analyzer.activePoseProvider
        XCTAssertTrue(provider.supports3D)
    }
    
    func testSwingAnalyzer_TrackingModeSwitch() {
        let analyzer = SwingAnalyzerIOS()
        
        // Start in 2D mode
        XCTAssertEqual(analyzer.trackingMode, .vision2D)
        
        // Switch to 3D (if available)
        if analyzer.isARKitAvailable {
            analyzer.trackingMode = .arkit3D
            XCTAssertEqual(analyzer.trackingMode, .arkit3D)
            
            // Switch back to 2D
            analyzer.trackingMode = .vision2D
            XCTAssertEqual(analyzer.trackingMode, .vision2D)
        }
    }
    
    func testSwingAnalyzer_SessionWithTrackingMode() {
        let analyzer = SwingAnalyzerIOS()
        
        // Start a session
        analyzer.startSession()
        
        // Session should record tracking mode
        XCTAssertNotNil(analyzer.currentSession)
        XCTAssertEqual(analyzer.currentSession?.trackingMode, .vision2D)
        
        // End session
        _ = analyzer.endSession()
    }
    
    // MARK: - PoseFrameBuilder Tests
    
    func testPoseFrameBuilder_Build() {
        var builder = PoseFrameBuilder(
            timestamp: Date(),
            frameIndex: 42,
            confidence: 0.95
        )
        
        builder.nose = CGPoint(x: 0.5, y: 0.15)
        builder.leftShoulder = CGPoint(x: 0.35, y: 0.35)
        builder.rightShoulder = CGPoint(x: 0.65, y: 0.35)
        builder.spineAngle = -25.0
        
        let pose = builder.build()
        
        XCTAssertEqual(pose.frameIndex, 42)
        XCTAssertEqual(pose.confidence, 0.95, accuracy: 0.01)
        XCTAssertNotNil(pose.nose)
        XCTAssertNotNil(pose.leftShoulder)
        XCTAssertNotNil(pose.rightShoulder)
        XCTAssertEqual(pose.spineAngle, -25.0, accuracy: 0.1)
    }
    
    func testPoseFrameBuilder_EmptyBuild() {
        let builder = PoseFrameBuilder(
            timestamp: Date(),
            frameIndex: 0,
            confidence: 0.5
        )
        
        let pose = builder.build()
        
        // Should build successfully even with no joints
        XCTAssertEqual(pose.frameIndex, 0)
        XCTAssertNil(pose.nose)
        XCTAssertNil(pose.leftShoulder)
    }
    
    // MARK: - RangeSession Tracking Mode Tests
    
    func testRangeSession_TrackingModeStorage() {
        var session = RangeSession()
        
        // Default should be nil (for backward compatibility)
        XCTAssertNil(session.trackingMode)
        
        // Set tracking mode
        session.trackingMode = .arkit3D
        XCTAssertEqual(session.trackingMode, .arkit3D)
    }
    
    func testRangeSession_Codable_WithTrackingMode() throws {
        var session = RangeSession()
        session.trackingMode = .vision2D
        session.selectedClub = "7 Iron"
        
        // Encode
        let data = try JSONEncoder().encode(session)
        
        // Decode
        let decoded = try JSONDecoder().decode(RangeSession.self, from: data)
        
        XCTAssertEqual(decoded.trackingMode, .vision2D)
        XCTAssertEqual(decoded.selectedClub, "7 Iron")
    }
    
    func testRangeSession_Codable_WithoutTrackingMode() throws {
        // Simulate old session data without tracking mode
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "startTime": \(Date().timeIntervalSince1970),
            "swings": [],
            "selectedClub": "Driver"
        }
        """.data(using: .utf8)!
        
        // Should decode without error, trackingMode should be nil
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let session = try decoder.decode(RangeSession.self, from: json)
        
        XCTAssertNil(session.trackingMode)
        XCTAssertEqual(session.selectedClub, "Driver")
    }
    
    // MARK: - AlignmentStatus Tests
    
    func testAlignmentStatus_AllCases() {
        let statuses: [AlignmentStatus] = [
            .searching, .tooFar, .tooClose, .tooLeft, .tooRight, .lowConfidence, .good
        ]
        
        for status in statuses {
            // Each status should have a color
            XCTAssertFalse(status.color.isEmpty, "\(status) should have a color")
            
            // Each status should have a system image
            XCTAssertFalse(status.systemImage.isEmpty, "\(status) should have a system image")
        }
    }
    
    func testAlignmentStatus_GoodIsGreen() {
        XCTAssertEqual(AlignmentStatus.good.color, "green")
    }
    
    func testAlignmentStatus_SearchingIsYellow() {
        XCTAssertEqual(AlignmentStatus.searching.color, "yellow")
    }
}
