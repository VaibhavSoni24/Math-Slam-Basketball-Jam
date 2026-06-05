extends Control
## Pre-match screen: player avatars VS graphic + 3-2-1 countdown.

const C_BG      := Color(0.051, 0.082, 0.149, 1.0)
const C_ORANGE  := Color(1.0,   0.549, 0.102, 1.0)
const C_BLUE    := Color(0.227, 0.651, 1.0,   1.0)
const C_TEXT    := Color(0.92,  0.92,  0.95,  1.0)

var _countdown_label: Label
var _count: int = 3

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()
	AudioManager.play_sfx("countdown")
	_start_countdown()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Court lines decoration
	for i in range(5):
		var line := ColorRect.new()
		line.color = Color(1.0, 1.0, 1.0, 0.04)
		line.size  = Vector2(1280, 2)
		line.position = Vector2(0, 130.0 + i * 110.0)
		add_child(line)

	# Player 1 avatar card (left)
	_make_player_card(
		Vector2(240, 360),
		GameState.player_name if GameState.game_mode != "solo" else GameState.player_name,
		"🏀", C_ORANGE, GameState.my_player_slot == 1
	)

	# VS label (center)
	var vs := Label.new()
	vs.text = "VS"
	vs.position = Vector2(590, 290)
	vs.add_theme_font_size_override("font_size", 80)
	vs.add_theme_color_override("font_color", Color.WHITE)
	add_child(vs)

	# Tier badge
	var tier_lbl := Label.new()
	var tier_map := {"pro": "⭐ PRO", "all_star": "🌟 ALL-STAR", "rookie": "ROOKIE",
					 "varsity": "VARSITY", "mvp": "MVP"}
	tier_lbl.text = tier_map.get(GameState.current_tier, GameState.current_tier.to_upper())
	tier_lbl.position = Vector2(575, 395)
	tier_lbl.add_theme_font_size_override("font_size", 22)
	tier_lbl.add_theme_color_override("font_color", C_ORANGE)
	add_child(tier_lbl)

	# Player 2 avatar card (right)
	var opp_name := GameState.opponent_name if GameState.game_mode != "solo" else "🤖 CPU"
	_make_player_card(Vector2(1040, 360), opp_name, "🏀", C_BLUE, GameState.my_player_slot == 2)

	# Countdown label
	_countdown_label = Label.new()
	_countdown_label.text = "3"
	_countdown_label.position = Vector2(590, 480)
	_countdown_label.add_theme_font_size_override("font_size", 100)
	_countdown_label.add_theme_color_override("font_color", C_ORANGE)
	add_child(_countdown_label)

	var get_ready := Label.new()
	get_ready.text = "GET READY!"
	get_ready.position = Vector2(510, 590)
	get_ready.add_theme_font_size_override("font_size", 28)
	get_ready.add_theme_color_override("font_color", C_TEXT)
	add_child(get_ready)

func _make_player_card(center: Vector2, name_txt: String, emoji: String,
					   col: Color, _is_me: bool) -> void:
	var card_w := 280.0
	var card_h := 320.0
	var pos := center - Vector2(card_w / 2.0, card_h / 2.0)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.9)
	style.corner_radius_top_left    = 20
	style.corner_radius_top_right   = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right= 20
	style.border_width_left = style.border_width_right = style.border_width_top = style.border_width_bottom = 3
	style.border_color = col
	style.content_margin_left   = 20
	style.content_margin_right  = 20
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.position = pos
	panel.custom_minimum_size = Vector2(card_w, card_h)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var ball_lbl := Label.new()
	ball_lbl.text = emoji
	ball_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ball_lbl.add_theme_font_size_override("font_size", 80)
	vbox.add_child(ball_lbl)

	var n_lbl := Label.new()
	n_lbl.text = name_txt
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.add_theme_font_size_override("font_size", 22)
	n_lbl.add_theme_color_override("font_color", Color.WHITE)
	n_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(n_lbl)

	var tier_badge := Label.new()
	tier_badge.text = GameState.current_tier.to_upper().replace("_", "-")
	tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_badge.add_theme_font_size_override("font_size", 16)
	tier_badge.add_theme_color_override("font_color", col)
	vbox.add_child(tier_badge)

func _start_countdown() -> void:
	GameState.start_new_match()
	_tick_countdown()

func _tick_countdown() -> void:
	if _count <= 0:
		AudioManager.play_sfx("final_tick")
		_countdown_label.text = "GO!"
		_countdown_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file("res://Scenes/GameArena.tscn")
		return
	_countdown_label.text = str(_count)
	AudioManager.play_sfx("countdown")
	# Scale punch animation
	if not GameState.settings.get("reduced_motion", false):
		var tween := create_tween()
		tween.tween_property(_countdown_label, "scale", Vector2(1.4, 1.4), 0.0)
		tween.tween_property(_countdown_label, "scale", Vector2(1.0, 1.0), 0.4)
	_count -= 1
	await get_tree().create_timer(1.0).timeout
	_tick_countdown()
