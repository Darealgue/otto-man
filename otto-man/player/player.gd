extends CharacterBody2D

signal health_changed(new_health: float)
signal perfect_parry  # Signal for Perfect Guard powerup
signal dash_started
signal dodge_started  # Signal for dodge state
signal fall_attack_performed  # Signal for Triple Strike powerup

const DustCloudEffect = preload("res://assets/effects/player fx/dust_cloud_effect.tscn")

@export var speed: float = 400.0
@export var jump_velocity: float = -600.0  # Changed to -600 for higher jump
@export var double_jump_velocity: float = -550.0
@export var acceleration: float = 2000.0
@export var air_acceleration: float = 1500.0  # Lower acceleration in air for better momentum
@export var friction: float = 1000.0
@export var air_friction: float = 200.0  # Much lower friction in air to preserve momentum
@export var stop_friction_multiplier: float = 2.0
@export var air_control_multiplier: float = 0.5  # Reduced from 0.65 for more precise control
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1
@export var fall_gravity_multiplier: float = 2.5
@export var max_fall_speed: float = 1200.0
@export var jump_cut_height: float = 0.5
@export var max_jump_time: float = 0.4

# Hollow Knight tarzı zıplama parametreleri
@export var jump_apex_gravity_multiplier: float = 0.3  # Tepe noktasında çok zayıf yer çekimi
@export var jump_fall_acceleration: float = 0.1  # Düşerken yer çekiminin artış hızı
@export var max_fall_gravity_multiplier: float = 3.5  # Maksimum düşme yer çekimi
@export var jump_apex_threshold: float = 0.1  # Tepe noktası eşiği (velocity.y'nin 0'a yakın olduğu alan)
@export var jump_horizontal_dampening: float = 0.9
@export var wall_slide_speed: float = 150.0
@export var wall_jump_velocity: Vector2 = Vector2(450.0, -600.0)
@export var wall_slide_gravity_multiplier: float = 0.5
@export var wall_stick_force: float = 20.0
@export var wall_stick_distance: float = 15.0
@export var wall_jump_horizontal_dampening: float = 0.2
@export var wall_jump_boost: float = 1.5
@export var wall_detach_boost: float = 300.0
@export var wall_jump_momentum_preservation: float = 0.8
@export var wall_jump_control_delay: float = 0.15
@export var wall_slide_buffer_time: float = 0.1  # Buffer time before wall sliding
@export var wall_slide_min_height: float = 50.0  # Minimum height to allow wall sliding
@export var debug_enabled: bool = false
@export var precision_air_control_multiplier: float = 0.9  # How much control player has in air when holding down
@export var precision_air_friction: float = 400.0  # Higher air friction when holding down for more precise control
@export var air_momentum_cancel_rate: float = 0.85  # How quickly to reduce horizontal velocity when releasing direction in air

const COYOTE_TIME := 0.15  # Time in seconds player can still jump after leaving ground
const FALL_GRAVITY_MULTIPLIER := 1.5  # Makes falling faster than rising

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_double_jump: bool = false
var has_double_jumped: bool = false
var coyote_timer: float = 0.0
var was_on_floor: bool = false
var jump_timer: float = 0.0
var is_jumping: bool = false
var jump_buffer_timer: float = 0.0
var current_gravity_multiplier: float = 1.0
var jump_fall_gravity_progress: float = 0.0  # Düşerken yer çekimi artış progressi
var is_wall_sliding: bool = false
var wall_normal: Vector2 = Vector2.ZERO
var can_wall_jump: bool = true
var wall_jump_timer: float = 0.0
var is_wall_jumping: bool = false
var wall_jump_direction: float = 0.0
var wall_jump_boost_timer: float = 0.0
var last_hit_position: Vector2 = Vector2.ZERO
var last_hit_knockback: Dictionary = {}
var ledge_grab_cooldown_timer: float = 0.0  # Cooldown timer for ledge grabbing
var invincibility_timer: float = 0.0  # Invincibility timer after getting hit
var attack_cooldown_timer: float = 0.0 # <<< YENİ DEĞİŞKEN >>>
var is_dodging: bool = false  # Track if player is currently dodging
var hit_recoil_lock_timer: float = 0.0  # Lock facing direction during hit recoil
var jump_input_blocked: bool = false  # Block jump input during dodge
var jump_block_timer: float = 0.0  # Timer to keep jump blocked after dodge
var block_input_blocked_timer: float = 0.0  # Global timer to block block input after dodge

# Combat state tracking for idle_combat animation
var is_in_combat: bool = false
var combat_timer: float = 0.0
var combat_timeout: float = 3.0  # 3 seconds without combat actions before returning to normal idle

# Air-combo float for player (stay airborne longer during juggles)
@export var air_combo_float_duration: float = 0.35
@export var air_combo_gravity_scale: float = 0.35
@export var air_combo_max_fall_speed: float = 620.0
var air_combo_float_timer: float = 0.0

# Counter window after perfect parry
var counter_window_timer: float = 0.0
var counter_damage_bonus: float = 0.5  # +50% damage during counter
var counter_knockback_bonus: float = 0.35  # +35% knockback during counter

# Etkileşim için değişkenler (YENİ - physics_process'e dokunmadan)
var overlapping_interactables: Array[Area2D] = []

# Stats multipliers for powerups
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var base_damage: float = 15.0  # Base damage value
var damage_multipliers: Array[float] = []  # Array to store all active multipliers
var is_dashing: bool = false  # For Speed Demon powerup

var facing_direction := 1.0  # 1 for right, -1 for left

# UI lock: when true, movement and inputs are ignored (e.g., menus open)
var _ui_locked: bool = false
var _ui_lock_logged_once: bool = false
var _ui_lock_last_reason: String = ""

func _is_any_menu_open() -> bool:
	var mcs = get_tree().get_first_node_in_group("mission_center")
	if mcs and mcs.visible:
		return true
	return false

func set_ui_locked(locked: bool) -> void:
	_ui_locked = locked
	_ui_lock_logged_once = false
	_ui_lock_last_reason = "MissionCenter.set_ui_locked(%s)" % (locked)
	# Hard lock: stop state machine and animations, zero velocity
	if locked:
		velocity = Vector2.ZERO
	if state_machine:
		state_machine.set_process(not locked)
		state_machine.set_physics_process(not locked)
	if animation_tree:
		animation_tree.active = not locked
	# print("[Player] set_ui_locked -> ", locked)

@onready var animation_tree = $AnimationTree
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var player_sprite = $PlayerRenderLayer/PlayerSprite
@onready var player_render_layer = $PlayerRenderLayer
@onready var dash_state = $StateMachine/Dash as State
@onready var hurtbox = $Hurtbox
@onready var hitbox = $Hitbox
@onready var state_machine = $StateMachine


var is_dead: bool = false

func _ready():
	VillageManager.Village_Player = self
	# Add to player group
	add_to_group("player")
	
	# Set player z_index to appear above ground traps but below flying objects
	# Use call_deferred to ensure sprite is ready
	call_deferred("_set_player_z_index")
	
	# Collision layer ve mask'ı doğru şekilde ayarla
	collision_layer = CollisionLayers.PLAYER  # Player layer
	# print("Oyuncu collision_layer: ", collision_layer)
	
	# Set up collision mask to detect both ground and platforms
	collision_mask |= CollisionLayers.PLATFORM  # Add platform layer
	collision_mask |= CollisionLayers.BUILDING_SLOT  # Add building slot layer
	set_collision_mask_value(10, true)  # Ensure platform collision is enabled by default (kept as numeric for now)
	# print("Oyuncu collision_mask: ", collision_mask)
	
	animation_player.active = true
	#animation_tree.active = false
	# Ensure counter animations exist even if scene file missed them
	_ensure_counter_animations()
	
	# Initialize health from PlayerStats and connect death signal
	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats:
		player_stats.health_changed.connect(_on_health_changed)
		emit_signal("health_changed", player_stats.get_current_health())
		player_stats.stat_changed.connect(_on_stat_changed)
		# Connect death signal
		if not player_stats.player_died.is_connected(_on_player_died):
			player_stats.player_died.connect(_on_player_died)
	
	# Set up hitbox and hurtbox
	if hitbox:
		hitbox.collision_layer = CollisionLayers.PLAYER_HITBOX
		hitbox.collision_mask = CollisionLayers.ENEMY_HURTBOX
	
	if hurtbox:
		hurtbox.collision_layer = CollisionLayers.PLAYER_HURTBOX
		hurtbox.collision_mask = CollisionLayers.ENEMY_HITBOX
		# Disconnect any existing connections to avoid duplicates
		if hurtbox.hurt.is_connected(_on_hurtbox_hurt):
			hurtbox.hurt.disconnect(_on_hurtbox_hurt)
		# Connect the hurt signal
		hurtbox.hurt.connect(_on_hurtbox_hurt)
	else:
		push_error("[Player] Warning: No hurtbox found!")
	
	# Register with PowerupManager and RoomManager
	PowerupManager.register_player(self)
	
	# Initialize stats
	damage_multiplier = 1.0
	speed_multiplier = 1.0
	
	# Connect dash state signals
	if dash_state:
		if not dash_state.is_connected("state_entered", _on_dash_state_entered):
			dash_state.connect("state_entered", _on_dash_state_entered)
		if not dash_state.is_connected("state_exited", _on_dash_state_exited):
			dash_state.connect("state_exited", _on_dash_state_exited)
	
	# Connect dodge state signals
	var dodge_state = $StateMachine.get_node("Dodge")
	if dodge_state:
		if not dodge_state.is_connected("state_entered", _on_dodge_state_entered):
			dodge_state.connect("state_entered", _on_dodge_state_entered)
		if not dodge_state.is_connected("state_exited", _on_dodge_state_exited):
			dodge_state.connect("state_exited", _on_dodge_state_exited)
		
	# Initialize stats from PlayerStats
	_sync_stats_from_player_stats()
func _input(event: InputEvent) -> void:
	# Debug: if locked, show which input attempted
	if _ui_locked or _is_any_menu_open():
		if event.is_pressed():
			var act := ""
			if event.is_action("move_left"): act = "move_left"
			elif event.is_action("move_right"): act = "move_right"
			elif event.is_action("jump"): act = "jump"
			elif event.is_action("dash"): act = "dash"
			elif event.is_action("attack"): act = "attack"
			# print("[Player] Input blocked due to UI lock -> ", act)
		return
	if VillageManager.active_dialogue_npc != null:
		if event.is_action_pressed("interact"):
			VillageManager.active_dialogue_npc._on_interact_button_pressed()
func _physics_process(delta):
	# Stop all updates if dead
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Stop all player updates while UI is locked
	var menu_open := _is_any_menu_open()
	if _ui_locked or menu_open:
		if not _ui_lock_logged_once:
			var reason: String = ""
			if _ui_locked:
				reason = _ui_lock_last_reason
			else:
				reason = "MissionCenter visible"
			# print("[Player] UI lock active - movement halted (", reason, ")")
			_ui_lock_logged_once = true
		# Ensure we don't move
		velocity = Vector2.ZERO
		move_and_slide()
		return
	elif _ui_lock_logged_once:
		# print("[Player] UI lock released - controls restored")
		_ui_lock_logged_once = false
	# Update attack cooldown timer
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	# Update hit recoil lock timer
	if hit_recoil_lock_timer > 0:
		hit_recoil_lock_timer -= delta
	
	# Update combat state timer
	if is_in_combat:
		combat_timer -= delta
		if combat_timer <= 0:
			is_in_combat = false
			combat_timer = 0.0
	# Decay counter window
	if counter_window_timer > 0.0:
		counter_window_timer -= delta
		if counter_window_timer < 0.0:
			counter_window_timer = 0.0
		
	# Handle drop-through platform
	if is_on_floor() and Input.is_action_pressed("down") and Input.is_action_just_pressed("jump"):
		drop_through_platform()
		return  # Skip other processing for this frame
	
	# Update dash cooldown
	if dash_state and dash_state.has_method("cooldown_update"):
		dash_state.cooldown_update(delta)
	
	# Update dodge cooldown
	var dodge_state = $StateMachine.get_node("Dodge")
	if dodge_state and dodge_state.has_method("cooldown_update"):
		dodge_state.cooldown_update(delta)
	
	# Update jump block timer
	if jump_block_timer > 0:
		jump_block_timer -= delta
		if jump_block_timer <= 0:
			jump_input_blocked = false
			print("[Player] Jump input unblocked after timer")
	
	# Update block input block timer
	if block_input_blocked_timer > 0:
		block_input_blocked_timer -= delta
		if block_input_blocked_timer <= 0:
			print("[Player] Block input unblocked after timer")
	
	# Dash input removed - only dodge available until powerup upgrade
	
	# Handle hurt exit timer
	if has_meta("hurt_exit_timer"):
		var timer = get_meta("hurt_exit_timer")
		timer -= delta
		if timer <= 0:
			remove_meta("hurt_exit_timer")
		else:
			set_meta("hurt_exit_timer", timer)
	
	# Handle sprite flipping (but not during hit recoil)
	if not is_wall_jumping and not (state_machine and state_machine.current_state and state_machine.current_state.name == "Hurt"):  # Don't auto-flip during hurt state
		# Don't auto-flip for a short time after hurt state to maintain facing direction
		# Also don't auto-flip during hit recoil to maintain facing direction toward enemy
		if not (has_meta("hurt_exit_timer") and get_meta("hurt_exit_timer") > 0) and hit_recoil_lock_timer <= 0.0:
			if velocity.x < 0:
				sprite.flip_h = true
			elif velocity.x > 0:
				sprite.flip_h = false
	
	# Handle jump buffering (disabled during Crouch and Dodge)
	var is_crouching := false
	var is_dodging := false
	if $StateMachine and $StateMachine.current_state:
		is_crouching = $StateMachine.current_state.name == "Crouch"
		is_dodging = $StateMachine.current_state.name == "Dodge"
	if Input.is_action_just_pressed("jump"):
		if not is_crouching and not is_dodging and not jump_input_blocked and jump_block_timer <= 0:
			jump_buffer_timer = jump_buffer_time
		else:
			print("[Player] Jump buffering BLOCKED - crouching:", is_crouching, " dodging:", is_dodging, " blocked:", jump_input_blocked, " timer:", jump_block_timer)
	elif jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Handle coyote time
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		if jump_buffer_timer > 0:  # Execute buffered jump
			# Do not execute buffered jump while crouching or dodging
			var crouch_now := false
			var dodge_now := false
			if $StateMachine and $StateMachine.current_state:
				crouch_now = $StateMachine.current_state.name == "Crouch"
				dodge_now = $StateMachine.current_state.name == "Dodge"
			if not crouch_now and not dodge_now and not jump_input_blocked and jump_block_timer <= 0:
				spawn_dust_cloud(get_foot_position(), "puff_up")
				start_jump()
				jump_buffer_timer = 0.0
	elif was_on_floor:
		coyote_timer -= delta
		if coyote_timer <= 0:
			was_on_floor = false

	# Handle variable jump height and Hollow Knight style gravity
	if is_jumping:
		jump_timer += delta
		current_gravity_multiplier = 1.0
		if jump_timer >= max_jump_time or not Input.is_action_pressed("jump"):
			is_jumping = false
			if velocity.y < 0:  # Only cut jump height if still moving upward
				velocity.y *= jump_cut_height
				# Reset Hollow Knight gravity progress when jump is cut
				jump_fall_gravity_progress = 0.0
	else:
		# Use Hollow Knight style gravity calculation
		current_gravity_multiplier = calculate_hollow_knight_gravity()
		
		# Apply air-combo float modifier while airborne
		if not is_on_floor() and air_combo_float_timer > 0.0:
			air_combo_float_timer = max(0.0, air_combo_float_timer - delta)
			current_gravity_multiplier *= air_combo_gravity_scale
	
	# Apply maximum fall speed with the new higher limit
	var max_fall := max_fall_speed
	if air_combo_float_timer > 0.0:
		max_fall = min(max_fall_speed, air_combo_max_fall_speed)
	if velocity.y > max_fall:
		velocity.y = max_fall

	# Update wall jump timer
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	# Handle wall jump momentum with better control
	if is_wall_jumping:
		var input_dir = InputManager.get_flattened_axis(&"left", &"right")
		
		# Only allow input control after delay
		if wall_jump_timer <= 0 and input_dir != 0:
			# Calculate target velocity while preserving wall jump momentum
			var target_x = velocity.x
			if sign(input_dir) == sign(wall_jump_direction):
				# Moving in same direction as wall jump - maintain momentum
				target_x = wall_jump_velocity.x * wall_jump_direction
			else:
				# Moving opposite to wall jump - gradual control but preserve some momentum
				target_x = lerp(velocity.x, input_dir * speed, 0.1)  # Gradual transition
			
			velocity.x = target_x
		
		# End wall jump state only when touching ground
		if is_on_floor():
			is_wall_jumping = false
			wall_jump_direction = 0.0

	if wall_jump_boost_timer > 0:
		# Apply continuous boost in the wall jump direction while preserving current velocity
		var boosted_velocity = wall_jump_direction * wall_jump_velocity.x * wall_jump_boost
		velocity.x = lerp(velocity.x, boosted_velocity, 0.5)  # Smooth transition
		wall_jump_boost_timer -= delta

	# Update ledge grab cooldown
	if ledge_grab_cooldown_timer > 0:
		ledge_grab_cooldown_timer -= delta
			
	# Update invincibility timer
	if invincibility_timer > 0:
		invincibility_timer -= delta

	# Skip default movement handling if in attack state or hurt state (these states handle their own movement)
	var is_attacking := false
	var is_hurt := false
	if $StateMachine and $StateMachine.current_state:
		is_attacking = $StateMachine.current_state.name == "Attack"
		is_hurt = $StateMachine.current_state.name == "Hurt"
	
	if not is_attacking and not is_hurt:
		# Apply speed multiplier to movement using flattened input
		var grounded_input := InputManager.get_flattened_axis(&"left", &"right")
		if grounded_input != 0:
			velocity.x = move_toward(velocity.x, grounded_input * speed * speed_multiplier, acceleration * delta)
		else:
			apply_friction(delta)

		# Update facing direction based on movement (but not during hit recoil)
		var input_dir = grounded_input
		if input_dir != 0:
			if hit_recoil_lock_timer > 0.0:
				print("[Player] DEBUG: Facing direction update BLOCKED - hit_recoil_lock_timer: %f, input_dir: %f, current facing: %f" % [hit_recoil_lock_timer, input_dir, facing_direction])
			else:
				var old_facing = facing_direction
				facing_direction = sign(input_dir)
				# Flip the sprite based on direction
				sprite.flip_h = facing_direction < 0
				if old_facing != facing_direction:
					print("[Player] DEBUG: Facing direction changed from %f to %f (input_dir: %f)" % [old_facing, facing_direction, input_dir])

	# Handle landing
	var is_landing = is_on_floor() and not was_on_floor
	if is_landing:
		# Debug: Landing detection
		var current_state_name = "UNKNOWN"
		if $StateMachine and $StateMachine.current_state:
			current_state_name = $StateMachine.current_state.name
		
		
		# Dodge state'deyken toz efekti çıkmasın
		if $StateMachine and $StateMachine.current_state:
			is_dodging = $StateMachine.current_state.name == "Dodge"
		
		# Block state'deyken de toz efekti çıkmasın
		var is_blocking = false
		if $StateMachine and $StateMachine.current_state:
			is_blocking = $StateMachine.current_state.name == "Block"
		
		if not is_dodging and not is_blocking:
			# Yere indiğimizde yapılacaklar (ses çalma vb.)
			spawn_dust_cloud(get_foot_position(), "puff_down")
		# Yere indiğimizde was_on_floor'u hemen true yapabiliriz
		was_on_floor = true
		coyote_timer = COYOTE_TIME # Yere iner inmez coyote time'ı sıfırla
	
	# Z-Index'i ayarla: köy sahnesinde dinamik, diğer sahnelerde sabit
	if sprite:
		if _is_village_scene():
			# Köy sahnesinde NPC'lerle aynı mantıkla dinamik z_index
			var foot_y = get_foot_y_position()
			sprite.z_index = _calculate_player_z_index_from_foot_y(foot_y)
		else:
			# Diğer sahnelerde sabit z_index (eski davranış)
			sprite.z_index = 5  # Fixed z-index, above torches (z-index=2)

# No need to call physics_update explicitly, it's handled by _physics_process in the state machine

		# Multi-layer rendering: Sync player sprite with original sprite
		if sprite and player_sprite:
			player_sprite.frame = sprite.frame
			player_sprite.flip_h = sprite.flip_h
			player_sprite.modulate = sprite.modulate
			player_sprite.visible = true  # Always visible
			
			# Position player sprite at player position (smooth, not affected by camera smoothing)
			player_sprite.global_position = global_position + Vector2(1, -48)
			# print("[DEBUG] Player sprite sync - frame: ", sprite.frame, " visible: ", player_sprite.visible, " pos: ", global_position, " player_sprite_pos: ", player_sprite.global_position)
		else:
			# print("[DEBUG] Missing sprites - sprite: ", sprite, " player_sprite: ", player_sprite)
			pass



func can_jump() -> bool:
	# Prevent jumping if pressing down
	if Input.is_action_pressed("down"):
		return false
		
	var can_jump_result = (
		is_on_floor() or
		($StateMachine.current_state and (
			$StateMachine.current_state.name == "WallSlide" or
			$StateMachine.current_state.name == "LedgeGrab"
			)
		)
	)
	return can_jump_result

func start_jump() -> void:
	# Don't start jump if pressing down
	if Input.is_action_pressed("down"):
		return
		
	is_jumping = true
	jump_timer = 0.0
	velocity.y = jump_velocity
	# Reduce horizontal boost for more predictable jumps
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	if input_dir != 0:
		velocity.x += input_dir * speed * 0.2  # Reduced from 0.3

func start_double_jump():
	# Don't start double jump if pressing down
	if Input.is_action_pressed("down"):
		return
		
	is_jumping = true
	jump_timer = 0.0
	velocity.y = double_jump_velocity
	# Reduce horizontal boost for double jump too
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	if input_dir != 0:
		velocity.x += input_dir * speed * 0.25  # Reduced from 0.4

func apply_friction(delta: float, input_dir: float = 0.0, use_precision: bool = false) -> void:
	# Use different friction values based on state and parameters
	var current_friction = friction
	
	if !is_on_floor():
		# Use air friction
		current_friction = precision_air_friction if use_precision else air_friction
	elif input_dir == 0:
		# Apply stronger friction when stopping
		current_friction = friction * stop_friction_multiplier
	
	velocity.x = move_toward(velocity.x, 0, current_friction * delta)

func calculate_hollow_knight_gravity() -> float:
	"""
	Hollow Knight tarzı zıplama eğrisi hesaplar.
	Yukarı çıkış: Normal yer çekimi
	Tepe noktası: Çok zayıf yer çekimi (float hissi)
	Düşüş: Yavaş yavaş artan yer çekimi, sonunda çok güçlü
	"""
	if is_on_floor():
		return 1.0  # Yerde normal yer çekimi
	
	# Yukarı çıkış (velocity.y < 0)
	if velocity.y < 0:
		return 1.0  # Normal yer çekimi
	
	# Tepe noktası (velocity.y çok küçük pozitif değer)
	if velocity.y <= jump_apex_threshold:
		return jump_apex_gravity_multiplier  # Çok zayıf yer çekimi - float hissi
	
	# Düşüş (velocity.y > jump_apex_threshold)
	# Yer çekimini yavaş yavaş artır
	jump_fall_gravity_progress = min(1.0, jump_fall_gravity_progress + jump_fall_acceleration)
	
	# Smooth transition from apex gravity to max fall gravity
	var current_gravity = lerp(jump_apex_gravity_multiplier, max_fall_gravity_multiplier, jump_fall_gravity_progress)
	
	return current_gravity

func reset_jump_state():
	is_jumping = false
	has_double_jumped = false
	is_wall_jumping = false
	wall_jump_timer = 0.0
	wall_jump_boost_timer = 0.0
	jump_timer = 0.0
	coyote_timer = 0.0
	was_on_floor = false
	jump_buffer_timer = 0.0
	current_gravity_multiplier = 1.0
	jump_fall_gravity_progress = 0.0  # Reset Hollow Knight gravity progress

func enable_double_jump():
	can_double_jump = true
	has_double_jumped = false

# Fall attack bounce is handled in fall_attack_state.gd
# No need for these functions here

func take_damage(amount: float, show_damage_number: bool = true):
	var player_stats = get_node("/root/PlayerStats")
	if player_stats:
		var current_health = player_stats.get_current_health()
		player_stats.set_current_health(current_health - amount, show_damage_number)
		if amount > 0.0:
			player_stats.lose_resources_on_damage()

func heal(amount: float):
	var player_stats = get_node("/root/PlayerStats")
	if player_stats:
		var current_health = player_stats.get_current_health()
		player_stats.set_current_health(current_health + amount)

func is_moving_away_from_wall() -> bool:
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	var moving_away = input_dir * wall_normal.x > 0
	# print("[WALL_SLIDE_DEBUG] Player: Moving away check - input_dir: ", input_dir, " wall_normal.x: ", wall_normal.x, " moving_away: ", moving_away)
	return moving_away

func is_on_wall_slide() -> bool:
	# Don't allow wall sliding if too close to ground
	if is_on_floor() or position.y < wall_slide_min_height:
		# print("[WALL_SLIDE_DEBUG] Player: Cannot wall slide - on_floor: ", is_on_floor(), " position.y: ", position.y, " min_height: ", wall_slide_min_height)
		return false
		
	# Basic wall slide conditions
	var on_wall = is_on_wall()
	var not_moving_away = not is_moving_away_from_wall()
	
	# print("[WALL_SLIDE_DEBUG] Player: Wall slide check - on_wall: ", on_wall, " not_moving_away: ", not_moving_away, " is_wall_sliding: ", is_wall_sliding)
	
	# Only check current conditions if we're already wall sliding
	if is_wall_sliding:
		return on_wall and not_moving_away
	
	# For new wall slides, use immediate check without delay
	return on_wall and not_moving_away and not is_wall_sliding

func start_wall_slide(normal: Vector2) -> void:
	is_wall_sliding = true
	wall_normal = normal
	can_wall_jump = true
	current_gravity_multiplier = wall_slide_gravity_multiplier
	
	# Apply magnetic effect
	if abs(velocity.x) < wall_stick_force:
		velocity.x = -wall_normal.x * wall_stick_force

func end_wall_slide() -> void:
	is_wall_sliding = false
	wall_normal = Vector2.ZERO
	current_gravity_multiplier = 1.0

func wall_jump():
	is_jumping = true
	is_wall_jumping = true
	jump_timer = 0.0
	wall_jump_timer = wall_jump_control_delay
	
	# Store wall jump direction - should be same as wall normal to jump away from wall
	wall_jump_direction = wall_normal.x
	
	# Calculate jump velocities with preserved momentum
	var jump_x = wall_jump_velocity.x * wall_jump_direction * wall_jump_boost
	var jump_y = wall_jump_velocity.y * wall_jump_boost
	
	# Set velocities directly without any dampening
	velocity = Vector2(jump_x, jump_y)
	
	# Add an immediate position adjustment for instant feedback
	position.x += wall_jump_direction * 20
	
	# Enable double jump after wall jump
	enable_double_jump()

func _on_hurtbox_hurt(hitbox: Area2D) -> void:
	# Check if player is invincible
	if invincibility_timer > 0:
		return
		
	# Store attacker's position and knockback data for hurt state BEFORE taking damage
	last_hit_position = hitbox.global_position
	if hitbox.has_method("get_knockback_data"):
		last_hit_knockback = hitbox.get_knockback_data()
	
	# Check if we're in block state
	if state_machine and state_machine.current_state.name == "Block":
		# Use the damage value set by block state (0 for parry, reduced for block)
		var is_parry = hurtbox.last_damage == 0  # Check if this was a parry
		take_damage(hurtbox.last_damage, !is_parry)  # Only show damage number if not a parry
	else:
		# Normal damage handling
		if hitbox.has_method("get_damage"):
			var damage = hitbox.get_damage()
			take_damage(damage)  # Show damage number for normal hits

	# Only transition to hurt state if not blocking
	if state_machine and state_machine.has_node("Hurt") and state_machine.current_state.name != "Block":
		# Force immediate transition to hurt state
		if state_machine.current_state:
			state_machine.current_state.exit()
		
		var hurt_state = state_machine.get_node("Hurt")
		state_machine.current_state = hurt_state
		state_machine.current_state.enter()
	
	# Flash the sprite red to indicate damage (only if actually taking damage)
	if hurtbox.last_damage > 0:
		sprite.modulate = Color(1, 0, 0, 1)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color(1, 1, 1, 1)

func has_coyote_time() -> bool:
	return coyote_timer > 0.0

# Powerup-related functions
func modify_damage_multiplier(multiplier: float) -> void:
	# This function now only handles attack damage multipliers
	
	# Convert multiplier to bonus (e.g., 1.2 becomes 0.2)
	var bonus = multiplier - 1.0
	damage_multipliers.append(bonus)
	
	# Calculate total bonus (additive stacking)
	var total_bonus = 0.0
	for bonus_value in damage_multipliers:
		total_bonus += bonus_value
	
	# Apply total bonus
	damage_multiplier = 1.0 + total_bonus
	
	
	# Update hitbox damage using base damage from PlayerStats
	if hitbox:
		hitbox.damage = base_damage * damage_multiplier

func remove_damage_multiplier(multiplier: float) -> void:
	# Convert multiplier to bonus before removing
	var bonus = multiplier - 1.0
	damage_multipliers.erase(bonus)
	
	# Recalculate total bonus
	var total_bonus = 0.0
	for bonus_value in damage_multipliers:
		total_bonus += bonus_value
	
	# Apply the total bonus
	damage_multiplier = 1.0 + total_bonus
	
	# Update hitbox damage using base damage
	if hitbox:
		hitbox.damage = base_damage * damage_multiplier

func modify_speed(multiplier: float) -> void:
	# This function is now just for temporary speed modifications (like dash)
	speed_multiplier = multiplier

func get_stats() -> Dictionary:
	var player_stats = get_node("/root/PlayerStats")
	return {
		"current_health": get_current_health(),
		"max_health": get_max_health(),
		"damage_multiplier": damage_multiplier,
		"movement_speed": speed * speed_multiplier,
		"base_damage": base_damage,
		"total_damage": base_damage * damage_multiplier,
		"speed_multiplier": speed_multiplier
	}

# Update dash state tracking
func _on_dash_state_entered() -> void:
	is_dashing = true
	emit_signal("dash_started")

func _on_dash_state_exited() -> void:
	is_dashing = false

# Update dodge state tracking
func _on_dodge_state_entered() -> void:
	is_dodging = true
	emit_signal("dodge_started")

func _on_dodge_state_exited() -> void:
	is_dodging = false

# Update perfect parry detection
func _on_successful_parry() -> void:
	emit_signal("perfect_parry")
	# Open counter window for a brief time
	start_counter_window(0.5)

# Counter window API
func start_counter_window(duration: float = 0.5) -> void:
	counter_window_timer = max(counter_window_timer, duration)
	# Optional: small visual cue
	if has_node("/root/ScreenEffects"):
		var fx = get_node("/root/ScreenEffects")
		if fx and fx.has_method("shake"):
			fx.shake(0.05, 2.0)

func is_counter_window_active() -> bool:
	return counter_window_timer > 0.0

func consume_counter_window() -> void:
	counter_window_timer = 0.0

# Add new functions for stat syncing
func _sync_stats_from_player_stats() -> void:
	var player_stats = get_node("/root/PlayerStats")
	if !player_stats:
		return
		
	speed = player_stats.get_stat("movement_speed")
	base_damage = player_stats.get_stat("base_damage")

func _on_stat_changed(stat_name: String, _old_value: float, new_value: float) -> void:
	match stat_name:
		"movement_speed":
			speed = new_value
		"base_damage":
			base_damage = new_value
			if hitbox:
				hitbox.damage = base_damage * damage_multiplier

func _on_health_changed(new_health: float) -> void:
	emit_signal("health_changed", new_health)
	
	# Check for death
	if new_health <= 0.0 and not is_dead:
		_on_player_died()

func _on_player_died() -> void:
	if is_dead:
		return  # Already dead, prevent multiple calls
	
	is_dead = true
	print("[Player] 💀 Player died!")
	
	# Disable player controls
	if state_machine:
		state_machine.set_process(false)
		state_machine.set_physics_process(false)
	
	# Stop movement
	velocity = Vector2.ZERO
	
	# Disable hitbox and hurtbox
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Play death animation if available
	if animation_tree:
		animation_tree.set("parameters/dead_transition/transition_request", "dead")
	elif animation_player:
		if animation_player.has_animation("death"):
			animation_player.play("death")
		else:
			animation_player.stop()
	
	# Fade out sprite after a delay
	call_deferred("_fade_out_on_death")
	
	# Auto-return to village after a delay (roguelike style)
	await get_tree().create_timer(2.0).timeout
	_return_to_village_on_death()

func _fade_out_on_death() -> void:
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func(): visible = false)

func _return_to_village_on_death() -> void:
	print("[Player] 🏠 Returning to village after death...")
	
	# Apply roguelike mechanics before scene change
	_apply_roguelike_mechanics_on_death()
	
	if is_instance_valid(SceneManager):
		SceneManager.change_to_village({})
	else:
		push_error("[Player] SceneManager not available for death return!")

func _apply_roguelike_mechanics_on_death() -> void:
	"""Apply roguelike mechanics when player dies (before returning to village)."""
	var powerup_manager = get_node_or_null("/root/PowerupManager")
	var player_stats = get_node_or_null("/root/PlayerStats")
	var global_player_data = get_node_or_null("/root/GlobalPlayerData")
	
	# Clear powerups
	if powerup_manager and powerup_manager.has_method("clear_all_powerups"):
		powerup_manager.clear_all_powerups()
		print("[Player] 🎮 Roguelike: All powerups cleared on death")
	
	# Clear inventory (death penalty)
	if global_player_data and "envanter" in global_player_data:
		var envanter: Array = global_player_data.get("envanter")
		var lost_count = envanter.size()
		global_player_data.set("envanter", [])
		print("[Player] 💀 Roguelike: Inventory cleared on death (%d items lost)" % lost_count)
	
	# Reset health to max (will be applied in reset_death_state, but we do it here too)
	if player_stats:
		var max_health = player_stats.get_stat("max_health")
		player_stats.current_health = max_health
		if player_stats.has_signal("health_changed"):
			player_stats.health_changed.emit(max_health)
		print("[Player] 💚 Roguelike: Health reset to %.1f on death" % max_health)
	
	# Reset kill count
	if powerup_manager and "enemy_kill_count" in powerup_manager:
		powerup_manager.set("enemy_kill_count", 0)
		print("[Player] 🎮 Roguelike: Kill count reset on death")

func reset_death_state() -> void:
	"""Reset player death state - called when returning to village."""
	if not is_dead:
		return  # Already alive
	
	is_dead = false
	print("[Player] 🔄 Resetting death state...")
	
	# Reset health if it's 0 or very low (roguelike reset)
	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats:
		var current_health = player_stats.get_current_health()
		if current_health <= 0.0:
			var max_health = player_stats.get_stat("max_health")
			player_stats.current_health = max_health
			if player_stats.has_signal("health_changed"):
				player_stats.health_changed.emit(max_health)
			print("[Player] 💚 Health reset to %.1f (was %.1f)" % [max_health, current_health])
	
	# Make visible again
	visible = true
	if sprite:
		sprite.modulate.a = 1.0
		sprite.modulate = Color(1, 1, 1, 1)
	
	# Re-enable state machine
	if state_machine:
		state_machine.set_process(true)
		state_machine.set_physics_process(true)
		# Reset to idle state
		if state_machine.has_node("Idle"):
			var idle_state = state_machine.get_node("Idle")
			if state_machine.current_state:
				state_machine.current_state.exit()
			state_machine.current_state = idle_state
			state_machine.current_state.enter()
	
	# Re-enable hitbox and hurtbox
	if hitbox:
		hitbox.enable()
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
	
	# Reset velocity
	velocity = Vector2.ZERO
	
	# Reset animation
	if animation_tree:
		animation_tree.set("parameters/dead_transition/transition_request", "idle")
	elif animation_player:
		animation_player.play("idle")
	
	print("[Player] ✅ Death state reset complete")

func get_max_health() -> float:
	var player_stats = get_node("/root/PlayerStats")
	return player_stats.get_max_health() if player_stats else 100.0

func get_current_health() -> float:
	var player_stats = get_node("/root/PlayerStats")
	return player_stats.get_current_health() if player_stats else 100.0

func get_health_percent() -> float:
	var max_health = get_max_health()
	return get_current_health() / max_health if max_health > 0 else 1.0

# Make dash state accessible for powerups
func get_dash_state() -> State:
	return dash_state

# Ensure counter animations exist in AnimationPlayer at runtime
func _ensure_counter_animations() -> void:
	if not animation_player:
		return
	# Ensure default animation library exists
	var lib_obj = animation_player.get_animation_library("")
	if lib_obj == null:
		lib_obj = AnimationLibrary.new()
		animation_player.add_animation_library("", lib_obj)
	var lib: AnimationLibrary = lib_obj
	# Counter Light (6 frames)
	if not animation_player.has_animation("counter_light"):
		var anim_l = Animation.new()
		anim_l.length = 0.4
		# hframes = 6
		var t0 = anim_l.add_track(Animation.TYPE_VALUE)
		anim_l.track_set_path(t0, NodePath("Sprite2D:hframes"))
		anim_l.track_insert_key(t0, 0.0, 6)
		# texture
		var tex_l = load("res://resources/player_normalmap resources/counter_light_n.tres")
		if tex_l:
			var t1 = anim_l.add_track(Animation.TYPE_VALUE)
			anim_l.track_set_path(t1, NodePath("Sprite2D:texture"))
			anim_l.track_insert_key(t1, 0.0, tex_l)
		# frame keys 0..5
		var t2 = anim_l.add_track(Animation.TYPE_VALUE)
		anim_l.track_set_path(t2, NodePath("Sprite2D:frame"))
		var times_l = [0.0, 0.067, 0.134, 0.201, 0.268, 0.335]
		for i in range(times_l.size()):
			anim_l.track_insert_key(t2, times_l[i], i)
		# method track for effect
		var tm = anim_l.add_track(Animation.TYPE_METHOD)
		anim_l.track_set_path(tm, NodePath("."))
		anim_l.track_insert_key(tm, 0.0, {"method": "spawn_attack_effect_by_name", "args": ["counter_light"]})
		lib.add_animation("counter_light", anim_l)
	# Counter Heavy (7 frames)
	if not animation_player.has_animation("counter_heavy"):
		var anim_h = Animation.new()
		anim_h.length = 0.47
		# hframes = 7
		var h0 = anim_h.add_track(Animation.TYPE_VALUE)
		anim_h.track_set_path(h0, NodePath("Sprite2D:hframes"))
		anim_h.track_insert_key(h0, 0.0, 7)
		# texture
		var tex_h = load("res://resources/player_normalmap resources/counter_heavy_n.tres")
		if tex_h:
			var h1 = anim_h.add_track(Animation.TYPE_VALUE)
			anim_h.track_set_path(h1, NodePath("Sprite2D:texture"))
			anim_h.track_insert_key(h1, 0.0, tex_h)
		# frame keys 0..6
		var h2 = anim_h.add_track(Animation.TYPE_VALUE)
		anim_h.track_set_path(h2, NodePath("Sprite2D:frame"))
		var times_h = [0.0, 0.067, 0.134, 0.201, 0.268, 0.335, 0.402]
		for j in range(times_h.size()):
			anim_h.track_insert_key(h2, times_h[j], j)
		# method track for effect
		var hm = anim_h.add_track(Animation.TYPE_METHOD)
		anim_h.track_set_path(hm, NodePath("."))
		anim_h.track_insert_key(hm, 0.0, {"method": "spawn_attack_effect_by_name", "args": ["counter_heavy"]})
		lib.add_animation("counter_heavy", anim_h)

# Update dash charges for Double Dash powerup
func update_dash_charges() -> void:
	var player_stats = get_node("/root/PlayerStats")
	if !player_stats:
		return
	
	var dash_charges = int(player_stats.get_stat("dash_charges"))
	
	# Update dash state if it exists
	if dash_state and dash_state.has_method("set_dash_charges"):
		dash_state.set_dash_charges(dash_charges)
	
	# print("[Player] Updated dash charges: " + str(dash_charges))

func apply_movement(delta: float, input_dir: float) -> void:
	# Use different acceleration values for ground and air
	var current_acceleration = acceleration if is_on_floor() else air_acceleration
	var target_speed = speed
	
	# In air, apply different control based on if down is held
	if !is_on_floor():
		if Input.is_action_pressed("down"):
			# Precision mode - better control and more friction
			target_speed *= precision_air_control_multiplier
			if input_dir == 0:
				apply_friction(delta, input_dir, true)  # Use precision friction
				return
		else:
			target_speed *= air_control_multiplier
			
			# Quick momentum cancellation when releasing direction in air
			# Only if not wall jumping to preserve wall jump feel
			if input_dir == 0 and !is_wall_jumping:
				velocity.x *= air_momentum_cancel_rate
			# Add extra friction when changing direction in air
			elif input_dir != 0 and sign(input_dir) != sign(velocity.x):
				velocity.x *= 0.95  # Slight momentum reduction when turning
	
	if input_dir != 0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, current_acceleration * delta)
	else:
		apply_friction(delta, input_dir)

func drop_through_platform() -> void:
	
	# Temporarily disable collision with platform layer (layer 10)
	set_collision_mask_value(10, false)  # Disable collision with platforms
	
	# Add downward velocity for faster dropping
	velocity.y = 200.0
	
	# Move down slightly to ensure we're no longer colliding
	position.y += 2
	
	# Create a timer to restore collision
	var timer = get_tree().create_timer(0.15)
	timer.timeout.connect(func():
		if not Input.is_action_pressed("down"):
			set_collision_mask_value(10, true)  # Re-enable platform collision
		else:
			# If still holding down, start another timer
			var extended_timer = get_tree().create_timer(0.1)
			extended_timer.timeout.connect(func():
				set_collision_mask_value(10, true)  # Re-enable platform collision
			)
	)

func get_facing_direction() -> float:
	return facing_direction

# Combat state management functions
func enter_combat_state() -> void:
	"""Enter combat state - will use idle_combat animation instead of normal idle"""
	is_in_combat = true
	combat_timer = combat_timeout

func exit_combat_state() -> void:
	"""Exit combat state - will return to normal idle animation"""
	is_in_combat = false
	combat_timer = 0.0

func is_in_combat_state() -> bool:
	"""Check if player is currently in combat state"""
	return is_in_combat

# Input Handling (YENİ - physics_process yerine)
func _unhandled_input(event: InputEvent) -> void:
	# Block all unhandled input when UI is locked or menu is open
	if _ui_locked or _is_any_menu_open():
		return
	
	# Hem interact hem ui_up tuşlarını destekle (klavye ve gamepad uyumluluğu için)
	var should_interact := false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_up"):
		should_interact = true
	
	if should_interact and not overlapping_interactables.is_empty():
		# En üstteki (genellikle en son girilen) etkileşimli nesneyi al
		var target_area = overlapping_interactables.back()

		# Alanın sahibi yerine, alanın EBEVEYN'ini (parent) hedef alıyoruz.
		# Bu, InteractionArea'nın doğrudan CampFire'ın altında olduğunu varsayar.
		var interactable_node = target_area.get_parent()

		if interactable_node and interactable_node.has_method("interact"):
			interactable_node.interact() # Artık CampFire'daki interact() çağrılmalı
			get_viewport().set_input_as_handled() # Input'un başka yerde işlenmesini önle (get_tree yerine get_viewport)
		else:
			# Daha bilgilendirici hata mesajı
			var node_name = interactable_node.name if interactable_node else "Bulunamadı"
			# print("Uyarı: Etkileşimli alanın ebeveyni ('%s' - Area: %s) 'interact' metoduna sahip değil veya ebeveyni yok." % [node_name, target_area.name])

# Handle hitbox hit events
func _on_hitbox_hit(enemy: Node) -> void:
	# print("[Player] Hitbox hit enemy: ", enemy.name if enemy else "Unknown")
	pass

func _on_interaction_detection_area_area_entered(area: Area2D) -> void:
	# (YENİ - fonksiyon içeriği)
	if area.is_in_group("interactables"):
		if not overlapping_interactables.has(area):
			overlapping_interactables.push_back(area)
			# İsteğe bağlı: Ekranda "Etkileşim için E'ye bas" gibi bir ipucu gösterebilirsin
			var parent_node = area.get_parent()
			# print("Etkileşim alanına girildi:", parent_node.name if parent_node else "Ebeveynsiz Alan")
			if parent_node.is_in_group("NPC"):
				VillageManager.active_dialogue_npc = parent_node
				VillageManager.dialogue_npcs.append(parent_node)
				HandleDialogueNpcWindows(parent_node)

func _on_interaction_detection_area_area_exited(area: Area2D) -> void:
	# (YENİ - fonksiyon içeriği)
	if area.is_in_group("interactables"):
		var index = overlapping_interactables.find(area)
		if index != -1:
			overlapping_interactables.remove_at(index)
			# İsteğe bağlı: Etkileşim ipucunu gizleyebilirsin
			var parent_node = area.get_parent()
			# print("Etkileşim alanından çıkıldı:", parent_node.name if parent_node else "Ebeveynsiz Alan")
			if parent_node.is_in_group("NPC"):
				parent_node.HideInteractButton()
				parent_node.CloseNpcWindow()
				VillageManager.dialogue_npcs.erase(parent_node)
				if VillageManager.dialogue_npcs.is_empty() == true:
					VillageManager.active_dialogue_npc = null
					
func HandleDialogueNpcWindows(last_npc):
	last_npc.ShowInteractButton()
	for NPC in VillageManager.dialogue_npcs:
		if NPC != last_npc:
			NPC.HideInteractButton()
			
# <<< YENİ FONKSİYON: Animasyondan çağırmak için >>>
func spawn_attack_effect_by_name(attack_name: String):
	# Debug print disabled to reduce console spam
	# print("[Player] spawn_attack_effect_by_name -> ", attack_name)
	var effect_scene_path = ""
	var effect_offset = Vector2.ZERO
	# var is_air = attack_name.begins_with("air_attack") # Bu değişkene gerek kalmadı

	# <<< YÖN HESAPLAMASINI DEĞİŞTİR >>>
	# Görsel yöne göre hesapla (flip_h false ise sağa = 1, true ise sola = -1)
	var current_visual_direction = 1.0 if not sprite.flip_h else -1.0

	# Saldırı adına göre yolu ve ofseti belirle
	match attack_name:
		"air_attack1":
			effect_scene_path = "res://assets/effects/player fx/air_attack_effect_1.tscn"
			effect_offset = Vector2(60 * current_visual_direction, -10) # <<< DEĞİŞTİ >>>
		"air_attack2":
			effect_scene_path = "res://assets/effects/player fx/air_attack_effect_2.tscn"
			effect_offset = Vector2(60 * current_visual_direction, -10) # <<< DEĞİŞTİ >>>
		"air_attack3":
			effect_scene_path = "res://assets/effects/player fx/air_attack_effect_3.tscn"
			effect_offset = Vector2(60 * current_visual_direction, -10) # <<< DEĞİŞTİ >>>
		"attack_1.1":
			effect_scene_path = "res://assets/effects/player fx/attack_1_1_effect.tscn"
			effect_offset = Vector2(50 * current_visual_direction, 0)    # <<< DEĞİŞTİ >>>
		"attack_1.2":
			effect_scene_path = "res://assets/effects/player fx/attack_1_2_effect.tscn"
			effect_offset = Vector2(70 * current_visual_direction, 5)
		"attack_1.3":
			effect_scene_path = "res://assets/effects/player fx/attack_1_3_effect.tscn"
			effect_offset = Vector2(75 * current_visual_direction, 6)
		"attack_1.4":
			effect_scene_path = "res://assets/effects/player fx/attack_1_1_effect.tscn"
			effect_offset = Vector2(60 * current_visual_direction, 2)
		"attack_1.3":
			effect_scene_path = "res://assets/effects/player fx/attack_1_3_effect.tscn"
			effect_offset = Vector2(75 * current_visual_direction, 6)
		"up_light":
			effect_scene_path = "res://assets/effects/player fx/attack_1_1_effect.tscn"
			effect_offset = Vector2(50 * current_visual_direction, -10)
		"attack_up1", "attack_up2", "attack_up3":
			effect_scene_path = "res://assets/effects/player fx/light_attack_up_effect.tscn"
			effect_offset = Vector2(50 * current_visual_direction, -10)
		"attack_down1", "attack_down2":
			effect_scene_path = "res://assets/effects/player fx/light_attack_down_effect.tscn"
			effect_offset = Vector2(50 * current_visual_direction, 10)
		"air_attack_down1", "air_attack_down2":
			effect_scene_path = "res://assets/effects/player fx/light_attack_down_effect.tscn"
			effect_offset = Vector2(50 * current_visual_direction, 20)  # Aşağı saldırı için biraz daha aşağı
		_:
			push_error("Bilinmeyen saldırı adı için efekt oluşturulamaz: " + attack_name)
			return

	if effect_scene_path == "":
		push_warning("Efekt yolu bulunamadı: " + attack_name)
		return

	# Sahneyi yükle (fallback'lerle)
	var resolved_path = effect_scene_path
	if not ResourceLoader.exists(resolved_path):
		if attack_name == "attack_1.3" and ResourceLoader.exists("res://assets/effects/player fx/attack_1_2_effect.tscn"):
			resolved_path = "res://assets/effects/player fx/attack_1_2_effect.tscn"
		elif ResourceLoader.exists("res://assets/effects/player fx/attack_1_1_effect.tscn"):
			resolved_path = "res://assets/effects/player fx/attack_1_1_effect.tscn"
		else:
			push_error("Efekt sahnesi bulunamadı: " + effect_scene_path)
			return
	var effect_scene = load(resolved_path)
	if not effect_scene:
		push_error("Efekt sahnesi yüklenemedi: " + resolved_path)
		return

	# Örneği oluştur
	var effect_instance = effect_scene.instantiate()

	# Pozisyonu ŞİMDİ hesapla (o anki oyuncu pozisyonuna göre)
	var effect_pos = global_position + effect_offset
	effect_instance.global_position = effect_pos

	# Sprite'ı çevir (o anki oyuncu yönüne göre)
	var should_flip = sprite.flip_h
	var sprite_node = effect_instance.find_child("AnimatedSprite2D", true, false)
	if sprite_node and sprite_node.has_method("set_flip_h"):
		sprite_node.flip_h = should_flip
	elif sprite_node:
		push_warning("Efekt içindeki düğüm ('AnimatedSprite2D') çevirme (flip_h) özelliğine sahip değil.")

	# Hızı ayarla (o anki oyuncu hızına göre)
	if effect_instance.has_method("set_initial_velocity"):
		var horizontal_momentum_transfer = 0.5
		var vertical_momentum_transfer = 0.7
		var initial_effect_velocity = Vector2(velocity.x * horizontal_momentum_transfer, velocity.y * vertical_momentum_transfer)
		effect_instance.set_initial_velocity(initial_effect_velocity)
	else:
		push_warning("Efekt script'i 'set_initial_velocity' metoduna sahip değil.")

	# Ana sahneye ekle
	get_tree().current_scene.add_child(effect_instance)

func spawn_dust_cloud(position: Vector2, animation_name: String):
	var dust_effect = DustCloudEffect.instantiate()
	dust_effect.animation_to_play = animation_name
	dust_effect.global_position = position
	get_tree().current_scene.add_child(dust_effect)

func get_foot_position() -> Vector2:
	var sprite_height = sprite.texture.get_height() * sprite.scale.y
	return global_position + Vector2(0, sprite_height / 2 + 5)

# Köy sahnesinde mi kontrol et
func _is_village_scene() -> bool:
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		var scene_path: String = scene_manager.current_scene_path
		if scene_path:
			var village_scene_path: String = scene_manager.VILLAGE_SCENE
			return scene_path == village_scene_path or "village" in scene_path.to_lower()
	# Fallback: current_scene'dan kontrol
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.scene_file_path:
		return "village" in current_scene.scene_file_path.to_lower()
	return false

# Oyuncunun ayak Y pozisyonunu hesapla (NPC'lerle aynı mantık - sadece köy sahnesinde kullanılır)
func get_foot_y_position() -> float:
	# Sprite position = Vector2(1, -48) → sprite merkezi body'den 48 piksel yukarıda (Y'de -48)
	# Ayaklar = sprite merkezi + sprite_height/2 → foot_y = global_position.y + (-48) + height/2
	var sprite_offset_y = 48.0  # Sprite'ın Y offset'i (negatif = yukarı)
	var sprite_height = 96.0  # Varsayılan yükseklik
	
	if sprite and sprite.texture:
		sprite_height = sprite.texture.get_height() * sprite.scale.y
	
	# Doğru formül: sprite merkezi = global_position.y - 48, ayaklar = merkez + height/2
	return global_position.y - sprite_offset_y + (sprite_height / 2.0)

# Z-index'i ayak pozisyonuna göre normalize et (NPC'lerle aynı mantık, su yansımasında görünmesi için)
# Kamp ateşinin z_index'i 5, su sprite'ı z_index=20
# Oyuncunun z_index'i kamp ateşinden yüksek (6+) ama su sprite'ından düşük (19-) olmalı
# Sadece köy sahnesinde kullanılır
func _calculate_player_z_index_from_foot_y(foot_y: float) -> int:
	# NPC'lerle aynı normalizasyon mantığını kullan
	# VERTICAL_RANGE_MAX = 25.0 (NPC'lerden alınan değer)
	const VERTICAL_RANGE_MAX: float = 25.0
	const CAMPFIRE_Z_INDEX: int = 5  # Kamp ateşinin z_index'i
	const WATER_Z_INDEX: int = 20  # Su sprite'ının z_index'i
	const MIN_PLAYER_Z_INDEX: int = CAMPFIRE_Z_INDEX + 1  # Kamp ateşinden yüksek (6)
	const MAX_PLAYER_Z_INDEX: int = WATER_Z_INDEX - 1  # Su sprite'ından düşük (19)
	
	var sprite_offset_y = 48.0  # Oyuncunun sprite'ı 48 piksel yukarıda (NPC'lerle aynı)
	var sprite_height = 96.0  # Varsayılan yükseklik
	
	if sprite and sprite.texture:
		sprite_height = sprite.texture.get_height() * sprite.scale.y
	
	# foot_y = global_position.y - 48 + height/2 → aynı dünya aralığı (min/max) NPC'lerle uyumlu
	var max_foot_y = VERTICAL_RANGE_MAX - sprite_offset_y + (sprite_height / 2.0)
	var min_foot_y = 0.0 - sprite_offset_y + (sprite_height / 2.0)
	var range_foot_y = max_foot_y - min_foot_y
	
	# Division by zero kontrolü
	if range_foot_y <= 0.0:
		return (MIN_PLAYER_Z_INDEX + MAX_PLAYER_Z_INDEX) / 2  # Varsayılan orta değer (12-13)
	
	var normalized_foot_y = (foot_y - min_foot_y) / range_foot_y
	normalized_foot_y = clamp(normalized_foot_y, 0.0, 1.0)  # 0-1 aralığına sınırla
	# 6-19 aralığına normalize et (kamp ateşinden yüksek, su sprite'ından düşük)
	var z_index_range = MAX_PLAYER_Z_INDEX - MIN_PLAYER_Z_INDEX
	return MIN_PLAYER_Z_INDEX + int(normalized_foot_y * z_index_range)

func _set_player_z_index():
	# Köy sahnesinde dinamik z_index, diğer sahnelerde sabit
	if sprite:
		if _is_village_scene():
			# Köy sahnesinde NPC'lerle aynı mantıkla dinamik z_index
			var foot_y = get_foot_y_position()
			sprite.z_index = _calculate_player_z_index_from_foot_y(foot_y)
		else:
			# Diğer sahnelerde sabit z_index (eski davranış)
			sprite.z_index = 5  # Fixed z-index, above torches (z-index=2)
		# print("Oyuncu z_index set to: ", sprite.z_index)
	else:
		# print("Oyuncu sprite not found for z_index setting")
		pass
