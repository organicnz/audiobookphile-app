# ✅ iOS App Build Checklist - Complete Reference

## 🎯 Everything Needed to Ship in 3-5 Days

This is your master checklist. Follow it step-by-step, and you WILL have a working app.

---

## 📋 PRE-DEVELOPMENT CHECKLIST

### Environment Setup

- [ ] Mac with macOS 13+ installed
- [ ] Xcode 15+ installed
- [ ] Apple Developer account (for TestFlight/App Store)
- [ ] Audiobookphile server running (for API testing)
- [ ] Git installed
- [ ] GitHub/GitLab repo created (optional but recommended)

### Documentation Read

- [ ] Read `SPEED-RUN.md` (main guide)
- [ ] Read `API-REFERENCE.md` (API endpoints)
- [ ] Browse `native-ios-example/` (code examples)
- [ ] Read `native-ios-strategy.md` (strategy overview)

---

## DAY 1: PROJECT SETUP & INFRASTRUCTURE ✅

### Hour 1-2: Xcode Project

- [ ] Create new iOS App project in Xcode
- [ ] Set Product Name: `AudiobookphileClient`
- [ ] Set Bundle ID: `com.audiobookphile.native`
- [ ] Set Interface: SwiftUI
- [ ] Set Language: Swift
- [ ] Set Min iOS Version: 15.0
- [ ] Create folder structure:
  ```
  AudiobookphileClient/
  ├── App/
  ├── Features/
  ├── Components/
  ├── Core/
  ├── Models/
  ├── Services/
  └── Utilities/
  ```

### Hour 2-3: Copy Design System

- [ ] Copy `GlassCard.swift` from examples
- [ ] Copy `GlassButton.swift` from examples
- [ ] Copy `GlassModifiers.swift` from examples
- [ ] Copy `GlassParticles.swift` from examples
- [ ] Test in Xcode previews - should compile ✅

### Hour 3-4: Copy Core Infrastructure

- [ ] Copy `ProMotionManager.swift` from examples
- [ ] Copy `MetalContext.swift` from examples
- [ ] Copy `ParallaxScrollView.swift` from examples
- [ ] Test in Xcode previews - should compile ✅

### Hour 4-5: Models

- [ ] Copy `Models.swift` from examples
- [ ] Verify all models compile
- [ ] **Critical models to check:**
  - [ ] Book
  - [ ] PlaybackSession
  - [ ] Chapter
  - [ ] MediaProgress
  - [ ] User
  - [ ] Library

### Hour 5-8: API Client

- [ ] Create `Services/Networking/AudiobookphileAPI.swift`
- [ ] Implement `connect()` function (login)
- [ ] Implement `getLibraries()` function
- [ ] Implement `getLibraryItems()` function
- [ ] Implement `startPlaybackSession()` function
- [ ] Implement `syncProgress()` function
- [ ] **Test API calls:**
  - [ ] Login works ✅
  - [ ] Can fetch libraries ✅
  - [ ] Can fetch books ✅

**END OF DAY 1 CHECKPOINT:**

```swift
// This should work:
Task {
    let user = try await AudiobookphileAPI.shared.connect(
        to: "http://your-server.com",
        username: "test",
        password: "test"
    )
    print("Logged in: \(user.username)")

    let libraries = try await AudiobookphileAPI.shared.getLibraries()
    print("Found \(libraries.count) libraries")
}
```

---

## DAY 2: VIEWS & NAVIGATION ✅

### Hour 1-2: App Entry Point

- [ ] Create `App/AudiobookphileApp.swift` (main app)
- [ ] Create `Services/AuthenticationManager.swift`
- [ ] Implement login/logout logic
- [ ] Add Keychain storage (UserDefaults for now is OK)
- [ ] Test auth flow in simulator

### Hour 2-3: Connect View

- [ ] Create `Features/Authentication/Views/ConnectView.swift`
- [ ] Add text fields for server URL, username, password
- [ ] Add glass styling
- [ ] Wire up to AuthenticationManager
- [ ] **Test:** Can login and see user object ✅

### Hour 3-4: Main Tab View

- [ ] Create `App/MainTabView.swift`
- [ ] Add 3 tabs: Library, Downloads, Settings
- [ ] Add tab icons
- [ ] Test navigation between tabs

### Hour 4-6: Bookshelf View

- [ ] Copy `BookshelfView.swift` from examples
- [ ] Create `Features/Library/ViewModels/BookshelfViewModel.swift`
- [ ] Wire up to API client
- [ ] **Test:** Can see list of books ✅
- [ ] Add loading states
- [ ] Add error states
- [ ] Add pull-to-refresh

### Hour 6-8: Book Card & Detail

- [ ] Copy `BookCard.swift` from examples
- [ ] Create `Features/Library/Views/BookDetailView.swift`
- [ ] Show book cover, title, author, description
- [ ] Add "Play" button (wire up later)
- [ ] **Test:** Can navigate to book detail ✅

**END OF DAY 2 CHECKPOINT:**

```
Can complete this flow:
1. Open app
2. Login
3. See library grid
4. Tap book
5. See book details
```

---

## DAY 3: AUDIO PLAYBACK ✅

### Hour 1-3: Audio Player Service

- [ ] Create `Services/Audio/AudioPlayerService.swift`
- [ ] Set up AVAudioSession
- [ ] Set up AVPlayer
- [ ] Implement `loadSession()`
- [ ] Implement `play()` / `pause()`
- [ ] Implement `seek(to:)`
- [ ] Implement `seek(by:)` (skip forward/back)
- [ ] **Test:** Can play audio file ✅

### Hour 3-4: Background Audio & Lock Screen

- [ ] Configure audio session for background
- [ ] Set up MPRemoteCommandCenter
- [ ] Implement Now Playing info
- [ ] **Test:** Audio continues in background ✅
- [ ] **Test:** Lock screen controls work ✅

### Hour 4-6: AudioPlayerView (Full Player)

- [ ] Copy `AudioPlayerView.swift` from examples
- [ ] Create `Features/Player/ViewModels/AudioPlayerViewModel.swift`
- [ ] Wire up to AudioPlayerService
- [ ] Add playback controls
- [ ] Add seek bar
- [ ] Add chapter navigation
- [ ] **Test:** Full player UI works ✅

### Hour 6-7: Mini Player

- [ ] Create `Components/Player/MiniPlayerView.swift`
- [ ] Add to MainTabView (persistent bottom bar)
- [ ] Show currently playing book
- [ ] Add play/pause button
- [ ] Tap to show full player
- [ ] **Test:** Mini player persists across tabs ✅

### Hour 7-8: Progress Sync

- [ ] Implement periodic progress sync (every 30s)
- [ ] Sync when pause/seek
- [ ] Sync when app enters background
- [ ] **Test:** Progress saves to server ✅
- [ ] **Test:** Can resume from another device ✅

**END OF DAY 3 CHECKPOINT:**

```
Can complete this flow:
1. Login
2. Browse library
3. Tap book
4. Tap play
5. Audio starts playing
6. Lock phone - audio continues
7. Use lock screen controls
8. Unlock - see mini player
9. Tap mini player - see full player
10. Seek, pause, play all work
11. Progress syncs to server
```

---

## DAY 4: POLISH & FEATURES ✅

### Hour 1-2: Settings View

- [ ] Create `Features/Settings/Views/SettingsView.swift`
- [ ] Show server info
- [ ] Show user info
- [ ] Add logout button
- [ ] Add playback settings (speed, skip times)
- [ ] **Test:** Settings save/load ✅

### Hour 2-3: Downloads View (Stub)

- [ ] Create `Features/Downloads/Views/DownloadsView.swift`
- [ ] Show "Coming soon" message
- [ ] (Optional) Wire up download functionality

### Hour 3-4: Error Handling

- [ ] Add error alerts throughout app
- [ ] Handle network errors gracefully
- [ ] Handle auth errors (re-login)
- [ ] Add loading indicators everywhere
- [ ] **Test:** App doesn't crash on errors ✅

### Hour 4-5: Loading States

- [ ] Add ProgressView to all async operations
- [ ] Add skeleton loaders for images
- [ ] Add pull-to-refresh everywhere
- [ ] **Test:** UI feels responsive ✅

### Hour 5-6: Visual Polish

- [ ] Ensure all screens use LG design
- [ ] Add animations (spring, fade, scale)
- [ ] Add haptic feedback to buttons
- [ ] Fix any UI glitches
- [ ] **Test:** App looks beautiful ✅

### Hour 6-8: Testing & Bug Fixes

- [ ] Test full app flow 5+ times
- [ ] Fix any crashes
- [ ] Fix any UI bugs
- [ ] Test on real device (not simulator)
- [ ] Test with poor network
- [ ] Test with no network
- [ ] **Test:** App is stable ✅

**END OF DAY 4 CHECKPOINT:**

```
App is feature-complete and stable:
✅ Login works
✅ Library browsing works
✅ Audio playback works
✅ Background audio works
✅ Progress syncs
✅ Settings work
✅ No crashes
✅ Beautiful UI
```

---

## DAY 5: TESTFLIGHT & DEPLOYMENT ✅

### Hour 1-2: App Store Connect Setup

- [ ] Log in to App Store Connect
- [ ] Create new app
- [ ] Set app name: "Audiobookphile"
- [ ] Set bundle ID: Matches Xcode
- [ ] Set SKU: "audiobookphile-ios-native"
- [ ] Upload app icon (1024x1024)
- [ ] Set privacy policy URL
- [ ] Set support URL

### Hour 2-3: App Icon & Assets

- [ ] Create app icon (all sizes)
- [ ] Add to Xcode asset catalog
- [ ] Create launch screen
- [ ] Test launch screen appears

### Hour 3-4: Build & Archive

- [ ] In Xcode: Product → Archive
- [ ] Wait for build to complete
- [ ] Window → Organizer → View archives
- [ ] Validate app
- [ ] Fix any validation errors
- [ ] Distribute to App Store Connect
- [ ] Wait for processing (15-30 min)

### Hour 4-5: TestFlight Setup

- [ ] In App Store Connect → TestFlight
- [ ] Add build to TestFlight
- [ ] Create internal testing group
- [ ] Add testers (emails)
- [ ] Submit for beta review (if needed)
- [ ] Wait for approval (usually instant for TestFlight)

### Hour 5-6: Beta Testing

- [ ] Install TestFlight on iPhone
- [ ] Install app from TestFlight
- [ ] Test full flow on device
- [ ] Fix any device-specific issues
- [ ] Upload new build if needed

### Hour 6-8: Gather Feedback & Iterate

- [ ] Add more beta testers
- [ ] Create feedback form
- [ ] Monitor crash reports
- [ ] Fix critical bugs
- [ ] Upload build 2 if needed

**END OF DAY 5 CHECKPOINT:**

```
✅ App is on TestFlight
✅ Beta testers can install
✅ App works on real devices
✅ Crash-free
✅ Ready for wider testing
```

---

## 🎯 CRITICAL PATH (MUST-HAVES)

### Authentication

- ✅ Can connect to server
- ✅ Can login with username/password
- ✅ Token stored securely

### Library

- ✅ Can browse books
- ✅ Can search books (nice-to-have)
- ✅ Can view book details

### Playback

- ✅ Can play audiobooks
- ✅ Background audio works
- ✅ Lock screen controls work
- ✅ Progress syncs to server
- ✅ Can resume from any device

### UI/UX

- ✅ Liquid Glass design everywhere
- ✅ Smooth 120fps animations (ProMotion devices)
- ✅ Beautiful cover images
- ✅ Loading states
- ✅ Error handling

---

## 🚫 CAN SKIP (v1.1)

### Downloads

- ❌ Download for offline (can add later)
- ❌ Download management
- ❌ Storage usage

### Advanced Features

- ❌ Widgets
- ❌ CarPlay
- ❌ Siri Shortcuts
- ❌ Apple Watch
- ❌ SharePlay

### Nice-to-Haves

- ❌ Advanced search filters
- ❌ Collections/playlists
- ❌ Listening stats
- ❌ Bookmarks
- ❌ Advanced player features (EQ, etc.)

**Focus:** Ship working MVP first, add features later!

---

## 🐛 COMMON ISSUES & SOLUTIONS

### App Won't Compile

- **Check:** All files added to Xcode target
- **Check:** No duplicate file names
- **Check:** Models match API response structure
- **Solution:** Clean build folder (Cmd+Shift+K)

### API Calls Fail

- **Check:** Server URL is correct (no trailing slash)
- **Check:** Token is being sent in headers
- **Check:** JSON decoder strategy matches API
- **Solution:** Print request/response for debugging

### Audio Won't Play

- **Check:** Audio session configured correctly
- **Check:** File URL is valid
- **Check:** Background modes enabled (Xcode capabilities)
- **Solution:** Test with direct file URL first

### App Crashes

- **Check:** Xcode console for error
- **Check:** Force unwrapping (!) causing nil crash
- **Solution:** Use optional binding (if let, guard let)

### TestFlight Upload Fails

- **Check:** All required icons present
- **Check:** Bundle ID matches App Store Connect
- **Check:** Version/build number incremented
- **Solution:** Validate before distributing

---

## 📊 PROGRESS TRACKING

### Day 1 Complete ✅

- [ ] Can compile project
- [ ] Can run in simulator
- [ ] API client works
- [ ] Can login to server

### Day 2 Complete ✅

- [ ] Can browse library
- [ ] Can view book details
- [ ] Navigation works
- [ ] UI looks good

### Day 3 Complete ✅

- [ ] Audio playback works
- [ ] Background audio works
- [ ] Progress syncs
- [ ] Mini player works

### Day 4 Complete ✅

- [ ] Settings implemented
- [ ] Error handling complete
- [ ] Loading states done
- [ ] No crashes

### Day 5 Complete ✅

- [ ] App on TestFlight
- [ ] Beta testers have access
- [ ] Works on real devices
- [ ] Ready for feedback

---

## 🎉 SUCCESS CRITERIA

### Technical

- [ ] App compiles without errors/warnings
- [ ] All core features work
- [ ] No crashes in normal use
- [ ] 120fps scrolling (ProMotion devices)
- [ ] Background audio works perfectly

### User Experience

- [ ] Beautiful Liquid Glass UI
- [ ] Smooth animations
- [ ] Fast and responsive
- [ ] Easy to use
- [ ] Reliable playback

### Deployment

- [ ] On TestFlight
- [ ] 10+ beta testers
- [ ] Positive feedback
- [ ] <5 critical bugs
- [ ] Ready for wider release

---

## 🚀 AFTER TESTFLIGHT

### Short-term (Week 1-2)

- [ ] Gather feedback from beta testers
- [ ] Fix critical bugs
- [ ] Optimize performance
- [ ] Add polish based on feedback
- [ ] Upload improved build

### Medium-term (Week 3-4)

- [ ] Expand beta testing
- [ ] Add missing features
- [ ] App Store submission prep
- [ ] Create marketing materials
- [ ] Prepare App Store listing

### Long-term (Month 2+)

- [ ] App Store release
- [ ] Monitor reviews/ratings
- [ ] Plan v1.1 features
- [ ] Add downloads
- [ ] Add widgets/CarPlay

---

## 📝 DAILY CHECKLIST TEMPLATE

Copy this for each day:

```markdown
## Day X - [Date]

### Morning (9am-12pm)

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

### Afternoon (1pm-5pm)

- [ ] Task 4
- [ ] Task 5
- [ ] Task 6

### Evening (6pm-9pm)

- [ ] Task 7
- [ ] Task 8
- [ ] Test today's work

### End of Day

- [ ] Commit code to git
- [ ] Document progress
- [ ] Plan tomorrow
```

---

## 🎯 YOU GOT THIS!

Follow this checklist step-by-step. Don't skip ahead. Test as you go.

**3-5 days to TestFlight is absolutely achievable!** 🚀

---

_Last Updated: December 21, 2024_ _All code examples in: `docs/native-ios-example/`_ _API Reference in: `docs/API-REFERENCE.md`_ _Speed Run Guide in: `docs/SPEED-RUN.md`_
