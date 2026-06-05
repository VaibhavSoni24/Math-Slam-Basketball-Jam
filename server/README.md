# Math Slam Basketball Jam — Relay Server

Lightweight Node.js WebSocket relay server for **Math Slam: Basketball Jam**.

## Quick Start (Local Dev)

```bash
cd server
npm install
node server.js
# Server running at ws://localhost:3000
```

Then in Godot Settings, set Server URL to `ws://localhost:3000`.

## Deploy to Railway (Free Tier)

### Method 1 — Railway CLI
```bash
npm install -g @railway/cli
railway login
cd server
railway init
railway up
```

### Method 2 — GitHub Integration
1. Push this repository to GitHub
2. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub Repo
3. Select your repo → Set **Root Directory** to `/server`
4. Railway auto-detects `package.json` and deploys

### After Deploy
Railway gives you a URL like `https://mathslam-relay-XXXX.up.railway.app`.

Convert it to WebSocket: `wss://mathslam-relay-XXXX.up.railway.app`

Set this URL in the game via:
- **In-game Settings → Relay Server URL field**, OR
- Add `<script>window.MATHSLAM_SERVER_URL = "wss://...";</script>` in the Godot HTML export shell

## Environment Variables

| Variable          | Default                | Description                        |
|-------------------|------------------------|------------------------------------|
| `PORT`            | `3000`                 | WebSocket server port              |
| `ALLOWED_ORIGINS` | (any)                  | Comma-separated allowed origins    |

Copy `.env.example` to `.env` and fill in values for local dev.

## Protocol Summary

All messages are JSON: `{ type, player_id, payload, timestamp }`

| Direction        | Message Type       | Key Payload Fields                              |
|------------------|--------------------|--------------------------------------------------|
| Client → Server  | `player_join`      | `tier`, `player_name`, `lobby_code` (optional)  |
| Client → Server  | `answer_submit`    | `answer`, `round`                               |
| Client → Server  | `shot_release`     | `power` (0.0–1.0)                               |
| Server → Client  | `lobby_created`    | `code`, `player_slot`                            |
| Server → Client  | `round_start`      | `problem_seed`, `round_number`, `time_limit`     |
| Server → Client  | `answer_result`    | `winner_id`, `correct_answer`                   |
| Server → Client  | `possession_grant` | `player_id`                                     |
| Server → Client  | `shot_result`      | `scored`, `power`, `points_awarded`             |
| Server → Client  | `score_update`     | `p1_score`, `p2_score`                          |
| Server → Client  | `match_end`        | `winner_id`, `final_scores`                     |
