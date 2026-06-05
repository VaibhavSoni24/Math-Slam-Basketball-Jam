extends Node
## WebSocket client singleton. All server communication flows through here.
## Emits typed signals so game scenes stay decoupled from the protocol.

# ─── Signals ──────────────────────────────────────────────────────────────────
signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()

signal lobby_created(data: Dictionary)   ## { code, player_slot }
signal opponent_joined(data: Dictionary) ## { opponent_name, opponent_tier }
signal match_started(data: Dictionary)   ## { player_slot, opponent_name }
signal round_started(data: Dictionary)   ## { problem_seed, round_number, time_limit }
signal answer_resulted(data: Dictionary) ## { winner_id, correct_answer }
signal possession_granted(data: Dictionary) ## { player_id }
signal shot_resulted(data: Dictionary)   ## { player_id, scored, power, points_awarded }
signal score_updated(data: Dictionary)   ## { p1_score, p2_score }
signal match_ended(data: Dictionary)     ## { winner_id, final_scores, xp_earned }
signal opponent_left()

# ─── Internal state ───────────────────────────────────────────────────────────
var _ws: WebSocketPeer = null
var _player_id: String = ""
var _connected: bool = false
var _server_url: String = "ws://localhost:3000"

func _ready() -> void:
	_player_id = _generate_uuid()
	# Read server URL from GameState settings (set from persistent config)
	await get_tree().process_frame  # Let GameState load first
	if GameState.settings.has("server_url"):
		_server_url = GameState.settings["server_url"]
	# On web, try window.MATHSLAM_SERVER_URL
	if OS.has_feature("web"):
		var js_url: String = JavaScriptBridge.eval("window.MATHSLAM_SERVER_URL || ''")
		if js_url != "":
			_server_url = js_url

func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				print("[NetworkManager] Connected to %s" % _server_url)
				connected_to_server.emit()
			while _ws.get_available_packet_count() > 0:
				var raw := _ws.get_packet()
				_handle_message(raw.get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				print("[NetworkManager] Disconnected")
				disconnected_from_server.emit()

		WebSocketPeer.STATE_CLOSING:
			pass

# ─── Connection management ────────────────────────────────────────────────────

func connect_to_server(url: String = "") -> void:
	if url != "":
		_server_url = url
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(_server_url)
	if err != OK:
		push_warning("[NetworkManager] connect_to_url failed: %d" % err)
		connection_failed.emit()

func disconnect_from_server() -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()
	_connected = false

func is_connected_to_server() -> bool:
	return _connected

func get_player_id() -> String:
	return _player_id

# ─── Outbound messages ────────────────────────────────────────────────────────

func join_match(lobby_code: String = "", tier: String = "pro") -> void:
	_send("player_join", {
		"lobby_code": lobby_code,
		"tier": tier,
		"player_name": GameState.player_name,
		"player_id": _player_id
	})

func submit_answer(answer: String, round_num: int) -> void:
	_send("answer_submit", {"answer": answer, "round": round_num})

func release_shot(power: float) -> void:
	_send("shot_release", {"power": snappedf(power, 0.001)})

func send_player_ready() -> void:
	_send("player_ready", {})

func request_rematch() -> void:
	_send("player_rematch", {})

# ─── Inbound dispatcher ───────────────────────────────────────────────────────

func _handle_message(txt: String) -> void:
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_warning("[NetworkManager] Bad JSON: " + txt.left(120))
		return
	var msg_type: String = parsed.get("type", "")
	var payload: Dictionary = parsed.get("payload", {})

	match msg_type:
		"lobby_created":     lobby_created.emit(payload)
		"opponent_joined":   opponent_joined.emit(payload)
		"match_start":       match_started.emit(payload)
		"round_start":       round_started.emit(payload)
		"answer_result":     answer_resulted.emit(payload)
		"possession_grant":  possession_granted.emit(payload)
		"shot_result":       shot_resulted.emit(payload)
		"score_update":      score_updated.emit(payload)
		"match_end":         match_ended.emit(payload)
		"opponent_left":     opponent_left.emit()
		"error":             push_warning("[Server Error] " + str(payload.get("message", "")))
		_:                   print("[NetworkManager] Unknown type: " + msg_type)

# ─── Internal helpers ─────────────────────────────────────────────────────────

func _send(msg_type: String, payload: Dictionary = {}) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_warning("[NetworkManager] Cannot send '%s' — not connected" % msg_type)
		return
	var msg := {
		"type": msg_type,
		"player_id": _player_id,
		"payload": payload,
		"timestamp": int(Time.get_unix_time_from_system() * 1000)
	}
	_ws.send_text(JSON.stringify(msg))

func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%04x-4%03x-%04x-%012x" % [
		rng.randi() & 0xFFFFFFFF,
		rng.randi() & 0xFFFF,
		rng.randi() & 0x0FFF,
		(rng.randi() & 0x3FFF) | 0x8000,
		rng.randi() & 0xFFFFFFFF
	]
