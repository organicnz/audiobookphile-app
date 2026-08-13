import XCTest
@testable import Audiobookphile

final class TelemetryServiceTests: XCTestCase {

    func testDSNParseSentryCloud() {
        let dsn = SentryDSN(string: "https://a1b2c3d4e5f6@o123456.ingest.sentry.io/654321")
        XCTAssertNotNil(dsn)
        XCTAssertEqual(dsn?.host, "o123456.ingest.sentry.io")
        XCTAssertEqual(dsn?.publicKey, "a1b2c3d4e5f6")
        XCTAssertEqual(dsn?.projectID, "654321")
        XCTAssertEqual(dsn?.envelopeURL?.absoluteString, "https://o123456.ingest.sentry.io/api/654321/envelope/")
    }

    func testDSNParseSelfHosted() {
        let dsn = SentryDSN(string: "https://abc123@sentry.example.com/7")
        XCTAssertNotNil(dsn)
        XCTAssertEqual(dsn?.host, "sentry.example.com")
        XCTAssertEqual(dsn?.publicKey, "abc123")
        XCTAssertEqual(dsn?.projectID, "7")
        XCTAssertEqual(dsn?.envelopeURL?.absoluteString, "https://sentry.example.com/api/7/envelope/")
    }

    func testDSNRejectsInvalid() {
        XCTAssertNil(SentryDSN(string: ""))
        XCTAssertNil(SentryDSN(string: "not a dsn"))
        XCTAssertNil(SentryDSN(string: "https://nohost"))
        XCTAssertNil(SentryDSN(string: "   "))
    }

    func testDSNTrimsWhitespace() {
        let dsn = SentryDSN(string: "  https://key@o1.ingest.sentry.io/2  ")
        XCTAssertNotNil(dsn)
        XCTAssertEqual(dsn?.publicKey, "key")
    }

    func testTelemetryDisabledWithoutDSN() {
        XCTAssertFalse(TelemetryService.shared.isConfigured)
    }
}
