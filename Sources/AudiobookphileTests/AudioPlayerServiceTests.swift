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
            missingTrackCount: 0,
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

    func testSeekWithZeroInitialDurationFallback() async throws {
        let service = AudioPlayerService.shared
        
        let dummySession = PlaybackSession(
            id: "test-session-zero-dur",
            userId: "test-user",
            libraryId: "lib-1",
            libraryItemId: "item-2",
            episodeId: nil,
            displayTitle: "Test Audiobook Zero Dur",
            displayAuthor: "Test Author",
            coverPath: nil,
            duration: 1200,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [
                AudioTrack(index: 0, startOffset: 0, duration: 600, title: "Part 1", contentUrl: "https://example.com/1.mp3", mimeType: "audio/mp3", codec: "mp3"),
                AudioTrack(index: 1, startOffset: 600, duration: 600, title: "Part 2", contentUrl: "https://example.com/2.mp3", mimeType: "audio/mp3", codec: "mp3")
            ],
            chapters: [],
            manifestUrl: nil,
            missingTrackCount: 0,
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )
        service.session = dummySession
        service.duration = 0 // Simulating uninitialized service duration
        
        // Seek to 750 (Part 2)
        service.seek(to: 750)
        XCTAssertEqual(service.currentTime, 750, "Should fall back to session duration and not clamp to 0")
    }

    /// Regression: swapping sessions used to spawn `Task { await closeSession() }`
    /// which resolved `self.session` at execution time — i.e. the NEW session —
    /// and engine.cleanup() destroyed the freshly built playback queue.
    func testStartPlaybackSwapPreservesNewQueue() async throws {
        let service = AudioPlayerService.shared

        func makeSession(id: String) -> PlaybackSession {
            PlaybackSession(
                id: id,
                userId: "test-user",
                libraryId: "lib-1",
                libraryItemId: "item-\(id)",
                episodeId: nil,
                displayTitle: "Book \(id)",
                displayAuthor: "Author",
                coverPath: nil,
                duration: 1000,
                playMethod: 0,
                mediaPlayer: "AVQueuePlayer",
                mediaType: "book",
                audioTracks: [
                    AudioTrack(index: 0, startOffset: 0, duration: 500, title: "Part 1", contentUrl: "https://example.com/\(id)-1.mp3", mimeType: "audio/mp3", codec: "mp3"),
                    AudioTrack(index: 1, startOffset: 500, duration: 500, title: "Part 2", contentUrl: "https://example.com/\(id)-2.mp3", mimeType: "audio/mp3", codec: "mp3")
                ],
                chapters: [],
                manifestUrl: nil,
                missingTrackCount: 0,
                currentTime: 0,
                playbackRate: 1.0,
                startedAt: Date(),
                updatedAt: Date()
            )
        }

        // Session A is playing…
        service.startPlayback(session: makeSession(id: "swap-A"))
        // …then the user starts session B without closing A first.
        service.startPlayback(session: makeSession(id: "swap-B"))

        // Yield so any spawned teardown task gets a chance to run (it used to
        // run here and wipe the queue of session B).
        await Task.yield()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(service.session?.id, "swap-B")
        XCTAssertGreaterThan(
            service.engine.queuedItemsCount, 0,
            "New session's playback queue must survive the session swap"
        )
        XCTAssertTrue(service.isPlaying)
    }
}
