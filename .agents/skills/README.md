# Agent Skills (vendored)

Curated third-party AI agent skills for this repository, sourced via
[twostraws/Swift-Agent-Skills](https://github.com/twostraws/Swift-Agent-Skills).
Each skill was reviewed before vendoring and pinned to the exact source
commit it was copied from. `.claude/skills/*` are symlinks into this
directory so both Claude Code (`.claude/skills/`) and generic agent
loaders (`.agents/skills/`) discover the same files — edit only here. Do not add skills without reading
them in full first.

| Skill | Author | Source | License | Why it fits this repo |
|---|---|---|---|---|
| `swift-concurrency-pro` | Paul Hudson | [Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) | MIT | 48 source files use `@MainActor`/`Sendable`/structured concurrency; two production races traced to task/isolation mistakes |
| `background-execution` | Anton Novoselov | [Background-Execution-Agent-Skill](https://github.com/n0an/Background-Execution-Agent-Skill) | MIT | `BGTaskScheduler` progress-sync registered in `AudiobookphileApp` + submitted in `AudioPlayerSyncManager`; background audio mode |
| `app-intents` | Anton Novoselov | [App-Intents-Agent-Skill](https://github.com/n0an/App-Intents-Agent-Skill) | MIT | `Intents/SiriIntents.swift` exposes playback intents via the modern AppIntents framework (`AppIntent`, `AudioPlaybackIntent`), guarded `#if os(iOS) && !SKIP` to Siri/Shortcuts |
| `widgets` | Anton Novoselov | [Widgets-Agent-Skill](https://github.com/n0an/Widgets-Agent-Skill) | MIT | Native WidgetKit extension at `Darwin/WidgetExtensionTemplates/AudiobookWidget.swift` shares state via the `group.organicnz.audiobookphile` app group (`syncWidgetState()`) |

## ⚠️ Skip (Android) constraint overrides pure-iOS advice

This app compiles for iOS **and** Android through
[Skip](https://skip.dev): SwiftUI code is transpiled to Kotlin/Compose.
These skills document Apple-only APIs that may not exist on the Skip side.
When applying any guidance from these skills:

1. Wrap iOS-only frameworks (`WidgetKit`, `BGTaskScheduler`, App Intents,
   `AVFoundation`, `UIKit`, Sentry) in `#if !SKIP && os(iOS)` / matching
   `#if SKIP` fallbacks, following the existing pattern throughout
   `Sources/Audiobookphile`.
2. Prefer APIs already used in this codebase over catalog suggestions;
   check how a neighboring file does it first.
3. After any change, build both targets: `swift build` must pass and the
   Skip plugin must transpile cleanly (CI enforces this).
4. Widget/intent extensions live outside the Skip-transpiled module — keep
   their code native-iOS and do not import app types that drag in Skip.

## Deliberately excluded

- `conorluddy/ios-simulator-skill` — ships 29 executable Python scripts;
  duplicates our existing Maestro E2E suite and `run_sim.sh`, and vendoring
  executable third-party tooling is a supply-chain risk we decline here.
- SwiftData/Core Data skills — the app has no local persistence framework
  (UserDefaults + app group only); guidance would be dead weight.
- App Store Connect / ASO skills — releases run through Xcode Cloud.
