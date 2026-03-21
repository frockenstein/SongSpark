# SongSpark — TODO

## Bugs / polish
- [ ] Clips screen: downloading spinner shows on wrong row (shows when
      `isDownloading && playingFilename == nil` — refine per-clip state)
- [ ] If Dropbox upload fails mid-session, error banner appears but the
      recorder stays in `.error` state — tapping record again should reset cleanly
- [ ] Tag filter bar: "ALL" pill should always be visible / sticky left

## Features — near term
- [ ] Clip duration — store in metadata after first download, display in row
- [ ] Waveform thumbnail in clip row (generate on download, cache locally)
- [ ] GPS stamp — CoreLocation, store lat/lng in clip metadata
- [ ] Ratings / favorites — star or heart on clip row, filter by favorites
- [ ] Search — full-text across description, tags, filename
- [ ] Sort options in library (newest, oldest, rating)
- [ ] Swipe-to-delete on clip rows (in addition to the trash button)
- [ ] Haptic feedback on record start/stop

## Features — 2.0
- [ ] ChordPro export
- [ ] Automatic speech-to-text transcription (OpenAI Whisper or Apple Speech)
- [ ] Automatic key detection (AVAudioEngine spectral analysis)
- [ ] Chord detection from guitar audio
- [ ] Collaborative comments / feedback (requires web backend)
- [ ] AI lyric suggestions via Claude API
- [ ] Android / Flutter

## Tech debt
- [ ] `SplashView.swift` — either bring it back with a purpose or delete it
- [ ] `DropboxManager` upload callback is still closure-based; convert to async/await
- [ ] Add unit tests for filename parsing / sanitization logic
- [ ] Audit cache eviction — currently grows forever, never pruned
