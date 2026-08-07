import XCTest
@testable import Audiobookphile

@MainActor
final class AudioPlayerServiceTests: XCTestCase {

    override func setUp() async throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() async throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialState() async throws {
        let service = AudioPlayerService.shared
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.currentTime, 0)
        XCTAssertNil(service.playbackError)
    }

    // Add more tests for queuing and error handling logic
}
