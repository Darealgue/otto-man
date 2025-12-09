extends Camera2D

@export var ground_bias_y: float = -140.0 # keep player slightly below center when grounded (negative moves camera up)
@export var air_bias_y: float = -40.0   # gentle upward bias when in air but not falling fast
@export var fall_look_ahead: float = 120.0 # extra look-down when falling fast to see below
@export var jump_recent_center_time: float = 0.18 # time window to recenter on jump start
@export var smooth_speed: float = 3.5
@export var offset_smooth_speed: float = 8.0
@export var tile_probe_distance: float = 64.0 # how far below the player to check for ground support
@export var tile_probe_mask: int = 1 | (1 << 9) # WORLD | PLATFORM
@export var debug: bool = false
@export var ground_switch_delay_s: float = 0.15
@export var air_switch_delay_s: float = 0.10
@export var max_offset_rate_px_s: float = 220.0
@export var fall_start_speed: float = 600.0
@export var fall_look_scale: float = 0.06

var _player: Node2D
var _vel_y: float = 0.0
var _last_player_y: float = 0.0
var _jump_recenter_timer: float = 0.0
var _was_on_ground: bool = false
var _dbg_acc: float = 0.0
var _offset_y: float = 0.0
var _last_current_cam: Camera2D = null
var _time_on_ground: float = 0.0
var _time_in_air: float = 0.0
var _default_zoom: Vector2 = Vector2.ONE
var _zoom_tween: Tween = null

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed
	set_process(true)
	_find_player()
	if _player:
		_last_player_y = _player.global_position.y
	# Initialize offset smoothing to current offset to avoid snap
	_offset_y = offset.y
	_default_zoom = zoom
	if debug:
		call_deferred("debug_dump_cameras")

func force_init() -> void:
	# Call this after setting the script at runtime to ensure initialization
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed
	set_process(true)
	_find_player()
	if _player:
		_last_player_y = _player.global_position.y
	_offset_y = offset.y
	_default_zoom = zoom

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_find_player()
		return
	var py: float = _player.global_position.y
	_vel_y = (py - _last_player_y) / max(0.0001, delta)
	_last_player_y = py

	var on_ground: bool = _is_ground_supported_below()
	# Auto-detect jump start for brief re-center
	if _was_on_ground and not on_ground and _vel_y < -50.0:
		_jump_recenter_timer = jump_recent_center_time
	_was_on_ground = on_ground
	if on_ground:
		_time_on_ground += delta
		_time_in_air = 0.0
	else:
		_time_in_air += delta
		_time_on_ground = 0.0

	var bias_y: float = _compute_vertical_bias(delta, on_ground)
	# Rate-limit large jumps to avoid teleport feel
	var diff: float = bias_y - _offset_y
	var max_step: float = max_offset_rate_px_s * delta
	if abs(diff) > max_step:
		_offset_y += sign(diff) * max_step
	else:
		_offset_y = bias_y
	# Optional extra smoothing for micro jitter
	var k: float = 1.0 - pow(0.001, max(0.0, offset_smooth_speed) * delta)
	_offset_y = lerp(_offset_y, bias_y, clamp(k, 0.0, 1.0))
	offset.y = _offset_y

	if debug:
		_dbg_acc += delta
		if _dbg_acc >= 0.25:
			_dbg_acc = 0.0
			print("[ForestCam] on_ground=", on_ground, " vy=", int(_vel_y), " bias=", int(bias_y), " offsetY=", int(offset.y))
	# Detect if another camera became current
	var cur: Camera2D = get_viewport().get_camera_2d()
	if cur != _last_current_cam:
		_last_current_cam = cur
		if debug:
			var who: String = (String(cur.name) if cur else "<none>")
			print("[ForestCam] Current camera changed -> ", who)
			if cur != self:
				print("[ForestCam] WARNING: Another camera is current. Dumping cameras...")
				debug_dump_cameras()

func _compute_vertical_bias(delta: float, on_ground: bool) -> float:
	# If we recently started a jump, briefly recenter to show ceiling/arc
	if _jump_recenter_timer > 0.0:
		_jump_recenter_timer = max(0.0, _jump_recenter_timer - delta)
		return -20.0  # near-center but slightly up to reduce harsh snap

	# Hysteresis: require small delays before switching states to avoid flicker
	if on_ground:
		if _time_on_ground >= ground_switch_delay_s:
			return ground_bias_y
		# transitioning: smoothly blend towards ground bias without instant jump
		return lerp(air_bias_y, ground_bias_y, clamp(_time_on_ground / ground_switch_delay_s, 0.0, 1.0))

	# In air: gentle upward bias, plus look-down when falling fast
	var bias: float = air_bias_y
	# Only add look-ahead after a small air delay and significant fall speed
	if _time_in_air >= air_switch_delay_s and _vel_y > fall_start_speed:
		var extra: float = min(fall_look_ahead, (_vel_y - fall_start_speed) * fall_look_scale)
		# Ease-in for the first 0.2s in air to avoid sudden jump
		var ease: float = clamp((_time_in_air - air_switch_delay_s) / 0.2, 0.0, 1.0)
		bias += extra * ease
	return bias

func notify_jump_started() -> void:
	# Call from player when a jump begins to briefly center
	_jump_recenter_timer = jump_recent_center_time


func _find_player() -> void:
	var list: Array = get_tree().get_nodes_in_group("player")
	if list.size() > 0:
		var cand: Node = list[0]
		if cand is Node2D:
			_player = cand as Node2D

func _is_ground_supported_below() -> bool:
	if not _player:
		return false
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = _player.global_position + Vector2(0, 4)
	var to: Vector2 = from + Vector2(0, tile_probe_distance)
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = tile_probe_mask
	var hit: Dictionary = space.intersect_ray(params)
	return hit and hit.has("position")

func debug_dump_cameras() -> void:
	var cams: Array = []
	var root: Node = get_tree().current_scene
	if not root:
		return
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
			if ch is Camera2D:
				var c: Camera2D = ch as Camera2D
				cams.append(c)
	print("[ForestCam] Camera2D count:", cams.size())
	var cur: Camera2D = get_viewport().get_camera_2d()
	for c in cams:
		print("  - ", c.get_path(), " current=", (c == cur), " enabled=", c.enabled, " smoothing=", c.position_smoothing_enabled, 
			" speed=", c.position_smoothing_speed)

func zoom_to_factor(factor: float, duration: float = 0.25) -> void:
	var clamped_factor = max(0.05, factor)
	var target = _default_zoom * clamped_factor
	_apply_zoom(target, duration)

func zoom_to_vector(target: Vector2, duration: float = 0.25) -> void:
	_apply_zoom(target, duration)

func reset_zoom(duration: float = 0.25) -> void:
	_apply_zoom(_default_zoom, duration)

func _apply_zoom(target: Vector2, duration: float) -> void:
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	if duration <= 0.0:
		zoom = target
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
