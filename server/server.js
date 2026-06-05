/**
 * Math Slam: Basketball Jam — WebSocket Relay Server
 *
 * Handles:
 *  - Quick matchmaking (pairing by tier)
 *  - Friend lobby (6-char code rooms)
 *  - Round management (6 rounds, 30s each)
 *  - Server-side answer validation (identical SeededRNG as GDScript)
 *  - Server-authoritative scoring
 *  - Disconnect / reconnect handling (5s grace)
 */

const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

const PORT = parseInt(process.env.PORT || '3000', 10);

// ─── SeededRNG (must match GDScript MathEngine exactly) ───────────────────────
class SeededRNG {
  constructor(seed) {
    this.state = seed & 0x7FFFFFFF;
  }
  nextInt() {
    this.state = ((this.state * 1664525 + 1013904223) & 0x7FFFFFFF) >>> 0;
    return this.state;
  }
  randiRange(lo, hi) {
    return lo + (this.nextInt() % (hi - lo + 1));
  }
}

// ─── MathEngine (mirrors GDScript version) ────────────────────────────────────
class MathEngine {
  static generate(seed, tier = 'pro') {
    const rng = new SeededRNG(seed);
    switch (tier.toLowerCase()) {
      case 'rookie':   return MathEngine._genRookie(rng);
      case 'varsity':  return MathEngine._genVarsity(rng);
      case 'pro':      return MathEngine._genPro(rng);
      case 'all_star': return MathEngine._genAllStar(rng);
      case 'mvp':      return MathEngine._genMvp(rng);
      default:         return MathEngine._genPro(rng);
    }
  }

  static validate(submitted, problem) {
    submitted = String(submitted).trim();
    const correctStr = String(problem.answer_str || '');
    if (submitted === correctStr) return true;
    const sNum = parseFloat(submitted), cNum = parseFloat(correctStr);
    if (!isNaN(sNum) && !isNaN(cNum)) return Math.abs(sNum - cNum) < 0.01;
    if (submitted.includes('/') && problem.display_type === 'fraction') {
      const parts = submitted.split('/');
      if (parts.length === 2) {
        const n = parseInt(parts[0]), d = parseInt(parts[1]);
        if (d !== 0) return Math.abs(n / d - problem.answer) < 0.01;
      }
    }
    return false;
  }

  static _arith(question, answer, answerStr = null) {
    return { question, answer, answer_str: answerStr ?? String(answer), display_type: 'arithmetic' };
  }

  static _genRookie(rng) {
    const a = rng.randiRange(1, 10), b = rng.randiRange(1, 10);
    return MathEngine._arith(`${a} + ${b} = ?`, a + b);
  }

  static _genVarsity(rng) {
    if (rng.randiRange(0, 1) === 0) {
      const a = rng.randiRange(10, 50), b = rng.randiRange(10, 50);
      return MathEngine._arith(`${a} + ${b} = ?`, a + b);
    } else {
      const a = rng.randiRange(20, 90), b = rng.randiRange(1, a);
      return MathEngine._arith(`${a} − ${b} = ?`, a - b);
    }
  }

  static _genPro(rng) {
    if (rng.randiRange(0, 1) === 0) {
      const a = rng.randiRange(2, 12), b = rng.randiRange(2, 12);
      return MathEngine._arith(`${a} × ${b} = ?`, a * b);
    } else {
      const divisor = rng.randiRange(2, 12), quotient = rng.randiRange(2, 12);
      const dividend = divisor * quotient;
      if (rng.randiRange(0, 1) === 0)
        return MathEngine._arith(`${dividend} ÷ ${divisor} = ?`, quotient);
      else
        return MathEngine._arith(`${divisor} × ? = ${dividend}`, quotient);
    }
  }

  static _genAllStar(rng) {
    switch (rng.randiRange(0, 2)) {
      case 0: return MathEngine._genFractionAdd(rng);
      case 1: return MathEngine._genDecimalMult(rng);
      case 2: return MathEngine._genMixedOps(rng);
    }
  }

  static _genMvp(rng) {
    const x = rng.randiRange(1, 20), a = rng.randiRange(1, 10);
    return MathEngine._arith(`${a} + x = ${a + x}`, x);
  }

  static _genFractionAdd(rng) {
    const denoms = [2, 3, 4, 5, 6, 8, 10];
    const d = denoms[rng.randiRange(0, denoms.length - 1)];
    const n1 = rng.randiRange(1, d - 1), n2 = rng.randiRange(1, d - 1);
    const ansN = n1 + n2, ansD = d, g = MathEngine._gcd(ansN, ansD);
    const rN = ansN / g, rD = ansD / g;
    const ansStr = rD === 1 ? String(rN) : `${rN}/${rD}`;
    return {
      question: `${n1}/${d} + ${n2}/${d} = ?`,
      answer: (n1 + n2) / d,
      answer_str: ansStr,
      display_type: 'fraction',
      fraction_data: { n1, d1: d, n2, d2: d }
    };
  }

  static _genDecimalMult(rng) {
    const a = rng.randiRange(1, 9), b = rng.randiRange(1, 9);
    const fa = a * 0.1, result = Math.round(fa * b * 10) / 10;
    return MathEngine._arith(`${fa.toFixed(1)} × ${b} = ?`, result, result.toFixed(1));
  }

  static _genMixedOps(rng) {
    const a = rng.randiRange(1, 9), b = rng.randiRange(2, 9), c = rng.randiRange(2, 9);
    return MathEngine._arith(`${a} + ${b} × ${c} = ?`, a + b * c);
  }

  static _gcd(a, b) { while (b) { [a, b] = [b, a % b]; } return Math.abs(a); }
}

// ─── Server state ─────────────────────────────────────────────────────────────
const rooms = new Map();          // roomCode -> Room
const players = new Map();        // playerId -> PlayerState
const matchmakingQueue = new Map(); // tier -> [playerId]

class Room {
  constructor(code) {
    this.code = code;
    this.playerIds = [];          // max 2, slot = index + 1
    this.round = 0;
    this.scores = { 1: 0, 2: 0 };
    this.currentProblem = null;
    this.currentSeed = 0;
    this.roundActive = false;
    this.roundAnswers = {};       // playerId -> { answer, timestamp }
    this.possessionSlot = 0;
    this.tier = 'pro';
    this.disconnectTimers = {};   // playerId -> timeout handle
  }
  getSlot(playerId) { return this.playerIds.indexOf(playerId) + 1; }
  getOpponentId(playerId) { return this.playerIds.find(id => id !== playerId); }
}

// ─── WebSocket server ─────────────────────────────────────────────────────────
const wss = new WebSocket.Server({ port: PORT });
console.log(`[MathSlam] Relay server running on ws://0.0.0.0:${PORT}`);

wss.on('connection', (ws, req) => {
  const connId = uuidv4();
  ws._connId = connId;
  console.log(`[+] Connection: ${connId}`);

  ws.on('message', (rawData) => {
    let msg;
    try { msg = JSON.parse(rawData.toString()); }
    catch { return; }

    const playerId = msg.player_id;
    const payload  = msg.payload || {};

    // Attach ws to player record
    if (!players.has(playerId)) {
      players.set(playerId, { ws, name: 'Player', tier: 'pro', roomCode: null });
    } else {
      players.get(playerId).ws = ws;
    }

    switch (msg.type) {
      case 'player_join':   handleJoin(playerId, payload); break;
      case 'player_ready':  handleReady(playerId); break;
      case 'answer_submit': handleAnswer(playerId, payload); break;
      case 'shot_release':  handleShot(playerId, payload); break;
      case 'player_rematch':handleRematch(playerId); break;
    }
  });

  ws.on('close', () => {
    console.log(`[-] Disconnected: ${connId}`);
    handleDisconnect(ws);
  });

  ws.on('error', (err) => console.error('[WS error]', err.message));
});

// ─── Join / Matchmaking ───────────────────────────────────────────────────────
function handleJoin(playerId, payload) {
  const player = players.get(playerId);
  player.name = payload.player_name || 'Player';
  player.tier = payload.tier || 'pro';

  const lobbyCode = payload.lobby_code || '';

  // Reconnect to existing room
  if (player.roomCode && rooms.has(player.roomCode)) {
    const room = rooms.get(player.roomCode);
    if (room.disconnectTimers[playerId]) {
      clearTimeout(room.disconnectTimers[playerId]);
      delete room.disconnectTimers[playerId];
      console.log(`[Reconnect] ${playerId} rejoined ${player.roomCode}`);
    }
    return;
  }

  if (lobbyCode === 'HOST') {
    // Create a friend lobby
    const code = _genCode();
    const room = new Room(code);
    room.tier = player.tier;
    room.playerIds.push(playerId);
    player.roomCode = code;
    rooms.set(code, room);
    send(playerId, 'lobby_created', { code, player_slot: 1 });
    console.log(`[Lobby] Created ${code} by ${playerId}`);
  } else if (lobbyCode && rooms.has(lobbyCode)) {
    // Join existing lobby
    const room = rooms.get(lobbyCode);
    if (room.playerIds.length < 2) {
      room.playerIds.push(playerId);
      player.roomCode = lobbyCode;
      const opponentId = room.getOpponentId(playerId);
      const opp = players.get(opponentId);
      // Notify both
      send(playerId, 'opponent_joined', {
        opponent_name: opp?.name || 'Opponent',
        opponent_tier: opp?.tier || 'pro',
        player_slot: 2
      });
      send(opponentId, 'opponent_joined', {
        opponent_name: player.name,
        opponent_tier: player.tier,
        player_slot: 1
      });
      console.log(`[Lobby] ${playerId} joined ${lobbyCode}`);
      startMatch(room);
    } else {
      send(playerId, 'error', { message: 'Lobby is full.' });
    }
  } else {
    // Quick match
    const tier = player.tier;
    if (!matchmakingQueue.has(tier)) matchmakingQueue.set(tier, []);
    const queue = matchmakingQueue.get(tier);

    // Filter stale entries
    const validQueue = queue.filter(id => players.has(id) && players.get(id).ws?.readyState === WebSocket.OPEN);
    matchmakingQueue.set(tier, validQueue);

    if (validQueue.length > 0) {
      const opponentId = validQueue.shift();
      const code = _genCode();
      const room = new Room(code);
      room.tier = tier;
      room.playerIds = [opponentId, playerId];
      players.get(opponentId).roomCode = code;
      player.roomCode = code;
      rooms.set(code, room);
      console.log(`[Match] Pairing ${opponentId} vs ${playerId} in room ${code}`);
      startMatch(room);
    } else {
      validQueue.push(playerId);
      matchmakingQueue.set(tier, validQueue);
      console.log(`[Queue] ${playerId} waiting in ${tier} queue`);
    }
  }
}

function handleReady(playerId) {
  const player = players.get(playerId);
  if (!player?.roomCode) return;
  const room = rooms.get(player.roomCode);
  if (!room) return;
  if (room.playerIds.length === 2 && !room.roundActive) {
    startRound(room);
  }
}

// ─── Match flow ───────────────────────────────────────────────────────────────
function startMatch(room) {
  const [p1id, p2id] = room.playerIds;
  const p1 = players.get(p1id), p2 = players.get(p2id);
  broadcast(room, 'match_start', {
    player_slot: 0  // each client uses their slot index
  }, (playerId) => ({
    player_slot: room.getSlot(playerId),
    opponent_name: playerId === p1id ? (p2?.name || 'Opponent') : (p1?.name || 'Opponent')
  }));
  // Brief delay then start round 1
  setTimeout(() => startRound(room), 1500);
}

function startRound(room) {
  room.round += 1;
  room.roundAnswers = {};
  room.possessionSlot = 0;
  room.roundActive = true;
  room.currentSeed = Math.floor(Math.random() * 2147483647);
  room.currentProblem = MathEngine.generate(room.currentSeed, room.tier);

  broadcast(room, 'round_start', {
    problem_seed: room.currentSeed,
    round_number: room.round,
    time_limit: 30,
    tier: room.tier
  });

  // Auto-end round after 30s if no answer
  room._roundTimeout = setTimeout(() => {
    if (room.roundActive) endRound(room, null);
  }, 31000);
}

function handleAnswer(playerId, payload) {
  const player = players.get(playerId);
  if (!player?.roomCode) return;
  const room = rooms.get(player.roomCode);
  if (!room || !room.roundActive) return;

  // Ignore if this player already answered correctly
  if (room.roundAnswers[playerId]) return;

  const submitted = String(payload.answer || '').trim();
  const isCorrect = MathEngine.validate(submitted, room.currentProblem);

  if (isCorrect) {
    room.roundAnswers[playerId] = { answer: submitted, timestamp: Date.now() };
    const slot = room.getSlot(playerId);

    // Determine winner (first correct answer by server timestamp)
    const opponentId = room.getOpponentId(playerId);
    const opponentAlreadyCorrect = room.roundAnswers[opponentId];

    if (!opponentAlreadyCorrect) {
      // This player wins possession
      broadcast(room, 'answer_result', {
        winner_id: playerId,
        correct_answer: room.currentProblem.answer_str
      });
      broadcast(room, 'possession_grant', { player_id: playerId });
      room.possessionSlot = slot;
    }
  } else {
    // Wrong answer — notify only the submitter
    send(playerId, 'answer_result', {
      winner_id: null,
      correct: false,
      correct_answer: null
    });
  }
}

function handleShot(playerId, payload) {
  const player = players.get(playerId);
  if (!player?.roomCode) return;
  const room = rooms.get(player.roomCode);
  if (!room) return;

  const power = Math.max(0, Math.min(1, parseFloat(payload.power) || 0));
  let scored = false, points = 0;

  if (power >= 0.85)      { scored = true;           points = 3; }
  else if (power >= 0.65) { scored = Math.random() < 0.80; points = 2; }
  else if (power >= 0.40) { scored = Math.random() < 0.40; points = 1; }
  else                    { scored = false;           points = 0; }

  const slot = room.getSlot(playerId);
  if (scored) room.scores[slot] += points;

  broadcast(room, 'shot_result', {
    player_id: playerId,
    scored,
    power,
    points_awarded: scored ? points : 0
  });
  broadcast(room, 'score_update', {
    p1_score: room.scores[1],
    p2_score: room.scores[2]
  });

  // End round after shot
  setTimeout(() => endRound(room, playerId), 1800);
}

function endRound(room, _shooterId) {
  if (!room.roundActive) return;
  room.roundActive = false;
  clearTimeout(room._roundTimeout);

  if (room.round >= 6) {
    endMatch(room);
  }
  // else: clients handle next round_start after overlay
  // server waits for player_ready from both
}

function endMatch(room) {
  const [p1id, p2id] = room.playerIds;
  const winnerId = room.scores[1] > room.scores[2] ? p1id :
                   room.scores[2] > room.scores[1] ? p2id : null;

  broadcast(room, 'match_end', {
    winner_id: winnerId,
    final_scores: { p1: room.scores[1], p2: room.scores[2] }
  });

  // Cleanup room after 60s
  setTimeout(() => rooms.delete(room.code), 60000);
}

// ─── Disconnect handling ──────────────────────────────────────────────────────
function handleDisconnect(ws) {
  for (const [playerId, player] of players.entries()) {
    if (player.ws === ws) {
      const code = player.roomCode;
      if (code && rooms.has(code)) {
        const room = rooms.get(code);
        // 5s grace window
        room.disconnectTimers[playerId] = setTimeout(() => {
          const opponentId = room.getOpponentId(playerId);
          if (opponentId) send(opponentId, 'opponent_left', {});
          rooms.delete(code);
          console.log(`[Disconnect] Room ${code} closed — ${playerId} did not reconnect`);
        }, 5000);
      }
      players.delete(playerId);
      break;
    }
  }
}

function handleRematch(playerId) {
  const player = players.get(playerId);
  if (!player?.roomCode) return;
  const room = rooms.get(player.roomCode);
  if (!room) return;
  // Reset scores and restart
  room.scores = { 1: 0, 2: 0 };
  room.round = 0;
  startMatch(room);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function send(playerId, type, payload) {
  const player = players.get(playerId);
  if (!player?.ws || player.ws.readyState !== WebSocket.OPEN) return;
  player.ws.send(JSON.stringify({ type, payload, timestamp: Date.now() }));
}

/** Broadcast to all players in room. If perPlayerPayload is provided, call it
 *  with playerId to get individual payload overrides. */
function broadcast(room, type, basePayload, perPlayerPayload = null) {
  for (const pid of room.playerIds) {
    const payload = perPlayerPayload ? { ...basePayload, ...perPlayerPayload(pid) } : basePayload;
    send(pid, type, payload);
  }
}

function _genCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return rooms.has(code) ? _genCode() : code;  // ensure uniqueness
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[MathSlam] Shutting down…');
  wss.close(() => process.exit(0));
});
