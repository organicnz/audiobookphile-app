# 🎨 Audiobookshelf Mobile UI/UX Benchmark & Mapping Guide

This document defines the **official UI/UX benchmarks** derived from the upstream Capacitor/NuxtJS mobile application ([advplyr/audiobookshelf-app](https://github.com/advplyr/audiobookshelf-app)) and maps them directly to our high-fidelity, native Swift/Kotlin implementation. 

Use this guide as the permanent source of truth for matching features, client-server sync flows, and screen navigation models while enhancing the aesthetics using the **Liquid Glass (LG)** visual system.

---

## 🎯 Core UX Pillars & Behaviors

To achieve parity with the official app, every native component must satisfy these key user behaviors:

### 1. Robust Server Connection & State
*   **Upstream Standard**: The app requires a validated server URL, username, and password. Multiple server profiles can be cached for fast switching.
*   **Native Translation (`ConnectView.swift`)**:
    *   Dynamic validation: Connect button is enabled only when URL, Username, and Password are valid.
    *   Profile Cache: Stores up to 5 recently visited servers with their respective usernames for quick tap-to-fill selection.
    *   Hassle-Free Debugging: Automatic simulator auto-login enabled for rapid developer iteration.

### 2. The Bookshelf & Cover Art Presentation
*   **Upstream Standard**: A custom shelf-style presentation representing home feeds (e.g., "Continue Reading", "Recently Added", "Read/Unread"). Custom grids support covers with aspect ratio containment, title/author labels, and progress bar rings/lines.
*   **Native Translation (`BookshelfView.swift` & `BookCard.swift`)**:
    *   Use highly virtualized lists (`LazyVGrid` with item prefetching) to handle library catalogs with thousands of items at 120fps.
    *   Implement **Liquid Glass cards** featuring real-time dominant color extraction from covers to adapt background highlights dynamically.
    *   Display a clean, low-profile progress indicator overlays (semi-translucent glass tracks with colored status lines).

### 3. Media Player Navigation & Gestures
*   **Upstream Standard**: Dual-state media player consisting of:
    *   *Mini Player*: A persistent bottom bar showing cover art, title, current playback, play/pause toggle, and dismissal swipe.
    *   *Full Player*: Expansive fullscreen player with large cover art, elapsed/remaining tracks, skip intervals (forward/back), speed picker, sleep timer, and a chapters tray.
*   **Native Translation (`AudioPlayerView.swift` & `MiniPlayerView.swift`)**:
    *   **Interactive Spring Gestures**: Seamless transition between the Mini Player and Full Player using native swipe-up/down gestures.
    *   **Dynamic Glass Backdrop**: High-performance Metal-accelerated background blur that morphs colors to match the active audiobook cover art.
    *   **Audio Controls & Precise Seek**: Large glass controls with feedback haptics on tap. Progress scrubbing must support relative chapter seek and total track seek.

### 4. Reliable Background Playback & Sync
*   **Upstream Standard**: Utilizes system audio sessions, publishes metadata to system locks/control centers, and coordinates real-time progress syncing with the server via persistent WebSockets (or REST APIs).
*   **Native Translation (`AudioPlayerService.swift` & `SocketService.swift`)**:
    *   Keep standard playback position in sync on background state changes.
    *   Syncing progress via real-time WebSocket connection to the server when online.
    *   Failing Sync UI: Display a visual sync-alert status icon on the player screen if connection drops, queuing updates to sync automatically when reconnected.

---

## 🛠️ Screen-by-Screen UI/UX Specifications

| Screen / Flow | Upstream Capacitor Feature | Native Liquid Glass Enhancement | Target Parity Status |
| :--- | :--- | :--- | :--- |
| **Server Login** | Plain text inputs, basic forms, simple loading spinner. | Animated mesh gradients, glass fields with inner blur overlay, system haptics. | ✅ Parity & Elevated |
| **Library Browser** | Grid/List views, basic top filtering bar. | Virtualized lazy grid, glass cards, dynamic search input with immediate filter, swipe gestures. | ✅ Parity & Elevated |
| **Item Details** | Book metadata, large cover, chapter list, download buttons. | Layered glass card panel, hero animation transition from grid to detail, sliding chapter sheet. | ✅ Parity & Elevated |
| **Downloads / Local** | Offline list showing downloaded items and delete buttons. | Offline-enabled database check; items downloaded can be played with zero latency via local AVPlayer URL. | ✅ Parity & Elevated |
| **Settings** | Configuration options for skipped times, sync intervals, cache limits. | Tabbed settings with Glass sliders, toggles, and clear cache actions. | ✅ Parity & Elevated |

---

## 🎨 Visual Identity & Polish Guidelines

Always respect the following **Liquid Glass Design System** rules to deliver a premium, visually stunning user experience:

1.  **Glassmorphism Everywhere**:
    *   Never use flat backgrounds. Use `.ultraThinMaterial` backdrops combined with thin borders that simulate light refraction:
        ```swift
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        ```
2.  **No Flat Colors**:
    *   Prefer dynamic linear gradients and interactive background particles (`GlassParticlesView`) over plain, solid colors.
3.  **ProMotion 120Hz Responsiveness**:
    *   Ensure all animations use spring physics (`.spring(response:dampingFraction:)`) to look organic and fluid on Apple displays.
4.  **Haptics**:
    *   Provide discrete micro-vibrations (e.g., `.light` or `.selection` impact) on every interface action like play, pause, skip, and speed selection.

---

*This document is saved as a permanent part of the codebase repository under `docs/UI-UX-BENCHMARK.md` to guide all future feature additions and ensure visual integrity.*
