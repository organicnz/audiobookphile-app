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

    func testSeekEpochsAndBounds() async throws {
        let service = AudioPlayerService.shared
        let initialEpoch = service.activeSeekEpoch
        
        let dummySession = PlaybackSession(
            id: "test-session-1",
            userId: "test-user",
            libraryId: "lib-1",
            libraryItemId: "item-1",
            episodeId: nil,
            displayTitle: "Test Audiobook",
            displayAuthor: "Test Author",
            coverPath: nil,
            duration: 1000,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [
                AudioTrack(index: 0, startOffset: 0, duration: 500, title: "Part 1", contentUrl: "https://example.com/1.mp3", mimeType: "audio/mp3", codec: "mp3"),
                AudioTrack(index: 1, startOffset: 500, duration: 500, title: "Part 2", contentUrl: "https://example.com/2.mp3", mimeType: "audio/mp3", codec: "mp3")
            ],
            chapters: [],
            manifestUrl: "/api/items/item-1/manifest.m3u8",
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )
        service.session = dummySession
        service.duration = dummySession.duration
        
        // Seek forward
        service.seek(to: 250)
        XCTAssertEqual(service.currentTime, 250)
        XCTAssertGreaterThan(service.activeSeekEpoch, initialEpoch)
        
        // Seek beyond bounds (should clamp to duration)
        service.seek(to: 1500)
        XCTAssertEqual(service.currentTime, 1000)
        
        // Seek below 0 (should clamp to 0)
        service.seek(to: -50)
        XCTAssertEqual(service.currentTime, 0)
    }
}
