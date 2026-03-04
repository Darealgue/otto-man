class_name BasicEnemy
extends "res://enemy/base_enemy.gd"

# Basic enemy - simple AI, low HP, optimized for juggling/combos
# Designed to be spawned in large numbers in dungeons

# Patrol / movement properties
var patrol_point_left: float
var patrol_point_right: float
var patrol_range: float = 150.0  # How far to patrol from spawn point

# Behavior timers
var patrol_wait_time: float = 1.0  # Wait time at patrol points
var chase_speed_multiplier: float = 1.8  # Chase significantly faster than patrol

# Chase behavior tuning (to reduce flicker)
@export var chase_start_distance: float = 260.0  # Distance to START chasing
@export var chase_stop_distance: float = 320.0   # Distance to STOP chasing (should be > start)
@export var min_chase_time: float = 0.4          # Minimum time to stay in chase before giving up
var _chase_time: float = 0.0                     # Time spent in current chase

# Step / small-climb settings
@export var can_step_climb: bool = true
@export var max_step_height: float = 32.0        # 1 tile by default
@export var step_check_distance: float = 12.0    # How far ahead to look for a step
@export var step_jump_force: float = 360.0       # Upward force for auto step jump (needs to clear 1 tile)
var _is_step_jumping: bool = false                # True while in air from step-climb; use jump anim instead of fall

# Attack properties
var attack_range: float = 40.0  # Distance to start attack
var attack_cooldown_timer: float = 0.0
var attack_cooldown: float = 1.5  # Time between attacks
var is_attacking: bool = false

# Air juggle optimization
@export var extended_air_float: bool = true  # Extended air float for combos
@export var air_float_duration_override: float = 0.5  # Longer float window
@export var air_float_gravity_override: float = 0.25  # Slower fall during juggle

# Store original collision layer for dynamic adjustment
var _original_collision_layer: int = 4

# Track previous frame's floor state to detect ground impact
var _was_in_air: bool = false
var _previous_velocity_y: float = 0.0  # Track velocity before landing to calculate bounce

# Bounce system for hurt enemies
var _bounce_count: int = 0  # How many times enemy has bounced
var _max_bounces: int = 1  # Maximum bounces (calculated based on fall velocity)
const MIN_BOUNCE_VELOCITY: float = 250.0  # Minimum fall velocity to trigger bounce
const HIGH_FALL_VELOCITY: float = 500.0  # Velocity threshold for 2 bounces
const BOUNCE_FORCE_MULTIPLIER: float = 0.5  # How much velocity is converted to upward bounce
var _is_bouncing: bool = false  # Track if currently bouncing
var _just_bounced: bool = false  # Prevent multiple bounces in same landing frame
var _bounce_cooldown: float = 0.0  # Cooldown to prevent rapid bounce loops
const BOUNCE_COOLDOWN_DURATION: float = 0.1  # Minimum time between bounces

# Direction change throttle to prevent flip-flopping
var _direction_change_cooldown_timer: float = 0.0
const DIRECTION_CHANGE_COOLDOWN: float = 0.2  # Minimum time between direction changes
var _last_direction: int = 1  # Track last direction

# Wall hit detection debounce to prevent animation flickering
var _wall_hit_timer: float = 0.0
const WALL_HIT_DURATION: float = 0.5  # How long to stay in "wall hit" state
var _is_wall_hit: bool = false  # Track if we're currently in wall hit state
var _backing_off_timer: float = 0.0  # Timer for backing off from wall
const BACK_OFF_DURATION: float = 0.2  # How long to back off from wall after turning
# Require wall to be "clear" for this long before exiting wall-hit (stops chase/idle flicker at ledges)
var _wall_clear_time: float = 0.0
const WALL_CLEAR_DEBOUNCE: float = 0.14

# Corner-stuck safety (prevents endless ground-hit loop on tile corners)
var _corner_stuck_timer: float = 0.0
const CORNER_STUCK_THRESHOLD: float = 0.45  # React faster so loop doesn't drag on
const CORNER_STUCK_POSITION_TOLERANCE: float = 14.0  # Consider "same place" if moved less than this
const CORNER_STUCK_VELOCITY_TOLERANCE: float = 25.0  # Consider "barely moving" if velocity below this
const CORNER_UNSTUCK_NUDGE: float = 14.0  # Pixels to push away from wall
var _last_stuck_position: Vector2 = Vector2.ZERO

# One-time spawn floor fix per enemy (prevents infinite fall hover on bad spawn positions)
var _spawn_floor_fix_applied: bool = false
var _spawn_floor_fix_time_left: float = 1.5
const SPAWN_FLOOR_RAYCAST_LENGTH: float = 320.0

# Continuous airborne safety: if alive enemy stays airborne too long, force-snap to floor
var _airborne_time: float = 0.0
const AIRBORNE_SAFETY_THRESHOLD: float = 3.0

# Ledge / attack helpers
const MAX_ATTACK_VERTICAL_DIFF: float = 40.0  # Max vertical diff to allow melee attack
const LEDGE_CHECK_DISTANCE: float = 18.0      # How far ahead to look for floor
const LEDGE_CHECK_DEPTH: float = 32.0         # How far down to raycast for floor

# Patrol wall/ledge turn debounce (prevents rapid left-right spam at walls)
var _patrol_turn_cooldown: float = 0.0
const PATROL_TURN_COOLDOWN_TIME: float = 0.25

# Ambient (visual flavor) system
@export var ambient_enabled: bool = true
@export var ambient_min_delay: float = 1.5
@export var ambient_max_delay: float = 3.0
@export_range(0.0, 1.0) var ambient_start_chance: float = 0.15
@export var ambient_spawn_grace: float = 2.0  # Short grace; don't block AI for long
var _ambient_timer: float = 0.0
var _ambient_playing: bool = false
var _ambient_anim: String = ""
var _ambient_spawn_grace_timer: float = 0.0
@export var ambient_profile_randomize: bool = true
var _ambient_profile_roll: float = -1.0

# Some enemies can be explicitly flagged (via scene or spawner) to start in ambient pose
@export var start_in_ambient_pose: bool = false

# Birbirini itme (separation): iç içe geçmeyi azaltır, duvara itmez
const SEPARATION_RADIUS: float = 90.0  # Bu mesafenin altındaki düşmanlardan itilir (erken başla)
const SEPARATION_FORCE: float = 380.0  # Saniyede ek hız (güçlü itme)
const SEPARATION_CLOSE_RADIUS: float = 35.0  # Bu kadar yakınsa ek güçlü itme
const SEPARATION_WALL_CHECK: float = 32.0  # Duvar bu mesafedeyse itme kısıtlanır

# Spawn state tracking
var _should_transition_to_patrol: bool = false  # Flag to transition to patrol after landing

# Chase blocked at wall: don't apply separation so we stay put (avoids push-away then run-again loop)
var _chase_blocked_at_wall: bool = false
# Debounce: stay "blocked" briefly after wall is no longer detected (stops sit->chase->idle flicker)
var _chase_blocked_clear_timer: float = 0.0
const CHASE_BLOCKED_CLEAR_TIME: float = 0.4

# After corner-stuck forces patrol, briefly don't re-enter chase (stops attack->patrol->chase loop at wall)
var _chase_after_wall_cooldown: float = 0.0
var _chase_cooldown_just_set: bool = false  # Skip decrement on first patrol frame so chase is blocked
const CHASE_AFTER_WALL_COOLDOWN_TIME: float = 1.8

# Debug chase/wall loop (enable in Inspector under Basic Enemy)
@export var debug_chase_wall: bool = false
var _debug_chase_timer: float = 0.0
const _DEBUG_CHASE_INTERVAL: float = 0.25
var _debug_was_blocked_last_frame: bool = false

func _ready() -> void:
	super._ready()
	# Initialize bounce variables
	_bounce_count = 0
	_max_bounces = 1
	_is_bouncing = false
	_just_bounced = false
	_bounce_cooldown = 0.0
	# Initialize wall hit variables
	_backing_off_timer = 0.0
	_corner_stuck_timer = 0.0
	_last_stuck_position = global_position
	
	# Ensure chase stop distance is never smaller than start distance
	if chase_stop_distance < chase_start_distance:
		chase_stop_distance = chase_start_distance + 40.0
	
	# NOTE: Rely on spawners/level generator to place enemies on the floor.
	# Extra floor raycasts here caused double-snapping and hover issues in some chunks.
	# Initialize floor tracking based on current position.
	_was_in_air = not is_on_floor()
	
	# Initialize direction tracking
	_last_direction = direction
	_direction_change_cooldown_timer = 0.0
	
	# Initialize wall hit tracking
	_is_wall_hit = false
	_wall_hit_timer = 0.0
	
	# IMPORTANT: Ensure hurtbox signal connects to our override (not base class)
	# In Godot, virtual functions are automatically overridden, but we need to ensure
	# the signal connection uses our version. BaseEnemy connects in its _ready,
	# so we reconnect after super._ready() to ensure our override is used.
	if hurtbox and hurtbox.has_signal("hurt"):
		# Disconnect any existing connections
		if hurtbox.hurt.get_connections().size() > 0:
			for connection in hurtbox.hurt.get_connections():
				hurtbox.hurt.disconnect(connection.callable)
		# Connect to our override function
		if not hurtbox.hurt.is_connected(_on_hurtbox_hurt):
			hurtbox.hurt.connect(_on_hurtbox_hurt)
	
	# Override air float settings for better juggling
	if extended_air_float:
		air_float_duration = air_float_duration_override
		air_float_gravity_scale = air_float_gravity_override
	
	# CRITICAL: Connect to animation signals to prevent fall animation from playing
	# when hurt animations finish or change
	if sprite:
		if sprite.has_signal("animation_finished"):
			if not sprite.animation_finished.is_connected(_on_animation_finished):
				sprite.animation_finished.connect(_on_animation_finished)
		# Also connect to animation_changed to catch when BaseEnemy tries to play "hurt"
		if sprite.has_signal("animation_changed"):
			if not sprite.animation_changed.is_connected(_on_animation_changed):
				sprite.animation_changed.connect(_on_animation_changed)
		air_float_max_fall_speed = 200.0  # Slower max fall speed
	
	# Ensure collision mask includes WORLD and PLATFORM layers
	# collision_mask should be: WORLD (1) + PLATFORM (512) = 513
	# Make sure we collide with tiles/platforms
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	set_collision_mask_value(1, true)  # WORLD layer
	set_collision_mask_value(10, true)  # PLATFORM layer (bit 10)
	
	# Store original collision layer for dynamic adjustment
	_original_collision_layer = collision_layer

	# Optional: per-enemy ambient "personality" so everyone oturup kalkmasın
	if ambient_profile_randomize:
		_ambient_profile_roll = randf()
		if _ambient_profile_roll < 0.6:
			# Pure patrol guard (~60%): never uses ambient
			ambient_enabled = false
		elif _ambient_profile_roll < 0.85:
			# Chill ama çok tembel değil (~25%): ara sıra oturur
			ambient_enabled = true
			ambient_start_chance = 0.25
			ambient_min_delay = 4.0
			ambient_max_delay = 8.0
		else:
			# Tam tembel (~15%): sık sık oturur / yatar
			ambient_enabled = true
			ambient_start_chance = 0.6
			ambient_min_delay = 2.0
			ambient_max_delay = 4.0
	
	# Initialize ambient timer
	_reset_ambient_timer()
	
	# Set up patrol points around spawn position
	var initial_pos = global_position
	if initial_pos != Vector2.ZERO:
		patrol_point_left = initial_pos.x - patrol_range
		patrol_point_right = initial_pos.x + patrol_range
	
	if debug_enabled or debug_chase_wall:
		print("[BasicEnemy] Debug ENABLED | name=%s path=%s" % [name, get_path()])
	
	# Spawn debug: log ambient-related configuration for this enemy instance
	if debug_enabled:
		var scene_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		print("[BasicEnemy][Spawn] pos=%s scene=%s ambient_enabled=%s start_chance=%.2f start_in_ambient_pose=%s" % [
			str(global_position),
			scene_path,
			str(ambient_enabled),
			ambient_start_chance,
			str(start_in_ambient_pose),
		])
	
	# Pool nesneleri (0,0)'da _ready çalıştırır; snap/floor kontrolü yapmadan patrol'e geç.
	# Gerçek pozisyona taşındığında _physics_process gravity + floor_snap ile halleder.
	current_behavior = "patrol"
	if sprite:
		sprite.play("idle")
	behavior_timer = 0.0

	# Optionally start some enemies already sitting/relaxed when the scene loads.
	# This can be forced via start_in_ambient_pose, or random via ambient_start_chance.
	var want_ambient_start: bool = start_in_ambient_pose
	if not want_ambient_start and ambient_enabled and ambient_start_chance > 0.0:
		var roll := randf()
		if roll < ambient_start_chance:
			want_ambient_start = true
		print("[BasicEnemy][Ambient] spawn roll=%.2f chance=%.2f -> %s" % [roll, ambient_start_chance, str(want_ambient_start)])
	else:
		print("[BasicEnemy][Ambient] spawn flag start_in_ambient_pose=%s" % [str(start_in_ambient_pose)])
	if want_ambient_start:
		print("[BasicEnemy][Ambient] starting in ambient pose at %s" % [str(global_position)])
		_start_initial_ambient_pose()
		_ambient_spawn_grace_timer = ambient_spawn_grace
		_should_transition_to_patrol = false
	
	# Basic enemy has simple collision - smaller than heavy enemy
	# Collision shape is set in scene file

# Spawn fall fix: aşağıda zemin varsa zemine snap'le. _physics_process'ten çağrılır.
func _try_spawn_floor_snap() -> bool:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	var from_pos: Vector2 = global_position
	var to_pos: Vector2 = global_position + Vector2.DOWN * SPAWN_FLOOR_RAYCAST_LENGTH
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		if debug_enabled:
			print("[BasicEnemy][SpawnFloorFix] no hit (level=%s) from=%s to=%s" % [
				str(get_meta("spawned_level") if has_meta("spawned_level") else "unknown"),
				str(from_pos),
				str(to_pos),
			])
		return false
	# Ignore non-floor hits (normali yukarı bakmayan yüzeyler), duvar i&ccedil;i snap'leri engelle
	var normal: Vector2 = result.normal
	if normal.y <= 0.5:
		if debug_enabled:
			print("[BasicEnemy][SpawnFloorFix] non-floor normal=%s, skipping (level=%s from=%s to=%s)" % [
				str(normal),
				str(get_meta("spawned_level") if has_meta("spawned_level") else "unknown"),
				str(from_pos),
				str(to_pos),
			])
		return false
	# Compute vertical offset from our own collision shape instead of magic 32 px
	var feet_offset: float = 32.0
	var col_shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape_node and col_shape_node.shape:
		var shape := col_shape_node.shape
		if shape is CapsuleShape2D:
			var cap := shape as CapsuleShape2D
			feet_offset = cap.height * 0.5
		elif shape is RectangleShape2D:
			var rect := shape as RectangleShape2D
			feet_offset = rect.size.y * 0.5
	var hit_pos: Vector2 = result.position
	global_position = hit_pos - Vector2(0, feet_offset)
	velocity = Vector2.ZERO
	move_and_slide()
	if debug_enabled:
		print("[BasicEnemy][SpawnFloorFix] level=%s from=%s hit=%s offset=%.1f to=%s floor=%s" % [
			str(get_meta("spawned_level") if has_meta("spawned_level") else "unknown"),
			str(from_pos),
			str(hit_pos),
			feet_offset,
			str(global_position),
			is_on_floor(),
		])
	return true

func handle_behavior(delta: float) -> void:
	"""Override BaseEnemy's handle_behavior to prevent fall animation in hurt state,
	while still preserving base detection/behavior timer semantics."""
	if is_sleeping:
		return
	
	# Advance behavior timer like in BaseEnemy
	behavior_timer += delta
	
	# Update target detection each frame (needed for chase + ambient cancel)
	# Keep this simple and robust: always use detection range, don't hard-block with spawn grace.
	target = get_nearest_player_in_range()
	
	# Dead corpses: don't run normal behavior, let physics/juggle handle them
	if current_behavior == "dead":
		return
	
	# Hurt veya ölüme giderken (henüz dead değil) hurt mantığı
	if current_behavior == "hurt" or health <= 0:
		handle_hurt_behavior(delta)
		return
	
	# Patrol / chase / attack logic
	_handle_child_behavior(delta)

func _handle_child_behavior(delta: float) -> void:
	if is_sleeping:
		return
	
	# IMPORTANT: Don't process patrol/chase/attack if dead or dying
	# Dead enemies should stay in hurt state until they hit ground
	if health <= 0 and current_behavior != "hurt" and current_behavior != "dead":
		# Force hurt state for dead enemies
		current_behavior = "hurt"
		behavior_timer = 0.0
		
	match current_behavior:
		"patrol":
			# Don't patrol if dead
			if health <= 0:
				return
			handle_patrol(delta)
			if is_on_floor() and not _is_wall_hit and _backing_off_timer <= 0.0:
				_apply_separation(delta)
			_process_ambient(delta)
		"idle":
			# Idle state - check if we should transition to patrol (spawn landing)
			if _should_transition_to_patrol and is_on_floor():
				_should_transition_to_patrol = false
				current_behavior = "patrol"
				if sprite:
					sprite.play("idle")
				behavior_timer = 0.0
			elif not _should_transition_to_patrol:
				# Normal idle - transition to patrol
				current_behavior = "patrol"
				if sprite:
					sprite.play("idle")
				behavior_timer = 0.0
		"chase":
			# Don't chase if dead
			if health <= 0:
				return
			handle_chase(delta)
			var do_separation: bool = is_on_floor() and not _is_wall_hit and _backing_off_timer <= 0.0 and not _chase_blocked_at_wall
			if do_separation:
				_apply_separation(delta)
			if debug_enabled or debug_chase_wall:
				_debug_chase_timer += delta
				if _debug_chase_timer >= _DEBUG_CHASE_INTERVAL:
					_debug_chase_timer = 0.0
					print("[BasicEnemy] chase | sep=%s blocked=%s on_wall=%s vel.x=%.0f anim=%s" % [do_separation, _chase_blocked_at_wall, is_on_wall(), velocity.x, sprite.animation if sprite else "n/a"])
		"attack":
			# Don't attack if dead
			if health <= 0:
				return
			handle_attack(delta)
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			return

func _has_floor_ahead(dir: int) -> bool:
	if dir == 0:
		return true
	var start := global_position + Vector2(dir * LEDGE_CHECK_DISTANCE, 0)
	var end := start + Vector2(0, LEDGE_CHECK_DEPTH)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(start, end)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var result := space_state.intersect_ray(query)
	return not result.is_empty()

func _process_ambient(delta: float) -> void:
	if not ambient_enabled or not sprite:
		return
	
	# Count down initial spawn grace timer (while enemy is allowed to ignore detection)
	if _ambient_spawn_grace_timer > 0.0:
		_ambient_spawn_grace_timer = max(0.0, _ambient_spawn_grace_timer - delta)
	
	# If we're playing an ambient anim but state is no longer safe, cancel it.
	if _ambient_playing:
		var unsafe := current_behavior != "patrol" or not is_on_floor() \
			or (_ambient_spawn_grace_timer <= 0.0 and target != null)
		if unsafe:
			print("[BasicEnemy][Ambient] CANCEL ambient anim=%s reason=unsafe state=%s" % [_ambient_anim, current_behavior])
			_ambient_playing = false
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
			return
		
		# If ambient animation finished or changed, exit ambient mode.
		if not sprite.is_playing() or sprite.animation != _ambient_anim:
			_ambient_playing = false
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
		return
	
	# Only consider starting ambient in patrol, when truly relaxed.
	if current_behavior != "patrol":
		_ambient_timer = 0.0
		return
	
	# Ambient should depend on player distance, not full detection range.
	# Compute a local distance to the nearest player and require them to be "far enough".
	var player := get_nearest_player()
	var player_far_enough := true
	if player:
		var dist := global_position.distance_to(player.global_position)
		var block_radius := 180.0  # Within ~3 tiles, don't sit
		player_far_enough = dist > block_radius
		if debug_enabled and Engine.get_physics_frames() % 180 == 0:
			print("[BasicEnemy][Ambient] dist=%.1f block_radius=%.1f far_enough=%s state=%s vel=%.1f" % [
				dist, block_radius, str(player_far_enough), current_behavior, velocity.x,
			])
	
	# In dungeon, patrol hızı zaten sabit (~movement_speed*0.7). Burada ekstra yavaşlama
	# şartı koymak ambient'i neredeyse imkânsız hale getiriyor. Güvenlik için sadece:
	# zeminde ol, duvarda olma, oyuncu uzakta olsun yeter.
	var safe_for_ambient: bool = is_on_floor() \
		and not is_on_wall() \
		and player_far_enough
	
	if not safe_for_ambient:
		if debug_enabled and Engine.get_physics_frames() % 240 == 0:
			print("[BasicEnemy][Ambient] NOT SAFE (floor=%s wall=%s far=%s vel=%.1f state=%s)" % [
				str(is_on_floor()),
				str(is_on_wall()),
				str(player_far_enough),
				velocity.x,
				current_behavior,
			])
		_ambient_timer = 0.0
		return
	
	if _ambient_timer > 0.0:
		_ambient_timer -= delta
		return
	
	# Choose an ambient animation if available
	var options: Array = []
	if sprite.sprite_frames.has_animation("sit"):
		options.append("sit")
	if sprite.sprite_frames.has_animation("sit2"):
		options.append("sit2")
	if sprite.sprite_frames.has_animation("sit3"):
		options.append("sit3")
	if sprite.sprite_frames.has_animation("lay"):
		options.append("lay")
	
	if options.is_empty():
		_reset_ambient_timer()
		return
	
	_ambient_anim = options[randi() % options.size()]
	print("[BasicEnemy][Ambient] START ambient anim=%s at %s" % [_ambient_anim, str(global_position)])
	sprite.play(_ambient_anim)
	_ambient_playing = true
	_reset_ambient_timer()

func _reset_ambient_timer() -> void:
	# Ensure valid range
	if ambient_max_delay <= ambient_min_delay:
		ambient_max_delay = ambient_min_delay + 1.0
	_ambient_timer = randf_range(ambient_min_delay, ambient_max_delay)

func _start_initial_ambient_pose() -> void:
	if not sprite:
		return
	
	# Reuse the same ambient options logic
	var options: Array = []
	if sprite.sprite_frames.has_animation("sit"):
		options.append("sit")
	if sprite.sprite_frames.has_animation("sit2"):
		options.append("sit2")
	if sprite.sprite_frames.has_animation("sit3"):
		options.append("sit3")
	if sprite.sprite_frames.has_animation("lay"):
		options.append("lay")
	
	if options.is_empty():
		return
	
	_ambient_anim = options[randi() % options.size()]
	sprite.play(_ambient_anim)
	_ambient_playing = true

func _apply_separation(delta: float) -> void:
	var tree = get_tree()
	if not tree:
		return
	var my_pos = global_position
	var push_x := 0.0
	for node in tree.get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node):
			continue
		if node.get("current_behavior") == "dead":
			continue
		var other_pos = node.global_position
		var d = my_pos.distance_to(other_pos)
		if d <= 0.0 or d > SEPARATION_RADIUS:
			continue
		var away = (my_pos - other_pos).normalized()
		var strength = 1.0 - (d / SEPARATION_RADIUS)
		if d < SEPARATION_CLOSE_RADIUS:
			strength += 1.2
		push_x += away.x * strength
	if abs(push_x) < 0.01:
		return
	var sep_speed = sign(push_x) * min(abs(push_x) * SEPARATION_FORCE, SEPARATION_FORCE)
	var space = get_world_2d().direct_space_state
	var check_pos = my_pos + Vector2(sign(sep_speed) * SEPARATION_WALL_CHECK, 0.0)
	var query = PhysicsRayQueryParameters2D.create(my_pos, check_pos)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit = space.intersect_ray(query)
	var scale := 1.0
	if not hit.is_empty():
		var wall_dist = my_pos.distance_to(hit.position)
		if wall_dist <= 10.0:
			scale = 0.0
		else:
			scale = (wall_dist - 10.0) / (SEPARATION_WALL_CHECK - 10.0)
			scale = clamp(scale, 0.0, 1.0)
	velocity.x += sep_speed * delta * scale
	var base_speed = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
	var max_speed = base_speed * 1.8
	if abs(velocity.x) > max_speed:
		velocity.x = sign(velocity.x) * max_speed

func handle_patrol(delta: float) -> void:
	# Don't patrol if dead
	if health <= 0:
		return
	
	# If an ambient animation is playing, stay in place and let ambient system drive the sprite.
	if _ambient_playing:
		velocity.x = 0
		return
	
	# Cooldown for patrol wall/ledge turns (prevents rapid left-right flicker)
	if _patrol_turn_cooldown > 0.0:
		_patrol_turn_cooldown = max(0.0, _patrol_turn_cooldown - delta)
	
	# Check if we should transition to patrol (after landing from spawn)
	if _should_transition_to_patrol and is_on_floor():
		_should_transition_to_patrol = false
		current_behavior = "patrol"
		if sprite:
			sprite.play("idle")
		behavior_timer = 0.0
		return
	
	# If still in air and should transition, wait
	if _should_transition_to_patrol:
		return
		
	behavior_timer += delta
	
	# Update sprite direction
	update_sprite_direction()
	
	# After being forced to patrol from wall/corner-stuck, wait before re-entering chase
	if _chase_after_wall_cooldown > 0.0:
		if _chase_cooldown_just_set:
			_chase_cooldown_just_set = false  # First patrol frame: block chase, don't decrement yet
		else:
			_chase_after_wall_cooldown -= delta
	
	# Check for player first (with hysteresis-aware target selection) - never chase while cooldown active
	target = _get_chase_target()
	if target and _chase_after_wall_cooldown <= 0.0:
		change_behavior("chase")
		return
	
	# Only patrol if on floor; in air during step-climb drift forward
	if not is_on_floor():
		if _is_step_jumping:
			var drift_speed = (stats.movement_speed if stats else 80.0) * 0.6
			velocity.x = direction * drift_speed
		else:
			velocity.x = move_toward(velocity.x, 0, (stats.movement_speed if stats else 80.0) * delta)
		return
	
	# Determine target patrol point
	var target_x = patrol_point_right if direction > 0 else patrol_point_left
	var at_patrol_point = abs(global_position.x - target_x) < 15
	
	if at_patrol_point:
		# At patrol point, wait a bit. Skip sit when we just left wall (avoids sit-then-chase when turning)
		velocity.x = 0
		_play_idle_or_sit(_chase_after_wall_cooldown <= 0.0)
		
		# After waiting, turn around
		if behavior_timer >= patrol_wait_time:
			direction *= -1
			if sprite:
				sprite.flip_h = direction < 0
			behavior_timer = 0.0
	else:
		# Simple wall/ledge-aware patrol movement
		var move_speed = (stats.movement_speed if stats else 80.0) * 0.7
		var currently_on_wall = is_on_wall()
		var has_floor_ahead = _has_floor_ahead(direction)
		
		# Treat ledge (no floor ahead) always as a hard boundary.
		var boundary_hit: bool = not has_floor_ahead
		
		# For real walls, first try step-climb; only if that fails, treat as boundary.
		if currently_on_wall and has_floor_ahead:
			if _try_step_climb():
				# Successful 1-tile step climb; let gravity/physics handle movement this frame.
				return
			boundary_hit = true
		
		# Treat wall or ledge edge as a patrol boundary, but only flip direction
		# when cooldown has expired to avoid rapid left-right spam.
		if boundary_hit and _patrol_turn_cooldown <= 0.0:
			direction *= -1
			if sprite:
				sprite.flip_h = direction < 0
			_patrol_turn_cooldown = PATROL_TURN_COOLDOWN_TIME
			
			# Reset any wall-related state so patrol doesn't get stuck
			_is_wall_hit = false
			_backing_off_timer = 0.0
			_wall_hit_timer = 0.0
			_wall_clear_time = 0.0
			behavior_timer = 0.0
		
		# Always try to walk in the current patrol direction; move_and_slide/ledge check
		# plus the boundary flip above will keep us within safe bounds.
		velocity.x = direction * move_speed
		if sprite and sprite.animation != "walk":
			sprite.play("walk")

func handle_chase(delta: float) -> void:
	# Don't chase if dead
	if health <= 0:
		return
		
	# Track time spent in chase (for min_chase_time)
	_chase_time += delta
		
	# Update attack cooldown
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	
	# Get current target with hysteresis-aware logic
	target = _get_chase_target()
	
	if not target:
		# Lost target - optionally keep chasing a bit to avoid flicker
		if _chase_time < min_chase_time:
			# Keep moving in current direction for a short grace period
			if is_on_floor():
				var chase_speed_grace = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
				velocity.x = direction * chase_speed_grace
			return
		
		# Grace period over, return to patrol
		change_behavior("patrol")
		return
	
	# Calculate direction to player (needed for both direction update and backing off)
	var dir_to_player = sign(target.global_position.x - global_position.x)
	
	# Check if we're in attack range (with buffer distance for better feel)
	# Smarter melee: only attack when player is roughly on same vertical level and in front
	var distance_to_target = global_position.distance_to(target.global_position)
	var attack_range_with_buffer = attack_range + 30.0  # Add 30px buffer for better attack start
	var vertical_diff = abs(target.global_position.y - global_position.y)
	var facing_player = (dir_to_player == direction and dir_to_player != 0)
	if distance_to_target <= attack_range_with_buffer \
			and attack_cooldown_timer <= 0.0 \
			and is_on_floor() \
			and not _chase_blocked_at_wall \
			and vertical_diff <= MAX_ATTACK_VERTICAL_DIFF \
			and facing_player:
		change_behavior("attack")
		return
	
	# Update direction cooldown timer
	_direction_change_cooldown_timer = max(0.0, _direction_change_cooldown_timer - delta)
	
	# Check if we're on wall - if so, don't update direction (prevent flickering)
	var is_in_wall_hit_state = _is_wall_hit or _backing_off_timer > 0.0
	
	# Only update direction if not stuck on wall
	if not is_in_wall_hit_state:
		# Update direction towards player with throttle to prevent flip-flopping
		
		# Only change direction if:
		# 1. Player is not directly above/below (horizontal distance > threshold)
		# 2. Enough time has passed since last direction change
		# 3. Direction actually changed
		var horizontal_distance = abs(target.global_position.x - global_position.x)
		
		# If player is directly above/below (horizontal distance < 30px), don't change direction
		if horizontal_distance > 30.0 and dir_to_player != 0:
			# Check if direction actually changed and cooldown passed
			if dir_to_player != _last_direction and _direction_change_cooldown_timer <= 0.0:
				direction = dir_to_player
				_last_direction = direction
				_direction_change_cooldown_timer = DIRECTION_CHANGE_COOLDOWN  # Reset cooldown
				if sprite:
					sprite.flip_h = direction < 0
			elif dir_to_player == _last_direction:
				# Same direction, just update sprite flip (only if not already correct)
				if sprite and sprite.flip_h != (direction < 0):
					sprite.flip_h = direction < 0
	
	# Move towards player (only if on floor)
	if is_on_floor():
		# Update timers
		_wall_hit_timer = max(0.0, _wall_hit_timer - delta)
		_backing_off_timer = max(0.0, _backing_off_timer - delta)
		
		# Check if we hit a wall - use debounce to prevent flickering
		var currently_on_wall = is_on_wall()
		if currently_on_wall:
			_wall_clear_time = 0.0
			_chase_blocked_clear_timer = CHASE_BLOCKED_CLEAR_TIME  # Reset debounce while on wall
		else:
			_wall_clear_time += delta
			_chase_blocked_clear_timer -= delta
			if _chase_blocked_clear_timer <= 0.0:
				_chase_blocked_at_wall = false
		
		# If we're backing off from wall, don't check for new wall hits
		if _backing_off_timer > 0.0:
			# Backing off - move away from wall
			var chase_speed = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
			velocity.x = direction * chase_speed * 0.5  # Slower when backing off
			if _is_blocked_cannot_move_forward():
				# In chase, never sit when blocked; just idle
				_play_idle_or_sit(false)
			elif sprite:
				if sprite.sprite_frames.has_animation("chase"):
					sprite.play("chase")
				else:
					sprite.play("walk")
			# Once we're no longer on wall, exit backing off state and update direction to player
			if not currently_on_wall:
				_backing_off_timer = 0.0
				_is_wall_hit = false
				_wall_hit_timer = 0.0
				# Reset direction cooldown and update direction to player immediately
				_direction_change_cooldown_timer = 0.0
				_last_direction = 0  # Reset to force direction update
				# Update direction to face player (use existing dir_to_player from above)
				if dir_to_player != 0:
					direction = dir_to_player
					_last_direction = direction
					if sprite:
						sprite.flip_h = direction < 0
		elif currently_on_wall:
			# If player is behind us (other side of wall / below), turn and move — don't stay blocked
			if dir_to_player != 0 and dir_to_player != direction:
				_chase_blocked_at_wall = false
				_chase_blocked_clear_timer = 0.0
				_direction_change_cooldown_timer = 0.0
				direction = dir_to_player
				_last_direction = direction
				if sprite:
					sprite.flip_h = direction < 0
				var chase_speed = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
				velocity.x = direction * chase_speed
				_debug_was_blocked_last_frame = false
				return
			# First, try to climb a small step (1 tile) instead of treating as full wall
			if _try_step_climb():
				_is_wall_hit = false
				_wall_hit_timer = 0.0
				_backing_off_timer = 0.0
				return
			# Chase blocked at wall (can't reach player): stay put, idle only (no sit, no separation push)
			_chase_blocked_at_wall = true
			_chase_blocked_clear_timer = CHASE_BLOCKED_CLEAR_TIME
			_is_wall_hit = false
			_wall_hit_timer = 0.0
			_backing_off_timer = 0.0
			velocity.x = 0
			_play_idle_or_sit(false)
			if (debug_enabled or debug_chase_wall) and not _debug_was_blocked_last_frame:
				print("[BasicEnemy] CHASE BLOCKED AT WALL (idle, no separation)")
			_debug_was_blocked_last_frame = true
			if sprite and sprite.flip_h != (direction < 0):
				sprite.flip_h = direction < 0
			return
		else:
			# Not blocked - only exit wall-hit after debounce to prevent ledge flicker
			_debug_was_blocked_last_frame = false
			# Stay idle while chase-blocked debounce is active (stops sit->run->idle flicker at wall)
			if _chase_blocked_at_wall:
				velocity.x = 0
				_play_idle_or_sit(false)
			elif _wall_clear_time >= WALL_CLEAR_DEBOUNCE:
				_is_wall_hit = false
				_wall_hit_timer = 0.0
				_backing_off_timer = 0.0
				if _is_blocked_cannot_move_forward():
					# In chase, when blocked while trying to move, use idle (no sit flicker)
					_play_idle_or_sit(false)
				elif sprite and sprite.animation != "chase":
					if sprite.sprite_frames.has_animation("chase"):
						sprite.play("chase")
					else:
						sprite.play("walk")
				var chase_speed = (stats.movement_speed if stats else 80.0) * chase_speed_multiplier
				velocity.x = direction * chase_speed
			else:
				# Still in debounce: keep idle/sit so we don't flicker
				velocity.x = 0
				# In chase, debounce near wall should be idle only
				_play_idle_or_sit(false)
	else:
		# In air: during step-climb drift forward so we clear the ledge; otherwise slow down
		if _is_step_jumping:
			var drift_speed = (stats.movement_speed if stats else 80.0) * 0.7
			velocity.x = direction * drift_speed
		else:
			velocity.x = move_toward(velocity.x, 0, (stats.movement_speed if stats else 80.0) * delta)
		# Ensure fall animation is NOT playing when in chase state and in air
		if sprite and sprite.animation == "fall":
			sprite.stop()

func handle_attack(delta: float) -> void:
	behavior_timer += delta
	
	# CRITICAL: Don't attack if in air or hurt state - enemy can't attack while being juggled
	if not is_on_floor() or current_behavior == "hurt" or health <= 0:
		# Disable hitbox immediately if we're in air or hurt
		if hitbox:
			hitbox.disable()
		is_attacking = false
		# Return to appropriate state
		if health <= 0:
			change_behavior("hurt")
		elif not is_on_floor():
			change_behavior("hurt")
		else:
			if target:
				change_behavior("chase")
			else:
				change_behavior("patrol")
		return
	
	# Apply forward momentum during attack (lunge forward)
	var attack_lunge_speed = 120.0  # Forward lunge speed
	velocity.x = direction * attack_lunge_speed
	
	# Play attack animation if available
	if sprite:
		if sprite.sprite_frames.has_animation("attack"):
			if sprite.animation != "attack":
				sprite.play("attack")
				is_attacking = true
		else:
			# No attack animation, just use idle
			if sprite.animation != "idle":
				sprite.play("idle")
			is_attacking = true  # Set attacking flag even without animation
	
	# Enable hitbox during attack (only if on floor and not hurt)
	if hitbox and is_on_floor() and current_behavior != "hurt" and health > 0:
		# Position hitbox in front of enemy
		hitbox.position.x = 20 * direction  # 20 pixels in front
		hitbox.position.y = 0
		
		if sprite and sprite.sprite_frames.has_animation("attack"):
			# Attack animation exists - enable hitbox at the right frame
			var frame_count = sprite.sprite_frames.get_frame_count("attack")
			var current_frame = sprite.frame
			if current_frame >= 1 and current_frame <= frame_count - 1:
				if not hitbox.is_enabled():
					hitbox.damage = stats.attack_damage if stats else 5.0
					hitbox.knockback_force = 150.0
					hitbox.knockback_up_force = 50.0
					hitbox.enable()
			else:
				if hitbox.is_enabled():
					hitbox.disable()
		else:
			# No attack animation, enable hitbox briefly (0.1s to 0.3s)
			if behavior_timer >= 0.1 and behavior_timer <= 0.3:
				if not hitbox.is_enabled():
					hitbox.damage = stats.attack_damage if stats else 5.0
					hitbox.knockback_force = 150.0
					hitbox.knockback_up_force = 50.0
					hitbox.enable()
			elif hitbox.is_enabled() and behavior_timer > 0.3:
				hitbox.disable()
	
	# Check if attack animation finished
	if sprite and sprite.sprite_frames.has_animation("attack"):
		if not sprite.is_playing() or sprite.frame >= sprite.sprite_frames.get_frame_count("attack") - 1:
			# Attack finished
			is_attacking = false
			if hitbox:
				hitbox.disable()
			attack_cooldown_timer = attack_cooldown
			
			# Return to chase or patrol
			if target:
				change_behavior("chase")
			else:
				change_behavior("patrol")
	else:
		# No attack animation, just wait a bit
		if behavior_timer >= 0.5:  # Short attack duration
			is_attacking = false
			if hitbox:
				hitbox.disable()
			attack_cooldown_timer = attack_cooldown
			
			if target:
				change_behavior("chase")
			else:
				change_behavior("patrol")

func handle_hurt_behavior(delta: float) -> void:
	# Ölü ceset burada işlenmez (handle_behavior'da dead ise çağrılmıyor); yine de güvenlik
	if current_behavior == "dead":
		return
	behavior_timer += delta
	_bounce_cooldown = max(0.0, _bounce_cooldown - delta)
	if sprite and sprite.animation == "fall":
		sprite.stop()
	# Ölü ama hâlâ havada - yere çarpmayı bekle (punching bag)
	if health <= 0 and not is_on_floor():
		# Keep playing hurt animations until we hit ground
		# Keep hurtbox enabled so player can keep hitting (punching bag)
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true
		
		# Check for wall bounce (dead enemies can bounce off walls)
		if is_on_wall():
			# Bounce off wall - reverse horizontal velocity
			var wall_bounce_force = abs(velocity.x) * 0.6  # 60% of horizontal velocity
			velocity.x = -velocity.x * 0.6  # Reverse and reduce
			# Small upward component for visual interest
			if velocity.y > -50.0:  # Only if not already rising fast
				velocity.y = min(velocity.y, -100.0)  # Small upward boost
		
		if not is_on_floor():
			# CRITICAL: Stop fall animation immediately if it's playing
			if sprite and sprite.animation == "fall":
				sprite.stop()
			# In air - check if rising or falling
			# Use a smaller threshold to detect falling more accurately
			# IMPORTANT: Always play hurt animations when dead in air, never fall animation
			if velocity.y < -10.0:
				# Rising - play hurt_rise
				if sprite and sprite.sprite_frames.has_animation("hurt_rise"):
					# Force hurt_rise animation - don't let fall animation override
					if sprite.animation != "hurt_rise":
						sprite.play("hurt_rise")
			else:
				# Falling (or very slow upward) - play hurt_fall
				if sprite and sprite.sprite_frames.has_animation("hurt_fall"):
					# Force hurt_fall animation - don't let fall animation override
					if sprite.animation != "hurt_fall":
						sprite.play("hurt_fall")
		
		# Apply gravity and wait for ground impact
		# Don't exit hurt state until we hit ground
		# Don't apply horizontal damping when dead in air - let player juggle freely
		_was_in_air = true  # Track that we were in air
		return
	
	# Check if we just hit ground (was in air, now on ground)
	# IMPORTANT: Only check bounce if we weren't just bouncing and cooldown expired
	if _was_in_air and is_on_floor() and not _just_bounced and _bounce_cooldown <= 0.0:
		# Just landed - check fall velocity for bounce
		var fall_velocity = abs(_previous_velocity_y)
		
		# Determine max bounces based on fall velocity
		if fall_velocity >= HIGH_FALL_VELOCITY:
			_max_bounces = 2  # High fall = 2 bounces
		elif fall_velocity >= MIN_BOUNCE_VELOCITY:
			_max_bounces = 1  # Medium fall = 1 bounce
		else:
			_max_bounces = 0  # Low fall = no bounce
		
		# Check if we should bounce
		if health <= 0 and fall_velocity >= MIN_BOUNCE_VELOCITY and _bounce_count < _max_bounces:
			# Dead but should bounce - play ground hurt and bounce
			_bounce_count += 1
			_is_bouncing = true
			_just_bounced = true  # Set flag to prevent immediate re-trigger
			_bounce_cooldown = BOUNCE_COOLDOWN_DURATION  # Set cooldown
			behavior_timer = 0.0
			
			# Play ground hurt animation
			if sprite and sprite.sprite_frames.has_animation("hurt_ground"):
				sprite.play("hurt_ground")
			
			# Calculate bounce force based on fall velocity
			var bounce_force = fall_velocity * BOUNCE_FORCE_MULTIPLIER
			# Cap bounce force for gameplay feel
			bounce_force = min(bounce_force, 400.0)
			velocity.y = -bounce_force  # Apply upward bounce
			
			# Small horizontal bounce variation for visual interest
			velocity.x *= 0.5  # Reduce horizontal velocity on bounce
			
			_was_in_air = true  # Still in air after bounce
			return
		elif health <= 0:
			# Dead and no more bounces - play death animation
			_just_bounced = false  # Reset flag
			die()
			return
		else:
			# Alive - play ground impact animation
			if sprite:
				if sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
					behavior_timer = 0.0  # Reset timer for ground animation
				elif sprite.sprite_frames.has_animation("get_up"):
					sprite.play("get_up")
					behavior_timer = 0.0  # Reset timer for get_up animation
			_was_in_air = false
			_is_bouncing = false
			_just_bounced = false  # Reset flag
	
	# Normal hurt behavior (not dead)
	# Determine which hurt animation to play based on velocity
	# IMPORTANT: Always play hurt animations when in hurt state, never fall animation
	if not is_on_floor():
		# Check for wall bounce (hurt enemies can bounce off walls)
		if is_on_wall():
			# Bounce off wall - reverse horizontal velocity
			var wall_bounce_force = abs(velocity.x) * 0.6  # 60% of horizontal velocity
			velocity.x = -velocity.x * 0.6  # Reverse and reduce
			# Small upward component for visual interest
			if velocity.y > -50.0:  # Only if not already rising fast
				velocity.y = min(velocity.y, -100.0)  # Small upward boost
		
		# CRITICAL: Stop fall animation immediately if playing (check every frame)
		if sprite:
			if sprite.animation == "fall":
				sprite.stop()
			# In air - check if rising or falling
			# Use a smaller threshold to detect falling more accurately
			if velocity.y < -10.0:
				# Rising - play hurt_rise
				if sprite.sprite_frames.has_animation("hurt_rise"):
					if sprite.animation != "hurt_rise":
						sprite.play("hurt_rise")
			else:
				# Falling (or very slow upward) - play hurt_fall
				if sprite.sprite_frames.has_animation("hurt_fall"):
					if sprite.animation != "hurt_fall":
						sprite.play("hurt_fall")
		_was_in_air = true  # Track that we're in air
	else:
		# On ground - check if we just landed (was in air, now on ground)
		# IMPORTANT: Only check bounce if we weren't just bouncing and cooldown expired
		if _was_in_air and not _just_bounced and _bounce_cooldown <= 0.0:
			# Just hit ground - check fall velocity for bounce
			var fall_velocity = abs(_previous_velocity_y)
			
			# Determine max bounces based on fall velocity
			if fall_velocity >= HIGH_FALL_VELOCITY:
				_max_bounces = 2  # High fall = 2 bounces
			elif fall_velocity >= MIN_BOUNCE_VELOCITY:
				_max_bounces = 1  # Medium fall = 1 bounce
			else:
				_max_bounces = 0  # Low fall = no bounce
			
			# Check if we should bounce
			if health <= 0 and fall_velocity >= MIN_BOUNCE_VELOCITY and _bounce_count < _max_bounces:
				# Dead but should bounce - play ground hurt and bounce
				_bounce_count += 1
				_is_bouncing = true
				_just_bounced = true  # Set flag to prevent immediate re-trigger
				_bounce_cooldown = BOUNCE_COOLDOWN_DURATION  # Set cooldown
				behavior_timer = 0.0
				
				# Play ground hurt animation
				if sprite and sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
				
				# Calculate bounce force based on fall velocity
				var bounce_force = fall_velocity * BOUNCE_FORCE_MULTIPLIER
				# Cap bounce force for gameplay feel
				bounce_force = min(bounce_force, 400.0)
				velocity.y = -bounce_force  # Apply upward bounce
				
				# Small horizontal bounce variation for visual interest
				velocity.x *= 0.5  # Reduce horizontal velocity on bounce
				
				_was_in_air = true  # Still in air after bounce
				return
			elif health <= 0:
				# Dead and no more bounces - play death animation
				_just_bounced = false  # Reset flag
				die()
				return
			else:
				# Alive - play ground impact animation first
				if sprite:
					if sprite.sprite_frames.has_animation("hurt_ground"):
						sprite.play("hurt_ground")
						behavior_timer = 0.0  # Reset timer for ground animation
					elif sprite.sprite_frames.has_animation("get_up"):
						sprite.play("get_up")
						behavior_timer = 0.0  # Reset timer for get_up animation
			_was_in_air = false
			_just_bounced = false  # Reset flag
		
		# Ölüyse ve yerdeyse mutlaka die() (takılı kalmayı önle)
		if health <= 0 and is_on_floor():
			die()
			return
		
		# On ground and alive - play hurt_ground or get_up (if not already playing)
		if sprite:
			# Only play if we're not already playing these animations
			if sprite.animation != "hurt_ground" and sprite.animation != "get_up":
				if sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
				elif sprite.sprite_frames.has_animation("get_up"):
					sprite.play("get_up")
	
	# Apply horizontal damping while hurt (but less if dead in air - allow juggling)
	if health <= 0 and not is_on_floor():
		# Dead in air - minimal damping for punching bag effect
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		# Normal hurt - strong damping
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	
	# Exit hurt state when timer is up and mostly stopped (only if alive)
	if health > 0 and behavior_timer >= 0.3 and abs(velocity.x) <= 25 and is_on_floor():
		# Wait for hurt_ground animation to finish first (if playing)
		if sprite:
			if sprite.animation == "hurt_ground" and sprite.is_playing():
				return
			# Then wait for get_up animation to finish
			if sprite.sprite_frames.has_animation("get_up"):
				if sprite.animation == "get_up" and sprite.is_playing():
					return
				# If hurt_ground finished but get_up hasn't started, start it
				elif sprite.animation == "hurt_ground" and not sprite.is_playing():
					if sprite.sprite_frames.has_animation("get_up"):
						sprite.play("get_up")
						behavior_timer = 0.0  # Reset timer for get_up
						return
		
		# Return to appropriate behavior (both animations finished)
		if target:
			change_behavior("chase")
		else:
			change_behavior("patrol")
		
		# Re-enable hurtbox
		if hurtbox:
			hurtbox.monitoring = true
			hurtbox.monitorable = true

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == new_behavior and not force:
		return
	var was_attack: bool = (current_behavior == "attack")
	if debug_enabled or debug_chase_wall:
		print("[BasicEnemy] change_behavior: %s -> %s (force=%s)" % [current_behavior, new_behavior, force])
	
	# IMPORTANT: Don't allow changing to patrol/chase/attack if dead or dying
	# Dead enemies should stay in hurt state until they hit ground
	if health <= 0 and new_behavior in ["patrol", "chase", "attack"] and not force:
		# Force hurt state instead
		if current_behavior != "hurt":
			current_behavior = "hurt"
			behavior_timer = 0.0
		return
	
	if current_behavior == "dead" and not force:
		return
		
	# When entering chase, reset chase timer
	if new_behavior == "chase":
		_chase_time = 0.0
	
	current_behavior = new_behavior
	behavior_timer = 0.0
	
	# When forced to patrol or leaving attack for patrol, delay re-entering chase (stops wall loop)
	if new_behavior == "patrol" and (force or was_attack):
		_chase_after_wall_cooldown = CHASE_AFTER_WALL_COOLDOWN_TIME
		_chase_cooldown_just_set = true
	
	# IMPORTANT: Override BaseEnemy's automatic animation playing for hurt state
	# BaseEnemy tries to play "hurt" animation which doesn't exist, causing fall animation
	# We handle hurt animations manually in handle_hurt_behavior()
	if new_behavior == "hurt":
		# Don't play animation here - let handle_hurt_behavior() handle it
		# This prevents fall animation from playing
		return
	
	# Play appropriate animation for non-hurt behaviors
	# Hurt animations are handled in handle_hurt_behavior()
	if sprite:
		match new_behavior:
			"patrol":
				sprite.play("idle")
			"chase":
				if sprite.sprite_frames.has_animation("chase"):
					sprite.play("chase")
				else:
					sprite.play("walk")
			"attack":
				if sprite.sprite_frames.has_animation("attack"):
					sprite.play("attack")
				else:
					sprite.play("idle")
				is_attacking = false
			"hurt":
				# Animation will be determined in handle_hurt_behavior()
				# Don't play anything here to prevent fall animation from playing
				pass
			"dead":
				# Only play death animation if on ground
				# If in air, wait until we hit ground (handled in handle_hurt_behavior)
				if is_on_floor():
					sprite.play("death")
				# If in air, don't play death animation yet - let hurt animations play
			_:
				sprite.play("idle")

# Havada veya fırlatılmışken ölümü ertele; yere inince (ve sekme sonrası) die() handle_hurt_behavior'da çağrılır
func _should_die_now_on_lethal() -> bool:
	if not is_on_floor():
		return false
	# Yerdeyiz ama az önce knockback uygulandı (velocity henüz büyük) -> ertele
	if abs(velocity.x) > 15.0 or velocity.y < -15.0:
		return false
	return true

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0, apply_knockback: bool = true, source_hitbox: Area2D = null) -> void:
	_bounce_count = 0
	_max_bounces = 1
	_just_bounced = false
	_bounce_cooldown = 0.0
	var was_in_air = not is_on_floor()
	if current_behavior == "dead":
		return
	# Projectile / DoT base'de işlenir; biz sadece melee knockback ve hurt
	super.take_damage(amount, knockback_force, knockback_up_force, apply_knockback)
	if not apply_knockback:
		return
	# Base zaten lethal hasarda die() çağırdıysa devam etme (state/hurtbox ezilmesin)
	if current_behavior == "dead":
		return
	# Apply knockback - BasicEnemy is a punching bag, so stronger knockback
	# Start with base knockback values
	var final_knockback_force = knockback_force
	var final_up_force = knockback_up_force if knockback_up_force >= 0.0 else knockback_force * 0.5
	
	# Check if this is an upward attack by checking attack name from hitbox
	var is_up_attack = false
	var attack_name = ""
	if source_hitbox is PlayerHitbox:
		var player_hitbox = source_hitbox as PlayerHitbox
		# Safely get attack name - property always exists in PlayerHitbox
		attack_name = player_hitbox.current_attack_name if player_hitbox else ""
		
		
		# Check for up attacks - prioritize attack name check
		if attack_name != "":
			# Check for up attack patterns (ground and air)
			var has_up_pattern = attack_name.begins_with("up_") or attack_name.begins_with("attack_up") or attack_name.begins_with("air_attack_up") or attack_name.contains("_up") or attack_name.contains("up_")
			
			if has_up_pattern:
				is_up_attack = true
				# Boost upward force significantly for up attacks
				final_up_force *= 2.5  # 150% boost for up attacks on BasicEnemy
		# Fallback: check up_force value (up attacks have high up_force)
		if not is_up_attack and knockback_up_force > 150.0:
			is_up_attack = true
			final_up_force *= 2.0  # 100% boost if up_force is high
	
	# If we're already in air (being juggled), boost upward force significantly
	if was_in_air or not is_on_floor():
		# Boost upward force for better juggling - BasicEnemy is designed for air combos
		if final_up_force > 0:
			final_up_force *= 1.3  # 30% boost for air juggling
		else:
			final_up_force = knockback_force * 1.0  # Strong upward force even if no up_force
	
	# If dead but still in air, allow even more knockback (punching bag mode)
	# But cap upward force to prevent infinite flight
	# IMPORTANT: When death is deferred, we need stronger knockback to match normal death behavior
	if health <= 0:
		# Boost upward force significantly for death - this compensates for not calling die()
		# Normal death would apply DEATH_UP_FORCE (100.0), but we're using attack knockback
		# So boost it to match or exceed normal death knockback
		if is_up_attack:
			final_up_force *= 1.5  # Extra boost for up attacks on death
		else:
			final_up_force *= 1.4  # Extra boost for other attacks on death
		# Higher cap for dead enemies - they should fly higher for combos
		final_up_force = min(final_up_force, 600.0)  # Cap at 600 for dead enemies (higher)
	
	# Ensure minimum upward force for BasicEnemy (they should always launch)
	if final_up_force < 100.0 and knockback_up_force < 0.0:
		# If no explicit up_force and result is too low, apply minimum
		final_up_force = max(final_up_force, 150.0)
	
	velocity.x = -direction * final_knockback_force
	velocity.y = -final_up_force  # Direct assignment - don't let anything override
	
	# Basic enemy has extended air float for juggling
	# IMPORTANT: Also apply air float for dead enemies being launched upward
	# This prevents them from falling too fast and allows proper juggling
	if velocity.y < 0.0:
		if health > 0:
			air_float_timer = air_float_duration_override
		elif health <= 0:
			# Dead enemies also get air float when launched upward
			# This helps them fly higher and allows for air combos
			air_float_timer = air_float_duration_override * 0.7  # 70% of normal float time
	
	# Check for death BEFORE entering hurt state
	# If we're being launched upward, don't die immediately
	var should_defer_death = false
	if health <= 0:
		# Can barını hemen gizle
		if health_bar:
			health_bar.hide_bar()
		
		# IMPORTANT: If we're being launched upward (up attack), don't die immediately
		# Check if velocity indicates upward movement (negative y means upward)
		# OR if this is an up attack with significant force
		# Use velocity.y as the primary check - if it's negative, we're going up
		var is_being_launched_upward = velocity.y < 0.0  # Any upward velocity (negative y = up)
		var will_be_launched_upward = is_up_attack or (knockback_up_force > 50.0) or (final_up_force > 50.0)
		
		# ALWAYS defer death if we're in air OR being launched upward OR will be launched upward
		# Primary check: velocity.y < 0 means we're going up, so defer death
		should_defer_death = not is_on_floor() or is_being_launched_upward or will_be_launched_upward
		
		# If we should defer death, don't call die() at all - just stay in hurt state
		if should_defer_death:
			# Enter hurt state but don't die yet
			change_behavior("hurt")
			behavior_timer = 0.0
			
			# Flash red
			if sprite:
				sprite.modulate = Color(1, 0, 0, 1)
				create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
			
			# Spawn blood particles
			if _should_spawn_blood():
				_spawn_blood_particles(amount)
			
			# Keep hurtbox enabled so player can keep hitting in air (punching bag effect)
			if hurtbox:
				hurtbox.monitoring = true
				hurtbox.monitorable = true
			
			# IMPORTANT: Disable air float timer for dead enemies
			# Dead enemies should fall naturally, not float
			air_float_timer = 0.0
			
			# Play correct hurt animation based on velocity (hurt_rise or hurt_fall)
			if sprite:
				if velocity.y < -10.0:
					# Rising - play hurt_rise
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					# Falling or slow upward - play hurt_fall
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")
			
			# Don't call die() - stay in hurt state until we hit ground
			# This allows player to continue juggling dead enemies
			return
	
	# Enter hurt state
	change_behavior("hurt")
	behavior_timer = 0.0
	
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
	
	# Spawn blood particles
	if _should_spawn_blood():
		_spawn_blood_particles(amount)
	
	# Check for death - but don't die immediately if in air OR if being launched upward
	if health <= 0:
		# On ground and not being launched upward, die immediately
		die()

func _physics_process(delta: float) -> void:
	# Skip if sleeping or invalid position
	if global_position == Vector2.ZERO:
		return
	
	# CRITICAL: Prevent fade_out for BasicEnemy corpses - they should never disappear
	if fade_out:
		fade_out = false
		death_fade_timer = 0.0
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)  # Keep full opacity
	
	# Ölü ceset: hurtbox her kare kapalı (yaşayan düşmana vurmayı engellemesin)
	if current_behavior == "dead" and hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Dead + grounded: ensure death animation plays (may have been skipped if knockback was active during die())
	if current_behavior == "dead" and is_on_floor() and sprite:
		if sprite.animation != "death":
			if sprite.sprite_frames.has_animation("death"):
				sprite.play("death")
	
	# Spawn floor fix: zemine ilk temas olduğunda işaretle ve patrol noktalarını kur.
	# Süre dolarsa ve hâlâ havadaysa raycast ile zemine snap yap.
	if not _spawn_floor_fix_applied:
		if is_on_floor():
			_spawn_floor_fix_applied = true
			patrol_point_left = global_position.x - patrol_range
			patrol_point_right = global_position.x + patrol_range
		else:
			_spawn_floor_fix_time_left -= delta
			if _spawn_floor_fix_time_left <= 0.0:
				if current_behavior != "hurt" and current_behavior != "dead" and health > 0:
					_try_spawn_floor_snap()
				_spawn_floor_fix_applied = true
				patrol_point_left = global_position.x - patrol_range
				patrol_point_right = global_position.x + patrol_range
	
	# CRITICAL: Check animation FIRST, before any other processing
	# This ensures fall animation is stopped immediately if it starts playing
	if sprite:
		# If we're in hurt state or dead, NEVER allow fall animation
		if current_behavior == "hurt" or health <= 0:
			if sprite.animation == "fall":
				sprite.stop()
				# Immediately play correct hurt animation
				if not is_on_floor():
					if velocity.y < -10.0:
						if sprite.sprite_frames.has_animation("hurt_rise"):
							sprite.play("hurt_rise")
					else:
						if sprite.sprite_frames.has_animation("hurt_fall"):
							sprite.play("hurt_fall")
	
	# Check sleep state (delta for per-enemy spawn grace)
	check_sleep_state(delta)
	
	# CRITICAL: Disable hitbox if in air or hurt state - enemy can't attack while being juggled
	if hitbox:
		if not is_on_floor() or current_behavior == "hurt" or health <= 0:
			if hitbox.is_enabled():
				hitbox.disable()
			is_attacking = false
	
	# Gravity (always, so airborne sleeping enemies land)
	if not is_on_floor():
		var is_dead = current_behavior == "dead" or health <= 0
		if not is_dead:
			var g_scale := 1.0
			if current_behavior == "hurt" and air_float_timer > 0.0 and health > 0:
				g_scale = air_float_gravity_scale
				air_float_timer = max(0.0, air_float_timer - delta)
			velocity.y += GRAVITY * g_scale * delta
			if current_behavior == "hurt" and air_float_timer > 0.0 and health > 0:
				velocity.y = min(velocity.y, air_float_max_fall_speed)
		else:
			velocity.y += GRAVITY * delta
			if velocity.y < -800.0:
				velocity.y += GRAVITY * 0.3 * delta
	
	if current_behavior == "dead" and is_on_floor():
		velocity = Vector2.ZERO
	
	if collision_layer != CollisionLayers.ENEMY_HURTBOX:
		collision_layer = CollisionLayers.ENEMY_HURTBOX
	
	if is_on_floor() and velocity.y >= 0.0:
		_is_step_jumping = false
	
	# Airborne safety: alive enemy stuck in the air for too long → force-snap to floor
	if not is_on_floor() and current_behavior != "hurt" and current_behavior != "dead" and health > 0:
		_airborne_time += delta
		if _airborne_time >= AIRBORNE_SAFETY_THRESHOLD:
			if _try_spawn_floor_snap():
				_airborne_time = 0.0
				_spawn_floor_fix_applied = true
				if is_sleeping:
					wake_up()
				if current_behavior != "patrol" and current_behavior != "chase":
					current_behavior = "patrol"
				if sprite and sprite.animation == "fall":
					sprite.play("idle")
			else:
				_airborne_time = 0.0
	else:
		_airborne_time = 0.0
	
	# Only process behavior/AI if awake
	if not is_sleeping:
		# Handle behavior
		handle_behavior(delta)
		
		# Track velocity before move (for bounce calculation)
		_previous_velocity_y = velocity.y
		
		if not is_on_floor() and _just_bounced:
			_just_bounced = false
		
		# Hurt/dead animation overrides
		if sprite:
			if current_behavior == "hurt" or health <= 0:
				if sprite.animation == "fall":
					sprite.stop()
					if not is_on_floor():
						if velocity.y < -10.0:
							if sprite.sprite_frames.has_animation("hurt_rise"):
								sprite.play("hurt_rise")
						else:
							if sprite.sprite_frames.has_animation("hurt_fall"):
								sprite.play("hurt_fall")
				elif not is_on_floor():
					if velocity.y < -10.0:
						if sprite.sprite_frames.has_animation("hurt_rise"):
							if sprite.animation != "hurt_rise":
								sprite.play("hurt_rise")
					else:
						if sprite.sprite_frames.has_animation("hurt_fall"):
							if sprite.animation != "hurt_fall":
								sprite.play("hurt_fall")
			elif not is_on_floor() and current_behavior != "hurt" and current_behavior != "dead" and health > 0:
				if _is_step_jumping:
					if velocity.y < -10.0:
						if sprite.sprite_frames.has_animation("jump") and sprite.animation != "jump":
							sprite.play("jump")
					else:
						if sprite.sprite_frames.has_animation("fall") and sprite.animation != "fall":
							sprite.play("fall")
				elif sprite.sprite_frames.has_animation("fall"):
					if sprite.animation != "fall" and sprite.animation != "hurt_fall" and sprite.animation != "hurt_rise":
						sprite.play("fall")
	
	move_and_slide()
	
	# Sleeping enemy landed: switch from fall animation to idle so it doesn't look stuck
	if is_sleeping and is_on_floor() and sprite and sprite.animation == "fall":
		sprite.play("idle")
		if sprite.has_method("pause"):
			sprite.pause()
	
	# Corner-stuck safety: prevent endless loops at tile corners (hurt, dead, or alive patrol/chase)
	if is_on_floor() and is_on_wall():
		var barely_moving: bool = abs(velocity.x) < CORNER_STUCK_VELOCITY_TOLERANCE and abs(velocity.y) < CORNER_STUCK_VELOCITY_TOLERANCE
		var same_place: bool = _last_stuck_position.distance_to(global_position) < CORNER_STUCK_POSITION_TOLERANCE
		if barely_moving and same_place:
			_corner_stuck_timer += delta
		else:
			_corner_stuck_timer = 0.0
			_last_stuck_position = global_position
	else:
		_corner_stuck_timer = 0.0
		_last_stuck_position = global_position
	
	if _corner_stuck_timer >= CORNER_STUCK_THRESHOLD:
		var allow_nudge := (current_behavior == "hurt" or current_behavior == "dead" \
			or (current_behavior == "chase" and not _chase_blocked_at_wall))
		
		if not allow_nudge:
			_corner_stuck_timer = 0.0
			_last_stuck_position = global_position
		else:
			if current_behavior == "chase" and _chase_blocked_at_wall:
				_corner_stuck_timer = 0.0
				_last_stuck_position = global_position
			else:
				var push_dir: int = -direction if direction != 0 else 1
				global_position.x += float(push_dir) * CORNER_UNSTUCK_NUDGE
				velocity = Vector2.ZERO
				_corner_stuck_timer = 0.0
				_was_in_air = false
				_just_bounced = false
				_bounce_cooldown = 0.0
				_is_wall_hit = false
				_wall_hit_timer = 0.0
				_backing_off_timer = 0.0
				_wall_clear_time = 0.0
				
				if health <= 0:
					die()
				else:
					_chase_after_wall_cooldown = CHASE_AFTER_WALL_COOLDOWN_TIME
					_chase_cooldown_just_set = true
					change_behavior("patrol", true)

# When blocked at wall or waiting, play sit if available else idle (avoids walk stutter)
func _play_idle_or_sit(use_sit: bool = false) -> void:
	# For BasicEnemy, always use idle here.
	# Sit caused too many brief flickers at walls/turns; we keep behavior simple.
	if not sprite:
		return
	if sprite.animation != "idle":
		sprite.play("idle")

# True when against wall and not actually moving (so we should show idle/sit, not walk/chase)
func _is_blocked_cannot_move_forward() -> bool:
	return is_on_wall() and abs(velocity.x) < 18.0

func update_sprite_direction() -> void:
	"""Update sprite direction based on movement and target"""
	# Don't update direction if in wall hit state (prevents flickering)
	if _is_wall_hit or _backing_off_timer > 0.0:
		return
	
	if target:
		var target_direction = sign(target.global_position.x - global_position.x)
		if target_direction != 0:
			# Only update direction if it actually changed
			if direction != target_direction:
				direction = target_direction
				if sprite:
					sprite.flip_h = direction < 0
	elif abs(velocity.x) > 18.0:
		var vel_direction = sign(velocity.x)
		# Only update direction if it actually changed
		if direction != vel_direction:
			direction = vel_direction
			if sprite:
				sprite.flip_h = direction < 0
	else:
		# No movement and no target - keep current direction, just update sprite if needed
		if sprite and sprite.flip_h != (direction < 0):
			sprite.flip_h = direction < 0

func die() -> void:
	# Reset bounce state on death
	_bounce_count = 0
	_max_bounces = 0
	_is_bouncing = false
	_just_bounced = false
	_bounce_cooldown = 0.0
	# Override die to stop velocity immediately
	if current_behavior == "dead":
		return
	
	# IMPORTANT: Completely remove hitbox to prevent blocking player movement
	# Hitbox should not block player movement after death
	if hitbox:
		# Disable the hitbox component first
		hitbox.disable()
		
		# Remove hitbox from collision layers IMMEDIATELY
		hitbox.collision_layer = 0
		hitbox.collision_mask = 0
		
		# Disable monitoring IMMEDIATELY
		hitbox.monitoring = false
		hitbox.monitorable = false
		
		# Disable collision shape IMMEDIATELY
		var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
		if hitbox_shape:
			hitbox_shape.disabled = true
			# Remove shape reference to prevent any collision
			hitbox_shape.shape = null
		
		# Remove hitbox from scene tree completely
		hitbox.queue_free()
		hitbox = null
	
	# IMPORTANT: Play death animation BEFORE calling super.die()
	# super.die() sets fade_out = true which might hide sprite immediately
	# BUT: Only play death animation if on ground AND no knockback - if in air or has knockback, keep playing hurt animations
	if sprite:
		# Ensure sprite is visible
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)  # Reset modulate
		# Check if we have knockback from attack
		var has_knockback = abs(velocity.x) > 10.0 or velocity.y < -10.0
		# Play death animation only if on ground AND no knockback (enemy dies in place)
		# If in air or has knockback, don't play death animation - let handle_hurt_behavior() handle it when we land
		if is_on_floor() and not has_knockback:
			# Play death animation if available
			if sprite.sprite_frames.has_animation("death"):
				sprite.play("death")
			elif sprite.sprite_frames.has_animation("hurt_fall"):
				# Fallback to hurt_fall if death animation doesn't exist
				sprite.play("hurt_fall")
		# If in air or has knockback, don't change animation - keep playing hurt_rise or hurt_fall
	
	# Stop all movement before calling super - BUT only if on ground AND no knockback was applied
	# If in air, keep velocity so enemy can fall naturally
	# IMPORTANT: Check velocity.y instead of is_on_floor() because velocity might be set but not applied yet
	# IMPORTANT: Don't zero velocity if we have significant knockback (from attack) - let enemy fly
	# Only zero velocity if we're on ground AND velocity is very small (no knockback)
	var has_knockback = abs(velocity.x) > 10.0 or velocity.y < -10.0
	if is_on_floor() and velocity.y >= 0.0 and not has_knockback:
		velocity = Vector2.ZERO
	# If in air or going up or has knockback, don't zero velocity - let enemy fly/fall naturally
	
	# IMPORTANT: Prevent fade_out from hiding sprite immediately
	# BasicEnemy corpses should remain visible - NEVER fade out or disappear
	fade_out = false
	
	# IMPORTANT: Dead enemies should stay on tiles but NOT block player
	# Set collision_layer to a layer player doesn't detect (ENEMY_HURTBOX = 32)
	# Keep collision_mask to WORLD | PLATFORM so corpses still collide with tiles
	collision_layer = CollisionLayers.ENEMY_HURTBOX  # Layer player doesn't detect
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Collide with tiles/platforms
	
	# IMPORTANT: Save velocity BEFORE calling super.die() because it calls _apply_death_knockback()
	# which will override our velocity. We want to keep the velocity from the attack.
	var saved_velocity = velocity
	
	# Call base class die AFTER setting collision (base class sets collision_layer = 0)
	super.die()
	
	# IMPORTANT: Restore velocity if we have knockback from attack (being launched)
	# Don't let super.die() override our attack velocity
	# Always restore if we have significant velocity (knockback from attack)
	if abs(saved_velocity.x) > 10.0 or saved_velocity.y < -10.0 or not is_on_floor():
		velocity = saved_velocity
	
	# IMPORTANT: Re-apply collision settings after super.die() (it sets collision_layer = 0)
	collision_layer = CollisionLayers.ENEMY_HURTBOX  # Layer player doesn't detect
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM  # Collide with tiles/platforms
	fade_out = false  # CRITICAL: Prevent fade out - corpses stay forever
	
	# CRITICAL: Ensure sprite stays visible and never fades
	if sprite:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)  # Full opacity, no fade
		death_fade_timer = 0.0  # Reset fade timer to prevent any fading
	
	# Keep CollisionShape2D enabled so corpses can collide with tiles
	# Player won't collide because collision_layer is ENEMY_HURTBOX which player doesn't detect
	
	# Hitbox should already be removed, but double-check
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()
		hitbox = null
	
	# Ensure velocity stays zero after death (override death knockback) - BUT only if on ground
	# If in air, keep velocity so enemy can fall naturally
	if is_on_floor() and saved_velocity.y >= -50.0:
		velocity = Vector2.ZERO
	# If in air or being launched upward, keep saved velocity

func _apply_death_knockback() -> void:
	# Override to prevent upward flight - basic enemies just fall down
	# BUT: If we're being launched upward (from up attack), keep that velocity
	# Only zero velocity if we're on ground and not being launched upward
	if is_on_floor() and velocity.y >= -50.0:
		velocity = Vector2.ZERO
	# If in air or being launched upward, keep current velocity (don't override)
	
	# CRITICAL: Don't start fall delete timer - BasicEnemy corpses should NEVER disappear
	# Do NOT call _on_fall_timer_timeout - corpses stay forever
	pass

func _on_fall_timer_timeout() -> void:
	# Override BaseEnemy's fall timer - BasicEnemy corpses NEVER disappear
	# Do nothing - corpses stay forever
	pass

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Override to allow taking damage even when dead in air (punching bag mode)
	# IMPORTANT: Don't call super - we handle everything here
	
	# Safety: enemies only take damage from PlayerHitbox
	if not (hitbox is PlayerHitbox):
		return
	
	# If dead and on ground, don't take damage
	if current_behavior == "dead" and is_on_floor():
		return
	
	# Get knockback data
	var knockback_data = hitbox.get_knockback_data() if hitbox.has_method("get_knockback_data") else {"force": 200.0, "up_force": 100.0}
	var damage: float
	if hitbox.has_method("get_damage_for_target"):
		damage = hitbox.get_damage_for_target(self)
	elif hitbox.has_method("get_damage"):
		damage = hitbox.get_damage()
	else:
		damage = 10.0
	
	# If dead in air, allow damage but don't reduce health further
	if health <= 0 and not is_on_floor():
		# Dead but in air - allow knockback for punching bag effect
		# Apply knockback without reducing health
		var final_knockback_force = knockback_data.get("force", 200.0)
		var final_up_force = knockback_data.get("up_force", 100.0)
		
		# Check if this is an upward attack by checking attack name from hitbox
		var is_up_attack = false
		var attack_name = ""
		if hitbox is PlayerHitbox:
			var player_hitbox = hitbox as PlayerHitbox
			attack_name = player_hitbox.current_attack_name if player_hitbox else ""
			
			# Check for up attack patterns (ground and air)
			if attack_name != "":
				var has_up_pattern = attack_name.begins_with("up_") or attack_name.begins_with("attack_up") or attack_name.begins_with("air_attack_up") or attack_name.contains("_up") or attack_name.contains("up_")
				if has_up_pattern:
					is_up_attack = true
		# Fallback: check up_force value
		if not is_up_attack and final_up_force > 150.0:
			is_up_attack = true
		
		if is_up_attack:
			# Up attacks get even more boost for dead enemies
			final_up_force *= 3.0  # 200% boost for up attacks on dead enemies
		else:
			final_up_force *= 2.0  # 100% boost for other attacks
		
		# Higher cap for dead enemies - they should fly higher for combos
		final_up_force = min(final_up_force, 700.0)  # Cap at 700 for dead enemies
		final_knockback_force *= 1.3
		
		# Apply velocity DIRECTLY - don't let anything override this
		velocity.x = -direction * final_knockback_force
		velocity.y = -final_up_force  # Direct assignment for upward force
		
		# IMPORTANT: Ensure air float timer is disabled for dead enemies
		air_float_timer = 0.0
		
		# Play hurt animation based on velocity
		if sprite:
			if velocity.y < -10.0:
				if sprite.sprite_frames.has_animation("hurt_rise"):
					sprite.play("hurt_rise")
			else:
				if sprite.sprite_frames.has_animation("hurt_fall"):
					sprite.play("hurt_fall")
		
		# Flash red briefly
		if sprite:
			sprite.modulate = Color(1, 0, 0, 1)
			create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
		
		return
	
	# Normal damage handling - pass hitbox to take_damage (apply_knockback=true for physical hits)
	take_damage(damage, knockback_data.get("force", 200.0), knockback_data.get("up_force", -1.0), true, hitbox)

func go_to_sleep() -> void:
	# Clear ambient state before sleeping so enemy doesn't freeze in sit/lay animation
	if _ambient_playing:
		_ambient_playing = false
		_ambient_timer = 0.0
	super.go_to_sleep()

func reset() -> void:
	super.reset()
	patrol_point_left = global_position.x - patrol_range
	patrol_point_right = global_position.x + patrol_range
	behavior_timer = 0.0
	attack_cooldown_timer = 0.0
	is_attacking = false

func _on_animation_finished() -> void:
	"""Called when an animation finishes. Prevents fall animation from playing when hurt."""
	if not sprite:
		return
	
	# CRITICAL: If we're in hurt state or dead, NEVER let fall animation play
	# If fall animation just finished, immediately play correct hurt animation
	if current_behavior == "hurt" or health <= 0:
		if sprite.animation == "fall":
			sprite.stop()
			# Play correct hurt animation based on velocity
			if not is_on_floor():
				if velocity.y < -10.0:
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")
		# If hurt animations finished, loop them (don't let fall play)
		elif sprite.animation == "hurt_rise" or sprite.animation == "hurt_fall":
			# Loop the hurt animation if still in air
			if not is_on_floor():
				if velocity.y < -10.0:
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")

func _on_animation_changed() -> void:
	"""Called when animation changes. Prevents fall animation from playing when hurt."""
	if not sprite:
		return
	
	# CRITICAL: If BaseEnemy's change_behavior tries to play "hurt" (which doesn't exist),
	# AnimatedSprite2D might default to "fall". Intercept this immediately.
	if current_behavior == "hurt" or health <= 0:
		# Block ANY attempt to play fall animation
		if sprite.animation == "fall" or sprite.animation == "hurt":
			sprite.stop()
			# Play correct hurt animation based on velocity
			if not is_on_floor():
				if velocity.y < -10.0:
					if sprite.sprite_frames.has_animation("hurt_rise"):
						sprite.play("hurt_rise")
				else:
					if sprite.sprite_frames.has_animation("hurt_fall"):
						sprite.play("hurt_fall")
			else:
				# On ground - play hurt_ground or death
				# IMPORTANT: Only play death animation if we're actually dead AND on ground
				# Don't play death animation if we're still in air (handled in handle_hurt_behavior)
				if health <= 0 and is_on_floor():
					if sprite.sprite_frames.has_animation("death"):
						sprite.play("death")
				elif sprite.sprite_frames.has_animation("hurt_ground"):
					sprite.play("hurt_ground")
	
	# Reset air float settings
	if extended_air_float:
		air_float_duration = air_float_duration_override
		air_float_gravity_scale = air_float_gravity_override
		air_float_max_fall_speed = 200.0


# Helper: hysteresis-aware chase target selection
func _get_chase_target() -> Node2D:
	var player = get_nearest_player()
	if not player:
		return null
	
	var distance = global_position.distance_to(player.global_position)
	var detection_range = stats.detection_range if stats else 300.0
	
	# Never chase beyond overall detection range
	if distance > detection_range:
		return null
	
	# Use different thresholds depending on whether we're already chasing
	if current_behavior == "chase":
		return player if distance <= chase_stop_distance else null
	else:
		return player if distance <= chase_start_distance else null


# Helper: attempt to auto-climb a small step (1 tile by default)
func _try_step_climb() -> bool:
	if not can_step_climb:
		return false
	if not is_on_floor():
		return false
	if direction == 0:
		return false
	
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return false
	
	# Slightly ahead so we detect the ledge when touching it (collision can be 1–2 px inside)
	var check_dist := maxf(step_check_distance, 18.0)
	var forward := Vector2(direction * check_dist, 0.0)
	var exclude := [get_rid()]
	
	# 1) Horizontal ray in front at foot level to hit the step vertical face
	var foot_from := global_position + Vector2(0.0, 8.0)
	var foot_to := foot_from + forward
	var foot_query := PhysicsRayQueryParameters2D.create(foot_from, foot_to)
	foot_query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	foot_query.collide_with_areas = false
	foot_query.exclude = exclude
	var foot_hit = space_state.intersect_ray(foot_query)
	if foot_hit.is_empty():
		return false
	
	# 2) From hit point cast UP; hit within step height = tall wall (band just above step top so we don’t hit the step surface)
	var wall_check_from: Vector2 = foot_hit.position
	var wall_check_to: Vector2 = foot_hit.position + Vector2(0.0, -(max_step_height + 14.0))
	var wall_query := PhysicsRayQueryParameters2D.create(wall_check_from, wall_check_to)
	wall_query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	wall_query.collide_with_areas = false
	wall_query.exclude = exclude
	var wall_up_hit = space_state.intersect_ray(wall_query)
	if not wall_up_hit.is_empty():
		return false  # Obstacle continues upward = tall wall, not a step
	
	# Step jump: mostly up; horizontal movement applied in air so we drift over the ledge
	_is_step_jumping = true
	velocity.y = -step_jump_force
	velocity.x = 0.0  # Will be set each frame while in air
	if sprite and sprite.sprite_frames.has_animation("jump"):
		sprite.play("jump")
	return true
