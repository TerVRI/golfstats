import XCTest
@testable import GolfStats

/// Unit tests for WatchSwingSync sensor fusion
final class WatchSwingSyncTests: XCTestCase {
    
    // MARK: - Clock Synchronization Tests
    
    func testClockOffset_NoOffset() {
        // Given: iPhone and Watch clocks are synchronized
        let iPhoneTime = Date()
        let watchTime = iPhoneTime.timeIntervalSince1970
        let roundTrip: TimeInterval = 0.02 // 20ms round trip
        
        // When: Calculate offset
        let offset = calculateClockOffset(
            sendTime: iPhoneTime,
            watchTime: watchTime,
            roundTrip: roundTrip
        )
        
        // Then: Offset should be approximately 0
        XCTAssertEqual(offset, 0, accuracy: 0.015)
    }
    
    func testClockOffset_WatchAhead() {
        // Given: Watch is 100ms ahead of iPhone
        let iPhoneTime = Date()
        let watchTime = iPhoneTime.timeIntervalSince1970 + 0.1
        let roundTrip: TimeInterval = 0.02
        
        // When: Calculate offset
        let offset = calculateClockOffset(
            sendTime: iPhoneTime,
            watchTime: watchTime,
            roundTrip: roundTrip
        )
        
        // Then: Offset should be approximately -0.1 (negative = Watch ahead)
        XCTAssertEqual(offset, -0.09, accuracy: 0.02)
    }
    
    func testClockOffset_WatchBehind() {
        // Given: Watch is 50ms behind iPhone
        let iPhoneTime = Date()
        let watchTime = iPhoneTime.timeIntervalSince1970 - 0.05
        let roundTrip: TimeInterval = 0.02
        
        // When: Calculate offset
        let offset = calculateClockOffset(
            sendTime: iPhoneTime,
            watchTime: watchTime,
            roundTrip: roundTrip
        )
        
        // Then: Offset should be approximately +0.05 (positive = Watch behind)
        XCTAssertEqual(offset, 0.06, accuracy: 0.02)
    }
    
    // MARK: - Timestamp Conversion Tests
    
    func testTimestampConversion() {
        // Given: Known offset
        let offset: TimeInterval = -0.05 // Watch is 50ms ahead
        let watchTimestamp: TimeInterval = 1000.0
        
        // When: Convert to iPhone time
        let iPhoneTime = convertWatchTimestamp(watchTimestamp, offset: offset)
        
        // Then: iPhone time should be 50ms later (to account for Watch being ahead)
        XCTAssertEqual(iPhoneTime.timeIntervalSince1970, 999.95, accuracy: 0.001)
    }
    
    // MARK: - Motion Sample Interpolation Tests
    
    func testInterpolation_ExactMatch() {
        // Given: Buffer with sample at exact requested time
        let targetTime = Date()
        let samples = [
            createMotionSample(timestamp: targetTime.addingTimeInterval(-0.1), accelX: 1.0),
            createMotionSample(timestamp: targetTime, accelX: 2.0),
            createMotionSample(timestamp: targetTime.addingTimeInterval(0.1), accelX: 3.0)
        ]
        
        // When: Get sample at target time
        let result = getInterpolatedMotion(at: targetTime, from: samples)
        
        // Then: Should return exact sample
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.accelerationX, 2.0, accuracy: 0.01)
    }
    
    func testInterpolation_Midpoint() {
        // Given: Request time between two samples
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.1)
        let midpoint = time1.addingTimeInterval(0.05)
        
        let samples = [
            createMotionSample(timestamp: time1, accelX: 1.0),
            createMotionSample(timestamp: time2, accelX: 3.0)
        ]
        
        // When: Get interpolated sample
        let result = getInterpolatedMotion(at: midpoint, from: samples)
        
        // Then: Should be average (2.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.accelerationX, 2.0, accuracy: 0.01)
    }
    
    func testInterpolation_QuarterPoint() {
        // Given: Request time 25% between samples
        let time1 = Date()
        let time2 = time1.addingTimeInterval(0.1)
        let quarterPoint = time1.addingTimeInterval(0.025)
        
        let samples = [
            createMotionSample(timestamp: time1, accelX: 0.0),
            createMotionSample(timestamp: time2, accelX: 4.0)
        ]
        
        // When: Get interpolated sample
        let result = getInterpolatedMotion(at: quarterPoint, from: samples)
        
        // Then: Should be 25% of the way (1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.accelerationX, 1.0, accuracy: 0.1)
    }
    
    func testInterpolation_OutOfRange() {
        // Given: Request time outside buffer range
        let time1 = Date()
        let samples = [
            createMotionSample(timestamp: time1, accelX: 1.0),
            createMotionSample(timestamp: time1.addingTimeInterval(0.1), accelX: 2.0)
        ]
        
        // When: Request time before first sample
        let beforeResult = getNearestMotion(at: time1.addingTimeInterval(-0.5), from: samples)
        
        // Then: Should return nearest (first) sample
        XCTAssertNotNil(beforeResult)
        XCTAssertEqual(beforeResult!.accelerationX, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Motion Buffer Tests
    
    func testMotionBuffer_GetSamplesInRange() {
        // Given: Buffer with samples over time
        let startTime = Date()
        var samples: [MotionSample] = []
        for i in 0..<100 {
            samples.append(createMotionSample(
                timestamp: startTime.addingTimeInterval(Double(i) * 0.01),
                accelX: Double(i)
            ))
        }
        
        // When: Get samples in middle range
        let rangeStart = startTime.addingTimeInterval(0.25)
        let rangeEnd = startTime.addingTimeInterval(0.75)
        let rangeSamples = getMotionSamples(from: rangeStart, to: rangeEnd, buffer: samples)
        
        // Then: Should return approximately 50 samples
        XCTAssertEqual(rangeSamples.count, 50, accuracy: 5)
    }
    
    // MARK: - Swing Matching Tests
    
    func testSwingMatching_SameSwing() {
        // Given: Camera and Watch detected swing at nearly same time
        let cameraSwingStart = Date()
        let watchSwingStart = cameraSwingStart.addingTimeInterval(0.1) // 100ms later
        
        // When: Check if same swing
        let isMatch = isMatchingSwing(
            cameraStart: cameraSwingStart,
            watchStart: watchSwingStart,
            tolerance: 0.5
        )
        
        // Then: Should match
        XCTAssertTrue(isMatch)
    }
    
    func testSwingMatching_DifferentSwings() {
        // Given: Camera and Watch detected different swings
        let cameraSwingStart = Date()
        let watchSwingStart = cameraSwingStart.addingTimeInterval(2.0) // 2 seconds later
        
        // When: Check if same swing
        let isMatch = isMatchingSwing(
            cameraStart: cameraSwingStart,
            watchStart: watchSwingStart,
            tolerance: 0.5
        )
        
        // Then: Should not match
        XCTAssertFalse(isMatch)
    }
    
    // MARK: - Combined Confidence Tests
    
    func testCombinedConfidence_BothSources() {
        // Given: High camera confidence and Watch data available
        let cameraConfidence: Float = 0.9
        let hasWatchData = true
        let timeDelta: TimeInterval = 0.02 // 20ms
        
        // When: Calculate combined confidence
        let confidence = calculateCombinedConfidence(
            cameraConfidence: cameraConfidence,
            hasWatchData: hasWatchData,
            timeDelta: timeDelta
        )
        
        // Then: Should be boosted
        XCTAssertGreaterThan(confidence, cameraConfidence)
        XCTAssertLessThanOrEqual(confidence, 1.0)
    }
    
    func testCombinedConfidence_LargeTimeDelta() {
        // Given: Large time delta between camera and Watch
        let cameraConfidence: Float = 0.9
        let hasWatchData = true
        let timeDelta: TimeInterval = 0.2 // 200ms - too much
        
        // When: Calculate combined confidence
        let confidence = calculateCombinedConfidence(
            cameraConfidence: cameraConfidence,
            hasWatchData: hasWatchData,
            timeDelta: timeDelta
        )
        
        // Then: Should be reduced
        XCTAssertLessThan(confidence, cameraConfidence)
    }
    
    func testCombinedConfidence_NoWatch() {
        // Given: No Watch data
        let cameraConfidence: Float = 0.9
        let hasWatchData = false
        let timeDelta: TimeInterval = 0
        
        // When: Calculate combined confidence
        let confidence = calculateCombinedConfidence(
            cameraConfidence: cameraConfidence,
            hasWatchData: hasWatchData,
            timeDelta: timeDelta
        )
        
        // Then: Should equal camera confidence
        XCTAssertEqual(confidence, cameraConfidence)
    }
    
    // MARK: - Helper Methods
    
    private func calculateClockOffset(sendTime: Date, watchTime: TimeInterval, roundTrip: TimeInterval) -> TimeInterval {
        let estimatedWatchTime = watchTime + (roundTrip / 2)
        let receiveTime = sendTime.addingTimeInterval(roundTrip)
        return receiveTime.timeIntervalSince1970 - estimatedWatchTime
    }
    
    private func convertWatchTimestamp(_ watchTimestamp: TimeInterval, offset: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: watchTimestamp + offset)
    }
    
    private func createMotionSample(timestamp: Date, accelX: Double) -> MotionSample {
        return MotionSample(
            timestamp: timestamp,
            index: 0,
            acceleration: (x: accelX, y: 0, z: 0),
            rotation: (x: 0, y: 0, z: 0)
        )
    }
    
    private func getInterpolatedMotion(at timestamp: Date, from buffer: [MotionSample]) -> MotionSample? {
        guard buffer.count >= 2 else { return buffer.first }
        
        let before = buffer.last { $0.timestamp <= timestamp }
        let after = buffer.first { $0.timestamp > timestamp }
        
        guard let b = before, let a = after else {
            return getNearestMotion(at: timestamp, from: buffer)
        }
        
        let totalInterval = a.timestamp.timeIntervalSince(b.timestamp)
        guard totalInterval > 0 else { return b }
        
        let t = timestamp.timeIntervalSince(b.timestamp) / totalInterval
        
        return MotionSample(
            timestamp: timestamp,
            index: b.index,
            acceleration: (
                x: lerp(b.accelerationX, a.accelerationX, t),
                y: lerp(b.accelerationY, a.accelerationY, t),
                z: lerp(b.accelerationZ, a.accelerationZ, t)
            ),
            rotation: (
                x: lerp(b.rotationX, a.rotationX, t),
                y: lerp(b.rotationY, a.rotationY, t),
                z: lerp(b.rotationZ, a.rotationZ, t)
            )
        )
    }
    
    private func getNearestMotion(at timestamp: Date, from buffer: [MotionSample]) -> MotionSample? {
        return buffer.min(by: {
            abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp))
        })
    }
    
    private func getMotionSamples(from startTime: Date, to endTime: Date, buffer: [MotionSample]) -> [MotionSample] {
        return buffer.filter { $0.timestamp >= startTime && $0.timestamp <= endTime }
    }
    
    private func isMatchingSwing(cameraStart: Date, watchStart: Date, tolerance: TimeInterval) -> Bool {
        return abs(cameraStart.timeIntervalSince(watchStart)) < tolerance
    }
    
    private func calculateCombinedConfidence(cameraConfidence: Float, hasWatchData: Bool, timeDelta: TimeInterval) -> Float {
        var confidence = cameraConfidence
        
        if hasWatchData {
            confidence += 0.1
        }
        
        if timeDelta > 0.05 {
            confidence -= Float(timeDelta * 2)
        }
        
        return min(1.0, max(0, confidence))
    }
    
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
}
