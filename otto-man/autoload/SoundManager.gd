extends Node
## SFX: önce `assets/audio/` dosyası, yoksa sentez placeholder.
## Asset değiştirmek için bkz. `assets/audio/PLACEHOLDER.md`

const SoundCatalog = preload("res://autoload/SoundCatalog.gd")

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const POOL_SIZE := 10

var master_volume_db: float = 0.0
var music_volume_db: float = 0.0
var sfx_volume_db: float = 0.0

var _streams: Dictionary = {}
var _stream_source: Dictionary = {} # id -> "file" | "synth"
var _ui_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer2D] = []
var _pool_index: int = 0
var _hurt_cooldown_sec: float = 0.0
var _combat_hit_cooldown_sec: float = 0.0
var _enabled: bool = true
var _current_music_id: String = ""
var _light_attack_pitch_step: int = 0

const LIGHT_ATTACK_PITCH_MIN: float = 0.88
const LIGHT_ATTACK_PITCH_MAX: float = 1.14
const LIGHT_ATTACK_PITCH_STEPS: int = 6
const HEAVY_ATTACK_PITCH_MIN: float = 0.52
const HEAVY_ATTACK_PITCH_MAX: float = 0.68

const _SYNTH_DEFS: Dictionary = {
	"click": {"hz": 920.0, "duration": 0.05, "volume": 0.22, "slide_hz": 0.0, "wave": "sine"},
	"confirm": {"hz": 660.0, "duration": 0.07, "volume": 0.24, "slide_hz": 120.0, "wave": "sine"},
	"cancel": {"hz": 340.0, "duration": 0.08, "volume": 0.2, "slide_hz": -80.0, "wave": "triangle"},
	"hurt": {"hz": 220.0, "duration": 0.11, "volume": 0.38, "slide_hz": -140.0, "wave": "triangle"},
	"death": {"hz": 130.0, "duration": 0.55, "volume": 0.42, "slide_hz": -90.0, "wave": "sine"},
	"door_open": {"hz": 280.0, "duration": 0.22, "volume": 0.32, "slide_hz": 420.0, "wave": "square"},
	"door_locked": {"hz": 160.0, "duration": 0.08, "volume": 0.28, "slide_hz": -60.0, "wave": "square"},
	"hit_light": {"hz": 400.0, "duration": 0.06, "volume": 0.3, "slide_hz": -200.0, "wave": "square"},
	"block": {"hz": 180.0, "duration": 0.09, "volume": 0.35, "slide_hz": 0.0, "wave": "triangle"},
	"pickup": {"hz": 780.0, "duration": 0.09, "volume": 0.26, "slide_hz": 200.0, "wave": "sine"},
	"build_complete": {"hz": 520.0, "duration": 0.18, "volume": 0.3, "slide_hz": 180.0, "wave": "sine"},
	"attack_swipe": {"hz": 540.0, "duration": 0.09, "volume": 0.3, "slide_hz": -220.0, "wave": "triangle"},
	"footstep_player": {"hz": 95.0, "duration": 0.04, "volume": 0.18, "slide_hz": -40.0, "wave": "triangle"},
	"attack_light": {"hz": 540.0, "duration": 0.09, "volume": 0.3, "slide_hz": -220.0, "wave": "triangle"},
	"attack_heavy": {"hz": 165.0, "duration": 0.16, "volume": 0.42, "slide_hz": -45.0, "wave": "square"},
}


func _ready() -> void:
	_ensure_audio_buses()
	reload_audio()
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiSfxPlayer"
	_ui_player.bus = SFX_BUS
	add_child(_ui_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.name = "SfxPool_%d" % i
		p.bus = SFX_BUS
		p.max_distance = 2800.0
		p.attenuation = 1.0
		add_child(p)
		_pool.append(p)
	_apply_saved_volume_from_settings()
	_log_audio_status()


func _process(delta: float) -> void:
	if _hurt_cooldown_sec > 0.0:
		_hurt_cooldown_sec = maxf(0.0, _hurt_cooldown_sec - delta)
	if _combat_hit_cooldown_sec > 0.0:
		_combat_hit_cooldown_sec = maxf(0.0, _combat_hit_cooldown_sec - delta)


func set_enabled(on: bool) -> void:
	_enabled = on


func reload_audio() -> void:
	_streams.clear()
	_stream_source.clear()
	for sound_id in SoundCatalog.list_sfx_ids():
		_register_sfx(String(sound_id))
	_log_audio_status()


func get_audio_status() -> Dictionary:
	var file_count: int = 0
	var synth_count: int = 0
	for id in _stream_source.keys():
		if _stream_source[id] == "file":
			file_count += 1
		else:
			synth_count += 1
	return {
		"file_count": file_count,
		"synth_count": synth_count,
		"sources": _stream_source.duplicate(true),
	}


func play_ui(sound_id: String, pitch_scale: float = 1.0) -> void:
	_play_id(sound_id, Vector2.ZERO, true, pitch_scale)


func play_sfx(sfx_id: String, position: Vector2 = Vector2.ZERO, pitch_scale: float = 1.0) -> void:
	if sfx_id == "hurt" and _hurt_cooldown_sec > 0.0:
		return
	if sfx_id == "hurt":
		_hurt_cooldown_sec = 0.14
	_play_id(sfx_id, position, false, pitch_scale)


## Oyuncu saldırı whoosh — `combat_swipe`; light/heavy için pitch farkı.
func play_player_attack_swing(is_heavy: bool, position: Vector2 = Vector2.ZERO) -> void:
	if not _enabled:
		return
	var pitch: float
	if is_heavy:
		pitch = randf_range(HEAVY_ATTACK_PITCH_MIN, HEAVY_ATTACK_PITCH_MAX)
	else:
		var t: float = float(_light_attack_pitch_step) / float(maxi(1, LIGHT_ATTACK_PITCH_STEPS - 1))
		_light_attack_pitch_step = (_light_attack_pitch_step + 1) % LIGHT_ATTACK_PITCH_STEPS
		pitch = lerpf(LIGHT_ATTACK_PITCH_MAX, LIGHT_ATTACK_PITCH_MIN, t)
		pitch += randf_range(-0.035, 0.035)
		pitch = clampf(pitch, 0.82, 1.2)
	play_sfx("attack_swipe", position, pitch)


func play_footstep(position: Vector2, pitch_scale: float = 1.0) -> void:
	play_sfx("footstep_player", position, pitch_scale)


## İsabet — swipe sesine ek; `combat_hit_light` dosyası.
func play_combat_hit(position: Vector2 = Vector2.ZERO, is_heavy: bool = false) -> void:
	if not _enabled or _combat_hit_cooldown_sec > 0.0:
		return
	_combat_hit_cooldown_sec = 0.05
	var pitch: float = randf_range(0.93, 1.07)
	if is_heavy:
		pitch *= 0.88
	play_sfx("hit_light", position, pitch)


func play_music(track_id: String, loop := true) -> void:
	if not _enabled:
		return
	if track_id == _current_music_id and _music_player.playing:
		return
	var path: String = SoundCatalog.resolve_music_path(track_id)
	if path.is_empty():
		return
	var stream: Resource = load(path)
	if not stream is AudioStream:
		return
	_music_player.stream = stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	_current_music_id = track_id
	_music_player.play()


func stop_music() -> void:
	_current_music_id = ""
	if is_instance_valid(_music_player):
		_music_player.stop()


func set_master_volume_db(db: float) -> void:
	master_volume_db = db
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func set_music_volume_db(db: float) -> void:
	music_volume_db = db
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db
	var idx := AudioServer.get_bus_index(SFX_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func _register_sfx(sound_id: String) -> void:
	var path: String = SoundCatalog.resolve_sfx_path(sound_id)
	if not path.is_empty():
		var loaded: Resource = load(path)
		if loaded is AudioStream:
			_streams[sound_id] = loaded
			_stream_source[sound_id] = "file"
			return
	var def: Dictionary = _SYNTH_DEFS.get(sound_id, _SYNTH_DEFS.get("click", {}))
	if def.is_empty():
		push_warning("[SoundManager] Unknown sfx id: %s" % sound_id)
		return
	_streams[sound_id] = _synthesize(def)
	_stream_source[sound_id] = "synth"


func _play_id(sound_id: String, position: Vector2, ui_channel: bool, pitch_scale: float = 1.0) -> void:
	if not _enabled:
		return
	if not _streams.has(sound_id):
		_register_sfx(sound_id)
	var stream: AudioStream = _streams.get(sound_id, null)
	if stream == null:
		return
	var pitch: float = clampf(pitch_scale, 0.05, 4.0)
	if ui_channel or position == Vector2.ZERO:
		_ui_player.pitch_scale = pitch
		_ui_player.stream = stream
		_ui_player.play()
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.pitch_scale = pitch
	player.global_position = position
	player.stream = stream
	player.play()


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var sfx_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, SFX_BUS)
		var master_idx := AudioServer.get_bus_index("Master")
		if master_idx >= 0:
			AudioServer.set_bus_send(sfx_idx, "Master")
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var music_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, MUSIC_BUS)
		var master_idx2 := AudioServer.get_bus_index("Master")
		if master_idx2 >= 0:
			AudioServer.set_bus_send(music_idx, "Master")


func _synthesize(def: Dictionary) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = maxf(0.03, float(def.get("duration", 0.1)))
	var base_hz: float = float(def.get("hz", 440.0))
	var slide_hz: float = float(def.get("slide_hz", 0.0))
	var volume: float = clampf(float(def.get("volume", 0.3)), 0.01, 1.0)
	var wave: String = String(def.get("wave", "sine"))
	var sample_count: int = maxi(1, int(sample_rate * duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(maxi(1, sample_count - 1))
		var hz: float = base_hz + slide_hz * progress
		var envelope: float = (1.0 - progress) * (1.0 - progress * 0.35)
		var phase: float = TAU * hz * t
		var sample: float = 0.0
		match wave:
			"square":
				sample = 1.0 if fmod(phase, TAU) < PI else -1.0
			"triangle":
				var p := fmod(phase, TAU) / TAU
				sample = 4.0 * abs(p - 0.5) - 1.0
			_:
				sample = sin(phase)
		sample *= envelope * volume
		var s16: int = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _apply_saved_volume_from_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return
	var master_pct: int = int(config.get_value("audio", "master_volume", 100))
	var music_pct: int = int(config.get_value("audio", "music_volume", 80))
	var sfx_pct: int = int(config.get_value("audio", "sfx_volume", 100))
	set_master_volume_db(_percent_to_db(master_pct))
	set_music_volume_db(_percent_to_db(music_pct))
	set_sfx_volume_db(_percent_to_db(sfx_pct))


func _log_audio_status() -> void:
	var status: Dictionary = get_audio_status()
	print(
		"[SoundManager] Ready — %d file asset(s), %d synth fallback(s). See assets/audio/PLACEHOLDER.md"
		% [int(status.get("file_count", 0)), int(status.get("synth_count", 0))]
	)


func _percent_to_db(percent: int) -> float:
	var clamped: int = clampi(percent, 0, 100)
	if clamped <= 0:
		return -80.0
	return linear_to_db(float(clamped) / 100.0)
