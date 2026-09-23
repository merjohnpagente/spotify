# Manual QA Matrix (M5)

Record results when running each row. Backend assumed at `http://localhost:3000` (or Render URL for web deploy rows).

> **Status 2026-09-23:** Automated suite green (`flutter analyze` 0, `flutter test` 2/2, `backend npm test` 49/49, `backend npm run lint` clean). **Android debug APK build green** — `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` (157 MB, 2309.7s first-time Gradle 9.1 cold download; subsequent builds much faster). Render `/health` probe **unreachable from this network** (DNS resolves, TCP:443 times out — regional/infra block, GitHub/Cloudflare reachable). Re-run Deploy rows when Render is reachable. Manual device/web walkthrough rows below still need a human on emulator + Chrome.

## Android emulator (`flutter run`, API base `http://10.0.2.2:3000`)

| # | Step | Expected | Pass? |
|---|------|----------|-------|
| 1 | Cold start → Home loads | Trending grid + shimmer → content, no red errors | ☐ |
| 2 | Search `arthur nery` | Debounced results <1s, cover art visible | ☐ |
| 3 | Tap a result | Audio starts <3s warm / <8s cold; play button → pause icon | ☐ |
| 4 | Open player → Next | Queue advances, artwork + title update | ☐ |
| 5 | Seek / volume sliders | Seek moves progress; volume changes loudness only | ☐ |
| 6 | Like a song (signed in) | Heart fills; survives app restart (history/likes) | ☐ |
| 7 | Like while signed out | Toast/inline hint to sign in — no silent fail | ☐ |
| 8 | Library → History | Recent plays listed; clear history works | ☐ |
| 9 | Profile → Stats | Time listened / top artists render (or empty state) | ☐ |
| 10 | Kill + relaunch app | Session persists (refresh token), no forced re-login | ☐ |

## Chrome web — local (`flutter run -d chrome`, API `http://localhost:3000`)

| # | Step | Expected | Pass? |
|---|------|----------|-------|
| 1 | Search + play | Audio via `/audio` proxy — no CORS console errors | ☐ |
| 2 | Mini-player + tab nav | Mini-player never overlaps bottom nav | ☐ |
| 3 | Network error view (stop backend) | Shows base URL + `--dart-define=API_BASE_URL` hint, Retry works | ☐ |

## Chrome web — GitHub Pages (deployed, API base from repo var)

| # | Step | Expected | Pass? |
|---|------|----------|-------|
| 1 | Load https://merjohnpagente.github.io/spotify/ | App boots, hits Render API (not localhost) | ☐ |
| 2 | First load after idle | Render cold-start message, then Retry succeeds | ☐ |
| 3 | `GET /health` + `GET /api/debug/ytdlp?videoId=kJQP7kiw5Fk&strategy=android` | Both 200 | ☐ |

## Backend probes (curl / browser)

```bash
curl -s http://localhost:3000/health
curl -s "http://localhost:3000/api/debug/ytdlp?videoId=kJQP7kiw5Fk&strategy=android"
curl -s "http://localhost:3000/api/debug/ytdlp?videoId=hLQl3WQQoQ0&strategy=android"
curl -s "http://localhost:3000/api/debug/ytdlp?videoId=kJQP7kiw5Fk"
```

Expect `stream: ok (...ms)` for all three videoIds (spec DoD #5).

## Automated (run before every milestone commit)

- `flutter analyze --no-pub` → 0 issues
- `flutter test --no-pub` → pass
- `cd backend && npm run lint` → clean
- `cd backend && npm test` → pass
