# Spotify-FY

A full-stack music streaming app: Flutter frontend + Node.js backend that streams **free ad-free music from YouTube** (via yt-dlp, no API key or subscription needed).

## How it works

1. **Backend** (`backend/`) - Express API. Searches YouTube with `yt-dlp`, extracts direct audio stream URLs, and serves them to the app. MongoDB stores accounts, likes, history and playlists.
2. **Frontend** (`lib/`) - Flutter app. Search a song -> tap it -> it plays instantly (Spotify-style), plus Home/trending, genres, liked songs, history and playlists.

## Live demo (GitHub Pages)

The web build auto-deploys to **https://merjohnpagente.github.io/spotify/** on every push to `main` via `.github/workflows/deploy-pages.yml`.

One-time setup:

1. Repo **Settings -> Pages -> Build and deployment -> Source: GitHub Actions**, then re-run the *Deploy to GitHub Pages* workflow.
2. The web app needs the API online. Free option: deploy `backend/` to [Render](https://render.com) using the root `render.yaml` (Blueprint). Then set repo variable **`API_BASE_URL`** = your Render URL (`Settings -> Secrets and variables -> Actions -> Variables`) and re-run the workflow.
3. In MongoDB Atlas -> Network Access, allow access from anywhere (`0.0.0.0/0`) so Render's servers can connect.

> Note: "Continue with Google" only works in the Android/iOS apps (Firebase config); on web use email/password sign-in.

## Running the app

### 1. Start the backend

```bash
cd backend
npm install        # first time only
npm run dev
```

The API runs on http://localhost:3000.

> Music search & playback work even if MongoDB is unreachable - but sign-in, likes, history and playlists need it. If you see Atlas connection errors, open your MongoDB Atlas dashboard -> Network Access -> Add IP Address -> Allow access from anywhere (or add your current IP).

`yt-dlp` is bundled at `backend/bin/yt-dlp.exe` and configured via `YT_DLP_PATH` in `backend/.env`. Keep it updated now and then so YouTube extraction keeps working.

> **Env notes:** `AUDIO_CACHE_TTL_HOURS` default **5h** (below 6h googlevideo expiry) — cache is intentionally shorter than the ~6h signed-URL expiry so stale URLs are never served. `FRONTEND_URL` accepts a comma-separated list for CORS (e.g. `https://merjohnpagente.github.io/spotify/,http://localhost:3000`) for GitHub Pages + local. `android/app/google-services.json` is gitignored — add your own Firebase config locally; "Continue with Google" needs it.

### 2. Start the Flutter app

```bash
flutter pub get
flutter run
```

- Android emulator reaches the backend automatically at `http://10.0.2.2:3000`.
- Desktop/web uses `http://localhost:3000`.
- For a physical phone, override with your PC's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://<YOUR_PC_IP>:3000
```

## Features

- Search any song on YouTube (debounced live search)
- Tap-to-play with full player screen (queue, shuffle, repeat, seek, volume)
- Like songs, listen history & stats (requires MongoDB)
- Trending songs & browse by genre
- User playlists
- Email/password auth with JWT refresh tokens
- No ads, no payments - music streams directly from YouTube

## Project layout

```
backend/          Node.js + Express API (auth, songs, playlists, users)
  src/routes/     REST endpoints
  src/services/   YouTube search, audio extraction, business logic
  bin/            yt-dlp.exe binary
lib/              Flutter app
  tabs/           Search / Home / Library / Profile
  views/          Player, playlists, liked songs...
  providers/      Riverpod state management
  services/       API clients for the backend
```
