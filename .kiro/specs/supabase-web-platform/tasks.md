# Implementation Plan: Supabase Web Platform

## Overview

Migrate the Audiobookshelf client from a Nuxt 2 + Capacitor app to a fully web-native Nuxt 3 application deployed on Vercel, backed by Supabase (Auth, PostgreSQL with RLS, Storage, and Realtime). The implementation proceeds in layers: project scaffolding → database → auth → library/items → file upload → audio player → progress sync → ebook readers → playlists/collections → preferences → PWA/offline → tests → deployment.

## Tasks

- [x] 1. Scaffold Nuxt 3 project and configure core dependencies
  - Initialize a new Nuxt 3 project with TypeScript support (`nuxi init`)
  - Install and configure `@nuxtjs/supabase`, `@pinia/nuxt`, `@nuxtjs/tailwindcss`, and `@vite-pwa/nuxt`
  - Create `nuxt.config.ts` with Vercel preset (`nitro.preset: 'vercel-edge'`), PWA manifest stub, and `runtimeConfig` for `SUPABASE_URL` / `SUPABASE_ANON_KEY`
  - Create `vercel.json` with `buildCommand`, `outputDirectory`, and Service Worker cache headers
  - Create `.env.example` documenting all required environment variables
  - Set up `tailwind.config.ts` with the project color palette and dark-mode class strategy
  - Create the full directory structure: `pages/`, `components/player/`, `components/reader/`, `components/library/`, `components/download/`, `composables/`, `stores/`, `plugins/`, `server/api/`, `public/`
  - _Requirements: 9.1, 9.3_

- [x] 2. Create Supabase database schema and RLS migrations
  - [x] 2.1 Write SQL migration for all 9 tables
    - Create `supabase/migrations/001_initial_schema.sql` containing DDL for `libraries`, `library_items`, `media_files`, `media_progress`, `bookmarks`, `playlists`, `playlist_items`, `collections`, `collection_books`, and `user_preferences` exactly as specified in the design
    - Add all indexes: `library_items_library_id_idx`, `library_items_title_idx` (GIN full-text), `media_progress_user_id_idx`, `playlist_items_playlist_id_idx`
    - _Requirements: 2.1, 3.1, 4.5, 6.1, 8.1, 8.6, 10.1_

  - [x] 2.2 Write SQL migration for RLS policies
    - Create `supabase/migrations/002_rls_policies.sql` enabling RLS on every table and adding SELECT/INSERT/UPDATE/DELETE policies
    - Apply the ownership-chain pattern for `library_items`, `media_files`, `bookmarks`, `playlist_items`, `collection_books` (access via library ownership)
    - Apply direct `user_id = auth.uid()` policies for `media_progress`, `playlists`, `collections`, `user_preferences`
    - _Requirements: 2.3, 2.6, 3.2, 4.8_

  - [x] 2.3 Write SQL migration for Supabase Storage buckets and storage RLS
    - Create `supabase/migrations/003_storage.sql` defining the `media` (private) and `covers` (public) buckets
    - Add storage RLS policies restricting all operations on `media` to the authenticated user's own `{user_id}/**` path prefix
    - _Requirements: 4.4, 4.8_

  - [ ]\* 2.4 Write property test for RLS isolation (Property 2)
    - **Property 2: RLS isolation — no cross-user data leakage**
    - Generate random pairs of user JWTs and library/item data; assert that queries under user A's JWT never return rows belonging to user B, and writes targeting user B's rows are rejected
    - **Validates: Requirements 2.3, 2.6, 3.2, 4.8**

  - [ ]\* 2.5 Write property test for cascade delete completeness (Property 3)
    - **Property 3: Cascade delete completeness**
    - Generate random library trees with associated items, progress, bookmarks, and playlist entries; delete the root library or item; assert all descendant rows are absent
    - **Validates: Requirements 2.5, 3.7, 4.7**

- [x] 3. Implement authentication
  - [x] 3.1 Create Supabase client plugin and auth composable
    - Create `plugins/supabase.client.ts` initializing `@supabase/supabase-js` with the public anon key and `localStorage` session persistence
    - Create `composables/useAuth.ts` implementing `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, `signOut`, and `refreshSession` matching the `UseAuth` interface in the design
    - Wire `onAuthStateChange` to update the Pinia `auth` store and redirect to `/login` when the session is cleared
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.7, 1.9, 1.10_

  - [x] 3.2 Create Pinia auth store and auth pages
    - Create `stores/auth.ts` holding `user` and `session` refs, populated by `useAuth`
    - Create `pages/login.vue` with email/password form and Google OAuth button; display generic error messages without revealing which field is wrong
    - Create `middleware/auth.ts` redirecting unauthenticated users to `/login` and blocking library access when email is unverified
    - _Requirements: 1.1, 1.3, 1.8, 1.10_

  - [ ]\* 3.3 Write unit tests for auth composable
    - Test session persistence across page refresh (mock `localStorage`)
    - Test redirect to `/login` when refresh token is invalid
    - Test that JWT is included in all outgoing requests
    - _Requirements: 1.4, 1.5, 1.9_

- [-] 4. Implement library management
  - [x] 4.1 Create library composable and Pinia store
    - Create `composables/useLibrary.ts` with functions to create, read, update, and delete libraries using the Supabase JS client
    - Create `stores/library.ts` holding the reactive list of libraries and current library selection
    - Ensure all queries rely on RLS (no manual `user_id` filter needed in client code)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ] 4.2 Create library item composable with pagination, filter, sort, and search
    - Create `composables/useLibraryItems.ts` implementing `fetchItems(libraryId, { page, pageSize, filter, sort, search })` with configurable page size 10–100
    - Implement filter by author, series, genre, tag, and progress status using Supabase PostgREST query builder
    - Implement sort by title, author, `added_at`, `duration_seconds`, and `published_year` in asc/desc order
    - Implement case-insensitive full-text search across title, author, narrator, series, and description using the GIN index
    - Implement `deleteItem(itemId)` which also triggers Storage file deletion
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ] 4.3 Build library UI components
    - Create `components/library/BookCard.vue` displaying cover, title, author, and progress badge
    - Create `components/library/BookshelfGrid.vue` rendering a responsive grid of `BookCard` components with infinite scroll or pagination controls
    - Create `components/library/FilterBar.vue` with dropdowns for filter and sort options and a search input
    - Create `pages/index.vue` composing the library view and loading preferences before render
    - _Requirements: 3.3, 3.4, 3.5, 3.6, 9.4_

  - [ ]\* 4.4 Write property test for filter correctness (Property 10)
    - **Property 10: Library item filter correctness**
    - Generate random sets of library items with random metadata; apply random combinations of filter criteria; assert every returned item satisfies all specified predicates and no non-matching item appears
    - **Validates: Requirements 3.4**

  - [ ]\* 4.5 Write property test for sort correctness (Property 11)
    - **Property 11: Library item sort correctness**
    - Generate random item sets; apply random sort field and direction; assert that for every adjacent pair the sort key compares correctly per the specified direction
    - **Validates: Requirements 3.5**

- [ ] 5. Implement file upload and storage
  - [ ] 5.1 Create file validation helpers
    - Create `utils/fileValidation.ts` with `validateAudioFile`, `validateEbookFile`, and `validateCoverImage` functions that check MIME type against the allowed sets and enforce the 10 MB cover image limit
    - Ensure validation runs entirely client-side before any Storage request is made
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ] 5.2 Create upload composable with retry and progress tracking
    - Create `composables/useUpload.ts` implementing `uploadFile(file, storagePath)` that streams the upload and tracks byte progress
    - Implement exponential backoff retry: up to 3 attempts with delays of 1 s, 2 s, 4 s on network errors; surface an error toast only after all retries are exhausted
    - After a successful upload, persist the returned `storage_path` to the `media_files` or `library_items` record in the database
    - Implement `getSignedUrl(storagePath)` returning a 1-hour signed URL via `supabase.storage.from('media').createSignedUrl(path, 3600)`
    - _Requirements: 4.4, 4.5, 4.6, 4.9_

  - [ ] 5.3 Build upload UI component
    - Create `components/upload/FileUploadForm.vue` with drag-and-drop and file picker, showing per-file validation errors and upload progress bars
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ]\* 5.4 Write property test for file type validation (Property 8)
    - **Property 8: File type validation**
    - Generate random files with valid and invalid MIME types and sizes; assert the validation layer accepts exactly the allowed types and rejects all others before any Storage request
    - **Validates: Requirements 4.1, 4.2, 4.3**

  - [ ]\* 5.5 Write property test for upload retry behavior (Property 9)
    - **Property 9: Upload retry behavior**
    - Mock network failures at the fetch layer; assert the upload is retried exactly 3 times, each delay is at least double the previous, and the error is surfaced only after the third failure
    - **Validates: Requirements 4.6**

  - [ ]\* 5.6 Write property test for storage path user scoping (Property 5)
    - **Property 5: Storage path and cache key user scoping**
    - Generate random user IDs and file paths; assert every storage path begins with the authenticated user's `user_id` prefix and a lookup using a different user's prefix returns no results
    - **Validates: Requirements 4.4, 11.9**

- [ ] 6. Implement audio player
  - [ ] 6.1 Create player composable and Pinia store
    - Create `composables/usePlayer.ts` wrapping `HTMLAudioElement` and implementing the full `UsePlayer` interface from the design: `load`, `play`, `pause`, `seek`, `setPlaybackRate`, `jumpForward`, `jumpBackward`, `setSleepTimer`, `cancelSleepTimer`, `updateMediaSession`
    - Support playback rates: 0.5×, 0.75×, 1×, 1.25×, 1.5×, 1.75×, 2×
    - Support configurable jump intervals between 5 and 60 seconds
    - Implement multi-track queue: on `ended` event, advance to the next track's signed URL and call `load()` automatically
    - Implement sleep timer: pause after N minutes or at end of current chapter
    - Implement Media Session API integration (`navigator.mediaSession`) for browser-level playback controls
    - Create `stores/player.ts` holding all reactive playback state
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [ ] 6.2 Build audio player UI components
    - Create `components/player/AudioPlayer.vue` with play/pause, seek bar, playback rate selector, jump buttons, chapter list, and sleep timer controls
    - Create `components/player/SleepTimer.vue` with minute input and "end of chapter" option
    - Create `components/player/ChapterList.vue` listing chapters with seek-on-click
    - Create `pages/player.vue` as the full-screen player page
    - _Requirements: 5.2, 5.3, 5.4, 5.6, 5.7_

  - [ ] 6.3 Implement bookmark saving
    - Add `saveBookmark(title?: string)` to `usePlayer.ts` that upserts a `bookmarks` record with the current `currentTime` and optional user-supplied title
    - Add bookmark list display to the player UI
    - _Requirements: 5.8_

  - [ ]\* 6.4 Write unit tests for player composable
    - Test track queue advancement on `ended` event
    - Test sleep timer countdown and pause trigger
    - Test playback rate application
    - Test jump forward/backward boundary clamping
    - _Requirements: 5.2, 5.3, 5.4, 5.5_

- [ ] 7. Implement playback progress synchronization
  - [ ] 7.1 Create progress composable with upsert and Realtime subscription
    - Create `composables/useProgress.ts` implementing `upsertProgress`, `fetchAllProgress`, and `subscribeToProgress` matching the `UseProgress` interface in the design
    - In `usePlayer.ts`, wire a `currentTime` watcher that calls `upsertProgress` when `|new_time − old_time| ≥ 10` seconds (debounced)
    - Subscribe to `postgres_changes` on `media_progress` filtered by `user_id = auth.uid()`; on receiving a change, update the player store if the changed item is currently playing without interrupting playback
    - On app launch with an authenticated user, call `fetchAllProgress()` before rendering the library view
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]\* 7.2 Write property test for progress upsert round-trip (Property 1)
    - **Property 1: Progress upsert round-trip**
    - Generate random `(current_time, progress)` pairs within valid ranges (`0 ≤ progress ≤ 1`, `0 ≤ current_time ≤ duration`); upsert then fetch; assert round-trip equality of `current_time`, `progress`, and `is_finished`
    - **Validates: Requirements 6.1, 6.4**

  - [ ]\* 7.3 Write property test for progress value invariant (Property 7)
    - **Property 7: Progress value invariant**
    - Generate random `(current_time, duration, progress)` values including out-of-range values; assert the DB constraint rejects any `progress` outside `[0, 1]` and any `current_time` outside `[0, duration]` when duration is non-null
    - **Validates: Requirements 6.1**

  - [ ]\* 7.4 Write property test for 10-second upsert threshold (Property 12)
    - **Property 12: Playback progress 10-second threshold**
    - Generate random `(old_time, new_time)` pairs; assert `upsertProgress` is triggered if and only if `|new_time − old_time| ≥ 10`
    - **Validates: Requirements 6.1**

- [ ] 8. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Implement ebook readers
  - [ ] 9.1 Create EPUB reader component
    - Create `components/reader/EpubReader.vue` using `epubjs` (0.3.x), adapting `requestMethod` to fetch content via Supabase signed URLs
    - Implement configurable font size and theme (light, dark, sepia)
    - _Requirements: 7.1_

  - [ ] 9.2 Create PDF reader component
    - Create `components/reader/PdfReader.vue` using `@teckel/vue-pdf` with page navigation controls (previous/next page, page number input)
    - _Requirements: 7.2_

  - [ ] 9.3 Create MOBI reader component
    - Create `components/reader/MobiReader.vue` using the existing `assets/ebooks/mobi.js` parser to convert and render MOBI content
    - _Requirements: 7.3_

  - [ ] 9.4 Create CBZ/CBR comic reader component
    - Create `components/reader/ComicReader.vue` using `libarchive.js` to extract and display comic pages with previous/next navigation
    - _Requirements: 7.4_

  - [ ] 9.5 Create ebook progress composable and wire reading position persistence
    - Create `composables/useEbookProgress.ts` implementing upsert of `media_progress` with `ebook_location` (CFI for EPUB, page number for PDF) and `ebook_progress` (0–1 float)
    - On opening any ebook item, fetch the saved `media_progress` record and restore the reader to the saved position
    - Create `pages/reader/[id].vue` routing to the correct reader component based on file MIME type
    - _Requirements: 7.5, 7.6_

  - [ ]\* 9.6 Write property test for ebook reading position round-trip (Property 13)
    - **Property 13: Ebook reading position round-trip**
    - Generate random ebook locations (CFI strings for EPUB, page numbers for PDF); save via `useEbookProgress`; reopen the item; assert the reader initializes at the saved position
    - **Validates: Requirements 7.5, 7.6**

- [ ] 10. Implement playlists and collections
  - [ ] 10.1 Create playlist composable and UI
    - Create `composables/usePlaylists.ts` implementing create, read, update (reorder items), delete, and add/remove items for playlists
    - Persist item order via the `sort_order` column in `playlist_items`
    - Wire playlist playback to `usePlayer`: when a playlist is played, load items in `sort_order` sequence and advance automatically between items
    - Create `components/playlist/PlaylistCard.vue` and `pages/playlists.vue`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ] 10.2 Create collections composable and UI
    - Create `composables/useCollections.ts` implementing create, read, update, and delete for collections
    - On collection creation, validate that all referenced `library_item_ids` belong to the specified `library_id` before inserting
    - Create `components/collection/CollectionCard.vue` and `pages/collections.vue`
    - _Requirements: 8.6, 8.7_

  - [ ]\* 10.3 Write property test for playlist item ordering (Property 4)
    - **Property 4: Playlist item ordering preserved**
    - Generate random playlists with random item permutations; persist a reorder operation; fetch items ordered by `sort_order`; assert the returned sequence matches the persisted permutation
    - **Validates: Requirements 8.4**

- [ ] 11. Implement user preferences
  - [ ] 11.1 Create preferences composable and settings page
    - Create `composables/usePreferences.ts` implementing load and upsert for `user_preferences` records
    - On app launch with an authenticated user, load preferences from the database and apply them (playback rate, jump intervals, theme, sort/filter defaults) before rendering the library view
    - If the database is unreachable at launch, apply the last preferences cached in `localStorage`
    - Create `pages/settings.vue` with controls for all preference fields
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [ ]\* 11.2 Write unit tests for preferences composable
    - Test that preferences are applied before library render
    - Test fallback to cached preferences when the database is unreachable
    - _Requirements: 10.3, 10.4_

- [ ] 12. Implement PWA, Service Worker, and offline downloads
  - [ ] 12.1 Configure Workbox Service Worker via `@vite-pwa/nuxt`
    - Configure `nuxt.config.ts` PWA section with the web app manifest (name, icons, `display: standalone`, `start_url: /`)
    - Configure Workbox runtime caching: `StaleWhileRevalidate` for app shell, `CacheFirst` (30-day expiry) for cover images, custom `NetworkFirst` handler for Supabase Storage audio URLs with `abs-audio-v1` cache and 10-second network timeout
    - Create `plugins/pwa.client.ts` to register the Service Worker
    - Ensure `sw.js` is served with `Cache-Control: no-cache` and `Service-Worker-Allowed: /` headers (already in `vercel.json`)
    - _Requirements: 9.6, 11.5, 11.6_

  - [ ] 12.2 Create download manager composable
    - Create `composables/useDownload.ts` implementing the full `UseDownload` interface: `startDownload`, `pauseDownload`, `resumeDownload`, `deleteDownload`, `getStorageUsage`, `isDownloaded`
    - Fetch audio files via `fetch()` with `ReadableStream` to track byte progress; store audio blobs in Cache API under `abs-audio-v1` keyed by `{user_id}/{item_id}/{filename}`
    - Store download state and item metadata in IndexedDB (`abs-offline-db`)
    - Scope all cache keys to the authenticated user's `user_id` to prevent cross-user access
    - On network interruption, resume from the last successfully persisted byte on reconnect, up to 3 automatic retries
    - On download completion, mark the item as available offline in the local IndexedDB cache and update the UI
    - Implement `deleteDownload` to remove all Cache API entries matching the item's path prefix and update `isDownloaded` to return false
    - Implement `getStorageUsage` using the `navigator.storage.estimate()` API to report total downloaded bytes and remaining quota
    - If Cache API and IndexedDB are both unavailable, surface an informational message to the user
    - Create `stores/downloads.ts` holding reactive download state
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.7, 11.8, 11.9, 11.10_

  - [ ] 12.3 Build download UI components
    - Create `components/download/DownloadManager.vue` showing per-item download buttons, progress bars (percentage of total bytes), and storage usage summary
    - Create `components/download/DownloadProgress.vue` for inline progress display on `BookCard`
    - _Requirements: 11.2, 11.8_

  - [ ]\* 12.4 Write property test for downloaded items served from cache (Property 6)
    - **Property 6: Downloaded items served from cache regardless of connectivity**
    - Download a Library_Item; simulate online and offline states; initiate playback; assert all audio data is served from the Cache API and no fetch requests reach Supabase Storage URLs
    - **Validates: Requirements 11.5, 11.6**

  - [ ]\* 12.5 Write property test for download progress percentage accuracy (Property 14)
    - **Property 14: Download progress percentage accuracy**
    - Generate random `(bytesDownloaded, totalBytes)` pairs where `0 ≤ bytesDownloaded ≤ totalBytes`; assert the displayed percentage equals `floor(bytesDownloaded / totalBytes * 100)`
    - **Validates: Requirements 11.2**

  - [ ]\* 12.6 Write property test for download deletion clears cache (Property 15)
    - **Property 15: Download deletion clears cache**
    - Download a Library_Item fully; call `deleteDownload`; assert the Cache API contains no entries matching the item's storage path prefix and `isDownloaded(itemId)` returns false
    - **Validates: Requirements 11.7**

- [ ] 13. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. Write integration tests against local Supabase
  - [ ] 14.1 Write auth flow integration tests
    - Test full sign-up → email verify → sign-in → JWT refresh → sign-out flow against a local Supabase instance (`supabase start`)
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.8_

  - [ ]\* 14.2 Write RLS integration tests
    - Create a library as user A; attempt to read it as user B; assert 0 rows returned
    - Attempt to update/delete user A's rows as user B; assert rejection
    - _Requirements: 2.3, 2.6, 4.8_

  - [ ]\* 14.3 Write cascade delete integration tests
    - Create a library with items, progress records, bookmarks, and playlist entries; delete the library; assert all child rows are absent
    - _Requirements: 2.5, 3.7, 4.7_

  - [ ]\* 14.4 Write storage upload/download integration tests
    - Upload an audio file; generate a signed URL; fetch the content; assert it matches the original
    - _Requirements: 4.5, 4.9_

  - [ ]\* 14.5 Write Realtime progress sync integration tests
    - Open two sessions for the same user; update `media_progress` in session 1; assert session 2 receives the change within 2 seconds
    - _Requirements: 6.2_

- [ ] 15. Write end-to-end tests with Playwright
  - [ ] 15.1 Write E2E test for login flow
    - Test email/password login and Google OAuth (mock provider)
    - _Requirements: 1.1, 1.7_

  - [ ]\* 15.2 Write E2E test for library creation and item upload
    - Create a library, upload an audio file, verify the item appears in the library grid
    - _Requirements: 2.2, 4.5_

  - [ ]\* 15.3 Write E2E test for audio playback and progress persistence
    - Play an audiobook item; advance playback by 10+ seconds; reload the page; assert progress is restored
    - _Requirements: 5.1, 6.1, 6.4_

  - [ ]\* 15.4 Write E2E test for ebook reading with position restore
    - Open an EPUB item; navigate to a chapter; close and reopen; assert the reader restores the saved position
    - _Requirements: 7.5, 7.6_

  - [ ]\* 15.5 Write E2E test for offline download and playback
    - Download a Library_Item; simulate offline mode via Playwright network interception; play the item; assert audio is served from the Service Worker cache
    - _Requirements: 11.1, 11.5_

- [ ] 16. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 17. Configure Vercel deployment
  - Verify `nuxt.config.ts` uses `nitro.preset: 'vercel-edge'` (or `'vercel'` for Node.js runtime)
  - Confirm `vercel.json` is correct with `buildCommand: "nuxt build"`, `outputDirectory: ".output/public"`, and Service Worker headers
  - Document all required Vercel environment variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NUXT_PUBLIC_SUPABASE_URL`, `NUXT_PUBLIC_SUPABASE_ANON_KEY`) in `README.md`
  - Verify the app loads within 3 seconds on a 10 Mbps connection by running a Lighthouse audit in CI
  - _Requirements: 9.1, 9.2, 9.3, 9.5_

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests use `fast-check` with a minimum of 100 iterations each; each test file includes the tag comment `// Feature: supabase-web-platform, Property N: <property_text>`
- Unit and integration tests use Vitest; E2E tests use Playwright
- Integration tests require a local Supabase instance (`supabase start`)
- The Service Worker stores raw audio blobs under stable cache keys (not signed URLs, which expire) and intercepts Supabase Storage requests by path pattern
- All cache keys and storage paths are scoped to `{user_id}/` to prevent cross-user data access
- Capacitor native builds (Android/iOS) and Apple OAuth are explicitly deferred to a future phase
