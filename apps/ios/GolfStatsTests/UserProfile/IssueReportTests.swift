import XCTest
@testable import RoundCaddy

/// Tests for IssueReport model and IssueType enum
final class IssueReportTests: XCTestCase {
    
    // MARK: - IssueType Tests
    
    func testIssueTypeDisplayNames() {
        XCTAssertEqual(IssueType.clubRecommendationsWrong.displayName, "Club recommendations are wrong")
        XCTAssertEqual(IssueType.smartTargetsWrong.displayName, "Smart targets are wrong (course mapping issue)")
        XCTAssertEqual(IssueType.dispersionTooBig.displayName, "Dispersion ellipse sizes feel too big")
        XCTAssertEqual(IssueType.dispersionTooSmall.displayName, "Dispersion ellipse sizes feel too small")
        XCTAssertEqual(IssueType.noShotsDetected.displayName, "No shots detected")
        XCTAssertEqual(IssueType.batteryDrain.displayName, "Battery drain")
        XCTAssertEqual(IssueType.appCrash.displayName, "App crashed")
        XCTAssertEqual(IssueType.syncIssues.displayName, "Watch/phone sync issues")
        XCTAssertEqual(IssueType.other.displayName, "Other issue")
    }
    
    func testIssueTypeCaseCoverage() {
        // Ensure all cases have display names
        for issueType in IssueType.allCases {
            XCTAssertFalse(issueType.displayName.isEmpty, "\(issueType) should have a display name")
            XCTAssertFalse(issueType.rawValue.isEmpty, "\(issueType) should have a raw value")
        }
    }
    
    func testIssueTypeCodable() throws {
        let types: [IssueType] = [.clubRecommendationsWrong, .batteryDrain, .gpsInaccurate]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(types)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([IssueType].self, from: data)
        
        XCTAssertEqual(decoded, types)
    }
    
    // MARK: - IssueReport Tests
    
    func testIssueReportCreation() {
        let report = IssueReport(
            userId: "user-123",
            roundId: "round-456",
            courseId: "course-789",
            holeNumber: 7,
            issueTypes: [.clubRecommendationsWrong, .gpsInaccurate],
            additionalDetails: "The club recommendation was way off"
        )
        
        XCTAssertNotNil(report.id)
        XCTAssertEqual(report.userId, "user-123")
        XCTAssertEqual(report.roundId, "round-456")
        XCTAssertEqual(report.courseId, "course-789")
        XCTAssertEqual(report.holeNumber, 7)
        XCTAssertEqual(report.issueTypes.count, 2)
        XCTAssertTrue(report.issueTypes.contains(.clubRecommendationsWrong))
        XCTAssertTrue(report.issueTypes.contains(.gpsInaccurate))
        XCTAssertEqual(report.additionalDetails, "The club recommendation was way off")
        XCTAssertNotNil(report.createdAt)
    }
    
    func testIssueReportWithoutOptionalFields() {
        let report = IssueReport(
            userId: "user-123",
            issueTypes: [.batteryDrain]
        )
        
        XCTAssertNotNil(report.id)
        XCTAssertEqual(report.userId, "user-123")
        XCTAssertNil(report.roundId)
        XCTAssertNil(report.courseId)
        XCTAssertNil(report.holeNumber)
        XCTAssertEqual(report.issueTypes.count, 1)
        XCTAssertNil(report.additionalDetails)
    }
    
    func testIssueReportCodable() throws {
        let report = IssueReport(
            userId: "user-123",
            roundId: "round-456",
            courseId: "course-789",
            holeNumber: 7,
            issueTypes: [.clubRecommendationsWrong, .gpsInaccurate],
            additionalDetails: "Test details"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(IssueReport.self, from: data)
        
        XCTAssertEqual(decoded.id, report.id)
        XCTAssertEqual(decoded.userId, report.userId)
        XCTAssertEqual(decoded.roundId, report.roundId)
        XCTAssertEqual(decoded.courseId, report.courseId)
        XCTAssertEqual(decoded.holeNumber, report.holeNumber)
        XCTAssertEqual(decoded.issueTypes, report.issueTypes)
        XCTAssertEqual(decoded.additionalDetails, report.additionalDetails)
    }
    
    // MARK: - Issue Type Categories
    
    func testShotDetectionIssueTypes() {
        let shotDetectionIssues: [IssueType] = [
            .missingPutts,
            .missingShots,
            .noShotsDetected,
            .tooManyShotsDeleted,
            .shotsOnWrongHole
        ]
        
        for issue in shotDetectionIssues {
            XCTAssertTrue(IssueType.allCases.contains(issue))
        }
    }
    
    func testCourseRelatedIssueTypes() {
        let courseIssues: [IssueType] = [
            .clubRecommendationsWrong,
            .smartTargetsWrong,
            .courseMappingIssue,
            .gpsInaccurate
        ]
        
        for issue in courseIssues {
            XCTAssertTrue(IssueType.allCases.contains(issue))
        }
    }
    
    func testDisplayIssueTypes() {
        let displayIssues: [IssueType] = [
            .dispersionTooBig,
            .dispersionTooSmall,
            .scorePercentagesWrong
        ]
        
        for issue in displayIssues {
            XCTAssertTrue(IssueType.allCases.contains(issue))
        }
    }
}
