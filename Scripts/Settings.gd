extends Control
## Settings panel — volume sliders, accessibility toggles, server URL config.

const C_BG      := Color(0.051, 0.082, 0.149, 1.0)
const C_SURFACE := Color(0.102, 0.145, 0.251, 1.0)
const C_ORANGE  := Color(1.0,   0.549, 0.102, 1.0)
const C_BLUE    := Color(0.227, 0.651, 1.0,   1.0)
const C_TEXT    := Color(0.92,  0.92,  0.95,  1.0)
const C_SUBTEXT := Color(0.6,   0.65,  0.78,  1.0)

var _server_url_input: LineEdit

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var card := _make_card()
	add_child(card)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(540, 0)
	vbox.add_theme_constant_override("separation", 18)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚙️  SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", C_ORANGE)
	vbox.add_child(title)

	_add_section(vbox, "🔊 AUDIO")
	_add_slider(vbox, "Music Volume", "music_volume", 0.0, 1.0)
	_add_slider(vbox, "SFX Volume",   "sfx_volume",   0.0, 1.0)

	_add_section(vbox, "♿ ACCESSIBILITY")
	_add_toggle(vbox, "Larger Problem Text (48→60px)", "larger_text")
	_add_toggle(vbox, "Reduced Motion (disable animations)", "reduced_motion")
	_add_toggle(vbox, "High Contrast Mode", "high_contrast")
	_add_toggle(vbox, "Color-blind Mode (patterns instead of colours)", "colorblind_mode")

	_add_section(vbox, "🌐 NETWORK")
	var url_lbl := _make_label("Relay Server URL", 14, C_SUBTEXT)
	vbox.add_child(url_lbl)

	_server_url_input = LineEdit.new()
	_server_url_input.text = GameState.settings.get("server_url", "ws://localhost:3000")
	_server_url_input.placeholder_text = "ws://your-server.railway.app"
	_server_url_input.custom_minimum_size = Vector2(520, 46)
	_server_url_input.add_theme_font_size_override("font_size", 16)
	_server_url_input.text_submitted.connect(_on_server_url_changed)
	vbox.add_child(_server_url_input)

	var url_hint := _make_label("Press Enter to save URL. Used next time you connect.", 13, C_SUBTEXT)
	vbox.add_child(url_hint)

	_add_section(vbox, "🏆 PLAYER DATA")
	var xp_lbl := _make_label("Total XP: %d" % GameState.total_xp, 18, C_ORANGE)
	vbox.add_child(xp_lbl)

	var reset_btn := _make_btn("🗑  Reset Progress", Color(0.7, 0.2, 0.2))
	reset_btn.pressed.connect(_on_reset_progress)
	vbox.add_child(reset_btn)

	var sep := Control.new(); sep.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(sep)

	var back := _make_btn("← Back to Menu", Color(0.35, 0.35, 0.5))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))
	vbox.add_child(back)

# ─── Widget helpers ───────────────────────────────────────────────────────────
func _make_card() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_SURFACE
	s.corner_radius_top_left    = 24
	s.corner_radius_top_right   = 24
	s.corner_radius_bottom_left = 24
	s.corner_radius_bottom_right= 24
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color = Color(C_ORANGE.r, C_ORANGE.g, C_ORANGE.b, 0.3)
	s.content_margin_left   = 30
	s.content_margin_right  = 30
	s.content_margin_top    = 28
	s.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(620, 600)
	p.position = Vector2(640, 360) - Vector2(310, 320)
	return p

func _add_section(parent: VBoxContainer, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_BLUE)
	parent.add_child(lbl)
	var line := ColorRect.new()
	line.color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.3)
	line.custom_minimum_size = Vector2(520, 2)
	parent.add_child(line)

func _add_slider(parent: VBoxContainer, label_txt: String, key: String,
				 lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := _make_label(label_txt, 16, C_TEXT)
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = lo; slider.max_value = hi; slider.step = 0.01
	slider.value = GameState.settings.get(key, 0.7)
	slider.custom_minimum_size = Vector2(260, 30)
	slider.value_changed.connect(func(v: float): _on_slider_changed(key, v))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(slider.value * 100)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", C_ORANGE)
	val_lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v: float): val_lbl.text = "%d%%" % int(v * 100))

func _add_toggle(parent: VBoxContainer, label_txt: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var check := CheckButton.new()
	check.button_pressed = GameState.settings.get(key, false)
	check.toggled.connect(func(v: bool): _on_toggle_changed(key, v))
	row.add_child(check)

	var lbl := _make_label(label_txt, 16, C_TEXT)
	row.add_child(lbl)

func _make_label(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

func _make_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(520, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var n := StyleBoxFlat.new()
	n.bg_color = col
	n.corner_radius_top_left     = 10
	n.corner_radius_top_right    = 10
	n.corner_radius_bottom_left  = 10
	n.corner_radius_bottom_right = 10
	var h := n.duplicate(); h.bg_color = col.lightened(0.18)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  h)
	return btn

# ─── Callbacks ────────────────────────────────────────────────────────────────
func _on_slider_changed(key: String, value: float) -> void:
	GameState.settings[key] = value
	GameState.save_persistent()
	AudioManager.refresh_settings()

func _on_toggle_changed(key: String, value: bool) -> void:
	GameState.settings[key] = value
	GameState.save_persistent()
	GameState.settings_changed.emit()

func _on_server_url_changed(url: String) -> void:
	url = url.strip_edges()
	if url.begins_with("ws://") or url.begins_with("wss://"):
		GameState.settings["server_url"] = url
		GameState.save_persistent()
	else:
		_server_url_input.placeholder_text = "Must start with ws:// or wss://"

func _on_reset_progress() -> void:
	GameState.total_xp = 0
	GameState.win_streak = 0
	GameState.personal_bests = {}
	GameState.save_persistent()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
