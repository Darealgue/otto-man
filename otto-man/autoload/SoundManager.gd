extends Node
## SFX: önce `assets/audio/` dosyası, yoksa sentez placeholder.

const SoundCatalog = preload("res://autoload/SoundCatalog.gd")
const AudioPlaceholderTones = preload("res://tools/audio_placeholder_tones.gd")
const ForestNightLightUtil = preload("res://decoration/forest/forest_night_light_util.gd")

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const POOL_SIZE := 10

var master_volume_db: float = 0.0
var music_volume_db: float = 0.0
var sfx_volume_db: float = 0.0

var _streams: Dictionary = {}
var _stream_source: Dictionary = {}
var _ui_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _loop_sfx_player: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer2D] = []
var _pool_index: int = 0
var _hurt_cooldown_sec: float = 0.0
var _combat_hit_cooldown_sec: float = 0.0
var _enabled: bool = true
var _current_music_id: String = ""
var _current_ambient_id: String = ""
## Bu run için seçilen parça. Profilden çıkılınca sıfırlanır, tekrar girişte yeniden seçilir.
var _run_music_id: String = ""
## Üst üste aynı parçayı seçmemek için son run'ın parçası.
var _last_run_music_id: String = ""
var _ambient_profile: String = ""
var _ambient_is_night: bool = false
var _loop_sfx_id: String = ""
var _music_should_loop: bool = false
var _ambient_should_loop: bool = false
## Çalan parçanın özel loop noktası; _music_loop_end 0.0 ise dosya sonuna kadar çalar.
var _music_loop_start: float = 0.0
var _music_loop_end: float = 0.0
var _fade_tweens: Dictionary = {}
var _light_attack_pitch_step: int = 0

const LIGHT_ATTACK_PITCH_MIN: float = 0.88
const LIGHT_ATTACK_PITCH_MAX: float = 1.14
const LIGHT_ATTACK_PITCH_STEPS: int = 6
const HEAVY_ATTACK_PITCH_MIN: float = 0.52
const HEAVY_ATTACK_PITCH_MAX: float = 0.68
const AMBIENT_VOLUME_LINEAR: float = 0.6
## Müzik yatağı: dövüş SFX'ini boğmasın diye Music bus'ın altında headroom bırakır.
const MUSIC_VOLUME_LINEAR: float = 0.7
const MUSIC_FADE_SEC: float = 1.2
const AMBIENT_FADE_SEC: float = 0.6
const FADE_SILENCE_DB: float = -40.0
const SLIDE_VOLUME_LINEAR: float = 0.6


func _ready() -> void:
	# Fade tween'leri duraklatılmış oyunda da ilerlesin.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_ui_player = _make_stream_player("UiSfxPlayer", _resolve_bus(SFX_BUS))
	_music_player = _make_stream_player("MusicPlayer", _resolve_bus(MUSIC_BUS))
	# Ambient SFX bus'ında: oyuncu müzik ile ortam sesini ayrı ayrı kısabilsin.
	_ambient_player = _make_stream_player("AmbientPlayer", _resolve_bus(SFX_BUS))
	_loop_sfx_player = _make_stream_player("LoopSfxPlayer", _resolve_bus(SFX_BUS))
	if not _music_player.finished.is_connected(_on_music_player_finished):
		_music_player.finished.connect(_on_music_player_finished)
	if not _ambient_player.finished.is_connected(_on_ambient_player_finished):
		_ambient_player.finished.connect(_on_ambient_player_finished)
	if not _loop_sfx_player.finished.is_connected(_on_loop_sfx_player_finished):
		_loop_sfx_player.finished.connect(_on_loop_sfx_player_finished)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.name = "SfxPool_%d" % i
		p.bus = _resolve_bus(SFX_BUS)
		p.max_distance = 2800.0
		p.attenuation = 1.0
		add_child(p)
		_pool.append(p)
	reload_audio()
	_apply_saved_volume_from_settings()
	_log_audio_status()
	call_deferred("_bind_ambient_listeners")


func _make_stream_player(player_name: String, bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	player.volume_db = 0.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _resolve_bus(preferred: String) -> String:
	if AudioServer.get_bus_index(preferred) >= 0:
		return preferred
	return "Master"


func _bind_ambient_listeners() -> void:
	var scene_mgr := get_node_or_null("/root/SceneManager")
	if scene_mgr and scene_mgr.has_signal("scene_change_completed"):
		if not scene_mgr.scene_change_completed.is_connected(_on_scene_change_completed):
			scene_mgr.scene_change_completed.connect(_on_scene_change_completed)
	var time_mgr := get_node_or_null("/root/TimeManager")
	if time_mgr and time_mgr.has_signal("hour_changed"):
		if not time_mgr.hour_changed.is_connected(_on_hour_changed_ambient):
			time_mgr.hour_changed.connect(_on_hour_changed_ambient)
	_bootstrap_ambient_when_ready()


func _bootstrap_ambient_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var path: String = _resolve_active_scene_path()
	if not path.is_empty():
		play_ambient_for_scene(path)


func _resolve_active_scene_path() -> String:
	var scene_mgr := get_node_or_null("/root/SceneManager")
	if scene_mgr and scene_mgr.get("current_scene_path"):
		var managed: String = String(scene_mgr.current_scene_path)
		if not managed.is_empty():
			return managed
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		return scene.scene_file_path
	return ""


func _process(delta: float) -> void:
	if _hurt_cooldown_sec > 0.0:
		_hurt_cooldown_sec = maxf(0.0, _hurt_cooldown_sec - delta)
	if _combat_hit_cooldown_sec > 0.0:
		_combat_hit_cooldown_sec = maxf(0.0, _combat_hit_cooldown_sec - delta)
	_update_music_loop_point()


## Parçanın sonundaki reverb kuyruğu + sessizliği atlayıp erken başa sarar.
## Import'taki `loop=true` emniyet ağı olarak duruyor: burası bir sebeple
## kaçırırsa parça yine de durmaz, sadece boşluk duyulur.
func _update_music_loop_point() -> void:
	if _music_loop_end <= 0.0 or not _music_should_loop:
		return
	if not is_instance_valid(_music_player) or not _music_player.playing:
		return
	if _music_player.get_playback_position() >= _music_loop_end:
		_music_player.seek(_music_loop_start)


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
	play_sfx(_footstep_sfx_id_for_scene(_resolve_active_scene_path()), position, pitch_scale)


func play_land(position: Vector2, heavy: bool = false) -> void:
	var scene_path: String = _resolve_active_scene_path()
	var sfx_id: String = _land_sfx_id_for_scene(scene_path, heavy)
	var pitch: float = 0.88 if heavy and _is_dirt_surface_scene(scene_path) else 1.0
	play_sfx(sfx_id, position, pitch)


func play_combat_hit(position: Vector2 = Vector2.ZERO, is_heavy: bool = false) -> void:
	if not _enabled or _combat_hit_cooldown_sec > 0.0:
		return
	_combat_hit_cooldown_sec = 0.05
	var pitch: float = randf_range(0.93, 1.07)
	var hit_id: String = "hit_heavy" if is_heavy else "hit_light"
	if is_heavy:
		pitch *= 0.92
	play_sfx(hit_id, position, pitch)


## Gerçek müzik parçası (Music bus). `assets/audio/music/` altından okur.
## Boş id verilirse müziği fade ile durdurur.
func play_music(track_id: String, loop := true, force_restart := false) -> void:
	if not _enabled or not is_instance_valid(_music_player):
		return
	if track_id.is_empty():
		stop_music()
		return
	if not force_restart and track_id == _current_music_id and _music_player.playing:
		return
	var path: String = SoundCatalog.resolve_music_path(track_id)
	var stream: AudioStream = _load_stream_at_path(path)
	if stream == null:
		# Müzikte sentez placeholder yok: dosya yoksa bip çalmaktansa sessiz kal.
		push_warning(
			"[SoundManager] Music asset missing for track '%s' (expected: %s%s.ogg)"
			% [track_id, SoundCatalog.MUSIC_ROOT, SoundCatalog.get_music_file_stem(track_id)]
		)
		stop_music()
		return
	_music_should_loop = loop
	_current_music_id = track_id
	_music_loop_start = SoundCatalog.get_music_loop_start(track_id)
	_music_loop_end = SoundCatalog.get_music_loop_end(track_id)
	_start_stream_with_fade(_music_player, stream, linear_to_db(MUSIC_VOLUME_LINEAR), MUSIC_FADE_SEC)
	print(
		"[SoundManager] Music play: %s | path=%s | bus=%s | loop=%.1f-%.1f sn"
		% [track_id, path, _music_player.bus, _music_loop_start, _music_loop_end]
	)


## Ortam sesi (SFX bus). `assets/audio/bgs/` altından okur, yoksa sentez placeholder.
func play_ambient(track_id: String, loop := true, force_restart := false) -> void:
	if not _enabled or not is_instance_valid(_ambient_player):
		return
	if track_id.is_empty():
		stop_ambient()
		return
	if not force_restart and track_id == _current_ambient_id and _ambient_player.playing:
		return
	var path: String = SoundCatalog.resolve_ambient_path(track_id)
	var stream: AudioStream = _load_stream_at_path(path)
	if stream == null:
		var def: Dictionary = AudioPlaceholderTones.MUSIC_STEMS.get(SoundCatalog.get_ambient_file_stem(track_id), {})
		if not def.is_empty():
			stream = _synthesize(def)
	if stream == null:
		push_warning("[SoundManager] Ambient not found for track '%s' (path: %s)" % [track_id, path])
		stop_ambient()
		return
	_ambient_should_loop = loop
	_current_ambient_id = track_id
	_start_stream_with_fade(_ambient_player, stream, linear_to_db(AMBIENT_VOLUME_LINEAR), AMBIENT_FADE_SEC)
	print(
		"[SoundManager] Ambient play: %s | path=%s | bus=%s"
		% [track_id, path if not path.is_empty() else "synth", _ambient_player.bus]
	)


func _kill_fade(player: AudioStreamPlayer) -> void:
	var key: int = player.get_instance_id()
	var t: Tween = _fade_tweens.get(key, null)
	if t != null and t.is_valid():
		t.kill()
	_fade_tweens.erase(key)


func _start_stream_with_fade(player: AudioStreamPlayer, stream: AudioStream, target_db: float, fade_sec: float) -> void:
	_kill_fade(player)
	player.stream = stream
	if fade_sec <= 0.0:
		player.volume_db = target_db
		player.play()
		return
	player.volume_db = FADE_SILENCE_DB
	player.play()
	var t: Tween = create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(player, "volume_db", target_db, fade_sec)
	_fade_tweens[player.get_instance_id()] = t


func _fade_out_and_stop(player: AudioStreamPlayer, fade_sec: float) -> void:
	_kill_fade(player)
	if not player.playing or fade_sec <= 0.0:
		player.stop()
		return
	var t: Tween = create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(player, "volume_db", FADE_SILENCE_DB, fade_sec)
	t.tween_callback(player.stop)
	_fade_tweens[player.get_instance_id()] = t


func is_loop_sfx_active(sfx_id: String) -> bool:
	return _loop_sfx_id == sfx_id and is_instance_valid(_loop_sfx_player) and _loop_sfx_player.playing


func start_loop_sfx(sfx_id: String) -> void:
	if not _enabled or not is_instance_valid(_loop_sfx_player):
		return
	if is_loop_sfx_active(sfx_id):
		return
	var stream: AudioStream = _get_sfx_stream(sfx_id)
	if stream == null:
		push_warning("[SoundManager] Loop sfx missing: %s" % sfx_id)
		return
	stop_loop_sfx()
	_loop_sfx_id = sfx_id
	_loop_sfx_player.stream = stream
	_loop_sfx_player.volume_db = _loop_sfx_volume_db(sfx_id)
	_loop_sfx_player.play()
	print("[SoundManager] Loop sfx start: %s | playing=%s" % [sfx_id, _loop_sfx_player.playing])


func stop_loop_sfx() -> void:
	_loop_sfx_id = ""
	if is_instance_valid(_loop_sfx_player):
		_loop_sfx_player.stop()
		_loop_sfx_player.volume_db = 0.0


func _loop_sfx_volume_db(sfx_id: String) -> float:
	if sfx_id == "slide":
		return linear_to_db(SLIDE_VOLUME_LINEAR)
	return 0.0


func _on_music_player_finished() -> void:
	if not _music_should_loop or _current_music_id.is_empty():
		return
	if is_instance_valid(_music_player) and _music_player.stream != null:
		_music_player.play()


func _on_ambient_player_finished() -> void:
	if not _ambient_should_loop or _current_ambient_id.is_empty():
		return
	if is_instance_valid(_ambient_player) and _ambient_player.stream != null:
		_ambient_player.play()


func _on_loop_sfx_player_finished() -> void:
	if _loop_sfx_id.is_empty():
		return
	if is_instance_valid(_loop_sfx_player) and _loop_sfx_player.stream != null:
		_loop_sfx_player.play()


func play_ambient_for_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		scene_path = _resolve_active_scene_path()
	_ambient_profile = _ambient_profile_from_scene(scene_path)
	print("[SoundManager] Ambient profile '%s' for scene: %s" % [_ambient_profile, scene_path])
	# force_restart YOK: zindan → kamp → zindan → boss geçişlerinde aynı parça
	# baştan başlamasın, yoksa uzun müziğin sadece ilk saniyeleri duyulur.
	_refresh_ambient_music(false)


func _on_scene_change_completed(scene_path: String) -> void:
	play_ambient_for_scene(scene_path)


func _on_hour_changed_ambient(_hour: int) -> void:
	if _ambient_profile != "village" and _ambient_profile != "forest":
		return
	var night_now: bool = _is_night_ambient()
	if night_now == _ambient_is_night:
		return
	_refresh_ambient_music(false)


func _ambient_profile_from_scene(scene_path: String) -> String:
	var p: String = scene_path.to_lower()
	if p.contains("villagescene") or p.contains("/village/"):
		return "village"
	if p.contains("forest"):
		return "forest"
	if p.contains("dungeon") or p.contains("test_level") or p.contains("campscene") or p.contains("boss") or p.contains("tutorial"):
		return "dungeon"
	if p.contains("mainmenu"):
		return ""
	return ""


func _is_night_ambient() -> bool:
	return ForestNightLightUtil.get_night_blend() >= 0.5


func _footstep_sfx_id_for_scene(scene_path: String) -> String:
	return "footstep_dirt" if _is_dirt_surface_scene(scene_path) else "footstep_player"


func _land_sfx_id_for_scene(scene_path: String, heavy: bool) -> String:
	if _is_dirt_surface_scene(scene_path):
		return "land_dirt"
	return "land_heavy" if heavy else "land"


func _is_dirt_surface_scene(scene_path: String) -> bool:
	match _ambient_profile_from_scene(scene_path):
		"village", "forest":
			return true
		_:
			return false


func _refresh_ambient_music(force_restart := false) -> void:
	if _ambient_profile.is_empty():
		clear_ambient_profile()
		return
	var ambient_id: String = ""
	match _ambient_profile:
		"village":
			_ambient_is_night = _is_night_ambient()
			ambient_id = "village_night" if _ambient_is_night else "village_day"
		"forest":
			_ambient_is_night = _is_night_ambient()
			ambient_id = "forest_night" if _ambient_is_night else "forest_day"
		"dungeon":
			_ambient_is_night = false
			ambient_id = "dungeon"
	var music_id: String = _pick_profile_music(_ambient_profile)
	if ambient_id.is_empty() and music_id.is_empty():
		clear_ambient_profile()
		return
	play_ambient(ambient_id, true, force_restart)
	play_music(music_id, true, force_restart)


## Profilin çalma listesinden bu run'ın parçasını döndürür.
## Aynı profil içinde (zindan → kamp → zindan → boss) hep aynı parçayı verir;
## profilden çıkılıp geri girilince yeniden seçer.
func _pick_profile_music(profile: String) -> String:
	var playlist: Array[String] = SoundCatalog.get_music_playlist(profile)
	if playlist.is_empty():
		# Bu profilde müzik yok — sonraki girişte yeni parça seçilsin diye sıfırla.
		_run_music_id = ""
		return ""
	if not _run_music_id.is_empty() and playlist.has(_run_music_id):
		return _run_music_id
	var candidates: Array[String] = playlist.duplicate()
	if candidates.size() > 1 and candidates.has(_last_run_music_id):
		candidates.erase(_last_run_music_id)
	_run_music_id = candidates[randi() % candidates.size()]
	_last_run_music_id = _run_music_id
	print("[SoundManager] Run music picked for profile '%s': %s" % [profile, _run_music_id])
	return _run_music_id


func stop_music() -> void:
	_current_music_id = ""
	_music_should_loop = false
	_music_loop_start = 0.0
	_music_loop_end = 0.0
	if is_instance_valid(_music_player):
		_fade_out_and_stop(_music_player, MUSIC_FADE_SEC)


func stop_ambient() -> void:
	_current_ambient_id = ""
	_ambient_should_loop = false
	if is_instance_valid(_ambient_player):
		_fade_out_and_stop(_ambient_player, AMBIENT_FADE_SEC)


func clear_ambient_profile() -> void:
	_ambient_profile = ""
	_ambient_is_night = false
	_run_music_id = ""
	stop_music()
	stop_ambient()


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


func _get_sfx_stream(sfx_id: String) -> AudioStream:
	if not _streams.has(sfx_id):
		_register_sfx(sfx_id)
	return _streams.get(sfx_id, null)


func _load_stream_at_path(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded is AudioStream:
		return loaded as AudioStream
	return null


func _register_sfx(sound_id: String) -> void:
	var path: String = SoundCatalog.resolve_sfx_path(sound_id)
	if not path.is_empty():
		var loaded: AudioStream = _load_stream_at_path(path)
		if loaded != null:
			_streams[sound_id] = loaded
			_stream_source[sound_id] = "file"
			return
	var def: Dictionary = _synth_def_for_sound_id(sound_id)
	if def.is_empty():
		push_warning("[SoundManager] Unknown sfx id: %s" % sound_id)
		return
	_streams[sound_id] = _synthesize(def)
	_stream_source[sound_id] = "synth"


func _synth_def_for_sound_id(sound_id: String) -> Dictionary:
	var stem: String = SoundCatalog.get_sfx_file_stem(sound_id)
	return AudioPlaceholderTones.SFX_STEMS.get(stem, {})


func _play_id(sound_id: String, position: Vector2, ui_channel: bool, pitch_scale: float = 1.0) -> void:
	if not _enabled:
		return
	var stream: AudioStream = _get_sfx_stream(sound_id)
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
	var master_pct: int = 100
	var music_pct: int = 80
	var sfx_pct: int = 100
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_pct = int(config.get_value("audio", "master_volume", master_pct))
		music_pct = int(config.get_value("audio", "music_volume", music_pct))
		sfx_pct = int(config.get_value("audio", "sfx_volume", sfx_pct))
	set_master_volume_db(_percent_to_db(master_pct))
	set_music_volume_db(_percent_to_db(music_pct))
	set_sfx_volume_db(_percent_to_db(sfx_pct))


func _log_audio_status() -> void:
	var status: Dictionary = get_audio_status()
	print(
		"[SoundManager] Ready — %d file asset(s), %d synth fallback(s). Music bus=%s SFX bus=%s"
		% [int(status.get("file_count", 0)), int(status.get("synth_count", 0)), _resolve_bus(MUSIC_BUS), _resolve_bus(SFX_BUS)]
	)


func _percent_to_db(percent: int) -> float:
	var clamped: int = clampi(percent, 0, 100)
	if clamped <= 0:
		return -80.0
	return linear_to_db(float(clamped) / 100.0)
