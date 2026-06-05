# 🏀 Math Slam: Basketball Jam

> **Solve it first. Shoot it fast. Win the court.**

A fast-paced, 1v1 multiplayer math game for grades 3–6, built with **Godot 4.6** and a **Node.js WebSocket relay server**. Players race to answer math problems — whoever answers first earns the ball and takes a shot. Perfect for school browsers, no install needed.

---

## 🎮 Game Overview

Two players go head-to-head across **6 rounds** on a virtual basketball court. Each round:

1. A **math problem** appears on screen (shared and identical for both players via seeded RNG)
2. Both players race to type the correct answer
3. The **first correct answer** wins possession of the ball
4. The ball-holder presses the **power bar** to shoot — timing determines points
5. Scores are tracked; the player with the most points after 6 rounds wins

Solo practice mode is also available — compete against a CPU opponent.

---

## 🧮 Difficulty Tiers

| Tier | Grade | Problem Types |
|------|-------|---------------|
| 🟢 **Rookie** | K–2 | Addition & subtraction (1–10) |
| 🔵 **Varsity** | Gr 2–3 | Larger addition & subtraction (up to 90) |
| 🟠 **Pro** | Gr 3–4 | Multiplication & division (tables 2–12) |
| 🌟 **All-Star** | Gr 5–6 | Fractions, decimals, mixed operations |
| 🔴 **MVP** | Gr 6+ | Simple linear equations (a + x = b) |

**Adaptive difficulty**: If a player's accuracy exceeds 85% at mid-match, the game suggests bumping up a tier.

---

## 🏀 Shot Power Mechanic

After winning possession, a power bar cycles up and down. Press **Space** (or **tap** on mobile) to release the shot:

| Zone | Power | Points | Make % |
|------|-------|--------|--------|
| 🔴 Too Weak | 0–40% | 0 | 0% |
| 🟠 Risky | 40–65% | 1 | 40% |
| 🟡 Good | 65–85% | 2 | 80% |
| 🟢 Perfect | 85–100% | 3 | 100% |

---

## ✨ Features

- **6-round match structure** with 30-second timer per round
- **Fraction visual display** — rendered as proper stacked fractions, not plain text
- **Hint system** — a wrong-answer hint appears at the 15-second mark
- **Hot Streak** 🔥 — displayed when you answer correctly 3 rounds in a row
- **XP system** — Win: +10 XP, Loss: +5 XP, Perfect accuracy: +3 XP
- **Personal best** tracking per tier
- **Win streak** tracking across sessions
- **Quick Match** — auto-matchmaking with any online player
- **Friend Lobby** — share a 6-character code to play with a specific friend
- **5-second reconnect grace window** — brief disconnects don't forfeit the match
- **Web Share API** — share results directly from the browser on mobile
- **Synthesized audio** — all SFX and music generated procedurally (no audio files)
- **Accessibility** — larger text, reduced motion, high contrast, color-blind mode
- **PWA support** — installable as a standalone app from the browser

---

## 🏗️ Architecture

```
Math Slam Basketball Jam/
├── project.godot            # Godot 4.6 project (GL Compatibility renderer)
├── export_presets.cfg       # Web export preset (PWA, landscape)
│
├── Scripts/
│   ├── GameState.gd         # Autoload — persistent match state, XP, settings
│   ├── MathEngine.gd        # Autoload — deterministic SeededRNG problem gen
│   ├── AudioManager.gd      # Autoload — fully synthesized PCM audio
│   ├── NetworkManager.gd    # Autoload — WebSocket client
│   ├── Main.gd              # Root scene bootstrapper
│   ├── MainMenu.gd          # Animated main menu
│   ├── Matchmaking.gd       # Quick Match / Friend Lobby screens
│   ├── PreMatch.gd          # VS screen + countdown
│   ├── GameArena.gd         # Core game loop (FSM)
│   ├── MatchResults.gd      # End screen — confetti, XP, stats, share
│   └── Settings.gd          # Volume, accessibility, server URL
│
├── Scenes/                  # .tscn files (one per script above)
├── Assets/                  # court_bg.png, logo.png, players.png
│
└── server/
    ├── server.js            # Node.js WebSocket relay server
    ├── package.json
    ├── railway.toml         # Railway deployment config
    ├── Procfile
    └── README.md            # Server-specific docs
```

### Multiplayer Design

Because the game targets **school networks** (which often block WebRTC/UDP), multiplayer uses a **WebSocket relay server** instead of peer-to-peer. The server is **authoritative** — it validates answers, resolves ties, and determines shot outcomes to prevent cheating.

**Seeded RNG:** Both the Godot client (`MathEngine.gd`) and the Node.js server (`server.js`) implement the same **Lehmer LCG** (`state = state * 1664525 + 1013904223 & 0x7FFFFFFF`). Given the same seed, both always generate identical problems — guaranteeing fairness without sending the answer over the wire.

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| [Godot Engine](https://godotengine.org/download) | **4.6** | With Web export template |
| [Node.js](https://nodejs.org) | LTS (20+) | For the relay server |

### 1 — Open the Godot project

```
File → Open Project → select this folder → Import & Edit
```

Download Web export template if prompted: **Editor → Export → Manage Export Templates**.

### 2 — Run Solo Practice (no server needed)

Press **F5** → **Solo Practice** — works entirely offline.

### 3 — Run multiplayer locally

```powershell
cd server
npm install
node server.js
# WebSocket server listening on ws://localhost:3000
```

In the game: **Settings → Server URL** → `ws://localhost:3000`

Then open two browser tabs (or two Godot instances) and use **Quick Match**.

### 4 — Export for the web

In Godot: **Project → Export → Web → Export Project** → save to `export/web/`

Serve the export folder with any static file server:

```powershell
cd export/web
python -m http.server 8080
# Open http://localhost:8080 in Chrome
```

> **Important:** The web export requires **COOP/COEP headers** for SharedArrayBuffer. Use a server that sets these, or use the Godot editor's built-in "Run in Browser" button which handles this automatically.

---

## ☁️ Deploy to Railway (Free)

The relay server is pre-configured for [Railway](https://railway.app):

### Option A — GitHub integration (recommended)
1. Push this repo to GitHub
2. Railway → **New Project** → **Deploy from GitHub**
3. Set **Root Directory** to `/server`
4. Railway auto-detects `package.json` → deploys

### Option B — CLI
```bash
npm install -g @railway/cli
railway login
cd server
railway init && railway up
```

After deploy, Railway gives you a URL like:
`https://mathslam-XXXX.up.railway.app`

In the game Settings, set the Server URL to:
`wss://mathslam-XXXX.up.railway.app`

---

## 🎨 Tech Stack

| Layer | Technology |
|-------|-----------|
| Game engine | Godot 4.6 (GDScript, GL Compatibility renderer) |
| Multiplayer | Node.js + `ws` WebSocket library |
| Audio | Procedural PCM synthesis via `AudioStreamWAV` |
| Persistence | Godot `ConfigFile` (`user://mathslam_save.cfg`) |
| Deployment | Railway (server) + any static host (web export) |

---

## 📡 WebSocket Protocol

All messages are JSON: `{ "type": "...", "player_id": "...", "payload": {}, "timestamp": 0 }`

| Direction | Type | Key Payload Fields |
|-----------|------|-------------------|
| Client → Server | `player_join` | `tier`, `player_name`, `lobby_code` |
| Client → Server | `answer_submit` | `answer`, `round` |
| Client → Server | `shot_release` | `power` (0.0–1.0) |
| Server → Client | `round_start` | `problem_seed`, `round_number`, `time_limit` |
| Server → Client | `answer_result` | `winner_id`, `correct_answer` |
| Server → Client | `possession_grant` | `player_id` |
| Server → Client | `shot_result` | `scored`, `power`, `points_awarded` |
| Server → Client | `score_update` | `p1_score`, `p2_score` |
| Server → Client | `match_end` | `winner_id`, `final_scores` |

---

## 🧑‍💻 Development Notes

- **Renderer:** Must use `gl_compatibility` — Forward+ crashes in browser WebGL
- **Scene changes from `_ready()`:** Always use `.call_deferred()` to avoid "tree is busy" errors
- **Async functions:** After every `await`, check `is_inside_tree()` before touching nodes or calling `get_tree()`
- **GDScript strict mode:** All arrays must be typed (`Array[float]`, `Array[int]`) to avoid Variant inference errors in Godot 4.6
- **LineEdit alignment:** Use `.alignment` not `.horizontal_alignment` (the latter is Label-only)

---

## 📄 License

Assets in `Assets/` are AI-generated and copyright-free. All source code is original.
Feel free to use, modify, and adapt for educational purposes.

---

*Built with ❤️ for students who love both math and basketball.*