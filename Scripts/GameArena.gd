extends Node2D
## Main game scene — handles both online multiplayer and solo CPU modes.
## All visual nodes are built in _ready(); game state is a local FSM.

# ─── Colours ─────────────────────────────────────────────────────────────────
const C_BG       := Color(0.051, 0.082, 0.149, 1.0)
const C_COURT    := Color(0.69,  0.47,  0.22,  1.0)  # hardwood
const C_ORANGE   := Color(1.0,   0.549, 0.102, 1.0)
const C_BLUE     := Color(0.227, 0.651, 1.0,   1.0)
const C_GREEN    := Color(0.18,  0.80,  0.44,  1.0)
const C_YELLOW   := Color(1.0,   0.88,  0.1,   1.0)
const C_RED      := Color(0.95,  0.22,  0.22,  1.0)
const C_TEXT     := Color(0.92,  0.92,  0.95,  1.0)

# ─── Game constants ───────────────────────────────────────────────────────────
const ROUND_TIME       := 30.0
const HINT_TIME        := 15.0
const SHOT_WINDOW      := 3.0
const POWER_CYCLE_TIME := 1.5
const ROUND_END_PAUSE  := 1.8

# ─── State machine ────────────────────────────────────────────────────────────
enum State { WAITING, ANSWERING, SHOT_PHASE, ROUND_END, MATCH_END }
var _state := State.WAITING

# ─── Node references (built in code) ─────────────────────────────────────────
var _problem_label: Label
var _fraction_display: Control     # fraction visual container
var _frac_n1: Label; var _frac_d1: Label
var _frac_op: Label
var _frac_n2: Label; var _frac_d2: Label
var _answer_input: LineEdit
var _feedback_label: Label
var _p1_score_label: Label
var _p2_score_label: Label
var _round_label: Label
var _timer_bar: ProgressBar
var _ball: Label                   # emoji ball label
var _hoop: Label
var _p1_sprite: Label
var _p2_sprite: Label
var _power_bar_bg: ColorRect
var _power_bar_fill: ColorRect
var _power_zone_label: Label
var _shot_instruction: Label
var _overlay_panel: PanelContainer
var _overlay_winner: Label
var _overlay_answer: Label
var _hot_streak_label: Label
var _input_layer: CanvasLayer
var _shot_layer: CanvasLayer
var _hud_layer: CanvasLayer
var _problem_layer: CanvasLayer
var _overlay_layer: CanvasLayer

# ─── Game state ───────────────────────────────────────────────────────────────
var _round_timer: float = 0.0
var _power: float = 0.0
var _power_dir: float = 1.0
var _shot_timer: float = 0.0
var _hint_shown: bool = false

# ─── CPU opponent (solo mode) ─────────────────────────────────────────────────
var _cpu_think_time: float = 0.0
var _cpu_timer: float = 0.0

# ─── Ball animation ───────────────────────────────────────────────────────────
var _ball_pos := Vector2(200, 520)
var _ball_anim_t: float = -1.0  # -1 = idle
var _ball_start: Vector2
var _ball_peak: Vector2
var _ball_end: Vector2
var _ball_anim_dur: float = 0.7
var _ball_scored: bool = false
var _ball_idle_t: float = 0.0

# ─── Positions (1280×720 canvas) ─────────────────────────────────────────────
const HOOP_POS    := Vector2(1140, 240)
const P1_POS      := Vector2(220,  530)
const P2_POS      := Vector2(1060, 530)
const BALL_IDLE_P1 := Vector2(260,  490)
const BALL_IDLE_P2 := Vector2(1020, 490)

func _ready() -> void:
	_build_scene()
	_connect_network_signals()
	_begin_match()

# ─────────────────────────────────────────────────────────────────────────────
# SCENE BUILD
# ─────────────────────────────────────────────────────────────────────────────
func _build_scene() -> void:
	# — Court background ———————————————————————————————
	var court_bg := ColorRect.new()
	court_bg.color = Color(0.08, 0.32, 0.12)   # dark green arena
	court_bg.size  = Vector2(1280, 720)
	add_child(court_bg)

	# Court floor
	var floor_r := ColorRect.new()
	floor_r.color = C_COURT
	floor_r.size  = Vector2(1280, 240)
	floor_r.position = Vector2(0, 480)
	add_child(floor_r)

	# Court lines
	_draw_court_lines()

	# — Players ————————————————————————————————————————
	_p1_sprite = _make_emoji("🏃", 64, P1_POS)
	_p2_sprite = _make_emoji("🏃", 64, P2_POS)

	# — Hoop ———————————————————————————————————————————
	_hoop = _make_emoji("🏀\n🏀", 36, HOOP_POS)
	var hoop_lbl := Label.new()
	hoop_lbl.text = "🥅"
	hoop_lbl.add_theme_font_size_override("font_size", 72)
	hoop_lbl.position = HOOP_POS - Vector2(36, 36)
	add_child(hoop_lbl)

	# — Ball ———————————————————————————————————————————
	_ball = Label.new()
	_ball.text = "🏀"
	_ball.add_theme_font_size_override("font_size", 52)
	_ball.position = BALL_IDLE_P1
	add_child(_ball)

	# — HUD layer ——————————————————————————————————————
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_build_hud()

	# — Problem layer ——————————————————————————————————
	_problem_layer = CanvasLayer.new()
	_problem_layer.layer = 20
	add_child(_problem_layer)
	_build_problem_display()

	# — Input layer ————————————————————————————————————
	_input_layer = CanvasLayer.new()
	_input_layer.layer = 30
	add_child(_input_layer)
	_build_input_area()

	# — Shot layer ————————————————————————————————————-
	_shot_layer = CanvasLayer.new()
	_shot_layer.layer = 40
	add_child(_shot_layer)
	_build_shot_mechanic()

	# — Overlay layer ——————————————————————————————————
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 50
	add_child(_overlay_layer)
	_build_overlay()

func _draw_court_lines() -> void:
	# Center circle outline
	var outer_c := ColorRect.new()
	outer_c.color = Color(1.0, 1.0, 1.0, 0.15)
	outer_c.size  = Vector2(200, 200)
	outer_c.position = Vector2(540, 290)
	add_child(outer_c)
	# Three-point arc suggestion (simplified as rectangle)
	var arc := ColorRect.new()
	arc.color = Color(1.0, 1.0, 1.0, 0.08)
	arc.size  = Vector2(320, 3)
	arc.position = Vector2(960, 380)
	add_child(arc)
	# Foul line
	var foul := ColorRect.new()
	foul.color = Color(1.0, 1.0, 1.0, 0.12)
	foul.size  = Vector2(3, 200)
	foul.position = Vector2(900, 290)
	add_child(foul)

func _build_hud() -> void:
	# HUD bar background
	var hud_bg := ColorRect.new()
	hud_bg.color = Color(0.0, 0.0, 0.0, 0.78)
	hud_bg.size  = Vector2(1280, 72)
	_hud_layer.add_child(hud_bg)

	# P1 name + score
	var p1_name := Label.new()
	p1_name.text = GameState.player_name
	p1_name.position = Vector2(20, 8)
	p1_name.add_theme_font_size_override("font_size", 18)
	p1_name.add_theme_color_override("font_color", C_ORANGE)
	_hud_layer.add_child(p1_name)

	_p1_score_label = Label.new()
	_p1_score_label.text = "0"
	_p1_score_label.position = Vector2(20, 32)
	_p1_score_label.add_theme_font_size_override("font_size", 28)
	_p1_score_label.add_theme_color_override("font_color", C_ORANGE)
	_hud_layer.add_child(_p1_score_label)

	# Round
	_round_label = Label.new()
	_round_label.text = "ROUND 1 / %d" % GameState.max_rounds
	_round_label.position = Vector2(480, 20)
	_round_label.add_theme_font_size_override("font_size", 20)
	_round_label.add_theme_color_override("font_color", C_TEXT)
	_hud_layer.add_child(_round_label)

	# P2 name + score
	var p2_name := Label.new()
	p2_name.text = GameState.opponent_name if GameState.game_mode != "solo" else "🤖 CPU"
	p2_name.position = Vector2(1050, 8)
	p2_name.add_theme_font_size_override("font_size", 18)
	p2_name.add_theme_color_override("font_color", C_BLUE)
	_hud_layer.add_child(p2_name)

	_p2_score_label = Label.new()
	_p2_score_label.text = "0"
	_p2_score_label.position = Vector2(1050, 32)
	_p2_score_label.add_theme_font_size_override("font_size", 28)
	_p2_score_label.add_theme_color_override("font_color", C_BLUE)
	_hud_layer.add_child(_p2_score_label)

	# Timer bar
	_timer_bar = ProgressBar.new()
	_timer_bar.min_value = 0
	_timer_bar.max_value = ROUND_TIME
	_timer_bar.value = ROUND_TIME
	_timer_bar.size  = Vector2(1280, 8)
	_timer_bar.position = Vector2(0, 64)
	_timer_bar.show_percentage = false
	_hud_layer.add_child(_timer_bar)

	# Hot streak
	_hot_streak_label = Label.new()
	_hot_streak_label.text = "🔥 ON FIRE!"
	_hot_streak_label.position = Vector2(540, 80)
	_hot_streak_label.add_theme_font_size_override("font_size", 28)
	_hot_streak_label.add_theme_color_override("font_color", C_ORANGE)
	_hot_streak_label.visible = false
	_hud_layer.add_child(_hot_streak_label)

func _build_problem_display() -> void:
	var prob_bg := ColorRect.new()
	prob_bg.color = Color(0.0, 0.0, 0.0, 0.85)
	prob_bg.size  = Vector2(720, 130)
	prob_bg.position = Vector2(280, 85)
	_problem_layer.add_child(prob_bg)

	_problem_label = Label.new()
	_problem_label.text = ""
	_problem_label.size = Vector2(700, 110)
	_problem_label.position = Vector2(290, 90)
	_problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_problem_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_problem_label.add_theme_font_size_override("font_size",
		48 if not GameState.settings.get("larger_text", false) else 60)
	_problem_label.add_theme_color_override("font_color", C_TEXT)
	_problem_layer.add_child(_problem_label)

	# Fraction visual display (hidden by default)
	_fraction_display = Control.new()
	_fraction_display.size = Vector2(700, 110)
	_fraction_display.position = Vector2(290, 90)
	_fraction_display.visible = false
	_problem_layer.add_child(_fraction_display)

	var frac_hbox := HBoxContainer.new()
	frac_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	frac_hbox.add_theme_constant_override("separation", 12)
	frac_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fraction_display.add_child(frac_hbox)

	_frac_n1 = _make_frac_num()
	var d1_col := ColorRect.new(); d1_col.color = C_TEXT; d1_col.size = Vector2(50, 3)
	_frac_d1 = _make_frac_num()
	_frac_op = Label.new(); _frac_op.add_theme_font_size_override("font_size", 48)
	_frac_op.add_theme_color_override("font_color", C_TEXT)
	_frac_n2 = _make_frac_num()
	var d2_col := ColorRect.new(); d2_col.color = C_TEXT; d2_col.size = Vector2(50, 3)
	_frac_d2 = _make_frac_num()

	# Build fraction VBoxes
	var fv1 := _make_frac_vbox(_frac_n1, d1_col, _frac_d1)
	frac_hbox.add_child(fv1)
	frac_hbox.add_child(_frac_op)
	var fv2 := _make_frac_vbox(_frac_n2, d2_col, _frac_d2)
	frac_hbox.add_child(fv2)

	var eq := Label.new(); eq.text = "= ?"
	eq.add_theme_font_size_override("font_size", 48)
	eq.add_theme_color_override("font_color", C_TEXT)
	frac_hbox.add_child(eq)

func _make_frac_num() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 38)
	l.add_theme_color_override("font_color", C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _make_frac_vbox(n: Label, line: ColorRect, d: Label) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(n); v.add_child(line); v.add_child(d)
	return v

func _build_input_area() -> void:
	var input_bg := ColorRect.new()
	input_bg.color = Color(0.0, 0.0, 0.0, 0.88)
	input_bg.size  = Vector2(1280, 110)
	input_bg.position = Vector2(0, 610)
	_input_layer.add_child(input_bg)

	var prompt := Label.new()
	prompt.text = "TYPE YOUR ANSWER:"
	prompt.position = Vector2(320, 618)
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	_input_layer.add_child(prompt)

	_answer_input = LineEdit.new()
	_answer_input.placeholder_text = "Answer here… (Enter to submit)"
	_answer_input.size  = Vector2(640, 58)
	_answer_input.position = Vector2(320, 638)
	_answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer_input.add_theme_font_size_override("font_size", 32)
	_apply_lineedit_style(_answer_input)
	_answer_input.text_submitted.connect(_on_answer_submitted)
	_input_layer.add_child(_answer_input)
	_answer_input.grab_focus()

	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.position = Vector2(320, 640)
	_feedback_label.size  = Vector2(640, 58)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 26)
	_input_layer.add_child(_feedback_label)

func _apply_lineedit_style(le: LineEdit) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.20, 0.35)
	s.corner_radius_top_left    = 10
	s.corner_radius_top_right   = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right= 10
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_color = C_BLUE
	le.add_theme_stylebox_override("normal", s)
	le.add_theme_color_override("font_color", C_TEXT)

func _build_shot_mechanic() -> void:
	# Power bar background (right side)
	_power_bar_bg = ColorRect.new()
	_power_bar_bg.color = Color(0.1, 0.1, 0.15, 0.95)
	_power_bar_bg.size  = Vector2(54, 340)
	_power_bar_bg.position = Vector2(1210, 150)
	_power_bar_bg.visible = false
	_shot_layer.add_child(_power_bar_bg)

	# Zone ticks
	for zone_data in [
		[0.0,  0.40, C_RED],
		[0.40, 0.65, Color(1.0, 0.55, 0.0)],
		[0.65, 0.85, C_YELLOW],
		[0.85, 1.00, C_GREEN]
	]:
		var zone_rect := ColorRect.new()
		var y_start: float = (1.0 - zone_data[1]) * 300.0 + 20.0
		var y_end:   float = (1.0 - zone_data[0]) * 300.0 + 20.0
		zone_rect.color = Color(zone_data[2].r, zone_data[2].g, zone_data[2].b, 0.25)
		zone_rect.size  = Vector2(54, y_end - y_start)
		zone_rect.position = Vector2(0, y_start)
		_power_bar_bg.add_child(zone_rect)

	# Fill bar
	_power_bar_fill = ColorRect.new()
	_power_bar_fill.color = C_GREEN
	_power_bar_fill.size  = Vector2(54, 0)
	_power_bar_fill.position = Vector2(0, 340)
	_power_bar_bg.add_child(_power_bar_fill)

	# Zone label
	_power_zone_label = Label.new()
	_power_zone_label.text = ""
	_power_zone_label.position = Vector2(1160, 500)
	_power_zone_label.add_theme_font_size_override("font_size", 18)
	_power_zone_label.add_theme_color_override("font_color", C_TEXT)
	_power_zone_label.visible = false
	_shot_layer.add_child(_power_zone_label)

	# Instruction
	_shot_instruction = Label.new()
	_shot_instruction.text = "Press SPACE\nor TAP to shoot!"
	_shot_instruction.position = Vector2(1100, 510)
	_shot_instruction.add_theme_font_size_override("font_size", 20)
	_shot_instruction.add_theme_color_override("font_color", C_TEXT)
	_shot_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shot_instruction.visible = false
	_shot_layer.add_child(_shot_instruction)

func _build_overlay() -> void:
	_overlay_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.corner_radius_top_left    = 20
	style.corner_radius_top_right   = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right= 20
	_overlay_panel.add_theme_stylebox_override("panel", style)
	_overlay_panel.custom_minimum_size = Vector2(600, 180)
	_overlay_panel.position = Vector2(340, 260)
	_overlay_panel.visible = false
	_overlay_layer.add_child(_overlay_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_overlay_panel.add_child(vbox)

	_overlay_winner = Label.new()
	_overlay_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_winner.add_theme_font_size_override("font_size", 42)
	_overlay_winner.add_theme_color_override("font_color", C_ORANGE)
	vbox.add_child(_overlay_winner)

	_overlay_answer = Label.new()
	_overlay_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_answer.add_theme_font_size_override("font_size", 20)
	_overlay_answer.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	vbox.add_child(_overlay_answer)

# ─────────────────────────────────────────────────────────────────────────────
# NETWORK SIGNAL CONNECTIONS
# ─────────────────────────────────────────────────────────────────────────────
func _connect_network_signals() -> void:
	NetworkManager.round_started.connect(_on_round_start)
	NetworkManager.answer_resulted.connect(_on_answer_result)
	NetworkManager.possession_granted.connect(_on_possession_granted)
	NetworkManager.shot_resulted.connect(_on_shot_result)
	NetworkManager.score_updated.connect(_on_score_update)
	NetworkManager.match_ended.connect(_on_match_end)
	NetworkManager.opponent_left.connect(_on_opponent_left)

# ─────────────────────────────────────────────────────────────────────────────
# MATCH START
# ─────────────────────────────────────────────────────────────────────────────
func _begin_match() -> void:
	if GameState.game_mode == "solo":
		_start_solo_round()
	else:
		# Server will send round_start; just wait
		_set_state(State.WAITING)
		NetworkManager.send_player_ready()

# ─────────────────────────────────────────────────────────────────────────────
# ROUND MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _on_round_start(data: Dictionary) -> void:
	var seed: int  = data.get("problem_seed", 42)
	var round_num: int = data.get("round_number", 1)
	_start_round(seed, round_num)

func _start_solo_round() -> void:
	GameState.round_number += 1
	var seed := randi()
	var round_num := GameState.round_number
	_start_round(seed, round_num)
	# Schedule CPU answer
	var cpu_delay: float
	match GameState.current_tier:
		"pro":      cpu_delay = randf_range(3.5, 8.0)
		"all_star": cpu_delay = randf_range(5.0, 12.0)
		"rookie":   cpu_delay = randf_range(2.0, 5.0)
		_:          cpu_delay = randf_range(4.0, 9.0)
	_cpu_think_time = cpu_delay
	_cpu_timer = 0.0

func _start_round(seed: int, round_num: int) -> void:
	GameState.round_number = round_num
	GameState.current_problem = MathEngine.generate(seed, GameState.current_tier)
	GameState.has_possession   = false
	_hint_shown = false
	_round_timer = ROUND_TIME

	_update_round_label()
	_display_problem(GameState.current_problem)

	_answer_input.text = ""
	_answer_input.editable = true
	_answer_input.grab_focus()
	_feedback_label.text = ""
	_feedback_label.visible = false
	_hide_shot_mechanic()
	_hot_streak_label.visible = GameState.is_hot_streak()

	GameState.start_answer_timer()
	_set_state(State.ANSWERING)
	AudioManager.play_music("game")

func _display_problem(problem: Dictionary) -> void:
	if problem.get("display_type") == "fraction":
		_problem_label.visible = false
		_fraction_display.visible = true
		var fd: Dictionary = problem.get("fraction_data", {})
		_frac_n1.text = str(fd.get("n1", "?"))
		_frac_d1.text = str(fd.get("d1", "?"))
		_frac_op.text = " + "
		_frac_n2.text = str(fd.get("n2", "?"))
		_frac_d2.text = str(fd.get("d2", "?"))
	else:
		_fraction_display.visible = false
		_problem_label.visible    = true
		_problem_label.text = problem.get("question", "?")

func _update_round_label() -> void:
	var extra := "  •  SUDDEN DEATH" if GameState.in_sudden_death else ""
	_round_label.text = "ROUND %d / %d%s" % [GameState.round_number, GameState.max_rounds, extra]

# ─────────────────────────────────────────────────────────────────────────────
# ANSWER INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _on_answer_submitted(text: String) -> void:
	if _state != State.ANSWERING:
		return
	var trimmed := text.strip_edges()
	if trimmed == "":
		return

	GameState.total_count += 1

	if GameState.game_mode == "solo":
		_handle_solo_answer(trimmed)
	else:
		# Send to server; server determines winner
		NetworkManager.submit_answer(trimmed, GameState.round_number)
		# Local pre-check for feedback only
		if not MathEngine.validate(trimmed, GameState.current_problem):
			_show_wrong_feedback()
			_answer_input.text = ""
		# If correct, server will respond with answer_result

func _handle_solo_answer(answer: String) -> void:
	if MathEngine.validate(answer, GameState.current_problem):
		GameState.correct_count += 1
		GameState.consecutive_first_answers += 1
		var elapsed := GameState.stop_answer_timer()
		_answer_input.editable = false
		_cpu_timer = 9999.0  # cancel CPU
		_grant_possession_to(1)  # player always wins in solo if correct
	else:
		_show_wrong_feedback()
		_answer_input.text = ""

func _show_wrong_feedback() -> void:
	AudioManager.play_sfx("wrong")
	_feedback_label.text = "❌ Try again!"
	_feedback_label.add_theme_color_override("font_color", C_RED)
	_feedback_label.visible = true
	if not GameState.settings.get("reduced_motion", false):
		var tween := create_tween()
		tween.tween_property(_answer_input, "position:x", _answer_input.position.x + 10, 0.05)
		tween.tween_property(_answer_input, "position:x", _answer_input.position.x - 10, 0.05)
		tween.tween_property(_answer_input, "position:x", _answer_input.position.x, 0.05)

# ─────────────────────────────────────────────────────────────────────────────
# ANSWER RESULT (server / solo)
# ─────────────────────────────────────────────────────────────────────────────
func _on_answer_result(data: Dictionary) -> void:
	var winner_id: String = data.get("winner_id", "")
	var correct_answer: String = str(data.get("correct_answer", ""))
	var is_my_win := (winner_id == NetworkManager.get_player_id())

	if is_my_win:
		GameState.correct_count += 1
		GameState.consecutive_first_answers += 1
		GameState.stop_answer_timer()
	else:
		GameState.consecutive_first_answers = 0

	_answer_input.editable = false
	_feedback_label.visible = false

func _on_possession_granted(data: Dictionary) -> void:
	var pid: String = data.get("player_id", "")
	var is_me := (pid == NetworkManager.get_player_id())
	_grant_possession_to(1 if is_me else 2)

func _grant_possession_to(slot: int) -> void:
	GameState.has_possession = (slot == GameState.my_player_slot or GameState.game_mode == "solo")
	if slot == 1:
		AudioManager.play_sfx("correct")
		_ball.position = BALL_IDLE_P1
	else:
		_ball.position = BALL_IDLE_P2

	if GameState.has_possession:
		_start_shot_phase()
	else:
		_set_state(State.SHOT_PHASE)

# ─────────────────────────────────────────────────────────────────────────────
# SHOT MECHANIC
# ─────────────────────────────────────────────────────────────────────────────
func _start_shot_phase() -> void:
	_set_state(State.SHOT_PHASE)
	_power = 0.0
	_power_dir = 1.0
	_shot_timer = SHOT_WINDOW
	_show_shot_mechanic()

func _show_shot_mechanic() -> void:
	_power_bar_bg.visible = true
	_power_zone_label.visible = true
	_shot_instruction.visible = true

func _hide_shot_mechanic() -> void:
	_power_bar_bg.visible = false
	_power_zone_label.visible = false
	_shot_instruction.visible = false

func _update_power_bar() -> void:
	var fill_h: float = _power * 300.0
	_power_bar_fill.size  = Vector2(54, fill_h)
	_power_bar_fill.position = Vector2(0, 340.0 - fill_h)

	# Colour by zone
	if _power >= 0.85:
		_power_bar_fill.color = C_GREEN
		_power_zone_label.text = "🟢 PERFECT!"
	elif _power >= 0.65:
		_power_bar_fill.color = C_YELLOW
		_power_zone_label.text = "🟡 GOOD"
	elif _power >= 0.40:
		_power_bar_fill.color = Color(1.0, 0.55, 0.0)
		_power_zone_label.text = "🟠 RISKY"
	else:
		_power_bar_fill.color = C_RED
		_power_zone_label.text = "🔴 TOO WEAK"

func _release_shot() -> void:
	if GameState.game_mode == "online":
		NetworkManager.release_shot(_power)
	else:
		_resolve_solo_shot(_power)
	_hide_shot_mechanic()

func _resolve_solo_shot(power: float) -> void:
	var scored := false
	var points := 0
	if power >= 0.85:
		scored = true; points = 3
	elif power >= 0.65:
		scored = (randf() < 0.80); points = 2
	elif power >= 0.40:
		scored = (randf() < 0.40); points = 1
	else:
		scored = false; points = 0

	_animate_shot(power, scored)
	await get_tree().create_timer(_ball_anim_dur + 0.3).timeout

	if scored:
		GameState.p1_score += points
		AudioManager.play_sfx("score")
	else:
		AudioManager.play_sfx("miss")

	_update_score_display()
	_end_round()

func _on_shot_result(data: Dictionary) -> void:
	var scored: bool  = data.get("scored", false)
	var power: float  = data.get("power", 0.5)
	var pts: int      = data.get("points_awarded", 0)
	_animate_shot(power, scored)

func _on_score_update(data: Dictionary) -> void:
	GameState.p1_score = data.get("p1_score", 0)
	GameState.p2_score = data.get("p2_score", 0)
	_update_score_display()
	await get_tree().create_timer(0.8).timeout
	_end_round()

# ─────────────────────────────────────────────────────────────────────────────
# BALL ANIMATION
# ─────────────────────────────────────────────────────────────────────────────
func _animate_shot(power: float, scored: bool) -> void:
	_ball_scored = scored
	_ball_start  = _ball.position
	_ball_end    = HOOP_POS + Vector2(0, 30) if scored else HOOP_POS + Vector2(80, 60)
	var peak_x   = (_ball_start.x + _ball_end.x) * 0.5
	var peak_y   = min(_ball_start.y, _ball_end.y) - 220.0 - power * 80.0
	_ball_peak   = Vector2(peak_x, peak_y)
	_ball_anim_t = 0.0
	AudioManager.play_sfx("shoot")

# ─────────────────────────────────────────────────────────────────────────────
# ROUND END
# ─────────────────────────────────────────────────────────────────────────────
func _end_round() -> void:
	_set_state(State.ROUND_END)
	_show_round_overlay()

func _show_round_overlay() -> void:
	var my_pts := GameState.p1_score if GameState.my_player_slot == 1 else GameState.p2_score
	var opp_pts := GameState.p2_score if GameState.my_player_slot == 1 else GameState.p1_score

	if GameState.has_possession:
		_overlay_winner.text = "🏀 You scored!"
		_overlay_winner.add_theme_color_override("font_color", C_GREEN)
	else:
		_overlay_winner.text = "🏀 Opponent scored"
		_overlay_winner.add_theme_color_override("font_color", C_BLUE)

	_overlay_answer.text = "Score: You %d – %d Them  •  Correct: %s" % [
		my_pts, opp_pts,
		str(GameState.current_problem.get("answer_str", ""))
	]
	_overlay_panel.visible = true

	await get_tree().create_timer(ROUND_END_PAUSE).timeout
	_overlay_panel.visible = false

	if GameState.round_number >= GameState.max_rounds:
		_finish_match()
	elif GameState.game_mode == "solo":
		_start_solo_round()
	# else: server sends next round_start

func _update_score_display() -> void:
	_p1_score_label.text = str(GameState.p1_score)
	_p2_score_label.text = str(GameState.p2_score)
	# Pulse animation on score change
	if not GameState.settings.get("reduced_motion", false):
		for lbl in [_p1_score_label, _p2_score_label]:
			var tw := create_tween()
			tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1)
			tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2)

func _finish_match() -> void:
	_set_state(State.MATCH_END)
	GameState.add_xp(GameState.compute_match_xp())
	if GameState.did_i_win():
		GameState.win_streak += 1
	else:
		GameState.win_streak = 0
	GameState.save_persistent()
	AudioManager.stop_music()
	get_tree().change_scene_to_file("res://Scenes/MatchResults.tscn")

func _on_match_end(data: Dictionary) -> void:
	GameState.p1_score = data.get("final_scores", {}).get("p1", GameState.p1_score)
	GameState.p2_score = data.get("final_scores", {}).get("p2", GameState.p2_score)
	_finish_match()

func _on_opponent_left() -> void:
	_overlay_winner.text = "⚠ Opponent disconnected\nYou win!"
	_overlay_winner.add_theme_color_override("font_color", C_ORANGE)
	_overlay_answer.text = ""
	_overlay_panel.visible = true
	await get_tree().create_timer(2.5).timeout
	_finish_match()

# ─────────────────────────────────────────────────────────────────────────────
# PROCESS LOOP
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Ball animation
	if _ball_anim_t >= 0.0:
		_ball_anim_t += delta / _ball_anim_dur
		var t := clampf(_ball_anim_t, 0.0, 1.0)
		var p1 := _ball_start.lerp(_ball_peak, t)
		var p2 := _ball_peak.lerp(_ball_end, t)
		_ball.position = p1.lerp(p2, t)
		_ball.rotation = t * TAU * 1.5
		if _ball_anim_t >= 1.0:
			_ball_anim_t = -1.0
			if _ball_scored:
				AudioManager.play_sfx("score")
			else:
				AudioManager.play_sfx("miss")
	else:
		# Idle bob
		_ball_idle_t += delta
		_ball.position.y = _ball.position.y + sin(_ball_idle_t * 3.0) * 0.3

	match _state:
		State.ANSWERING:
			_process_answering(delta)
		State.SHOT_PHASE:
			_process_shot_phase(delta)

func _process_answering(delta: float) -> void:
	_round_timer -= delta
	_timer_bar.value = _round_timer

	# Timer bar colour
	if _round_timer < 8.0:
		_timer_bar.modulate = C_RED
	elif _round_timer < 15.0:
		_timer_bar.modulate = C_YELLOW
	else:
		_timer_bar.modulate = C_GREEN

	# Hint at 15s
	if _round_timer <= HINT_TIME and not _hint_shown:
		_hint_shown = true
		_show_hint()

	# Round timeout
	if _round_timer <= 0.0:
		_on_round_timeout()

	# CPU opponent logic (solo)
	if GameState.game_mode == "solo" and _state == State.ANSWERING:
		_cpu_timer += delta
		if _cpu_timer >= _cpu_think_time:
			_cpu_timer = 9999.0
			_cpu_answers()

func _show_hint() -> void:
	# Show "Not X" for one wrong answer
	var problem := GameState.current_problem
	var wrong := int(problem.get("answer", 0)) + randi_range(1, 5)
	_feedback_label.text = "💡 Hint: answer ≠ %d" % wrong
	_feedback_label.add_theme_color_override("font_color", C_YELLOW)
	_feedback_label.visible = true

func _on_round_timeout() -> void:
	# No shot awarded
	_answer_input.editable = false
	_overlay_winner.text = "⏱ Time's up! No shot."
	_overlay_winner.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	_overlay_answer.text = "Correct answer: " + str(GameState.current_problem.get("answer_str", "?"))
	_overlay_panel.visible = true
	_end_round()

func _process_shot_phase(delta: float) -> void:
	if not GameState.has_possession:
		return
	_shot_timer -= delta
	if _shot_timer <= 0.0:
		_release_shot()  # auto-release on timeout
		return

	# Animate power bar
	_power += _power_dir * delta / POWER_CYCLE_TIME
	if _power >= 1.0:
		_power = 1.0; _power_dir = -1.0
	elif _power <= 0.0:
		_power = 0.0; _power_dir = 1.0
	_update_power_bar()

	if Input.is_action_just_pressed("shoot_ball"):
		_release_shot()

func _cpu_answers() -> void:
	# CPU takes possession
	_grant_possession_to(2)
	# CPU auto-shoots with 70% accuracy simulation
	await get_tree().create_timer(0.8).timeout
	var cpu_power := 0.0
	if randf() < 0.70:
		cpu_power = randf_range(0.65, 0.95)  # makes it
	else:
		cpu_power = randf_range(0.0, 0.38)  # misses
	_resolve_solo_shot(cpu_power)  # uses p2 perspective — handled in resolve

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _set_state(s: State) -> void:
	_state = s

func _make_emoji(emoji: String, sz: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = emoji
	l.add_theme_font_size_override("font_size", sz)
	l.position = pos - Vector2(sz / 2, sz / 2)
	add_child(l)
	return l
