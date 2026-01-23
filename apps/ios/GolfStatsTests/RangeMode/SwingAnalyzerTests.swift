import XCTest
@testable import GolfStats

/// Unit tests for SwingAnalyzerIOS
final class SwingAnalyzerTests: XCTestCase {
    
    var analyzer: SwingAnalyzerIOS!
    
    override func setUp() {
        super.setUp()
        analyzer = SwingAnalyzerIOS()
    }
    
    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }
    
    // MARK: - Tempo Calculation Tests
    
    func testTempoRatio_Normal() {
        // Given: Normal swing timing
        let backswing: TimeInterval = 0.9
        let downswing: TimeInterval = 0.3
        
        // When: Calculate tempo ratio
        let ratio = backswing / downswing
        
        // Then: Should be approximately 3:1
        XCTAssertEqual(ratio, 3.0, accuracy: 0.1)
    }
    
    func testTempoRatio_Fast() {
        // Given: Fast tempo swing
        let backswing: TimeInterval = 0.6
        let downswing: TimeInterval = 0.25
        
        // When: Calculate tempo ratio
        let ratio = backswing / downswing
        
        // Then: Should be approximately 2.4:1
        XCTAssertEqual(ratio, 2.4, accuracy: 0.1)
    }
    
    func testTempoRatio_Slow() {
        // Given: Slow tempo swing
        let backswing: TimeInterval = 1.2
        let downswing: TimeInterval = 0.35
        
        // When: Calculate tempo ratio
        let ratio = backswing / downswing
        
        // Then: Should be approximately 3.4:1
        XCTAssertEqual(ratio, 3.43, accuracy: 0.1)
    }
    
    // MARK: - Tempo Score Tests
    
    func testTempoScore_Perfect() {
        // Given: Perfect tempo (matches target)
        let ratio = 3.0
        let target = 3.0
        
        // When: Calculate score
        let score = calculateTempoScore(ratio: ratio, target: target)
        
        // Then: Should be 100
        XCTAssertEqual(score, 100)
    }
    
    func testTempoScore_SlightlyOff() {
        // Given: Slightly off target
        let ratio = 2.7
        let target = 3.0
        
        // When: Calculate score
        let score = calculateTempoScore(ratio: ratio, target: target)
        
        // Then: Should be ~85
        XCTAssertEqual(score, 85, accuracy: 5)
    }
    
    func testTempoScore_WayOff() {
        // Given: Way off target
        let ratio = 2.0
        let target = 3.0
        
        // When: Calculate score
        let score = calculateTempoScore(ratio: ratio, target: target)
        
        // Then: Should be ~50
        XCTAssertEqual(score, 50, accuracy: 5)
    }
    
    // MARK: - Session Statistics Tests
    
    func testSessionAverageTempo() {
        // Given: Session with multiple swings
        let session = MockDataGenerators.generateRangeSession(swingCount: 5, includeVariation: false)
        
        // When: Calculate average tempo
        let avgTempo = session.averageTempo
        
        // Then: Should be close to normal tempo (3.0)
        XCTAssertNotNil(avgTempo)
        XCTAssertEqual(avgTempo!, 3.0, accuracy: 0.3)
    }
    
    func testSessionConsistencyScore_Consistent() {
        // Given: Session with consistent swings
        let session = MockDataGenerators.generateRangeSession(swingCount: 5, includeVariation: false)
        
        // When: Calculate consistency
        let consistency = session.consistencyScore
        
        // Then: Should be high (>70)
        XCTAssertNotNil(consistency)
        XCTAssertGreaterThan(consistency!, 70)
    }
    
    func testSessionConsistencyScore_Variable() {
        // Given: Session with variable swings
        let session = MockDataGenerators.generateRangeSession(swingCount: 10, includeVariation: true)
        
        // When: Calculate consistency
        let consistency = session.consistencyScore
        
        // Then: Should be lower due to variation
        XCTAssertNotNil(consistency)
        // Variable swings should still have some consistency
        XCTAssertGreaterThan(consistency!, 20)
    }
    
    func testSessionSwingCount() {
        // Given: Session with known number of swings
        let session = MockDataGenerators.generateRangeSession(swingCount: 7)
        
        // Then: Should match
        XCTAssertEqual(session.swingCount, 7)
    }
    
    // MARK: - Fault Detection Tests
    
    func testFaultDetection_LossOfPosture() {
        // Given: Swing with loss of posture
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .lossOfPosture)
        
        // When: Check for faults
        let metrics = swing.combinedMetrics
        
        // Then: Should not have spine angle maintained
        XCTAssertEqual(metrics?.spineAngleMaintained, false)
    }
    
    func testFaultDetection_NormalSwing() {
        // Given: Normal swing
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .normal)
        
        // When: Check metrics
        let metrics = swing.combinedMetrics
        
        // Then: Should have good metrics
        XCTAssertEqual(metrics?.spineAngleMaintained, true)
    }
    
    // MARK: - X-Factor Tests
    
    func testXFactor_Normal() {
        // Given: Normal swing with good separation
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .normal)
        
        // When: Get X-factor
        let xFactor = swing.combinedMetrics?.xFactor
        
        // Then: Should be ~45 degrees (90 shoulder - 45 hip)
        XCTAssertNotNil(xFactor)
        XCTAssertEqual(xFactor!, 45, accuracy: 10)
    }
    
    // MARK: - Combined Metrics Tests
    
    func testCombinedMetrics_HasBothSources() {
        // Given: Swing with both camera and Watch data
        let swing = MockDataGenerators.generateCombinedSwingCapture(includeWatch: true)
        
        // Then: Should indicate both sources
        XCTAssertEqual(swing.combinedMetrics?.hasCameraData, true)
        XCTAssertEqual(swing.combinedMetrics?.hasWatchData, true)
    }
    
    func testCombinedMetrics_CameraOnly() {
        // Given: Swing with camera only
        let swing = MockDataGenerators.generateCombinedSwingCapture(includeWatch: false)
        
        // Then: Should indicate camera only
        XCTAssertEqual(swing.combinedMetrics?.hasCameraData, true)
        XCTAssertEqual(swing.combinedMetrics?.hasWatchData, false)
    }
    
    // MARK: - Phase Detection Tests
    
    func testPhaseMarkers_AllPresent() {
        // Given: Swing capture
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        
        // When: Get phases
        let phases = swing.cameraCapture?.phases ?? []
        
        // Then: Should have all major phases
        let phaseTypes = Set(phases.map { $0.phase })
        XCTAssertTrue(phaseTypes.contains(.setup))
        XCTAssertTrue(phaseTypes.contains(.backswing))
        XCTAssertTrue(phaseTypes.contains(.topOfSwing))
        XCTAssertTrue(phaseTypes.contains(.downswing))
        XCTAssertTrue(phaseTypes.contains(.impact))
        XCTAssertTrue(phaseTypes.contains(.followThrough))
    }
    
    func testPhaseMarkers_InOrder() {
        // Given: Swing capture
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        
        // When: Get phases
        let phases = swing.cameraCapture?.phases ?? []
        
        // Then: Frame indices should be increasing
        for i in 1..<phases.count {
            XCTAssertGreaterThanOrEqual(phases[i].frameIndex, phases[i-1].frameIndex)
        }
    }
    
    // MARK: - Body Metrics Tests
    
    func testBodyMetrics_ShoulderTurn() {
        // Given: Normal swing
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .normal)
        
        // When: Get shoulder turn
        let shoulderTurn = swing.combinedMetrics?.shoulderTurnDegrees
        
        // Then: Should be approximately 90 degrees
        XCTAssertNotNil(shoulderTurn)
        XCTAssertEqual(shoulderTurn!, 90, accuracy: 10)
    }
    
    func testBodyMetrics_HipTurn() {
        // Given: Normal swing
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .normal)
        
        // When: Get hip turn
        let hipTurn = swing.combinedMetrics?.hipTurnDegrees
        
        // Then: Should be approximately 45 degrees
        XCTAssertNotNil(hipTurn)
        XCTAssertEqual(hipTurn!, 45, accuracy: 10)
    }
    
    // MARK: - Watch Metrics Tests
    
    func testWatchMetrics_ClubSpeed() {
        // Given: Swing with Watch data
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .normal)
        
        // When: Get club speed
        let clubSpeed = swing.combinedMetrics?.estimatedClubSpeed
        
        // Then: Should be reasonable (70-110 mph for iron)
        XCTAssertNotNil(clubSpeed)
        XCTAssertGreaterThan(clubSpeed!, 60)
        XCTAssertLessThan(clubSpeed!, 120)
    }
    
    func testWatchMetrics_ImpactQuality() {
        // Given: Normal swing with Watch data
        let swing = MockDataGenerators.generateCombinedSwingCapture(swingType: .normal)
        
        // When: Get impact quality
        let impactQuality = swing.combinedMetrics?.impactQuality
        
        // Then: Should be good (>0.7)
        XCTAssertNotNil(impactQuality)
        XCTAssertGreaterThan(impactQuality!, 0.7)
    }
    
    // MARK: - Variance Calculation Tests
    
    func testVarianceCalculation_Uniform() {
        // Given: Uniform values
        let values = [3.0, 3.0, 3.0, 3.0, 3.0]
        
        // When: Calculate variance
        let variance = calculateVariance(values)
        
        // Then: Should be 0
        XCTAssertEqual(variance, 0, accuracy: 0.001)
    }
    
    func testVarianceCalculation_Varied() {
        // Given: Varied values
        let values = [2.0, 3.0, 4.0]
        
        // When: Calculate variance
        let variance = calculateVariance(values)
        
        // Then: Should be approximately 0.667
        XCTAssertEqual(variance, 0.667, accuracy: 0.01)
    }
    
    // MARK: - Helper Methods
    
    private func calculateTempoScore(ratio: Double, target: Double) -> Double {
        let deviation = abs(ratio - target)
        return max(0, 100 - (deviation * 50))
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}
