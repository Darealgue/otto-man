extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox_collision = $Hurtbox/CollisionShape2D
@onready var camera = $Camera2D
@onready var shield_sprite = $ShieldSprite
@onready var stamina_bar = get_node_or_null("../GameUI/StaminaBar")

const GRAVITY = 1000
const SPEED = 600
const JUMP_FORCE = -600
const AIR_CONTROL = 500
const COYOTE_TIME = 0.15
const JUMP_BUFFER_TIME = 0.1
const MAX_JUMPS = 2  # New constant for double jump
const JUMP_CUT_FORCE = 0.6  # Multiplier when releasing jump early (0.4 = 40% of current jump force)
const FALL_GRAVITY_MULTIPLIER = 1.8  # Makes falling faster than rising
const JUMP_RELEASE_FORCE = 0.5  # Controls jump height when releasing early
const MIN_JUMP_FORCE = -400
const MAX_JUMP_HEIGHT_TIME = 0.2
const DOUBLE_JUMP_FORCE = -500
const MIN_DOUBLE_JUMP_FORCE = -350
const AIR_FRICTION = 2000
const AIR_ACCELERATION = 2500
const AIR_SPEED = 600
const WALL_JUMP_FORCE = Vector2(400, -600)  # More balanced horizontal/vertical force
const WALL_SLIDE_SPEED = 100
const WALL_JUMP_TIME = 0.2  # Slightly longer wall jump time
const ATTACK_COMBO_WINDOW = 0.5  # Increased from 0.5 to 0.8
const ATTACK_BUFFER_TIME = 0.2   # New constant for buffering next attack input
const WALL_SLIDE_HORIZONTAL_BOOST = 100  # Add this constant at the top with other constants
const WALL_JUMP_DISABLE_TIME = 0.2  # Time before player can wall slide again
const WALL_CLIMB_CHECK_DISTANCE = 40  # Keep this
const WALL_CLIMB_CHECK_WIDTH = 15    # Keep this
const WALL_CLIMB_CHECK_HEIGHT = 32   # Increased to match character height better
const WALL_CLIMB_VERTICAL_OFFSET = 0  # Remove offset for now
const WALL_CLIMB_FORCE = Vector2(0, -800)  # Reduced climbing force
const WALL_CLIMB_BOOST = Vector2(200, 0)  # Add horizontal boost away from wall
const WALL_JUMP_CONTROL_DELAY = 0.15  # Time before player regains full air control
const WALL_JUMP_CONTROL_MULTIPLIER = 0.5  # How much air control during wall jump

# Add these constants for debug visualization
const DEBUG_COLORS = {
	"character_top": Color.YELLOW,
	"platform_edge": Color.CYAN,
	"check_area": Color.MAGENTA
}

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	WALL_SLIDE,
	DASH,
	HURT,
	BLOCK,
	ATTACK,
	WALL_ATTACK,
	FALL_ATTACK,
	PARRY
}
enum AnimState { IDLE, WALK, RUN, JUMP, FALL }
enum AttackState {
	NONE,
	ATTACK1,
	ATTACK2,
	ATTACK3
}

var current_state: State
var current_anim_state: AnimState
var previous_anim_state: AnimState
var current_attack_state = AttackState.NONE
var can_attack = true
var attack_combo_timer = 0.0
var attack_combo_window = 0.5
var is_attacking = false

var coyote_timer: float = 0
var jump_buffer_timer: float = 0
var was_on_floor: bool = false
var jumps_remaining: int = MAX_JUMPS  # New variable to track jumps
var is_double_jumping: bool = false  # Add this with your other variables
var jump_time: float = 0
var is_jumping: bool = false
var double_jump_time: float = 0  # New variable for double jump
var is_double_jump_rising: bool = false  # To track double jump state separately from animation
var is_wall_sliding: bool = false
var wall_jump_timer: float = 0
var wall_direction: float = 0
var attack_buffer_timer = 0.0
var next_attack_buffered = false
var can_wall_slide = true  # New variable at the top with other vars
var can_wall_climb = false
var is_wall_climbing = false
var wall_jump_control_timer: float = 0

# At the very top with other signals
signal health_changed(new_health: int)
signal died
signal hit_landed(hit_info: String)
signal shield_broken
signal stamina_changed(new_stamina: float, max_stamina: float)
signal block_charge_used
signal block_started
signal block_ended

# Constants section (group ALL constants together)
const MAX_HEALTH = 100
const INVINCIBILITY_TIME = 0.5
const DAMAGE_FLASH_DURATION = 0.2
const DAMAGE_FLASH_COLOR = Color(1, 0.3, 0.3)
const KNOCKBACK_FORCE = Vector2(300, -200)

# Variables section (group ALL variables together)
var health: int = MAX_HEALTH  # ONLY ONE declaration of health
var is_invincible: bool = false
var invincibility_timer: float = 0

# Add these constants with your other constants
const DASH_SPEED = 2500
const DASH_DURATION = 0.1
const BASE_DASH_COOLDOWN = 1.2  # Changed from DASH_COOLDOWN to BASE_DASH_COOLDOWN

# Add these variables with other variables
var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var current_dash_cooldown: float = BASE_DASH_COOLDOWN  # New variable for modifiable cooldown

# Add this preload at the top of the file
# var DashReadyParticles = preload("res://effects/dash_ready_particles.tscn")  # We'll create this

# Add these constants at the top
const GHOST_SPAWN_INTERVAL = 0.01  # How often to spawn ghosts during dash
const GHOST_DURATION = 0.2  # How long each ghost lasts
const GHOST_OPACITY = 0.2  # Starting opacity of ghosts

var ghost_timer: float = 0  # Add with other variables

# Adjust these constants for a more noticeable flash
const DASH_READY_FLASH_INTENSITY = 3.0  # Even brighter flash
const DASH_READY_FLASH_DURATION = 0.4   # Slightly longer duration
const DASH_READY_COLOR = Color(1.0, 0.9, 0.2)  # Bright yellow tint

# Add these constants
const FALL_ATTACK_SPEED = 2400  # Doubled from 1200 for faster fall
const FALL_ATTACK_BOUNCE_FORCE = -1800  # 4x stronger bounce (from -800)
const FALL_ATTACK_DAMAGE = 15  # Damage dealt to enemy
const MIN_FALL_ATTACK_HEIGHT = 100  # Minimum height needed (optional)

# Add this variable with other variables
var is_fall_attacking: bool = false

# Add these constants at the top
const FALL_ATTACK_SHAKE_STRENGTH = 5.0
const FALL_ATTACK_SHAKE_DURATION = 0.2

# Add this variable with other variables
# @onready var camera = get_node_or_null("Camera2D")  # If camera is child of player
# OR
# @onready var camera = get_tree().get_first_node_in_group("camera")  # If camera is elsewhere

# Add these constants at the top
const LANDING_DURATION = 0.2  # Duration of landing animation
const LANDING_SQUASH = 0.8   # How much to squash vertically
const LANDING_STRETCH = 1.2   # How much to stretch horizontally

# Add this variable with other variables
var landing_timer: float = 0.0
var is_landing: bool = false

# Add these constants at the top with other constants
const HURT_KNOCKBACK_FORCE = Vector2(400, -300)  # Adjust these values as needed
const HURT_STATE_DURATION = 0.3  # Reduced from 1.0 to match invincibility better
const HURT_INVINCIBILITY_TIME = 1.0  # How long player stays invincible after getting hit

# Add these variables with other variables
var is_hurt: bool = false
var hurt_timer: float = 0.0

# Add these collision layer constants at the top with other constants
const LAYERS = {
	WORLD = 1,                
	PLAYER = 2,
	ENEMY = 4,                        
	PLAYER_HITBOX = 16,        
	PLAYER_HURTBOX = 8,       
	ENEMY_HITBOX = 64,       
	ENEMY_HURTBOX = 32,      
	ENEMY_PROJECTILE = 256    # 
}

# Powerup-related variables
var damage_boost := 0  # Changed from damage_multiplier to damage_boost
var max_health_multiplier := 1.0
var shield_enabled := false
var shield_cooldown := 15.0
var shield_timer := 0.0
var has_shield := false
var dash_damage_enabled := false
var dash_damage := 0.0

var base_max_health := MAX_HEALTH
var current_max_health := MAX_HEALTH

var hitbox_state = {
	"active": false,
	"offset": Vector2.ZERO,
	"monitoring": false,
	"monitorable": false,
	"collision_disabled": true
}

# Add these variables with other variables
var fire_trail_enabled := false
var fire_trail_damage := 0.0
var fire_trail_duration := 0.0
var fire_trail_interval := 0.0
var fire_trail_timer := 0.0

# Add this preload at the top with other preloads
const FireTrailEffect = preload("res://resources/powerups/scenes/fire_trail_effect.tscn")

# Add these constants for movement speed thresholds
const INPUT_DEADZONE = 0.2  # Minimum input strength required to move
const WALK_SPEED = 300.0  # Speed for walking
const RUN_SPEED = 600.0   # Speed for running (same as current SPEED)

# Add new constants for block/parry mechanics
const BLOCK_DAMAGE_REDUCTION = 0.5  # Take 50% damage while blocking (changed from 0.2)
const BLOCK_MOVE_SPEED_MULTIPLIER = 0.5  # Move slower while blocking
const MAX_STAMINA = 100.0
const STAMINA_DRAIN_RATE = 20.0  # Stamina drain per second while blocking
const STAMINA_REGEN_RATE = 10.0  # Stamina regeneration per second
const BLOCK_FLASH_COLOR = Color(0.2, 0.4, 1.0, 1.0)  # Blue flash for successful block
const BLOCK_EFFECT_DURATION = 0.15

# Variables for block
var stamina: float = MAX_STAMINA
var is_blocking: bool = false
var block_animation_state := 0  # 0: none, 1: startup, 2: hold, 3: release

func _ready() -> void:
	add_to_group("player")
	
	# Set up player's main collision
	collision_layer = LAYERS.PLAYER
	collision_mask = LAYERS.WORLD | LAYERS.ENEMY
	
	# Setup camera
	if camera:
		camera.enabled = true
		camera.make_current()
		camera.add_to_group("camera")
	
	current_state = State.IDLE
	current_anim_state = AnimState.IDLE
	previous_anim_state = AnimState.IDLE
	jumps_remaining = MAX_JUMPS
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	set_process_input(true)
	
	# Initialize stamina bar
	stamina_bar = get_node_or_null("../GameUI/StaminaBar")
	if stamina_bar:
		stamina_bar.hide_bar()
	else:
		stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	
	# Make sure hitboxes start disabled
	if hitbox:
		hitbox.disable()
	
	# Connect hitbox/hurtbox signals
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.add_to_group("hitbox")
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		hurtbox.add_to_group("hurtbox")
	
	# Configure hitbox/hurtbox layers
	if hitbox:
		hitbox.is_player = true
		hitbox.collision_layer = LAYERS.PLAYER_HITBOX
		hitbox.collision_mask = LAYERS.ENEMY_HURTBOX
		# Disable monitoring during initialization
		hitbox.monitoring = false
		if hitbox_collision:
			hitbox_collision.disabled = true

	if hurtbox:
		hurtbox.is_player = true
		hurtbox.collision_layer = LAYERS.PLAYER_HURTBOX
		hurtbox.collision_mask = LAYERS.ENEMY_HITBOX | LAYERS.ENEMY_PROJECTILE
		# Make sure hurtbox is properly configured
		hurtbox.monitorable = true
		if hurtbox_collision:
			hurtbox_collision.disabled = false

	# Keep this to emit initial health
	health_changed.emit(health)

	# Setup shield visual
	if !shield_sprite:
		shield_sprite = Node2D.new()
		add_child(shield_sprite)
		shield_sprite.z_index = 1
		shield_sprite.position = Vector2(0, -32)  # Move shield up to center on character
		
		# Create multiple circles with different colors
		for i in range(3):
			var circle = ColorRect.new()
			var size = Vector2(100 - i * 10, 100 - i * 10)  # Each circle slightly smaller
			circle.size = size
			circle.position = -size / 2
			circle.color = Color(0.3, 0.7, 1.0, 0.3 - i * 0.1)
			shield_sprite.add_child(circle)
			
			# Make the ColorRect circular using a shader
			var shader = preload("res://shaders/circle.gdshader")
			var material = ShaderMaterial.new()
			material.shader = shader
			circle.material = material
		
		shield_sprite.visible = false
		
		# Start color animation
		_animate_shield_colors()

	# Initialize stamina and shield
	stamina = MAX_STAMINA
	stamina_changed.emit(stamina, MAX_STAMINA)
	shield_enabled = false
	has_shield = false
	if shield_sprite:
		shield_sprite.visible = false

	stamina_bar.hide_bar()

func _animate_shield_colors() -> void:
	for i in range(shield_sprite.get_child_count()):
		var circle = shield_sprite.get_child(i)
		var tween = create_tween()
		tween.set_loops()  # Make it repeat forever
		
		# Create a sequence of color changes
		var colors = [
			Color(0.3, 0.7, 1.0, 0.3 - i * 0.1),  # Light blue
			Color(0.2, 0.5, 0.9, 0.3 - i * 0.1),  # Medium blue
			Color(0.1, 0.3, 0.8, 0.3 - i * 0.1),  # Dark blue
			Color(0.2, 0.5, 0.9, 0.3 - i * 0.1)   # Back to medium blue
		]
		
		for color in colors:
			tween.tween_property(circle, "color", color, 1.0)

func _physics_process(delta: float) -> void:
	# Update hitbox based on state
	if hitbox_state.active:
		update_hitbox_state()
	
	# Add this at the start of _physics_process
	if shield_enabled:
		shield_timer += delta
		if shield_timer >= shield_cooldown:
			shield_timer = 0.0
			has_shield = true
			if shield_sprite:
				shield_sprite.visible = true
				var tween = create_tween()
				tween.tween_property(shield_sprite, "modulate:a", 0.5, 0.2)
	
	# Add this near the start of the function
	if is_landing:
		landing_timer -= delta
		if landing_timer <= 0:
			is_landing = false
			scale = Vector2.ONE
			if !is_attacking:
				animated_sprite_2d.play("idle")
			# Ensure hitbox is disabled when landing
			if hitbox:
				hitbox.disable()
				hitbox.position = Vector2.ZERO
				if hitbox_collision:
					hitbox_collision.disabled = false
		return
	
	# Handle hurt state first
	if current_state == State.HURT:
		handle_hurt_state(delta)
		move_and_slide()
		return
	
	# Add this check early in the function
	if current_state == State.FALL_ATTACK:
		velocity.y = FALL_ATTACK_SPEED
		
		# First check for Area2D collisions (enemy hurtbox)
		if hitbox and hitbox.is_active:
			var areas = hitbox.get_overlapping_areas()
			for area in areas:
				if area.is_in_group("hurtbox") and area.get_parent().is_in_group("enemy"):
					var target = area.get_parent()
					if target.has_method("take_damage"):
						var damage = FALL_ATTACK_DAMAGE
						var knockback_dir = Vector2.UP
						target.take_damage(damage, knockback_dir)
						handle_fall_attack_hit(target)
						return
		
		# Then check for direct collisions
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# Check if we're hitting from above and it's an enemy
			if collision.get_normal().y < -0.7 and collider.is_in_group("enemy"):  # More strict vertical check
				if hitbox and hitbox.is_active:
					var target = collider
					if target.has_method("take_damage"):
						var damage = FALL_ATTACK_DAMAGE
						target.take_damage(damage)  # Only pass damage amount
						handle_fall_attack_hit(target)
						return
		
		move_and_slide()
		
		# Only end fall attack if we hit the ground
		if is_on_floor():
			play_landing_animation()
			is_fall_attacking = false
			is_attacking = false
			current_state = State.IDLE
			if hitbox:
				hitbox.disable()
				hitbox.position = Vector2.ZERO
				if hitbox_collision:
					hitbox_collision.disabled = false
		return
	
	# Check for fall attack input - now requires down input
	if Input.is_action_pressed("down") and Input.is_action_just_pressed("attack") and !is_on_floor():
		if !is_fall_attacking and !is_attacking:
			perform_fall_attack()
			return
	
	# Handle dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true
			play_dash_ready_effect()
	
	# Handle dash state
	if is_dashing:
		dash_timer -= delta
		ghost_timer -= delta  # Add ghost timer
		update_fire_trail(delta)  # Add this line
		
		if ghost_timer <= 0:  # Spawn ghost on interval
			ghost_timer = GHOST_SPAWN_INTERVAL
			spawn_ghost()
			
		if dash_timer <= 0:
			end_dash()
		else:
			current_state = State.DASH
			var dash_direction = -1 if animated_sprite_2d.flip_h else 1
			velocity = Vector2(DASH_SPEED * dash_direction, 0)
			modulate.a = 0.5
			move_and_slide()
			return
	
	# Check for dash input before other movement
	if Input.is_action_just_pressed("dash") and can_dash and is_on_floor():
		perform_dash()
		return
	
	# Handle stamina regeneration when not blocking
	if !is_blocking and stamina < MAX_STAMINA:
		stamina = min(stamina + STAMINA_REGEN_RATE * delta, MAX_STAMINA)
		stamina_changed.emit(stamina, MAX_STAMINA)
	
	# Handle stamina drain while blocking
	if is_blocking and stamina > 0:
		stamina = max(stamina - STAMINA_DRAIN_RATE * delta, 0)
		stamina_changed.emit(stamina, MAX_STAMINA)
		if stamina == 0:
			stop_blocking()
	
	# Update block animation state
	if is_blocking:
		match block_animation_state:
			1:  # Startup
				if !animated_sprite_2d.is_playing() or animated_sprite_2d.animation != "block_startup":
					print("[BLOCK DEBUG] Block startup complete, transitioning to hold")
					block_animation_state = 2
					animated_sprite_2d.play("block_hold")
			2:  # Hold
				if animated_sprite_2d.animation != "block_hold":
					animated_sprite_2d.play("block_hold")
			3:  # Release
				if !animated_sprite_2d.is_playing() or animated_sprite_2d.animation != "block_release":
					print("[BLOCK DEBUG] Block release complete")
					block_animation_state = 0
					current_state = State.IDLE
					animated_sprite_2d.play("idle")
			4:  # Impact - don't interrupt this animation
				if animated_sprite_2d.animation != "block_impact":
					print("[BLOCK DEBUG] Block impact animation interrupted")
					animated_sprite_2d.play("block_impact")
	
	# Handle movement and physics
	var direction = Input.get_axis("left", "right")
	
	if is_on_floor():
		handle_ground_movement(direction)
	else:
		handle_air_movement(direction, delta)
	
	handle_jump_physics(delta)
	apply_gravity(delta)
	update_timers(delta)
	handle_state(delta)
	handle_combat(delta)
	move_and_slide()
	update_animations()

func handle_jump_physics(delta: float) -> void:
	if is_jumping:
		if Input.is_action_pressed("jump"):
				jump_time += delta
				if jump_time > MAX_JUMP_HEIGHT_TIME:
					is_jumping = false
		else:
			is_jumping = false
	
	if is_double_jumping:
		if Input.is_action_pressed("jump"):
			double_jump_time += delta
			if double_jump_time > MAX_JUMP_HEIGHT_TIME:
				is_double_jumping = false
		else:
			is_double_jumping = false

func update_timers(delta: float) -> void:
	if is_on_floor():
		jumps_remaining = MAX_JUMPS  # Reset jumps when touching ground
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(coyote_timer - delta, 0)
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0)

func handle_state(delta: float) -> void:
	var previous_state = current_state
	
	# Only log state changes
	if previous_state != current_state:
		print("[STATE] Changed from ", State.keys()[previous_state], " to ", State.keys()[current_state])
	
	# Force state check - if we're in IDLE but shouldn't be
	if current_state == State.IDLE:
		if is_blocking:
			current_state = State.BLOCK
		elif is_attacking:
			match current_attack_state:
				AttackState.ATTACK1: animated_sprite_2d.play("attack1")
				AttackState.ATTACK2: animated_sprite_2d.play("attack2")
				AttackState.ATTACK3: animated_sprite_2d.play("attack3")
		elif is_hurt:
			current_state = State.HURT
		elif is_fall_attacking:
			current_state = State.FALL_ATTACK
	
	wall_jump_timer = max(wall_jump_timer - delta, 0)
	
	var was_on_floor = is_on_floor()
	
	if !was_on_floor:
		apply_gravity(delta)
	
	var direction = Input.get_axis("left", "right")
	
	wall_direction = get_wall_direction()
	is_wall_sliding = can_wall_slide and is_near_wall() and !is_on_floor() and velocity.y > 0
	
	# Check if we can climb the wall
	if is_wall_sliding:
		var space_state = get_world_2d().direct_space_state
		
		# Get character's collision box top edge position
		var character_top = global_position.y - 32  # Adjust based on your collision box height
		
		# Forward ray to detect wall and find platform edge
		var wall_check = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + Vector2(-wall_direction * WALL_CLIMB_CHECK_WIDTH, 0),
			1
		)
		wall_check.exclude = [self]
		var wall_result = space_state.intersect_ray(wall_check)
		
		if wall_result:
			# Find the platform edge by casting ray downward from above
			var platform_check = PhysicsRayQueryParameters2D.create(
				Vector2(wall_result.position.x, wall_result.position.y - 50),
				Vector2(wall_result.position.x, wall_result.position.y),
				1
			)
			platform_check.exclude = [self]
			var platform_result = space_state.intersect_ray(platform_check)
			
			if platform_result:
				var platform_top = platform_result.position.y
				
				# Check if character is near the correct height
				var height_difference = character_top - platform_top
				
				# Allow climb if character is slightly above or below platform edge
				can_wall_climb = height_difference > -5 and height_difference < 5
				
				# If too high, keep sliding
				if height_difference < -5:
					velocity.y = WALL_SLIDE_SPEED
				# If at right height, stop sliding and allow climbing
				elif can_wall_climb:
					velocity.y = 0
					global_position.y = platform_top + 32  # Align perfectly with platform
					
					# Add climbing when pressing up
					if Input.is_action_just_pressed("up"):
						velocity = WALL_CLIMB_FORCE
						is_wall_climbing = true
						animated_sprite_2d.play("wall_climb")
						return
	
	if is_wall_sliding:
		velocity.y = WALL_SLIDE_SPEED if !can_wall_climb else 0
		current_state = State.WALL_SLIDE
		jumps_remaining = MAX_JUMPS
	else:
		if is_on_floor():
			if direction == 0:
				velocity.x = 0
			current_state = State.IDLE
			can_wall_slide = true
		else:
			if !is_near_wall() or velocity.y > 0:
				current_state = State.FALL
	
	match current_state:
		State.IDLE, State.RUN:
			handle_ground_movement(direction)
		State.JUMP, State.FALL, State.WALL_SLIDE:
			handle_air_movement(direction, delta)
	
	if can_jump() and (jump_buffer_timer > 0 or Input.is_action_just_pressed("jump")):
		perform_jump()
	
	if is_wall_sliding:
		queue_redraw()  # Show the green dot

func perform_jump() -> void:
	if is_attacking:
		return
		
	current_state = State.JUMP
	jump_buffer_timer = 0
	
	if is_wall_sliding:  # Wall jump
		var jump_direction = -wall_direction
		velocity = Vector2(WALL_JUMP_FORCE.x * jump_direction, WALL_JUMP_FORCE.y)
		animated_sprite_2d.stop()
		animated_sprite_2d.play("wall_jump")
		animated_sprite_2d.flip_h = jump_direction < 0
		is_wall_sliding = false
		can_wall_slide = false
		wall_jump_timer = WALL_JUMP_TIME
		wall_jump_control_timer = WALL_JUMP_CONTROL_DELAY
		jumps_remaining = MAX_JUMPS
		return
	
	if !is_on_floor():  # Double jump
		if jumps_remaining > 0:
			velocity.y = DOUBLE_JUMP_FORCE
			jumps_remaining -= 1
			is_double_jumping = true
			double_jump_time = 0
			animated_sprite_2d.stop()
			animated_sprite_2d.play("double_jump")
		return
	
	if jumps_remaining > 0: 
		jumps_remaining -= 1

	velocity.y = JUMP_FORCE
	is_jumping = true
	jump_time = 0
	coyote_timer = 0

func handle_ground_movement(direction: float) -> void:
	if is_blocking:
		velocity.x = 0  # Stop movement while blocking
		return
		
	if direction:
		# Get the raw input strength for analog input (d-pad or analog stick)
		var input_strength = abs(Input.get_axis("left", "right"))
		
		# Only move if input strength is above deadzone
		if input_strength > INPUT_DEADZONE:
			# Calculate target speed based on input strength
			var target_speed = WALK_SPEED
			if input_strength > 0.7:  # Only run if not blocking
				target_speed = RUN_SPEED
				
			velocity.x = direction * target_speed
			animated_sprite_2d.flip_h = direction < 0
		else:
			velocity.x = 0
	else:
		# Immediate stop
		velocity.x = 0

func handle_air_movement(direction: float, delta: float) -> void:
	wall_jump_control_timer = max(wall_jump_control_timer - delta, 0)
	
	if direction != 0:
		var control_multiplier = 1.0
		if wall_jump_control_timer > 0:
			control_multiplier = WALL_JUMP_CONTROL_MULTIPLIER  # Reduced control during wall jump
			
		var target_speed = direction * AIR_SPEED
		velocity.x = move_toward(velocity.x, target_speed, AIR_ACCELERATION * delta * control_multiplier)
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0 or jumps_remaining > 0

func update_animations() -> void:
	if is_attacking or is_blocking:  # Add is_blocking check
		return
	
	previous_anim_state = current_anim_state
	
	# Update the animation state based on movement
	if is_wall_sliding:
		animated_sprite_2d.play("wall_slide")
		animated_sprite_2d.flip_h = wall_direction < 0
		return

	if is_on_floor():
		var speed = abs(velocity.x)
		if speed > 10:
			if speed <= WALK_SPEED * 1.1:  # Add some tolerance
				current_anim_state = AnimState.WALK
			else:
				current_anim_state = AnimState.RUN
		else:
			current_anim_state = AnimState.IDLE
	else:
		if velocity.y < 0:
			current_anim_state = AnimState.JUMP
		else:
			current_anim_state = AnimState.FALL
			
	# Only play animations if we're not attacking
	if !is_attacking:
		match current_anim_state:
			AnimState.IDLE:
				if previous_anim_state == AnimState.FALL:
					animated_sprite_2d.play("landing")
				else:
					animated_sprite_2d.play("idle")
			
			AnimState.WALK:
				if previous_anim_state == AnimState.FALL:
					animated_sprite_2d.play("landing")
				else:
					animated_sprite_2d.play("walk")
			
			AnimState.RUN:
				if previous_anim_state == AnimState.FALL:
					animated_sprite_2d.play("landing")
				else:
					animated_sprite_2d.play("run")
			
			AnimState.JUMP:
				if previous_anim_state in [AnimState.IDLE, AnimState.WALK, AnimState.RUN]:
					animated_sprite_2d.play("jump_start")
				elif jumps_remaining == 0:
					animated_sprite_2d.play("double_jump")
				else:
					animated_sprite_2d.play("jump")
			
			AnimState.FALL:
				animated_sprite_2d.play("fall")

func _on_animation_finished() -> void:
	match animated_sprite_2d.animation:
		"block_start":
			if is_blocking:
				animated_sprite_2d.play("block_hold")
		"block_impact":
			if is_blocking:
				animated_sprite_2d.play("block_hold")
		"block_end":
			if !is_blocking:
				animated_sprite_2d.play("idle")

func apply_gravity(delta: float) -> void:
	if !is_on_floor():
		var gravity_scale = FALL_GRAVITY_MULTIPLIER if velocity.y > 0 else 1.0
		gravity_scale *= 2.0 if !Input.is_action_pressed("jump") and velocity.y < 0 else 1.0
		velocity.y += GRAVITY * gravity_scale * delta

func _process(delta: float) -> void:
	if is_jumping and Input.is_action_pressed("jump"):
		var jump_force = lerp(MIN_JUMP_FORCE, JUMP_FORCE, 
			(jump_time / MAX_JUMP_HEIGHT_TIME) * (jump_time / MAX_JUMP_HEIGHT_TIME))
		velocity.y = min(velocity.y, jump_force)
	
	if is_double_jumping and Input.is_action_pressed("jump"):
		var double_jump_force = lerp(MIN_DOUBLE_JUMP_FORCE, DOUBLE_JUMP_FORCE, 
			(double_jump_time / MAX_JUMP_HEIGHT_TIME) * (double_jump_time / MAX_JUMP_HEIGHT_TIME))
		velocity.y = min(velocity.y, double_jump_force)

	queue_redraw()  # Ensure debug drawing updates

func is_near_wall() -> bool:
	return is_on_wall() and Input.get_axis("left", "right") != 0

func get_wall_direction() -> float:
	if !is_on_wall(): return 0.0
	return -1.0 if get_wall_normal().x < 0 else 1.0

func handle_combat(delta: float) -> void:
	if attack_combo_timer > 0:
		attack_combo_timer -= delta
		if attack_combo_timer <= 0:
			current_attack_state = AttackState.NONE
			if !animated_sprite_2d.is_playing():
				is_attacking = false
				if current_state == State.ATTACK:  # Only change state if we're still in attack
					current_state = State.IDLE
					animated_sprite_2d.play("idle")
	
	if attack_buffer_timer > 0:
		attack_buffer_timer -= delta
		if attack_buffer_timer <= 0:
				next_attack_buffered = false
	
	if Input.is_action_just_pressed("attack"):
		if is_blocking:  # Prevent attacking while blocking
			return
			
		if can_attack and !is_attacking:
			perform_attack()
		elif is_attacking:
			next_attack_buffered = true
			attack_buffer_timer = ATTACK_BUFFER_TIME

func perform_attack() -> void:
	if is_blocking:  # Double check to prevent attacking while blocking
		return
		
	if is_wall_sliding:
		animated_sprite_2d.play("wall_attack")
		current_state = State.WALL_ATTACK
		is_attacking = true
		enable_hitbox(0.2)
		return
	
	match current_attack_state:
		AttackState.NONE:
				animated_sprite_2d.play("attack1")
				current_attack_state = AttackState.ATTACK1
				current_state = State.ATTACK
		AttackState.ATTACK1:
			if attack_combo_timer > 0:
				animated_sprite_2d.play("attack2")
				current_attack_state = AttackState.ATTACK2
				current_state = State.ATTACK
		AttackState.ATTACK2:
			if attack_combo_timer > 0:
				animated_sprite_2d.play("attack3")
				current_attack_state = AttackState.ATTACK3
				current_state = State.ATTACK
	
	attack_combo_timer = ATTACK_COMBO_WINDOW
	is_attacking = true
	enable_hitbox(0.2)

func take_damage(amount: int) -> void:
	if is_invincible:
		return
		
	if is_blocking and stamina_bar and stamina_bar.has_charges():
		# Use a block charge
		if stamina_bar.use_charge():
			# Play block impact animation
			animated_sprite_2d.stop()
			animated_sprite_2d.play("block_impact")
			
			# Take reduced damage
			var reduced_damage = int(amount * BLOCK_DAMAGE_REDUCTION)
			health = max(0, health - reduced_damage)
			emit_signal("health_changed", health)
			return
			
	# If not blocking or no charges, take full damage
	health = max(0, health - amount)
	emit_signal("health_changed", health)
	
	# Reset states when taking damage
	is_attacking = false
	is_blocking = false
	current_attack_state = AttackState.NONE
	attack_combo_timer = 0
	
	# Play hurt animation and set hurt state
	animated_sprite_2d.play("hurt")
	is_hurt = true
	current_state = State.HURT
	hurt_timer = HURT_STATE_DURATION
	
	if health <= 0:
		die()

func die() -> void:
	died.emit()
	# You can add death animation here
	queue_free()
func disable_hitbox() -> void:
	if !is_instance_valid(self):
		return
		
	set_hitbox_state(false)
	if hitbox:
		hitbox.disable()

func enable_hitbox(duration: float = 0.0) -> void:
	if !is_instance_valid(self):
		return
		
	var facing = -1 if animated_sprite_2d.flip_h else 1
	set_hitbox_state(true, Vector2(20, 0))
	
	# Set the hitbox damage using static function
	if hitbox:
		var base_damage = DamageValues.get_base_attack_damage()
		hitbox.damage = base_damage + damage_boost
	
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(self):
			disable_hitbox()

func set_hitbox_state(active: bool, offset: Vector2 = Vector2.ZERO) -> void:
	hitbox_state.active = active
	hitbox_state.offset = offset
	hitbox_state.monitoring = active
	hitbox_state.monitorable = active
	hitbox_state.collision_disabled = !active
	update_hitbox_state()

func update_hitbox_state() -> void:
	if !is_instance_valid(hitbox):
		return
		
	if hitbox_state.active:
		var facing = -1 if animated_sprite_2d.flip_h else 1
		var new_position = Vector2(
			hitbox_state.offset.x * facing,
			hitbox_state.offset.y
		)
		hitbox.call_deferred("set", "position", new_position)
		
		hitbox.call_deferred("set", "monitoring", hitbox_state.monitoring)
		hitbox.call_deferred("set", "monitorable", hitbox_state.monitorable)
		
		if is_instance_valid(hitbox_collision):
			hitbox_collision.call_deferred("set", "disabled", hitbox_state.collision_disabled)

func modify_max_health(multiplier: float) -> void:
	var old_max_health = current_max_health
	max_health_multiplier *= multiplier  # Multiply instead of assign to allow stacking
	current_max_health = base_max_health * max_health_multiplier
	
	# Adjust current health proportionally
	var health_percentage = float(health) / float(old_max_health)
	health = int(current_max_health * health_percentage)
	health = clamp(health, 1, current_max_health)  # Ensure health is between 1 and max
	
	if is_instance_valid(self):
		health_changed.emit(health)

func reset_max_health() -> void:
	max_health_multiplier = 1.0  # Reset the multiplier
	current_max_health = base_max_health
	health = clamp(health, 1, current_max_health)
	if is_instance_valid(self):
		health_changed.emit(health)

func enable_shield(cooldown: float) -> void:
	shield_enabled = true
	shield_cooldown = cooldown
	shield_timer = 0.0
	has_shield = true
	
	if shield_sprite:
		shield_sprite.visible = true
		shield_sprite.modulate.a = 0.5

func disable_shield() -> void:
	if !is_instance_valid(self):
		return
	shield_enabled = false
	has_shield = false
	shield_timer = 0.0
	if shield_sprite:
		shield_sprite.visible = false

func enable_dash_damage(damage: float) -> void:
	dash_damage_enabled = true
	dash_damage = damage
	
func disable_dash_damage() -> void:
	dash_damage_enabled = false
	dash_damage = 0.0

func modify_dash_cooldown(multiplier: float) -> void:
	current_dash_cooldown = BASE_DASH_COOLDOWN * multiplier
	
	# If currently in cooldown, adjust remaining time
	if !can_dash and dash_cooldown_timer > 0:
		dash_cooldown_timer *= multiplier

func reset_dash_cooldown() -> void:
	current_dash_cooldown = BASE_DASH_COOLDOWN
	
	# Reset current cooldown timer if it's active
	if !can_dash:
		dash_cooldown_timer = current_dash_cooldown

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_parent().has_method("is_dead") and area.get_parent().is_dead():
		return
		
	if area.is_in_group("hurtbox"):
		if area.get_parent().is_in_group("enemy"):
			apply_damage_to_target(area)
		
		if current_state == State.FALL_ATTACK:
			end_fall_attack()
			current_state = State.JUMP
			velocity.y = JUMP_FORCE

func apply_damage_to_target(area: Area2D) -> void:
	if area.get_parent().has_method("is_dead") and area.get_parent().is_dead():
		return
		
	if area.is_in_group("hurtbox"):
		var final_damage = 0
		
		if is_dashing and dash_damage_enabled:
			final_damage = int(dash_damage)  # Use the dash damage from powerup
		else:
			var base_damage = DamageValues.get_base_attack_damage()  # Use static function
			final_damage = base_damage + damage_boost  # Add flat damage boost
		
		# Set the hitbox damage before applying it
		if hitbox:
			hitbox.damage = final_damage
		
		var knockback_dir = (area.global_position - global_position).normalized()
		
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(final_damage)  # Only pass damage amount
		
		if current_state == State.FALL_ATTACK:
			if target.is_in_group("enemy"):
				handle_fall_attack_hit(target)
			else:
				end_fall_attack()
				current_state = State.JUMP
				velocity.y = JUMP_FORCE

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if !is_instance_valid(self):
		return
		
	if is_invincible:
		return
		
	if area.is_in_group("hitbox"):
		var damage = 10  # Default damage if not specified
		if area.has_method("get_damage"):
			damage = area.get_damage()
		
		var knockback_dir = (global_position - area.global_position).normalized()
		var knockback_force = HURT_KNOCKBACK_FORCE.length()
		
		# Set invincibility and hurt state BEFORE taking damage
		is_invincible = true
		invincibility_timer = INVINCIBILITY_TIME
		is_hurt = true
		hurt_timer = HURT_STATE_DURATION
		current_state = State.HURT
		
		# Apply knockback directly
		velocity = knockback_dir * knockback_force
		
		take_damage(damage)  # Only pass the damage amount

func handle_hurt_state(delta: float) -> void:
	if !is_hurt:
		return
		
	hurt_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 1000 * delta)
	
	if hurt_timer <= 0:
		is_hurt = false
		current_state = State.IDLE
		is_attacking = false  # Reset attacking state
		animated_sprite_2d.play("idle")
		
		# Reset all combat states
		is_fall_attacking = false
		current_attack_state = AttackState.NONE
		attack_combo_timer = 0
		if hitbox:
			disable_hitbox()
			
	# Update invincibility
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			modulate.a = 1.0
		else:
			# Flash the sprite while invincible
			modulate.a = 0.5 if int(Time.get_ticks_msec() * 0.01) % 2 == 0 else 1.0

func handle_fall_attack_hit(enemy: Node2D) -> void:
	var bounce_force = max(FALL_ATTACK_BOUNCE_FORCE, JUMP_FORCE * 4.8)
	
	velocity.y = bounce_force
	end_fall_attack()
	current_state = State.JUMP
	
	# Add screen shake
	shake_camera(FALL_ATTACK_SHAKE_STRENGTH, FALL_ATTACK_SHAKE_DURATION)

func play_landing_animation() -> void:
	is_landing = true
	landing_timer = LANDING_DURATION
	animated_sprite_2d.play("landing")
	
	# End fall attack if it's still active
	if is_fall_attacking:
		end_fall_attack()
	
	# Create squash and stretch effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(LANDING_STRETCH, LANDING_SQUASH), LANDING_DURATION * 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, LANDING_DURATION * 0.7)
	
	# Add particles or other effects
	spawn_landing_particles()
	
	# Add extra screen shake for landing
	shake_camera(FALL_ATTACK_SHAKE_STRENGTH * 0.5, FALL_ATTACK_SHAKE_DURATION * 0.5)

func perform_fall_attack() -> void:
	if current_state == State.FALL_ATTACK or !can_fall_attack():
		return
		
	current_state = State.FALL_ATTACK
	is_fall_attacking = true
	is_attacking = true
	velocity.y = FALL_ATTACK_SPEED
	velocity.x = 0
	animated_sprite_2d.play("fall_attack")
	
	collision_mask = LAYERS.WORLD | LAYERS.ENEMY
	
	if is_instance_valid(hitbox):
		var hitbox_offset = Vector2(0, 40)
		set_hitbox_state(true, hitbox_offset)
		
		hitbox.collision_layer = LAYERS.PLAYER_HITBOX
		hitbox.collision_mask = LAYERS.ENEMY_HURTBOX
		
		var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size = Vector2(60, 30)
			
	# Check for collisions with enemies
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("enemy"):
			if collider.has_method("take_damage"):
				collider.take_damage(FALL_ATTACK_DAMAGE)  # Only pass damage amount
				handle_fall_attack_hit(collider)

func play_dash_ready_effect() -> void:
	if !is_instance_valid(self):
		return
		
	var tween = create_tween()
	
	# Flash bright with blue tint
	tween.tween_property(self, "modulate", 
		DASH_READY_COLOR * DASH_READY_FLASH_INTENSITY, 
		DASH_READY_FLASH_DURATION * 0.2)
	
	# Return to normal
	tween.tween_property(self, "modulate", 
		Color.WHITE, 
		DASH_READY_FLASH_DURATION * 0.3)
	
	# Make sure alpha is 1.0
	modulate.a = 1.0

func spawn_ghost() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = animated_sprite_2d.sprite_frames.get_frame_texture("dash", animated_sprite_2d.frame)
	ghost.global_position = global_position + Vector2(0, -48)
	ghost.flip_h = animated_sprite_2d.flip_h
	ghost.modulate.a = GHOST_OPACITY
	ghost.z_index = z_index
	get_parent().add_child(ghost)
	
	# Create fade out tween
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_DURATION)
	tween.tween_callback(ghost.queue_free)

func end_dash() -> void:
	is_dashing = false
	is_invincible = false
	ghost_timer = 0
	modulate.a = 1.0
	
	if dash_damage_enabled:
		disable_hitbox()
	
	collision_mask = LAYERS.WORLD | LAYERS.ENEMY
	
	if is_on_floor():
		current_state = State.IDLE
		animated_sprite_2d.play("idle")
	else:
		current_state = State.FALL
		animated_sprite_2d.play("fall")

func perform_dash() -> void:
	if !is_instance_valid(self):
		return
		
	is_attacking = false
	current_attack_state = AttackState.NONE
	
	ghost_timer = 0
	is_dashing = true
	can_dash = false
	is_invincible = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = current_dash_cooldown
	current_state = State.DASH
	
	collision_mask = LAYERS.WORLD
	animated_sprite_2d.play("dash")
	
	if dash_damage_enabled:
		var facing = -1 if animated_sprite_2d.flip_h else 1
		set_hitbox_state(true, Vector2(20 * facing, 0))

func end_fall_attack() -> void:
	is_fall_attacking = false
	is_attacking = false
	disable_hitbox()
	set_deferred("collision_mask", LAYERS.WORLD | LAYERS.ENEMY)

func can_fall_attack() -> bool:
	return !is_fall_attacking and !is_attacking and !is_on_floor()

func spawn_landing_particles() -> void:
	# You can add particle effects here
	# For example:
	# var particles = preload("res://effects/landing_particles.tscn").instantiate()
	# particles.global_position = global_position + Vector2(0, 20)
	# get_parent().add_child(particles)
	pass

func shake_camera(strength: float, duration: float) -> void:
	if camera:
		var tween = create_tween()
		
		for i in range(int(duration / 0.05)):  # Create multiple shake steps
			# Random offset
			var offset = Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
			
			# Shake
			tween.tween_property(camera, "offset", offset, 0.05)
		
		# Reset camera position
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func modify_damage(boost: float) -> void:
	print("[DAMAGE DEBUG] Setting damage boost to: +", boost)
	damage_boost += boost  # Changed from = to += to allow stacking

func reset_damage() -> void:
	print("[DAMAGE DEBUG] Resetting damage boost to 0")
	damage_boost = 0

func enable_fire_trail(damage: float, duration: float, interval: float) -> void:
	fire_trail_enabled = true
	fire_trail_damage = damage
	fire_trail_duration = duration
	fire_trail_interval = interval
	fire_trail_timer = 0.0
	print("[DEBUG] Fire Trail: Enabled with damage ", damage, " per second")

func disable_fire_trail() -> void:
	fire_trail_enabled = false
	fire_trail_damage = 0.0
	print("[DEBUG] Fire Trail: Disabled")

func update_fire_trail(delta: float) -> void:
	if !fire_trail_enabled or !is_dashing:
		return
		
	fire_trail_timer -= delta
	if fire_trail_timer <= 0:
		spawn_fire_trail()
		fire_trail_timer = fire_trail_interval

func spawn_fire_trail() -> void:
	var facing = -1 if animated_sprite_2d.flip_h else 1
	
	for i in range(2):
		var offset = i * 10
		var patch = FireTrailEffect.instantiate()
		patch.global_position = global_position + Vector2(-20 * facing - (offset * facing), 20)
		patch.initialize(fire_trail_damage, fire_trail_duration)
		get_parent().add_child(patch)

func start_blocking() -> void:
	if current_state == State.HURT or current_state == State.DASH:
		return
		
	if !stamina_bar:
		stamina_bar = get_node_or_null("../GameUI/StaminaBar")
		if !stamina_bar:
			return
			
	if !is_blocking and stamina_bar.has_charges():
		is_blocking = true
		current_state = State.BLOCK
		stamina_bar.show_bar()
		
		# Play block startup animation
		animated_sprite_2d.stop()
		animated_sprite_2d.play("block_start")

func stop_blocking() -> void:
	if is_blocking:
		is_blocking = false
		current_state = State.IDLE
		stamina_bar.hide_bar()
		
		# Play block end animation
		animated_sprite_2d.stop()
		animated_sprite_2d.play("block_end")

func handle_block_state() -> void:
	if !Input.is_action_pressed("block") or !stamina_bar.has_charges():
		stop_blocking()
		return
		
	# Don't allow attacking while blocking
	if Input.is_action_just_pressed("attack"):
		return
		
	if !is_blocking:
		start_blocking()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("block"):
		start_blocking()
	elif event.is_action_released("block"):
		stop_blocking()
