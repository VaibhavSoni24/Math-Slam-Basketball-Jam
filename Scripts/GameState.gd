extends Node
## Global game state singleton — persists across all scene changes.
## Tracks match data, session stats, player prefs, and XP.

# ─── Match state ──────────────────────────────────────────────────────────────
var game_mode: String = "online"        ## "online" | "solo"
var matchmaking_mode: String = "quick"  ## "quick" | "friend"
var my_player_slot: int = 1            ## 1 or 2
var opponent_name: String = "Opponent"
var current_tier: String = "pro"
var round_number: int = 0
var max_rounds: int = 6
var p1_score: int = 0
var p2_score: int = 0
var current_problem: Dictionary = {}
var has_possession: bool = false
var in_sudden_death: bool = false

# ─── Session statistics ───────────────────────────────────────────────────────
var correct_count: int = 0
var total_count: int = 0
var fastest_time_ms: float = INF
var answer_start_time_ms: float = 0.0
var consecutive_first_answers: int = 0
var win_streak: int = 0

# ─── Persistent data (saved to disk) ─────────────────────────────────────────
var player_name: String = "Player"
var total_xp: int = 0
var personal_bests: Dictionary = {}   ## tier_name -> fastest_ms (float)
var settings: Dictionary = {
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"larger_text": false,
	"reduced_motion": false,
	"high_contrast": false,
	"colorblind_mode": false,
	"server_url": "ws://localhost:3000"
}

const SAVE_PATH := "user://mathslam_save.cfg"

# ─── Signals ──────────────────────────────────────────────────────────────────
signal xp_changed(new_total: int)
signal settings_changed()

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	load_persistent()

# ─── Match helpers ────────────────────────────────────────────────────────────
func start_new_match() -> void:
	round_number = 0
	p1_score = 0
	p2_score = 0
	correct_count = 0
	total_count = 0
	fastest_time_ms = INF
	consecutive_first_answers = 0
	has_possession = false
	in_sudden_death = false
	current_problem = {}

func start_answer_timer() -> void:
	answer_start_time_ms = Time.get_ticks_msec()

func stop_answer_timer() -> float:
	var elapsed: float = Time.get_ticks_msec() - answer_start_time_ms
	if elapsed < fastest_time_ms:
		fastest_time_ms = elapsed
	if not personal_bests.has(current_tier) or elapsed < personal_bests[current_tier]:
		personal_bests[current_tier] = elapsed
		save_persistent()
	return elapsed

func get_accuracy() -> float:
	if total_count == 0:
		return 0.0
	return float(correct_count) / float(total_count)

func is_hot_streak() -> bool:
	return consecutive_first_answers >= 3

func my_score() -> int:
	return p1_score if my_player_slot == 1 else p2_score

func opponent_score() -> int:
	return p2_score if my_player_slot == 1 else p1_score

func did_i_win() -> bool:
	return my_score() > opponent_score()

# ─── XP ───────────────────────────────────────────────────────────────────────
func add_xp(amount: int) -> void:
	total_xp += amount
	save_persistent()
	xp_changed.emit(total_xp)

func compute_match_xp() -> int:
	var xp := 0
	if did_i_win():
		xp += 10
	else:
		xp += 5
	if get_accuracy() >= 1.0:
		xp += 3
	return xp

# ─── Persistence ──────────────────────────────────────────────────────────────
func save_persistent() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "xp", total_xp)
	cfg.set_value("player", "tier", current_tier)
	cfg.set_value("player", "personal_bests", personal_bests)
	cfg.set_value("player", "win_streak", win_streak)
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SAVE_PATH)

func load_persistent() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_name = cfg.get_value("player", "name", "Player")
	total_xp = cfg.get_value("player", "xp", 0)
	current_tier = cfg.get_value("player", "tier", "pro")
	personal_bests = cfg.get_value("player", "personal_bests", {})
	win_streak = cfg.get_value("player", "win_streak", 0)
	for key in settings:
		settings[key] = cfg.get_value("settings", key, settings[key])
