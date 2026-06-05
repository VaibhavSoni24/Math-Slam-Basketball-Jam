extends Node
## Procedural audio manager — synthesises all SFX and music at runtime
## using AudioStreamWAV. No external audio files required.

const SAMPLE_RATE := 22050

var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_bus: String = "Master"

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_build_sfx_cache()
	_apply_volumes()

func _apply_volumes() -> void:
	var mv: float = GameState.settings.get("music_volume", 0.7)
	var sv: float = GameState.settings.get("sfx_volume", 1.0)
	_music_player.volume_db = linear_to_db(mv)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(sv))

# ─── Public API ───────────────────────────────────────────────────────────────
func play_sfx(name: String) -> void:
	if not _sfx_cache.has(name):
		push_warning("[AudioManager] Unknown sfx: " + name)
		return
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = _sfx_cache[name]
	p.volume_db = linear_to_db(GameState.settings.get("sfx_volume", 1.0))
	p.play()
	p.finished.connect(p.queue_free)

func play_music(track: String) -> void:
	var stream: AudioStreamWAV
	match track:
		"menu": stream = _gen_menu_music()
		"game": stream = _gen_game_music()
		_: return
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(GameState.settings.get("music_volume", 0.7))
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_music_volume(linear: float) -> void:
	_music_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))

func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clampf(linear, 0.0, 1.0)))

func refresh_settings() -> void:
	_apply_volumes()

# ─── SFX catalogue ────────────────────────────────────────────────────────────
func _build_sfx_cache() -> void:
	_sfx_cache["correct"]   = _gen_tone_env(880.0, 0.25, "sine",   [0.0, 0.02, 0.10, 0.25], [0.0, 1.0, 0.8, 0.0])
	_sfx_cache["wrong"]     = _gen_buzz(0.25)
	_sfx_cache["shoot"]     = _gen_sweep(700.0, 180.0, 0.30)
	_sfx_cache["score"]     = _gen_fanfare()
	_sfx_cache["miss"]      = _gen_tone_env(200.0, 0.30, "sine",   [0.0, 0.02, 0.15, 0.30], [0.0, 0.7, 0.4, 0.0])
	_sfx_cache["countdown"] = _gen_tone_env(660.0, 0.12, "sine",   [0.0, 0.01, 0.06, 0.12], [0.0, 1.0, 0.9, 0.0])
	_sfx_cache["final_tick"]= _gen_tone_env(880.0, 0.18, "sine",   [0.0, 0.01, 0.10, 0.18], [0.0, 1.0, 0.9, 0.0])
	_sfx_cache["powerbar"]  = _gen_sweep(300.0, 900.0, 1.5)
	_sfx_cache["win"]       = _gen_fanfare()
	_sfx_cache["ui_click"]  = _gen_tone_env(440.0, 0.08, "sine",   [0.0, 0.005, 0.04, 0.08], [0.0, 0.9, 0.6, 0.0])

# ─── Waveform helpers ─────────────────────────────────────────────────────────

func _gen_tone_env(freq: float, dur: float, shape: String,
				   env_times: Array[float], env_vals: Array[float]) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var wave: float
		match shape:
			"sine":   wave = sin(TAU * freq * t)
			"square": wave = 1.0 if sin(TAU * freq * t) > 0.0 else -1.0
			"saw":    wave = 2.0 * fmod(freq * t, 1.0) - 1.0
			_:        wave = sin(TAU * freq * t)
		var env := _sample_envelope(t / dur, env_times, env_vals)
		var s := int(wave * env * 14000.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(data)

func _gen_buzz(dur: float) -> AudioStreamWAV:
	return _gen_tone_env(110.0, dur, "square", [0.0, 0.01, 0.15, dur], [0.0, 0.8, 0.6, 0.0])

func _gen_sweep(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var prog: float = t / dur
		var freq := lerpf(f0, f1, prog)
		var wave := sin(TAU * freq * t)
		var env := 1.0
		if prog < 0.05: env = prog / 0.05
		elif prog > 0.90: env = (1.0 - prog) / 0.10
		var s := int(wave * env * 11000.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(data)

func _gen_fanfare() -> AudioStreamWAV:
	# C–E–G–C' arpeggio
	var note_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var note_dur := 0.13
	var total := note_dur * note_freqs.size()
	var n := int(SAMPLE_RATE * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var ni := int(t / note_dur)
		ni = mini(ni, note_freqs.size() - 1)
		var freq: float = note_freqs[ni]
		var nt: float = fmod(t, note_dur)
		var wave := sin(TAU * freq * t)
		var env := 1.0
		if nt < 0.01: env = nt / 0.01
		elif nt > note_dur - 0.03: env = (note_dur - nt) / 0.03
		var s := int(wave * env * 13000.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(data)

func _gen_menu_music() -> AudioStreamWAV:
	var bpm := 110.0
	var beat := 60.0 / bpm
	# Pentatonic scale C4
	var notes: Array[float] = [523.25, 659.25, 783.99, 880.0, 1046.50, 880.0, 783.99, 659.25]
	var total := beat * notes.size()
	var n := int(SAMPLE_RATE * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var ni := int(t / beat) % notes.size()
		var freq: float = notes[ni]
		var nt: float = fmod(t, beat)
		var wave := 0.5 * sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t)
		var env := 1.0
		if nt < 0.01: env = nt / 0.01
		elif nt > beat - 0.05: env = (beat - nt) / 0.05
		var s := int(wave * env * 7000.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := _make_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

func _gen_game_music() -> AudioStreamWAV:
	var bpm := 140.0
	var beat := 60.0 / bpm
	var notes: Array[float] = [783.99, 880.0, 783.99, 659.25, 783.99, 880.0, 1046.50, 880.0]
	var total := beat * notes.size()
	var n := int(SAMPLE_RATE * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / SAMPLE_RATE
		var ni := int(t / beat) % notes.size()
		var freq: float = notes[ni]
		var nt: float = fmod(t, beat)
		var wave := sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 0.5 * t) * 0.3
		var env := 1.0
		if nt < 0.01: env = nt / 0.01
		elif nt > beat - 0.03: env = (beat - nt) / 0.03
		var s := int(wave * env * 7000.0)
		s = clampi(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := _make_wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

# ─── Utilities ────────────────────────────────────────────────────────────────

func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _sample_envelope(t_norm: float, times: Array[float], vals: Array[float]) -> float:
	# t_norm is 0..1 within total duration
	if times.is_empty(): return 1.0
	if t_norm <= times[0]: return vals[0]
	if t_norm >= times[-1]: return vals[-1]
	for i in range(1, times.size()):
		if t_norm <= times[i]:
			var seg: float = (t_norm - times[i-1]) / (times[i] - times[i-1])
			return lerpf(vals[i-1], vals[i], seg)
	return vals[-1]
