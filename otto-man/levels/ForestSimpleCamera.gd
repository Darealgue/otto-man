extends Camera2D

# Simple, predictable vertical bias camera for platformers.

@export var bias_ground_y: float = -120.0   # show more sky when grounded (negative moves camera up)
@export var bias_air_y: float = -40.0       # neutral-ish when in air
@export var bias_jump_center_y: float = -10.0 # slight up-focus during jump start
@export var jump_center_time: float = 0.15
@export var smooth_speed: float = 5.0       # Camera2D position smoothing speed
@export var offset_smooth_speed: float = 8.0 # smoothing for offset changes (per second)
@export var debug: bool = true
@export var debug_interval_s: float = 0.25
@export var ground_switch_delay_s: float = 0.10 # debounce when switching to ground
@export var air_switch_delay_s: float = 0.08    # debounce when switching to air
@export var max_offset_rate_px_s: float = 140.0 # cap vertical offset change per second (slower, smoother)
@export var vy_deadzone: float = 5.0            # treat tiny vy as 0 to avoid flicker
@export var offset_tau_s: float = 0.45          # time constant for vertical offset smoothing (bigger = slower)
@export var support_probe_distance_px: float = 48.0
@export var support_probe_mask: int = CollisionLayers.WORLD | CollisionLayers.PLATFORM
@export var treat_platform_as_air: bool = true   # when standing on one-way platforms, behave like air (center)
@export var bias_platform_y: float = -10.0       # vertical bias when standing on platform branches

var _player: CharacterBody2D
var _last_y: float = 0.0
var _vy: float = 0.0
var _jump_timer: float = 0.0
var _offset_y: float = 0.0
var _dbg_t: float = 0.0
var _dbg_state: String = ""
var _dbg_switches: int = 0
var _ground_t: float = 0.0
var _air_t: float = 0.0
var _stable_on_floor: bool = false
var _support_kind: String = "none" # none|ground|platform

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed
	set_process(true)
	_find_player()
	_offset_y = offset.y
	if _player:
		_last_y = _player.global_position.y
	if debug:
		call_deferred("debug_dump_cameras")

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_find_player()
		return
	var y: float = _player.global_position.y
	_vy = (y - _last_y) / max(0.0001, delta)
	if abs(_vy) < vy_deadzone:
		_vy = 0.0
	_last_y = y

	# Update debounced ground/air state
	var raw_on_floor: bool = _player.is_on_floor()
	if raw_on_floor:
		_air_t = 0.0
		_ground_t += delta
		if not _stable_on_floor and _ground_t >= ground_switch_delay_s:
			_stable_on_floor = true
	else:
		_ground_t = 0.0
		_air_t += delta
		if _stable_on_floor and _air_t >= air_switch_delay_s:
			_stable_on_floor = false

	# Sense what we're standing on (ground vs one-way platform)
	_support_kind = _get_support_kind()

	# Determine target bias (with debounce + jump center)
	var target: float = bias_air_y
	var state: String = "air"
	var reason: String = "air"
	if _stable_on_floor:
		target = bias_ground_y
		_jump_timer = 0.0
		state = "ground"
		reason = "ground_debounced"
		if treat_platform_as_air and _support_kind == "platform":
			# On tree branch one-way platform → prefer platform/air behavior
			target = bias_platform_y
			state = "air"
			reason = "platform_bias"
	else:
		if _vy < -50.0 and _jump_timer <= 0.0:
			# Jump just started → slight recenter for a brief moment
			_jump_timer = jump_center_time
		if _jump_timer > 0.0:
			target = bias_jump_center_y
			_jump_timer = max(0.0, _jump_timer - delta)
			state = "jump"
			reason = "jump_center"
		else:
			target = bias_air_y
			state = "air"
			reason = "air_debounced"

	# Smooth towards target offset using exponential time-constant smoothing
	var diff: float = target - _offset_y
	var k: float = 1.0 - exp(-delta / max(0.0001, offset_tau_s))
	var desired: float = _offset_y + diff * clamp(k, 0.0, 1.0)
	var max_step: float = max_offset_rate_px_s * delta
	if abs(desired - _offset_y) > max_step:
		desired = _offset_y + sign(desired - _offset_y) * max_step
	_offset_y = desired
	offset.y = _offset_y

	if debug:
		if state != _dbg_state:
			_dbg_state = state
			_dbg_switches += 1
		_dbg_t += delta
		if _dbg_t >= max(0.05, debug_interval_s):
			_dbg_t = 0.0
			var cam_y: float = global_position.y
			var py: float = _player.global_position.y
			print("[SimpleCam] st=", state,
				" on_floor=", _stable_on_floor,
				" raw_floor=", raw_on_floor,
				" support=", _support_kind,
				" deb_t=(g:", snappedf(_ground_t, 0.001), ", a:", snappedf(_air_t, 0.001), ")",
				" vy=", int(_vy),
				" target=", int(target),
				" off=", int(offset.y),
				" diff=", int(diff),
				" k=", snappedf(k, 0.001),
				" max_step=", int(max_step),
				" reason=", reason,
				" pY=", int(py),
				" cY=", int(cam_y),
				" switches=", _dbg_switches)

func _get_support_kind() -> String:
	# Prefer reading actual floor collision from the player when available
	if not _player:
		return "none"
	var coll_kind: String = _get_floor_collision_kind()
	if coll_kind != "none":
		return coll_kind
	# Otherwise, cast multiple short rays downward to detect whether support is WORLD or PLATFORM
	var offsets: Array = [Vector2(-8, 0), Vector2(0, 0), Vector2(8, 0)]
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for oi in range(offsets.size()):
		var off: Vector2 = offsets[oi]
		var from: Vector2 = _player.global_position + off + Vector2(0, 2)
		var to: Vector2 = from + Vector2(0, max(1.0, support_probe_distance_px))
		var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
		params.collide_with_areas = false
		params.collision_mask = int(support_probe_mask)
		params.exclude = [ _player.get_rid() ]
		var hit: Dictionary = space.intersect_ray(params)
		if not hit.is_empty():
			var col: Object = hit.get("collider")
			if col != null and col is CollisionObject2D:
				var layer: int = (col as CollisionObject2D).collision_layer
				if (layer & CollisionLayers.PLATFORM) != 0:
					return "platform"
				if (layer & CollisionLayers.WORLD) != 0:
					return "ground"
	# Fallback: point overlap directly under feet (Godot 4: use query params)
	var point: Vector2 = _player.global_position + Vector2(0, 6)
	var pparams: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	pparams.position = point
	pparams.collide_with_areas = false
	pparams.collide_with_bodies = true
	pparams.collision_mask = int(support_probe_mask)
	pparams.exclude = [ _player.get_rid() ]
	var res: Array = space.intersect_point(pparams, 8)
	if res.size() > 0:
		var first: Dictionary = res[0]
		var c: Object = first.get("collider")
		if c != null and c is CollisionObject2D:
			var l: int = (c as CollisionObject2D).collision_layer
			if (l & CollisionLayers.PLATFORM) != 0:
				return "platform"
			if (l & CollisionLayers.WORLD) != 0:
				return "ground"
	return "none"

func _get_floor_collision_kind() -> String:
	if not _player or not _player.is_on_floor():
		return "none"
	var count: int = _player.get_slide_collision_count()
	for i in range(count):
		var kc: KinematicCollision2D = _player.get_slide_collision(i)
		if kc == null:
			continue
		var col: Object = kc.get_collider()
		if col != null and col is CollisionObject2D:
			var layer: int = (col as CollisionObject2D).collision_layer
			# If both bits exist, treat as platform first
			if (layer & CollisionLayers.PLATFORM) != 0:
				return "platform"
			if (layer & CollisionLayers.WORLD) != 0:
				return "ground"
	return "none"

func force_init() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed
	set_process(true)
	_find_player()
	if debug:
		call_deferred("debug_dump_cameras")

func debug_dump_cameras() -> void:
	var root: Node = get_tree().get_root()
	var stack: Array = [root]
	var cams: Array = []
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Camera2D:
			cams.append(n)
		var child_count: int = n.get_child_count()
		for j in range(child_count):
			var child: Node = n.get_child(j)
			stack.append(child)
	print("[SimpleCam] Camera2D count:", cams.size())
	for i in range(cams.size()):
		var cam: Camera2D = cams[i]
		print(" - ", cam.get_path(),
			" is_current=", cam.is_current(),
			" enabled=", cam.enabled,
			" smoothing=", cam.position_smoothing_enabled,
			" speed=", cam.position_smoothing_speed)
	var active_cam: Camera2D = get_viewport().get_camera_2d()
	if active_cam:
		print("[SimpleCam] Viewport active camera:", active_cam.get_path())

func _find_player() -> void:
	var list: Array = get_tree().get_nodes_in_group("player")
	if list.size() > 0:
		var cand: Node = list[0]
		if cand is CharacterBody2D:
			_player = cand as CharacterBody2D
