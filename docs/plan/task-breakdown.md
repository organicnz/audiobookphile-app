# Native iOS Audiobookphile App with Liquid Glass Design

## Project Overview

Create a fully native SwiftUI iOS app for Audiobookphile with Liquid Glass design system, translating the existing Nuxt.js/Capacitor structure.

---

## Architecture & Setup

- [ ] Create project structure
- [ ] Define folder organization (App, Features, Components, Models, Services, Utilities)
- [ ] Set up core app entry point
- [ ] Configure Info.plist and app settings

---

## Design System (Liquid Glass)

- [ ] Create `LiquidGlassComponents.swift` with reusable glass effects
- [ ] Build `GlassCard` component
- [ ] Build `GlassButton` component
- [ ] Build `GlassNavigationBar` component
- [ ] Create color system and theme support
- [ ] Add glassmorphism modifiers

---

## Core Models

- [ ] Create `Book.swift` model (from libraryItem)
- [ ] Create `Audiobook.swift` model
- [ ] Create `Podcast.swift` and `PodcastEpisode.swift` models
- [ ] Create `Library.swift` model
- [ ] Create `PlaybackSession.swift` model
- [ ] Create `Chapter.swift` model
- [ ] Create `User.swift` model
- [ ] Create `AudioTrack.swift` model

---

## Services Layer

- [ ] Create `NetworkService.swift` (API client)
- [ ] Create `AudiobookphileService.swift` (API endpoints)
- [ ] Create `AuthenticationService.swift` (login/connection)
- [ ] Create `AudioPlayerService.swift` (AVFoundation wrapper)
- [ ] Create `DownloadService.swift` (local storage)
- [ ] Create `LibraryService.swift` (library management)
- [ ] Create `StorageService.swift` (UserDefaults/CoreData)
- [ ] Create `SocketService.swift` (real-time updates)

---

## Audio Player

- [ ] Create `AudioPlayerView.swift` (fullscreen player with LG)
- [ ] Create `MiniPlayerView.swift` (bottom bar with LG)
- [ ] Create `AudioPlayerViewModel.swift` (player state management)
- [ ] Implement playback controls (play/pause/seek)
- [ ] Implement chapter navigation
- [ ] Implement sleep timer
- [ ] Implement playback speed control
- [ ] Add background audio support
- [ ] Add Now Playing info integration
- [ ] Add lock screen controls

---

## Feature Views

### Authentication

- [ ] Create `ConnectView.swift` (server connection with LG)
- [ ] Create `LoginView.swift` (if needed)

### Library/Bookshelf

- [ ] Create `BookshelfView.swift` (main library view with LG)
- [ ] Create `LibraryGridView.swift` (book grid with glass cards)
- [ ] Create `BookDetailView.swift` (book details with LG)

### Downloads

- [ ] Create `DownloadsView.swift` (download management with LG)
- [ ] Create `LocalMediaView.swift` (local files)

### Settings & Account

- [ ] Create `SettingsView.swift` (app settings with LG)
- [ ] Create `AccountView.swift` (user account with LG)
- [ ] Create `StatsView.swift` (listening stats with LG)

### Search

- [ ] Create `SearchView.swift` (search interface with LG)

---

## Reusable Components

- [ ] Create `BookCoverView.swift` (cover image with glass effects)
- [ ] Create `BookCard.swift` (library item card with LG)
- [ ] Create `ChapterListView.swift` (chapter list with LG)
- [ ] Create `PlaybackProgressBar.swift` (custom progress bar)
- [ ] Create `StatusBadge.swift` (status indicators with LG)
- [ ] Create `LoadingView.swift` (loading spinner with LG)

---

## Utilities & Extensions

- [ ] Create `TimeFormatter.swift` (duration formatting)
- [ ] Create `Color+Extensions.swift` (custom colors)
- [ ] Create `View+Extensions.swift` (custom modifiers)
- [ ] Create `Constants.swift` (app constants)

---

## Testing & Polish

- [ ] Test server connection
- [ ] Test audio playback
- [ ] Test offline downloads
- [ ] Test background audio
- [ ] Verify all LG components
- [ ] Polish animations and transitions
