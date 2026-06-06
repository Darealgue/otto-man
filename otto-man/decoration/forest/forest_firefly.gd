extends Node2D

const TEXTURE_PATH := "res://decoration/forest/firefly.png"
const FRAME_COUNT := 6
const ANIM_FPS := 12.0

const MAX_SPEED := 22.0
const GLIDE_SPEED_MIN := 8.0
const GLIDE_SPEED_MAX := 16.0
const GLIDE_MIN_S := 0.9
const GLIDE_MAX_S := 2.4
const ARC_SPEED := 15.0
const ARC_CHORD_MIN := 80.0
const ARC_CHORD_MAX := 220.0
const ARC_BULGE_MIN := 40.0
const ARC_BULGE_MAX := 110.0
const ARC_MIN_S := 1.4
const ARC_MAX_S := 4.0
const ROTATION_LERP := 10.0

enum FlightPhase { GLIDE, ARC }

@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = $PointLight2D

var _velocity: Vector2 = Vector2.ZERO
var _phase: FlightPhase = FlightPhase.GLIDE
var _phase_timer: float = 0.0
var _flutter_phase: float = 0.0
var _anim_time: float = 0.0
var _time: float = 0.0
var _random_offset: float = 0.0
var _noise: FastNoiseLite
var _base_light_energy: float = 1.05
var _base_light_scale: float = 13.5
var _floor_y: float = 0.0
var _fly_zone: Rect2 = Rect2()
var _min_fly_y: float = 0.0
var _max_fly_y: float = 0.0
var _frame_w: int = 0
var _frame_h: int = 0
var _glide_dir: Vector2 = Vector2.RIGHT
var _glide_speed: float = 11.0
var _arc_start: Vector2 = Vector2.ZERO
var _arc_end: Vector2 = Vector2.ZERO
var _arc_control: Vector2 = Vector2.ZERO
var _arc_duration: float = 3.0
var _arc_elapsed: float = 0.0
func _ready() -> void:
	top_level = true
	add_to_group("forest_ambient")
	add_to_group("forest_night_light")
	z_as_relative = false
	z_index = 2
	_random_offset = randf() * 10.0
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 0.2
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_read_spawn_meta()
	_ensure_fly_zone()
	_setup_sprite()
	if _light:
		ForestNightLightUtil.configure_ground_light(_light)
		_light.color = Color(1.0, 0.92, 0.45, 1.0)
		_base_light_energy = _light.energy
		_base_light_scale = _light.texture_scale
	_flutter_phase = randf() * TAU
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _light:
		_light.energy = 0.0
	call_deferred("_begin_glide", true)


func configure_flight(zone_global: Rect2, floor_global_y: float, min_clearance: float, max_clearance: float) -> void:
	_fly_zone = zone_global
	_floor_y = floor_global_y
	_min_fly_y = _floor_y - max_clearance
	_max_fly_y = _floor_y - min_clearance


func _read_spawn_meta() -> void:
	if has_meta("fly_zone"):
		var zone_val = get_meta("fly_zone")
		if zone_val is Rect2:
			_fly_zone = zone_val as Rect2
	if has_meta("fly_floor_y"):
		_floor_y = float(get_meta("fly_floor_y"))
	if has_meta("fly_min_clearance"):
		var min_c := float(get_meta("fly_min_clearance"))
		var max_c := float(get_meta("fly_max_clearance", min_c + 80.0))
		_min_fly_y = _floor_y - max_c
		_max_fly_y = _floor_y - min_c


func _ensure_fly_zone() -> void:
	if _fly_zone.size != Vector2.ZERO:
		return
	if is_zero_approx(_floor_y) and not has_meta("fly_floor_y"):
		return
	if has_meta("fly_floor_y"):
		_floor_y = float(get_meta("fly_floor_y"))
	var min_c := float(get_meta("fly_min_clearance", 55.0))
	var max_c := float(get_meta("fly_max_clearance", 180.0))
	_min_fly_y = _floor_y - max_c
	_max_fly_y = _floor_y - min_c
	var parent_nd := get_parent() as Node2D
	if parent_nd == null:
		return
	var chunk_w := 4096.0
	if parent_nd.has_method("get_chunk_size"):
		chunk_w = maxf(320.0, (parent_nd.call("get_chunk_size") as Vector2).x)
	var margin_x := 120.0
	var x0 := parent_nd.global_position.x + margin_x
	var x1 := parent_nd.global_position.x + chunk_w - margin_x
	_fly_zone = Rect2(x0, _min_fly_y, maxf(48.0, x1 - x0), maxf(24.0, _max_fly_y - _min_fly_y))


func _setup_sprite() -> void:
	if _sprite == null:
		return
	if not ResourceLoader.exists(TEXTURE_PATH):
		return
	var tex: Texture2D = load(TEXTURE_PATH) as Texture2D
	if tex == null:
		return
	_frame_w = int(floor(float(tex.get_width()) / float(FRAME_COUNT)))
	_frame_h = tex.get_height()
	if _frame_w <= 0 or _frame_h <= 0:
		return
	_sprite.texture = tex
	_sprite.hframes = FRAME_COUNT
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	var fade_blend: float = ForestNightLightUtil.get_firefly_fade_blend()
	modulate = Color(1.0, 1.0, 1.0, fade_blend)
	if _sprite:
		_sprite.modulate = Color(1.2, 1.05, 0.55, 1.0)
	if _light:
		if fade_blend <= 0.01:
			_light.energy = 0.0
		else:
			var light_strength: float = fade_blend * ForestNightLightUtil.get_light_night_blend()
			ForestNightLightUtil.update_flickering_light(
				_light,
				_base_light_energy,
				_base_light_scale,
				_time,
				_noise,
				_random_offset,
				light_strength,
				0.0,
				1.0,
				0.0,
				1.0,
				1.1,
				0.28,
				0.1
			)


func _physics_process(delta: float) -> void:
	if ForestNightLightUtil.get_firefly_fade_blend() <= 0.01:
		return
	if _sprite == null:
		return
	if _fly_zone.size == Vector2.ZERO:
		_ensure_fly_zone()
	if _fly_zone.size == Vector2.ZERO:
		return
	_anim_time += delta
	_sprite.frame = int(_anim_time * ANIM_FPS) % FRAME_COUNT
	_flutter_phase += delta * 5.0
	_phase_timer -= delta
	match _phase:
		FlightPhase.GLIDE:
			_tick_glide(delta)
			global_position += _velocity * delta
		FlightPhase.ARC:
			_tick_arc(delta)
	_velocity = _velocity.limit_length(MAX_SPEED)
	global_position = _clamp_to_zone(global_position)
	_update_facing(delta)


func _update_facing(delta: float) -> void:
	if _velocity.length() < 1.0:
		return
	var target := _velocity.angle()
	_sprite.rotation = lerp_angle(_sprite.rotation, target, delta * ROTATION_LERP)


func _tick_glide(delta: float) -> void:
	var perp := Vector2(-_glide_dir.y, _glide_dir.x)
	var drift := perp * sin(_flutter_phase * 2.2) * 5.0
	var bob := Vector2(0.0, sin(_flutter_phase * 2.6) * 4.0)
	var desired := (_glide_dir * _glide_speed) + drift + bob
	_velocity = _velocity.lerp(desired, delta * 3.0)
	if _phase_timer <= 0.0:
		if randf() < 0.58:
			_begin_arc()
		else:
			_begin_glide(false)


func _tick_arc(delta: float) -> void:
	_arc_elapsed += delta
	var t := clampf(_arc_elapsed / maxf(_arc_duration, 0.001), 0.0, 1.0)
	var u := 1.0 - t
	var target_pos := (
		u * u * _arc_start
		+ 2.0 * u * t * _arc_control
		+ t * t * _arc_end
	)
	var to_target := target_pos - global_position
	var step := minf(to_target.length(), ARC_SPEED * delta)
	if step > 0.0001:
		global_position += to_target.normalized() * step
		_velocity = to_target.normalized() * (step / maxf(delta, 0.0001))
	else:
		_velocity = Vector2.ZERO
	if t >= 1.0 and to_target.length() < 10.0:
		if randf() < 0.5:
			_begin_glide(false)
		else:
			_begin_arc()


func _begin_glide(first: bool) -> void:
	if _fly_zone.size == Vector2.ZERO:
		_ensure_fly_zone()
	if _fly_zone.size == Vector2.ZERO:
		return
	_phase = FlightPhase.GLIDE
	_phase_timer = randf_range(GLIDE_MIN_S, GLIDE_MAX_S)
	_glide_speed = randf_range(GLIDE_SPEED_MIN, GLIDE_SPEED_MAX)
	_glide_dir = _random_unit_nearby()
	if first:
		global_position = _random_point_in_zone()
	_velocity = _glide_dir * _glide_speed


func _begin_arc() -> void:
	_phase = FlightPhase.ARC
	_arc_elapsed = 0.0
	_arc_start = global_position
	_arc_end = _pick_arc_endpoint()
	var chord := _arc_end - _arc_start
	var perp := Vector2(-chord.y, chord.x)
	if perp.length() > 0.001:
		perp = perp.normalized()
	else:
		perp = Vector2.UP
	var side := -1.0 if randf() < 0.5 else 1.0
	var bulge := randf_range(ARC_BULGE_MIN, ARC_BULGE_MAX) * side
	var mid := (_arc_start + _arc_end) * 0.5
	_arc_control = _clamp_to_zone(mid + perp * bulge)
	var est_len := chord.length() + absf(bulge) * 0.5
	_arc_duration = clampf(est_len / ARC_SPEED, ARC_MIN_S, ARC_MAX_S)
	_phase_timer = _arc_duration


func _pick_arc_endpoint() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(ARC_CHORD_MIN, ARC_CHORD_MAX)
	return _clamp_to_zone(global_position + Vector2(cos(angle), sin(angle)) * dist)


func _random_point_in_zone() -> Vector2:
	if _fly_zone.size == Vector2.ZERO:
		return global_position
	var margin_x := 20.0
	var margin_y := 10.0
	var x0 := _fly_zone.position.x + margin_x
	var x1 := _fly_zone.position.x + _fly_zone.size.x - margin_x
	var y0 := _min_fly_y + margin_y
	var y1 := _max_fly_y - margin_y
	if x1 <= x0:
		x0 = _fly_zone.position.x
		x1 = _fly_zone.position.x + _fly_zone.size.x
	if y1 <= y0:
		y1 = y0 + 12.0
	return Vector2(randf_range(x0, x1), randf_range(y0, y1))


func _random_unit_nearby() -> Vector2:
	var target := _pick_arc_endpoint()
	var dir := target - global_position
	if dir.length() < 1.0:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-0.25, 0.25))
	return dir.normalized()


func _clamp_to_zone(pos: Vector2) -> Vector2:
	if _fly_zone.size == Vector2.ZERO:
		return pos
	var x0 := _fly_zone.position.x
	var x1 := _fly_zone.position.x + _fly_zone.size.x
	pos.x = clampf(pos.x, x0, x1)
	pos.y = clampf(pos.y, _min_fly_y, _max_fly_y)
	return pos
