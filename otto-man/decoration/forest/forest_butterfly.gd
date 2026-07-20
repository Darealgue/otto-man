extends Node2D

const TEXTURE_PATHS: Array[String] = [
	"res://decoration/forest/btfly1.png",
	"res://decoration/forest/btfly2.png",
]
const FRAME_COUNT := 6
const WING_FPS_GLIDE := 7.0
const WING_FPS_ARC := 10.0

## Tatlı uçuş — tüm fazlar bu tavanı geçmez (px/s)
const MAX_SPEED := 20.0
const GLIDE_SPEED_MIN := 5.0
const GLIDE_SPEED_MAX := 12.0
const GLIDE_MIN_S := 1.2
const GLIDE_MAX_S := 3.0
const ARC_SPEED := 14.0
const ARC_CHORD_MIN := 90.0
const ARC_CHORD_MAX := 240.0
const ARC_BULGE_MIN := 70.0
const ARC_BULGE_MAX := 160.0
const ARC_MIN_S := 2.4
const ARC_MAX_S := 6.5
const ROTATION_LERP := 9.0
const SPRITE_FACING_OFFSET := 0.0

enum FlightPhase { GLIDE, ARC }

@onready var _sprite: Sprite2D = $Sprite

const OFFSCREEN_CULL_MARGIN := 150.0

var _velocity: Vector2 = Vector2.ZERO
var _phase: FlightPhase = FlightPhase.GLIDE
var _phase_timer: float = 0.0
var _flutter_phase: float = 0.0
var _wing_time: float = 0.0
var _wing_color: Color = Color.WHITE
var _floor_y: float = 0.0
var _fly_zone: Rect2 = Rect2()
var _min_fly_y: float = 0.0
var _max_fly_y: float = 0.0
var _frame_w: int = 0
var _frame_h: int = 0

var _glide_dir: Vector2 = Vector2.RIGHT
var _glide_speed: float = 10.0
var _arc_start: Vector2 = Vector2.ZERO
var _arc_end: Vector2 = Vector2.ZERO
var _arc_control: Vector2 = Vector2.ZERO
var _arc_duration: float = 3.0
var _arc_elapsed: float = 0.0

static var _shader: Shader


func _ready() -> void:
	add_to_group("forest_ambient")
	z_as_relative = false
	z_index = 2
	scale = Vector2.ONE
	_read_spawn_meta()
	_wing_color = _random_wing_color()
	_setup_sprite()
	_apply_wing_color()
	_flutter_phase = randf() * TAU
	var day_alpha: float = clampf(1.0 - ForestNightLightUtil.get_night_blend(), 0.0, 1.0)
	modulate = Color(1.0, 1.0, 1.0, day_alpha)
	_begin_glide(true)
	call_deferred("_apply_wing_color")
	_setup_offscreen_culling()


## Ekran dışındayken uçuş fiziğini durdurur; birden çok chunk aktif kalırken görünmeyen
## kelebekler boş yere işlemci yiyordu.
func _setup_offscreen_culling() -> void:
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-OFFSCREEN_CULL_MARGIN, -OFFSCREEN_CULL_MARGIN, OFFSCREEN_CULL_MARGIN * 2.0, OFFSCREEN_CULL_MARGIN * 2.0)
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)
	if not notifier.is_on_screen():
		_on_screen_exited()


func _on_screen_exited() -> void:
	set_process(false)


func _on_screen_entered() -> void:
	set_process(true)


func configure_flight(zone_global: Rect2, floor_global_y: float, min_clearance: float, max_clearance: float) -> void:
	_fly_zone = zone_global
	_floor_y = floor_global_y
	_min_fly_y = _floor_y - max_clearance
	_max_fly_y = _floor_y - min_clearance
	global_position = _clamp_to_zone(global_position)


func _read_spawn_meta() -> void:
	if has_meta("fly_zone"):
		_fly_zone = get_meta("fly_zone")
	if has_meta("fly_floor_y"):
		_floor_y = float(get_meta("fly_floor_y"))
	if has_meta("fly_min_clearance"):
		var min_c := float(get_meta("fly_min_clearance"))
		var max_c := float(get_meta("fly_max_clearance", min_c + 120.0))
		_min_fly_y = _floor_y - max_c
		_max_fly_y = _floor_y - min_c


func _setup_sprite() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2.ONE
	_sprite.flip_h = false
	var path := TEXTURE_PATHS[randi() % TEXTURE_PATHS.size()]
	if not ResourceLoader.exists(path):
		path = TEXTURE_PATHS[0]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	var sheet_w := tex.get_width()
	var sheet_h := tex.get_height()
	_frame_w = int(floor(float(sheet_w) / float(FRAME_COUNT)))
	_frame_h = sheet_h
	if _frame_w <= 0 or _frame_h <= 0:
		return
	_sprite.texture = tex
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.region_enabled = true
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_frame(0)
	set_meta("butterfly_variant", path.get_file())


func _set_frame(idx: int) -> void:
	if _sprite == null or _frame_w <= 0:
		return
	var i := clampi(idx, 0, FRAME_COUNT - 1)
	_sprite.region_rect = Rect2(_frame_w * i, 0, _frame_w, _frame_h)


func _apply_wing_color() -> void:
	if _sprite == null:
		return
	_sprite.modulate = _wing_color
	if _shader == null:
		_shader = load("res://decoration/forest/forest_butterfly_wing.gdshader") as Shader
	if _shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("wing_tint", _wing_color)
		_sprite.material = mat


func _random_wing_color() -> Color:
	var presets: Array[Color] = [
		Color(0.45, 0.72, 1.0),
		Color(1.0, 0.62, 0.22),
		Color(0.98, 0.42, 0.72),
		Color(0.48, 0.92, 0.42),
		Color(0.82, 0.48, 0.98),
		Color(1.0, 0.86, 0.32),
		Color(0.35, 0.88, 0.95),
	]
	if randf() < 0.6:
		return presets[randi() % presets.size()]
	return Color.from_hsv(randf(), randf_range(0.5, 0.8), randf_range(0.88, 1.0))


func _process(delta: float) -> void:
	if _fly_zone.size == Vector2.ZERO or _sprite == null:
		return
	var night_blend: float = ForestNightLightUtil.get_night_blend()
	var day_alpha: float = clampf(1.0 - night_blend, 0.0, 1.0)
	modulate = Color(1.0, 1.0, 1.0, day_alpha)
	if day_alpha <= 0.02:
		return
	var wing_fps := WING_FPS_GLIDE if _phase == FlightPhase.GLIDE else WING_FPS_ARC
	_wing_time += delta
	_set_frame(int(_wing_time * wing_fps) % FRAME_COUNT)
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
	if _velocity.length() < 1.5:
		return
	var target := _velocity.angle() + SPRITE_FACING_OFFSET
	_sprite.rotation = lerp_angle(_sprite.rotation, target, delta * ROTATION_LERP)


func _tick_glide(delta: float) -> void:
	var perp := Vector2(-_glide_dir.y, _glide_dir.x)
	var drift := perp * sin(_flutter_phase * 1.6) * 5.0
	var bob := Vector2(0.0, sin(_flutter_phase * 2.0) * 4.0)
	var desired := (_glide_dir * _glide_speed) + drift + bob
	_velocity = _velocity.lerp(desired, delta * 2.6)
	_velocity = _velocity.limit_length(MAX_SPEED)
	if _phase_timer <= 0.0:
		if randf() < 0.68:
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
	var done_time := t >= 1.0
	var done_dist := to_target.length() < 10.0
	if done_time and done_dist:
		if randf() < 0.58:
			_begin_glide(false)
		else:
			_begin_arc()


func _begin_glide(first: bool) -> void:
	_phase = FlightPhase.GLIDE
	_phase_timer = randf_range(GLIDE_MIN_S, GLIDE_MAX_S)
	_glide_speed = randf_range(GLIDE_SPEED_MIN, GLIDE_SPEED_MAX)
	_glide_dir = _random_unit_nearby()
	if first:
		global_position = _random_point_in_zone()
		_velocity = _glide_dir * _glide_speed * 0.4


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
	var est_len := chord.length() + absf(bulge) * 0.55
	_arc_duration = clampf(est_len / ARC_SPEED, ARC_MIN_S, ARC_MAX_S)
	_phase_timer = _arc_duration


func _pick_arc_endpoint() -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(ARC_CHORD_MIN, ARC_CHORD_MAX)
	return _clamp_to_zone(global_position + Vector2(cos(angle), sin(angle)) * dist)


func _random_point_in_zone() -> Vector2:
	if _fly_zone.size == Vector2.ZERO:
		return global_position
	var margin_x := 24.0
	var margin_y := 12.0
	var x0 := _fly_zone.position.x + margin_x
	var x1 := _fly_zone.position.x + _fly_zone.size.x - margin_x
	var y0 := _min_fly_y + margin_y
	var y1 := _max_fly_y - margin_y
	if x1 <= x0:
		x0 = _fly_zone.position.x
		x1 = _fly_zone.position.x + _fly_zone.size.x
	if y1 <= y0:
		y1 = y0 + 16.0
	return Vector2(randf_range(x0, x1), randf_range(y0, y1))


func _random_unit_nearby() -> Vector2:
	var target := _pick_arc_endpoint()
	var dir := target - global_position
	if dir.length() < 1.0:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3))
	return dir.normalized()


func _clamp_to_zone(pos: Vector2) -> Vector2:
	if _fly_zone.size == Vector2.ZERO:
		return pos
	var x0 := _fly_zone.position.x
	var x1 := _fly_zone.position.x + _fly_zone.size.x
	pos.x = clampf(pos.x, x0, x1)
	pos.y = clampf(pos.y, _min_fly_y, _max_fly_y)
	return pos
