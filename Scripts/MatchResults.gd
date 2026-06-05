extends Control
## Match results screen — final score, stats, XP earned, share card, rematch.

const C_BG      := Color(0.051, 0.082, 0.149, 1.0)
const C_SURFACE := Color(0.102, 0.145, 0.251, 1.0)
const C_ORANGE  := Color(1.0,   0.549, 0.102, 1.0)
const C_BLUE    := Color(0.227, 0.651, 1.0,   1.0)
const C_GOLD    := Color(1.0,   0.843, 0.0,   1.0)
const C_GREEN   := Color(0.298, 0.686, 0.314, 1.0)
const C_TEXT    := Color(0.92,  0.92,  0.95,  1.0)
const C_SUBTEXT := Color(0.6,   0.65,  0.78,  1.0)

var _confetti_labels: Array[Label] = []
var _confetti_vels: Array[Vector2] = []
var _confetti_t: float = 0.0

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()
	if GameState.did_i_win():
		_spawn_confetti()
		AudioManager.play_sfx("win")
	else:
		AudioManager.play_sfx("countdown")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var card := _make_card()
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	# Result header
	var result_icon := Label.new()
	result_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_icon.add_theme_font_size_override("font_size", 72)
	if GameState.did_i_win():
		result_icon.text = "🏆"
	elif GameState.my_score() == GameState.opponent_score():
		result_icon.text = "🤝"
	else:
		result_icon.text = "😤"
	vbox.add_child(result_icon)

	var result_lbl := Label.new()
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 42)
	if GameState.did_i_win():
		result_lbl.text = "YOU WIN!"
		result_lbl.add_theme_color_override("font_color", C_GOLD)
	elif GameState.my_score() == GameState.opponent_score():
		result_lbl.text = "IT'S A TIE!"
		result_lbl.add_theme_color_override("font_color", C_ORANGE)
	else:
		result_lbl.text = "GOOD GAME!"
		result_lbl.add_theme_color_override("font_color", C_SUBTEXT)
	vbox.add_child(result_lbl)

	# Score card
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 30)
	vbox.add_child(score_row)

	_make_score_block(score_row, GameState.player_name,
		GameState.p1_score if GameState.my_player_slot == 1 else GameState.p2_score, C_ORANGE)
	var dash := Label.new(); dash.text = "–"
	dash.add_theme_font_size_override("font_size", 48)
	dash.add_theme_color_override("font_color", C_SUBTEXT)
	score_row.add_child(dash)
	var opp_name := GameState.opponent_name if GameState.game_mode != "solo" else "CPU"
	_make_score_block(score_row, opp_name,
		GameState.p2_score if GameState.my_player_slot == 1 else GameState.p1_score, C_BLUE)

	# XP earned
	var xp_earned := GameState.compute_match_xp()
	var xp_lbl := Label.new()
	xp_lbl.text = "✨ +%d XP  (Total: %d XP)" % [xp_earned, GameState.total_xp]
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.add_theme_font_size_override("font_size", 20)
	xp_lbl.add_theme_color_override("font_color", C_GOLD)
	vbox.add_child(xp_lbl)

	# Stats grid
	_add_sep(vbox, 4)
	_make_stats_row(vbox)

	# Personal best
	if GameState.fastest_time_ms < INF:
		var pb_key := GameState.current_tier
		var is_new_best := not GameState.personal_bests.has(pb_key) or \
						   GameState.fastest_time_ms <= GameState.personal_bests.get(pb_key, INF)
		if is_new_best:
			var pb_lbl := Label.new()
			pb_lbl.text = "⚡ NEW PERSONAL BEST! %.1fs" % (GameState.fastest_time_ms / 1000.0)
			pb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pb_lbl.add_theme_font_size_override("font_size", 20)
			pb_lbl.add_theme_color_override("font_color", C_GREEN)
			vbox.add_child(pb_lbl)

	# Win streak
	if GameState.win_streak >= 3:
		var streak_lbl := Label.new()
		streak_lbl.text = "🔥 %d-WIN STREAK!" % GameState.win_streak
		streak_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		streak_lbl.add_theme_font_size_override("font_size", 20)
		streak_lbl.add_theme_color_override("font_color", C_ORANGE)
		vbox.add_child(streak_lbl)

	_add_sep(vbox, 6)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	if GameState.game_mode == "online":
		var rematch := _make_btn("🔄  Rematch", C_ORANGE)
		rematch.pressed.connect(_on_rematch)
		btn_row.add_child(rematch)

	var share := _make_btn("📤  Share Result", C_BLUE)
	share.pressed.connect(_on_share)
	btn_row.add_child(share)

	var menu := _make_btn("🏠  Main Menu", Color(0.35, 0.35, 0.5))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))
	btn_row.add_child(menu)

# ─── Widget helpers ───────────────────────────────────────────────────────────
func _make_card() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_SURFACE
	s.corner_radius_top_left    = 24
	s.corner_radius_top_right   = 24
	s.corner_radius_bottom_left = 24
	s.corner_radius_bottom_right= 24
	s.border_width_left = s.border_width_right = s.border_width_top = s.border_width_bottom = 2
	s.border_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.5)
	s.content_margin_left   = 40
	s.content_margin_right  = 40
	s.content_margin_top    = 32
	s.content_margin_bottom = 32
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(620, 500)
	p.position = Vector2(640, 360) - Vector2(310, 270)
	return p

func _make_score_block(parent: HBoxContainer, name_txt: String,
					   score: int, col: Color) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)

	var n := Label.new(); n.text = name_txt
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 18)
	n.add_theme_color_override("font_color", col)
	v.add_child(n)

	var s := Label.new(); s.text = str(score)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 60)
	s.add_theme_color_override("font_color", col)
	v.add_child(s)

func _make_stats_row(parent: VBoxContainer) -> void:
	var accuracy_pct := int(GameState.get_accuracy() * 100.0)
	var fastest_s    := "%.1fs" % (GameState.fastest_time_ms / 1000.0) \
					    if GameState.fastest_time_ms < INF else "N/A"

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	var stats := [
		["📊 Accuracy", "%d%%" % accuracy_pct],
		["⚡ Fastest Answer", fastest_s],
		["🎯 Problems Tried", str(GameState.total_count)],
		["✅ Correct", str(GameState.correct_count)]
	]
	for stat in stats:
		var key := Label.new(); key.text = stat[0]
		key.add_theme_font_size_override("font_size", 17)
		key.add_theme_color_override("font_color", C_SUBTEXT)
		grid.add_child(key)
		var val := Label.new(); val.text = stat[1]
		val.add_theme_font_size_override("font_size", 17)
		val.add_theme_color_override("font_color", C_TEXT)
		grid.add_child(val)

func _make_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(180, 50)
	btn.add_theme_font_size_override("font_size", 18)
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

func _add_sep(parent: VBoxContainer, h: int) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(0, h); parent.add_child(s)

# ─── Confetti ─────────────────────────────────────────────────────────────────
func _spawn_confetti() -> void:
	var emojis := ["🏀", "⭐", "🎉", "🏆", "✨", "🌟"]
	for i in 30:
		var lbl := Label.new()
		lbl.text = emojis[i % emojis.size()]
		lbl.add_theme_font_size_override("font_size", randi_range(20, 40))
		lbl.position = Vector2(randf_range(0, 1280), randf_range(-100, 0))
		add_child(lbl)
		_confetti_labels.append(lbl)
		_confetti_vels.append(Vector2(randf_range(-60, 60), randf_range(80, 200)))

func _process(delta: float) -> void:
	_confetti_t += delta
	for i in _confetti_labels.size():
		if not is_instance_valid(_confetti_labels[i]):
			continue
		_confetti_labels[i].position += _confetti_vels[i] * delta
		_confetti_labels[i].rotation += delta * randf_range(-2.0, 2.0)
		if _confetti_labels[i].position.y > 780:
			_confetti_labels[i].position.y = -50

# ─── Actions ──────────────────────────────────────────────────────────────────
func _on_rematch() -> void:
	AudioManager.play_sfx("ui_click")
	NetworkManager.request_rematch()
	get_tree().change_scene_to_file("res://Scenes/Matchmaking.tscn")

func _on_share() -> void:
	AudioManager.play_sfx("ui_click")
	var msg: String = "I just played Math Slam Basketball Jam! Score: %d – %d. Can you beat me? 🏀" % [
		GameState.my_score(), GameState.opponent_score()
	]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			if (navigator.share) {
				navigator.share({ title: 'Math Slam Basketball Jam', text: '%s' });
			} else {
				navigator.clipboard.writeText('%s');
				alert('Result copied to clipboard!');
			}
		""" % [msg, msg])
	else:
		DisplayServer.clipboard_set(msg)
