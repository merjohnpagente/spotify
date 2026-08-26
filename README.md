# Spotify-FY

A full-stack music streaming app: Flutter frontend + Node.js backend that streams **free ad-free music from YouTube** (via yt-dlp, no API key or subscription needed).

## How it works

1. **Backend** (`backend/`) - Express API. Searches YouTube with `yt-dlp`, extracts direct audio stream URLs, and serves them to the app. MongoDB stores accounts, likes, history and playlists.
2. **Frontend** (`lib/`) - Flutter app. Search a song -> tap it -> it plays instantly (Spotify-style), plus Home/trending, genres, liked songs, history and playlists.

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
