# Manual QA Matrix (M5)

Record results when running each row. Backend assumed at `http://localhost:3000` (or Render URL for web deploy rows).

> **Status 2026-09-28 (Firestore mirror):** User accounts now sync to Firestore `users/{mongoId}`. Backend primary path: `syncUserToFirestore` (firebase-admin, best-effort — skips with warn when `FIREBASE_CLIENT_EMAIL`/`PRIVATE_KEY` unset; hooked into email register/login, Google login, profile update). Flutter secondary: `FirestoreUserService` (lazy, never throws) mirrored from `AuthProvider` on init/login/register/google/update. `firestore.rules` (owner-only via email/uid match) + `firebase.json` added. `cloud_firestore: ^5.4.3` added. **Service-account key wired locally:** `backend/.env` now has real `FIREBASE_CLIENT_EMAIL`/`FIREBASE_PRIVATE_KEY` (from Downloads key, gitignored) — smoke test `Firebase initialized (firebase-adminsdk-fbsvc@spotify-ee119...)` + `getFirestore()` OK. `firebase.js` supports 3 cred sources: `FIREBASE_SERVICE_ACCOUNT` (raw JSON), `FIREBASE_SERVICE_ACCOUNT_PATH` (file, honors `GOOGLE_APPLICATION_CREDENTIALS`), split fields. **BLOCKER: Firestore database not created in `spotify-ee119`** — probe write `5 NOT_FOUND` (API `GET /databases` → `{}`; service-account `POST create` → 403 permission). **User action:** Firebase console → Firestore → Create database → *production mode* → region `asia-southeast1` → deploy rules (`firebase deploy --only firestore:rules`, `firebase.json` ready) or paste `firestore.rules`. `google-services.json` refreshed from Downloads (now 2 Android clients: `spitify.app` + `messenger.app`; build uses `spitify.app`). Render still needs creds env'd.
> **Status 2026-09-28 12:00–13:30 UTC:**
> Automated green: `flutter analyze` 0 · `flutter test` 2/2 · `backend npm run lint` clean · `backend npm test` **59/59** (+4 B5) · APK 157 MB (debug). **Render reachable now** — `/health` 200 (`uptime` 600→2357s), `/api/status` 200 (`database: connected`), `/api/songs/trending?limit=3` 200 (cached results, e.g. `au_NQwXON0`). Earlier Render cold-start DNS timeout (175.176.85.240 → 216.24.57.16) was transient, now resolved.
> **DoD#5 probes:** local `yt-dlp.exe` direct 3/3 before throttling (`kJQP7kiw5Fk` Despacito, `hLQl3WQQoQ0` Adele, `dQw4w9WgXcQ` Rick Astley each returned JSON). Local server `GET /api/debug/ytdlp?strategy=android` timed 15–18s with `yt-dlp timed out` — YouTube throttled after burst of 7+ calls in 30 min (even `ytsearch1:adele hello` hung). Prod `GET /api/debug/ytdlp?strategy=android|ios|mweb|tv_embedded|web_embedded` all bot-check on Render datacenter IP (`Sign in to confirm you're not a bot. Use --cookies...`) — needs `YOUTUBE_COOKIES` env (added to `render.yaml` sync:false). All 5 Invidious hosts timeout from this network (breaker opens after 2 fails — B3 working). **App impact limited:** Android/iOS play via on-device `youtube_explode_dart` (primary, ~1s, residential IP) before server fallback — B5 fix removes double-retry (+70s) and bails on 2 bot-checks (~30s saved), so fail-fast → direct path.
> **B5 fix landed:** `extractWithFallbacks` bot-check early-bail (2 streak), `extractAudioUrl` no second chain after `Promise.any` rejects, invidious winner `preferredStrategy='invidious'` only for googlevideo. **Next:** set `YOUTUBE_COOKIES` in Render dashboard (export Netscape cookies.txt), then re-run prod `GET /api/debug/ytdlp` for 3 ids (expect `stream: ok` <15s). Manual emulator/web rows still need human walkthrough.

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

- `flutter analyze --no-pub` → 0 issues (2026-09-28)
- `flutter test --no-pub` → 2/2 (2026-09-28)
- `cd backend && npm run lint` → clean (2026-09-28)
- `cd backend && npm test` → 59/59 (2026-09-28, incl. B2/B3/B5)
