# Requirements Document

## Introduction

This feature aligns the iOS Swift app (audiobookphile-app) with the Supabase backend as the single source of truth. Three discrete gaps are addressed in one pass:

1. **Model drift** — `BookMetadata` in `Models.swift` is missing the `authorNameLF` and `abridged` fields present in the backend `BookMetadataSchema` Zod schema and emitted by `mappers.ts`.
2. **Date decoder mismatch** — `AudiobookphileAPI.swift` uses a millisecond-epoch-only `JSONDecoder`. Any endpoint that returns an ISO-8601 timestamp (e.g. direct DB progress rows) crashes the decoder. A dual-strategy decoder must try ms-epoch first and fall back to ISO-8601.
3. **Real-time progress subscription** — `SocketService.swift` is a no-op stub. A new `SupabaseRealtimeService` must implement a real WebSocket subscription to Supabase Realtime `postgres_changes` for the `media_progress` table, scoped to the authenticated user, using `URLSessionWebSocketTask` (no external SDK).

Stats / listening history are explicitly out of scope.

## Glossary

- **BookMetadata**: The Swift struct in `Models.swift` that mirrors `BookMetadataSchema` from `audiobookphile-backend/src/types/schemas.ts`.
- **BookMetadataSchema**: The canonical Zod schema in the backend that defines all fields the mobile API emits for book metadata.
- **authorNameLF**: A string field containing author name(s) in "Last, First" format, used for sort ordering. Emitted by `mappers.ts` as `authorNameLF`.
- **abridged**: A nullable boolean field on `BookMetadata` indicating whether an audiobook is an abridged edition.
- **DualStrategyDecoder**: A `JSONDecoder` configured with a custom `dateDecodingStrategy` that first attempts to decode a date value as a milliseconds-since-epoch `Double`, then falls back to ISO-8601 string parsing.
- **SupabaseRealtimeService**: A new Swift class that establishes and maintains a WebSocket connection to the Supabase Realtime endpoint, subscribing to `postgres_changes` on the `media_progress` table filtered by `user_id = <authenticated user's UUID>`.
- **SocketService**: The existing no-op WebSocket stub in `Sources/Audiobookphile/Core/Network/SocketService.swift` that `AppState` calls on login/logout.
- **MediaProgress**: The Swift struct in `Models.swift` representing a user's playback position and completion status for a library item.
- **URLSessionWebSocketTask**: The Foundation API used for WebSocket communication, avoiding a dependency on the `supabase-swift` SDK.
- **Supabase Realtime**: The WebSocket-based push service at `wss://<project>.supabase.co/realtime/v1/websocket` that broadcasts database change events.
- **postgres_changes**: The Supabase Realtime channel event type that delivers row-level INSERT / UPDATE / DELETE notifications for a specified Postgres table.
- **AudiobookphileAPI**: The Swift actor in `Sources/Audiobookphile/Core/Network/AudiobookphileAPI.swift` responsible for all HTTP communication with the backend.

## Requirements

### Requirement 1 — BookMetadata Model Alignment

**User Story:** As a developer, I want `BookMetadata` in the iOS app to declare the same fields as `BookMetadataSchema` in the backend, so that JSON responses from the API decode without data loss.

#### Acceptance Criteria

1. THE `BookMetadata` struct SHALL declare a `authorNameLF` property of type `String?`.
2. THE `BookMetadata` struct SHALL declare an `abridged` property of type `Bool?`.
3. THE `BookMetadata` CodingKeys enum SHALL include `authorNameLF` mapped to the JSON key `"authorNameLF"`.
4. THE `BookMetadata` CodingKeys enum SHALL include `abridged` mapped to the JSON key `"abridged"`.
5. WHEN the API returns a JSON object whose `media.metadata` field contains `"authorNameLF"` and `"abridged"` keys, THE `BookMetadata` decoder SHALL populate both properties without throwing a `DecodingError`.
6. WHEN the API returns a JSON object whose `media.metadata` field omits `"authorNameLF"` and `"abridged"` keys, THE `BookMetadata` decoder SHALL set both properties to `nil` without throwing a `DecodingError`.

### Requirement 2 — Dual-Strategy Date Decoder

**User Story:** As a developer, I want the app's JSON decoder to handle both millisecond-epoch and ISO-8601 date representations, so that every current and future endpoint decodes dates correctly regardless of which format the backend emits.

#### Acceptance Criteria

1. THE `AudiobookphileAPI` SHALL expose a `defaultDecoder` property whose `dateDecodingStrategy` first attempts to decode a date value as a `Double` representing milliseconds since the Unix epoch (divide by 1000 to obtain `TimeInterval`).
2. WHEN the `Double`-epoch strategy fails (i.e. the JSON value is a string, not a number), THE `defaultDecoder` SHALL attempt to parse the value as an ISO-8601 string using `ISO8601DateFormatter` with the `withInternetDateTime` and `withFractionalSeconds` options applied.
3. WHEN both strategies fail, THE `defaultDecoder` SHALL throw a `DecodingError.dataCorruptedError` that includes the offending value in its description.
4. THE `defaultDecoder` SHALL be the only decoder used in `AudiobookphileAPI` for responses that contain `Date`-typed fields (login, token refresh, library items, playback session, progress).
5. WHEN `AudiobookphileAPI.getUserProgress` receives a response whose timestamp fields (`lastUpdate`, `startedAt`, `finishedAt`) are ISO-8601 strings, THE `MediaProgress` decoder SHALL produce valid `Date` values for each present field.

### Requirement 3 — Supabase Realtime Progress Subscription

**User Story:** As a listener, I want in-progress reading state to update in real time when a progress change occurs in the database, so that the app reflects the current playback position without requiring a manual refresh.

#### Acceptance Criteria

1. THE codebase SHALL contain a `SupabaseRealtimeService` class in `Sources/Audiobookphile/Core/Network/SupabaseRealtimeService.swift` that manages a single persistent `URLSessionWebSocketTask` to the Supabase Realtime WebSocket endpoint.
2. WHEN `SupabaseRealtimeService.connect(projectURL:accessToken:userID:)` is called with a valid project URL, access token, and user UUID, THE `SupabaseRealtimeService` SHALL open a WebSocket connection to `wss://<project-host>/realtime/v1/websocket?apikey=<anonKey>&vsn=1.0.0`.
3. WHEN the WebSocket connection is established, THE `SupabaseRealtimeService` SHALL send a `phx_join` message to the channel `"realtime:public:media_progress:user_id=eq.<userID>"` with a valid Supabase Realtime join payload including an `access_token`.
4. WHEN the server returns a `phx_reply` message with `status: "ok"` for the join, THE `SupabaseRealtimeService` SHALL set `isConnected` to `true`.
5. WHEN Supabase Realtime delivers a `postgres_changes` event on the `media_progress` table for the subscribed user, THE `SupabaseRealtimeService` SHALL decode the change payload and invoke the `onProgressChanged` callback with the affected `libraryItemId` and updated `MediaProgress`-compatible field values.
6. WHEN the WebSocket connection closes unexpectedly, THE `SupabaseRealtimeService` SHALL set `isConnected` to `false` and schedule a reconnection attempt after an exponential back-off delay, with a maximum delay of 30 seconds and a maximum of 5 consecutive attempts.
7. WHEN `SupabaseRealtimeService.disconnect()` is called, THE `SupabaseRealtimeService` SHALL cancel the WebSocket task, set `isConnected` to `false`, and suppress any scheduled reconnection attempt.
8. THE `SupabaseRealtimeService` SHALL implement a heartbeat by sending a `heartbeat` Phoenix message every 30 seconds while the connection is open, to prevent the server from closing the connection due to inactivity.
9. THE `SupabaseRealtimeService` SHALL NOT depend on any third-party Swift package; THE implementation SHALL use only `Foundation` framework APIs (`URLSession`, `URLSessionWebSocketTask`).
10. WHILE `SupabaseRealtimeService.isConnected` is `false`, THE `SupabaseRealtimeService` SHALL buffer zero outbound messages and SHALL NOT throw errors on calls to `disconnect()`.

### Requirement 4 — SocketService Integration with SupabaseRealtimeService

**User Story:** As a developer, I want `AppState` to drive `SupabaseRealtimeService` through the existing `SocketService` call sites, so that real-time updates activate automatically on login and deactivate on logout without modifying `AppState`.

#### Acceptance Criteria

1. THE `SocketService.connect(serverAddress:token:)` method SHALL call `SupabaseRealtimeService.shared.connect(projectURL:accessToken:userID:)` when the `serverAddress` is a Supabase project URL (i.e. contains `.supabase.co` or the known local port `54321`) and a non-empty `token` is supplied.
2. THE `SocketService.disconnect()` method SHALL call `SupabaseRealtimeService.shared.disconnect()`.
3. WHEN `SupabaseRealtimeService` invokes `onProgressChanged`, THE `SocketService` SHALL forward the event to its own `onProgressUpdated` callback so that existing subscribers in the app continue to receive real-time progress updates.
4. THE `SocketService.isConnected` property SHALL reflect the value of `SupabaseRealtimeService.shared.isConnected`.
5. WHERE the server address is not a Supabase URL, THE `SocketService.connect(serverAddress:token:)` method SHALL log a message and take no further action (preserving the legacy no-op behaviour for non-Supabase servers).
