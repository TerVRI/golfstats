import XCTest
@testable import RoundCaddy

@MainActor
final class NewRoundButtonTests: XCTestCase {
    
    func testNewRoundButtonExists() async {
        // Test that new round functionality is accessible
        // This would be tested in UI tests, but we can test the underlying logic
        let roundManager = RoundManager()
        
        // New round should be able to start
        roundManager.startRound()
        XCTAssertTrue(roundManager.isRoundActive)
    }
    
    func testNewRoundInitialization() async {
        let roundManager = RoundManager()
        roundManager.startRound()
        
        // Round should start at hole 1
        XCTAssertEqual(roundManager.currentHole, 1)
        
        // No scores should be set initially
        let holeScores = roundManager.holeScores
        XCTAssertEqual(holeScores.count, 18)
    }
}
