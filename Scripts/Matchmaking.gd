extends Control
## Matchmaking screen: Quick Match spinner or Friend Lobby code UI.

const C_BG      := Color(0.051, 0.082, 0.149, 1.0)
const C_SURFACE := Color(0.102, 0.145, 0.251, 1.0)
const C_ORANGE  := Color(1.0,   0.549, 0.102, 1.0)
const C_BLUE    := Color(0.227, 0.651, 1.0,   1.0)
const C_TEXT    := Color(0.92,  0.92,  0.95,  1.0)
const C_SUBTEXT := Color(0.6,   0.65,  0.78,  1.0)

var _status_label: Label
var _code_label: Label
var _code_input: LineEdit
var _dot_timer: float = 0.0
var _dot_count: int = 0
var _lobby_code: String = ""
var _waiting_for_opponent: bool = false

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_connect_signals()
	_start_matchmaking()

# ─── UI ───────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var card := _make_card()
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	card.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", C_ORANGE)
	vbox.add_child(title)

	if GameState.matchmaking_mode == "quick":
		title.text = "🔍 QUICK MATCH"
		_status_label = Label.new()
		_status_label.text = "Finding opponent"
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_label.add_theme_font_size_override("font_size", 22)
		_status_label.add_theme_color_override("font_color", C_TEXT)
		vbox.add_child(_status_label)

		var spinner_lbl := Label.new()
		spinner_lbl.text = "🏀"
		spinner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spinner_lbl.add_theme_font_size_override("font_size", 80)
		spinner_lbl.name = "Spinner"
		vbox.add_child(spinner_lbl)

	else:
		title.text = "👫 FRIEND LOBBY"
		var host_lbl := Label.new()
		host_lbl.text = "Your Lobby Code:"
		host_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		host_lbl.add_theme_font_size_override("font_size", 18)
		host_lbl.add_theme_color_override("font_color", C_SUBTEXT)
		vbox.add_child(host_lbl)

		_code_label = Label.new()
		_code_label.text = "Connecting…"
		_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_code_label.add_theme_font_size_override("font_size", 56)
		_code_label.add_theme_color_override("font_color", C_BLUE)
		vbox.add_child(_code_label)

		var copy_btn := _make_btn("📋  Copy Code", C_BLUE)
		copy_btn.pressed.connect(_on_copy_code)
		vbox.add_child(copy_btn)

		var or_lbl := Label.new()
		or_lbl.text = "— OR JOIN A GAME —"
		or_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		or_lbl.add_theme_font_size_override("font_size", 14)
		or_lbl.add_theme_color_override("font_color", C_SUBTEXT)
		vbox.add_child(or_lbl)

		_code_input = LineEdit.new()
		_code_input.placeholder_text = "Enter friend's code…"
		_code_input.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_code_input.max_length = 6
		_code_input.custom_minimum_size = Vector2(300, 52)
		_code_input.add_theme_font_size_override("font_size", 30)
		vbox.add_child(_code_input)

		var join_btn := _make_btn("🚀  JOIN LOBBY", C_ORANGE)
		join_btn.pressed.connect(_on_join_lobby)
		vbox.add_child(join_btn)

		_status_label = Label.new()
		_status_label.text = "Waiting for opponent…"
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_label.add_theme_font_size_override("font_size", 18)
		_status_label.add_theme_color_override("font_color", C_SUBTEXT)
		_status_label.visible = false
		vbox.add_child(_status_label)

	var sep := Control.new(); sep.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(sep)

	var back := _make_btn("← Back", Color(0.4, 0.4, 0.55))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))
	vbox.add_child(back)

func _make_card() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_SURFACE
	s.corner_radius_top_left    = 24
	s.corner_radius_top_right   = 24
	s.corner_radius_bottom_left = 24
	s.corner_radius_bottom_right= 24
	s.border_width_left = s.border_width_right = s.border_width_top = s.border_width_bottom = 2
	s.border_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.4)
	s.content_margin_left   = 40
	s.content_margin_right  = 40
	s.content_margin_top    = 36
	s.content_margin_bottom = 36
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(540, 480)
	p.position = Vector2(640, 360) - Vector2(270, 240)
	return p

func _make_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(380, 52)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var n := StyleBoxFlat.new()
	n.bg_color = col
	n.corner_radius_top_left = n.corner_radius_top_right = n.corner_radius_bottom_left = n.corner_radius_bottom_right = 12
	var h := n.duplicate(); h.bg_color = col.lightened(0.18)
	var p := n.duplicate(); p.bg_color = col.darkened(0.22)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  h)
	btn.add_theme_stylebox_override("pressed",p)
	return btn

# ─── Logic ────────────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.lobby_created.connect(_on_lobby_created)
	NetworkManager.opponent_joined.connect(_on_opponent_joined)
	NetworkManager.match_started.connect(_on_match_started)

func _start_matchmaking() -> void:
	NetworkManager.connect_to_server(GameState.settings.get("server_url", "ws://localhost:3000"))

func _on_connected() -> void:
	if GameState.matchmaking_mode == "quick":
		NetworkManager.join_match("", GameState.current_tier)
		_status_label.text = "Finding opponent"
		_waiting_for_opponent = true
	else:
		# Host: request a lobby code
		NetworkManager.join_match("HOST", GameState.current_tier)

func _on_connection_failed() -> void:
	_status_label.text = "⚠ Cannot reach server.\nCheck connection or run Solo Practice."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_status_label.visible = true

func _on_lobby_created(data: Dictionary) -> void:
	_lobby_code = str(data.get("code", "------"))
	GameState.my_player_slot = data.get("player_slot", 1)
	if is_instance_valid(_code_label):
		_code_label.text = _lobby_code
	if is_instance_valid(_status_label):
		_status_label.visible = true
		_status_label.text = "Waiting for friend to join…"

func _on_opponent_joined(data: Dictionary) -> void:
	GameState.opponent_name = data.get("opponent_name", "Opponent")
	if is_instance_valid(_status_label):
		_status_label.text = "✅ " + GameState.opponent_name + " joined! Starting…"
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://Scenes/PreMatch.tscn")

func _on_match_started(data: Dictionary) -> void:
	GameState.my_player_slot = data.get("player_slot", 1)
	GameState.opponent_name  = data.get("opponent_name", "Opponent")
	get_tree().change_scene_to_file("res://Scenes/PreMatch.tscn")

func _on_copy_code() -> void:
	if _lobby_code != "":
		DisplayServer.clipboard_set(_lobby_code)
		AudioManager.play_sfx("ui_click")

func _on_join_lobby() -> void:
	var code: String = _code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		_code_input.placeholder_text = "Code must be 6 characters!"
		return
	AudioManager.play_sfx("ui_click")
	NetworkManager.join_match(code, GameState.current_tier)

func _process(delta: float) -> void:
	_dot_timer += delta
	if _dot_timer >= 0.5 and _waiting_for_opponent:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % 4
		if is_instance_valid(_status_label):
			_status_label.text = "Finding opponent" + ".".repeat(_dot_count)
	# Spin the basketball
	var spinner := get_node_or_null("Spinner")  ## won't exist in friend mode
	if is_instance_valid(spinner):
		spinner.rotation += delta * 3.0
