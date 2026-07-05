class_name PlayerNoiseEmitter
extends Node
## Olay tabanlı gürültü — her olayda genişleyen halka; koşu ayak vuruşları animasyonla senkron.

const NOISE_RUN: float = 92.0
const NOISE_DASH: float = 108.0
const NOISE_LIGHT_ATTACK: float = 88.0
const NOISE_HEAVY_ATTACK: float = 132.0
const NOISE_FALL_ATTACK: float = 110.0
const NOISE_JUMP: float = 58.0
const NOISE_LAND: float = 72.0
const NOISE_LAND_HEAVY: float = 98.0

const PULSE_DURATION: float = 0.48
const RunFootstepConfig = preload("res://components/run_footstep_config.gd")

const NOISE_PULSE_RING_SCRIPT := preload("res://effects/noise_pulse_ring.gd")

signal noise_emitted(origin: Vector2, max_radius: float)

class NoisePulse:
	var id: int
	var origin: Vector2
	var max_radius: float
	var age: float = 0.0
	var duration: float = PULSE_DURATION

	func _init(pulse_id: int, pulse_origin: Vector2, radius: float, pulse_duration: float) -> void:
		id = pulse_id
		origin = pulse_origin
		max_radius = radius
		duration = pulse_duration

var _player: CharacterBody2D = null
var _active_pulses: Array[NoisePulse] = []
var _next_pulse_id: int = 1
var _last_state_name: String = ""
var _last_run_frame: int = -1
var _was_on_floor: bool = true
var _noise_multiplier: float = 1.0


func setup(player: CharacterBody2D) -> void:
	_player = player
	_was_on_floor = player.is_on_floor() if is_instance_valid(player) else true


func set_noise_multiplier(mult: float) -> void:
	_noise_multiplier = maxf(0.0, mult)


func get_noise_multiplier() -> float:
	return _noise_multiplier


func emit_noise_event(max_radius: float, origin: Vector2 = Vector2.INF) -> void:
	if max_radius <= 0.0 or not is_instance_valid(_player):
		return
	if not _is_stealth_active():
		return
	var radius: float = max_radius * _noise_multiplier
	var pos: Vector2 = origin if origin != Vector2.INF else _get_feet_global()
	var pulse := NoisePulse.new(_next_pulse_id, pos, radius, PULSE_DURATION)
	_next_pulse_id += 1
	_active_pulses.append(pulse)
	_spawn_ring_visual(pos, radius, PULSE_DURATION)
	noise_emitted.emit(pos, radius)


func is_audible_at(listener_global: Vector2) -> bool:
	return _get_audible_strength_at(listener_global) > 0.0


func get_audible_strength_at(listener_global: Vector2) -> float:
	return _get_audible_strength_at(listener_global)


func get_active_pulse_ids_for_listener(listener_global: Vector2) -> Array[int]:
	var ids: Array[int] = []
	for pulse in _active_pulses:
		if pulse.duration <= 0.0:
			continue
		var t: float = clampf(pulse.age / pulse.duration, 0.0, 1.0)
		var current_radius: float = pulse.max_radius * t
		if listener_global.distance_to(pulse.origin) <= current_radius + 6.0:
			ids.append(pulse.id)
	return ids


func _get_audible_strength_at(listener_global: Vector2) -> float:
	var best: float = 0.0
	for pulse in _active_pulses:
		if pulse.duration <= 0.0:
			continue
		var t: float = clampf(pulse.age / pulse.duration, 0.0, 1.0)
		var current_radius: float = pulse.max_radius * t
		var dist: float = listener_global.distance_to(pulse.origin)
		if dist <= current_radius + 6.0:
			var edge_strength: float = 1.0 - clampf(dist / maxf(current_radius, 1.0), 0.0, 1.0)
			best = maxf(best, edge_strength)
	return best


func get_current_noise_radius() -> float:
	# Geriye dönük uyumluluk: aktif en geniş halka yarıçapı.
	var best: float = 0.0
	for pulse in _active_pulses:
		var t: float = clampf(pulse.age / pulse.duration, 0.0, 1.0)
		best = maxf(best, pulse.max_radius * t)
	return best


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_advance_pulses(delta)
	_poll_landing_noise()
	_poll_run_footsteps()
	_track_state_noise()


func _advance_pulses(delta: float) -> void:
	var i: int = _active_pulses.size() - 1
	while i >= 0:
		var pulse: NoisePulse = _active_pulses[i]
		pulse.age += delta
		if pulse.age >= pulse.duration:
			_active_pulses.remove_at(i)
		i -= 1


func _poll_landing_noise() -> void:
	var on_floor: bool = _player.is_on_floor()
	if on_floor and not _was_on_floor:
		var impact_speed: float = absf(float(_player.velocity.y))
		var sm := get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_land"):
			sm.play_land(_get_feet_global(), impact_speed >= 360.0)
		elif sm and sm.has_method("play_sfx"):
			if impact_speed >= 360.0:
				sm.play_sfx("land_heavy", _get_feet_global())
			else:
				sm.play_sfx("land", _get_feet_global())
		if impact_speed >= 360.0:
			emit_noise_event(NOISE_LAND_HEAVY)
		else:
			emit_noise_event(NOISE_LAND)
	_was_on_floor = on_floor


func _poll_run_footsteps() -> void:
	var anim_player: AnimationPlayer = _player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var sprite: Sprite2D = _player.get_node_or_null("Sprite2D") as Sprite2D
	if anim_player == null or sprite == null:
		_last_run_frame = -1
		return
	if StringName(anim_player.current_animation) != RunFootstepConfig.RUN_ANIM or not anim_player.is_playing():
		_last_run_frame = -1
		return
	if not _player.is_on_floor() or absf(float(_player.velocity.x)) < 40.0:
		_last_run_frame = -1
		return
	var frame: int = sprite.frame
	if frame == _last_run_frame:
		return
	if _last_run_frame >= 0 and RunFootstepConfig.is_foot_contact_frame(frame):
		emit_noise_event(NOISE_RUN)
	_last_run_frame = frame


func _track_state_noise() -> void:
	var state_machine: Node = _player.get_node_or_null("StateMachine")
	if state_machine == null or not state_machine.get("current_state"):
		return
	var current_state: Node = state_machine.current_state
	if not is_instance_valid(current_state):
		return
	var state_name: String = String(current_state.name)
	if state_name == _last_state_name:
		return
	match state_name:
		"Attack":
			emit_noise_event(NOISE_LIGHT_ATTACK)
		"HeavyAttack":
			emit_noise_event(NOISE_HEAVY_ATTACK)
		"FallAttack":
			emit_noise_event(NOISE_FALL_ATTACK)
		"Jump":
			emit_noise_event(NOISE_JUMP)
		"Dash":
			emit_noise_event(NOISE_DASH)
	_last_state_name = state_name


func _get_feet_global() -> Vector2:
	return _player.global_position + Vector2(0.0, 8.0)


func _spawn_ring_visual(pos: Vector2, max_radius: float, duration: float) -> void:
	var sm: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(sm) and sm.has_method("should_show_noise_visuals") and not sm.should_show_noise_visuals():
		return
	var tree: SceneTree = _player.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var ring: Node2D = NOISE_PULSE_RING_SCRIPT.new()
	ring.name = "NoisePulseRing"
	ring.global_position = pos
	tree.current_scene.add_child(ring)
	if ring.has_method("setup"):
		ring.setup(max_radius, duration)


func _is_stealth_active() -> bool:
	var sm: Node = get_node_or_null("/root/StealthManager")
	return is_instance_valid(sm) and sm.has_method("is_stealth_enabled") and sm.is_stealth_enabled()
