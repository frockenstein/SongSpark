# SongSpark — Claude Context

## What this app is
Personal audio capture and organization tool for solo songwriters.
One-tap record a musical idea, upload to Dropbox, browse and play back
your library. Tape deck aesthetic — warm, tactile, immediate.

Target user: solo songwriter, personal use first, collaboration later.

---

## Tech stack
- **Swift / SwiftUI** — iOS native, Swift 6 strict concurrency
- **AVAudioEngine / AVAudioRecorder** — recording + live metering
- **SwiftyDropbox SDK** — cloud storage, file upload/download, metadata
- **JSON flat file** (`clips.json` in Dropbox app folder) — metadata DB
- No backend, no database, no server

---

## Architecture

### Storage
- Audio files saved to Dropbox as `.m4a` (AAC, not MP3 — AVAudioRecorder
  can't write MP3 natively; m4a is universally supported)
- Single `clips.json` in the Dropbox app folder holds all metadata
- JSON format is a `LibraryData` envelope: `{ version, tags, clips[] }`
  - Backward compat: loader falls back to legacy flat `[Clip]` array
- Local cache directory: `Caches/songspark/{filename}` for playback

### Filename convention
`{year}-{day}-{month}-{unix}[-{description}].m4a`
e.g. `2026-20-03-1742482800-cool-riff.m4a`
- Description part is sanitized: spaces→hyphens, only `[a-z0-9-_]`
- Parse by splitting on `-`, first 4 parts = timestamp, rest = description

### Key files
| File | Responsibility |
|------|---------------|
| `AudioRecorder.swift` | AVAudioRecorder wrapper, live metering (30fps), state machine |
| `ClipStore.swift` | Clips metadata CRUD, Dropbox JSON read/write, playback queue, AVAudioPlayer |
| `DropboxManager.swift` | Auth, upload, account info |
| `Clip.swift` | Model — filename, createdAt, tags. Custom decoder for backward compat |
| `ContentView.swift` | Main screen, record button, post-record naming sheet |
| `ClipsView.swift` | Library list, tag filter bar, clip rows, edit/delete |
| `ClipNameSheet.swift` | Reusable sheet: description + tag picker. onCancel vs onSave |
| `SettingsView.swift` | Dropbox account info, unlink, tag management |
| `SplashView.swift` | Exists but unused — removed from app flow, kept for reference |

### Secrets / config
- Dropbox app key lives in `Config/Secrets.xcconfig` (gitignored)
- Template at `Config/Secrets.xcconfig.example`
- Read at runtime via `Bundle.main.infoDictionary["DropboxAppKey"]`

---

## Design language
- **Background:** `Color(red: 0.12, green: 0.10, blue: 0.08)` — dark warm brown
- **Accent:** `Color(red: 1.0, green: 0.75, blue: 0.3)` — amber/gold
- **Danger:** `Color(red: 1.0, green: 0.35, blue: 0.35)` — red
- **Font:** `.monospaced` throughout, `.black` weight for headers
- Tape deck / analog gear aesthetic — skeuomorphic but not childish

---

## Decisions & gotchas

- **`.m4a` not `.mp3`** — AVAudioRecorder requires the container format to
  match the file extension. AAC goes in `.m4a`. Tried `.mp3` first, got
  `OSStatus fmt?` (kAudioFormatUnsupportedDataFormatError).

- **Dropbox app key not hardcoded** — xcconfig file, gitignored.
  `LSApplicationQueriesSchemes` must include `dbapi-2` and `dbapi-8-emm`
  or the SDK throws a fatal error on launch.

- **`clips.json` format migration** — v0 was a flat `[Clip]` array.
  v1 is `LibraryData { version, tags, clips }`. Loader tries v1 first,
  falls back to v0. Tags default to `["melodic","slow","acoustic","lyrics"]`
  when migrating from v0.

- **Splash screen removed** — The "black screen on launch" was the iOS
  system launch screen firing before SwiftUI starts. Fixed by setting
  `UILaunchScreen → UIColorName → LaunchBackground` in Info.plist to match
  the app background. `SplashView.swift` kept but not used.

- **`static let sessionQuote`** — if you bring the splash back, use
  `static let` not `let` for the random quote. SwiftUI re-evaluates the
  body during `@StateObject` init, creating multiple struct instances;
  `static` ensures one pick per process.

- **Clip naming sheet keyboard** — do NOT auto-focus the text field on
  appear (no `.onAppear { focused = true }`). The keyboard and sheet
  animating in simultaneously looks janky. Let user tap to type.

- **Auto-advance queue** — `ClipStore.currentQueue` is set by `ClipsView`
  to whatever the filtered list is showing. The `AVAudioPlayerDelegate`
  uses this for next-clip logic so playback respects active tag filters.

- **Swift 6 concurrency** — `@MainActor` on `AudioRecorder` and
  `ClipStore`. Dropbox SDK callbacks use `Task { @MainActor in }` to
  hop back. `@preconcurrency import SwiftyDropbox` suppresses warnings
  from the SDK's pre-concurrency API.

---

## GitHub
https://github.com/frockenstein/SongSpark (private)
Branch: `master`
