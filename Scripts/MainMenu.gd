extends Control
## Main menu scene — fully built in code for maximum style control.

# ─── Theme colours ────────────────────────────────────────────────────────────
const C_BG       := Color(0.051, 0.082, 0.149, 1.0)   # #0D1526
const C_SURFACE  := Color(0.102, 0.145, 0.251, 1.0)   # #1A254x
const C_ORANGE   := Color(1.0,   0.549, 0.102, 1.0)   # #FF8C1A
const C_BLUE     := Color(0.227, 0.651, 1.0,   1.0)   # #3AA6FF
const C_GOLD     := Color(1.0,   0.843, 0.0,   1.0)   # #FFD700
const C_GREEN    := Color(0.298, 0.686, 0.314, 1.0)   # #4CAF50
const C_TEXT     := Color(0.92,  0.92,  0.95,  1.0)
const C_SUBTEXT  := Color(0.6,   0.65,  0.78,  1.0)

var _tier_btns: Dictionary = {}
var _name_input: LineEdit
var _xp_label: Label
var _ball_label: Label
var _ball_t: float = 0.0

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_refresh_tier_selection()
	AudioManager.play_music("menu")

# ─── UI builder ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Background gradient
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Subtle court pattern overlay (green tint)
	var court_tint := ColorRect.new()
	court_tint.color = Color(0.05, 0.25, 0.05, 0.12)
	court_tint.set_anchors_preset(PRESET_FULL_RECT)
	add_child(court_tint)

	# Decorative circles
	for i in 3:
		var circle := _make_deco_circle(
			Vector2(randi_range(100,1180), randi_range(100,620)),
			randi_range(60, 180),
			Color(C_ORANGE.r, C_ORANGE.g, C_ORANGE.b, 0.04 + i * 0.02)
		)
		add_child(circle)

	# Bouncing ball (emoji label — no external texture needed)
	_ball_label = Label.new()
	_ball_label.text = "🏀"
	_ball_label.add_theme_font_size_override("font_size", 72)
	_ball_label.position = Vector2(100, 250)
	add_child(_ball_label)

	var ball_r := Label.new()
	ball_r.text = "🏀"
	ball_r.add_theme_font_size_override("font_size", 48)
	ball_r.position = Vector2(1100, 400)
	ball_r.name = "BallR"
	add_child(ball_r)

	# Central card
	var card := _make_card(Vector2(640, 360), Vector2(540, 680))
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 0)
	vbox.size_flags_horizontal = SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "🏀 MATH SLAM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", C_ORANGE)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "BASKETBALL JAM"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", C_BLUE)
	vbox.add_child(subtitle)

	var tagline := Label.new()
	tagline.text = "Solve it first. Shoot it fast. Win the court."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", C_SUBTEXT)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(tagline)

	_add_sep(vbox, 8)

	# Name input
	var name_lbl := _make_label("YOUR NAME", 13, C_SUBTEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.text = GameState.player_name
	_name_input.placeholder_text = "Enter your name…"
	_name_input.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.custom_minimum_size = Vector2(460, 48)
	_name_input.add_theme_font_size_override("font_size", 20)
	_name_input.text_changed.connect(_on_name_changed)
	vbox.add_child(_name_input)

	_add_sep(vbox, 4)

	# Tier selector
	var tier_lbl := _make_label("DIFFICULTY TIER", 13, C_SUBTEXT)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tier_lbl)

	var tier_row := HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 10)
	vbox.add_child(tier_row)

	_tier_btns["pro"] = _make_pill_btn("⭐ PRO  Gr 3–4", C_ORANGE, func(): _select_tier("pro"))
	tier_row.add_child(_tier_btns["pro"])
	_tier_btns["all_star"] = _make_pill_btn("🌟 ALL-STAR  Gr 5–6", C_BLUE, func(): _select_tier("all_star"))
	tier_row.add_child(_tier_btns["all_star"])

	_add_sep(vbox, 6)

	# Main action buttons
	var qm := _make_action_btn("🔍  QUICK MATCH", C_ORANGE)
	qm.pressed.connect(_on_quick_match)
	vbox.add_child(qm)

	var fm := _make_action_btn("👫  CHALLENGE A FRIEND", C_BLUE)
	fm.pressed.connect(_on_friend_match)
	vbox.add_child(fm)

	var solo := _make_action_btn("🤖  SOLO PRACTICE", C_GREEN)
	solo.pressed.connect(_on_solo)
	vbox.add_child(solo)

	var sett := _make_action_btn("⚙️  SETTINGS", Color(0.45, 0.45, 0.60))
	sett.pressed.connect(_on_settings)
	vbox.add_child(sett)

	# XP display
	_xp_label = _make_label("✨ Total XP: %d" % GameState.total_xp, 16, C_GOLD)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_xp_label)

# ─── Widget helpers ───────────────────────────────────────────────────────────
func _make_card(center: Vector2, sz: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_SURFACE
	style.corner_radius_top_left    = 24
	style.corner_radius_top_right   = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right= 24
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(C_ORANGE.r, C_ORANGE.g, C_ORANGE.b, 0.35)
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = sz
	panel.position = center - sz / 2.0
	return panel

func _make_label(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _make_action_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(460, 54)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	_apply_btn_style(btn, col)
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_click"))
	return btn

func _make_pill_btn(txt: String, col: Color, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(220, 46)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)
	_apply_btn_style(btn, col.darkened(0.35))
	btn.pressed.connect(cb)
	return btn

func _apply_btn_style(btn: Button, col: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = col
	n.corner_radius_top_left    = 12
	n.corner_radius_top_right   = 12
	n.corner_radius_bottom_left = 12
	n.corner_radius_bottom_right= 12
	var h := n.duplicate(); h.bg_color = col.lightened(0.18)
	var p := n.duplicate(); p.bg_color = col.darkened(0.22)
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", p)

func _make_deco_circle(pos: Vector2, radius: int, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(radius * 2, radius * 2)
	r.position = pos - Vector2(radius, radius)
	return r

func _add_sep(parent: VBoxContainer, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)

# ─── State management ─────────────────────────────────────────────────────────
func _select_tier(tier: String) -> void:
	GameState.current_tier = tier
	GameState.save_persistent()
	_refresh_tier_selection()

func _refresh_tier_selection() -> void:
	for tier_key in _tier_btns:
		var btn: Button = _tier_btns[tier_key]
		var active := (tier_key == GameState.current_tier)
		var col := C_ORANGE if tier_key == "pro" else C_BLUE
		_apply_btn_style(btn, col if active else col.darkened(0.4))

# ─── Button callbacks ─────────────────────────────────────────────────────────
func _on_name_changed(txt: String) -> void:
	GameState.player_name = txt if txt != "" else "Player"

func _on_quick_match() -> void:
	GameState.matchmaking_mode = "quick"
	GameState.game_mode = "online"
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://Scenes/Matchmaking.tscn")

func _on_friend_match() -> void:
	GameState.matchmaking_mode = "friend"
	GameState.game_mode = "online"
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://Scenes/Matchmaking.tscn")

func _on_solo() -> void:
	GameState.game_mode = "solo"
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://Scenes/GameArena.tscn")

func _on_settings() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

# ─── Animation ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_ball_t += delta
	if is_instance_valid(_ball_label):
		_ball_label.position.y = 250.0 + sin(_ball_t * 2.2) * 40.0
		_ball_label.rotation    = _ball_t * 1.5
	var ball_r := get_node_or_null("BallR")
	if is_instance_valid(ball_r):
		ball_r.position.y = 400.0 + sin(_ball_t * 1.7 + 1.0) * 30.0
		ball_r.rotation    = -_ball_t * 1.2
