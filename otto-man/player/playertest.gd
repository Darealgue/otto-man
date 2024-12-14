extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox_collision = $Hurtbox/CollisionShape2D

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

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH }
enum AnimState { IDLE, RUN, JUMP, FALL }
enum AttackState { NONE, ATTACK1, ATTACK2, ATTACK3 }

var current_state: State
var current_anim_state: AnimState
var previous_anim_state: AnimState
var current_attack_state = AttackState.NONE
var can_attack = true
var attack_combo_timer = 0.0
var attack_combo_window = 0.5
var is_attacking = false
var health = 100

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

# Add these signals at the top of the file
signal health_changed(new_health: int)
signal died
signal hit_landed(hit_info: String)

# Add these constants with your other constants
const MAX_HEALTH = 100
const INVINCIBILITY_TIME = 0.5  # Seconds of invincibility after taking damage

# Add these variables with your other variables
var invincibility_timer: float = 0
var is_invincible: bool = false

# Add these constants at the top with other constants
const DASH_SPEED = 2500
const DASH_DURATION = 0.1
const DASH_COOLDOWN = 1.2

# Add these variables with other variables
var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

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

func _ready():
	current_state = State.IDLE
	current_anim_state = AnimState.IDLE
	previous_anim_state = AnimState.IDLE
	jumps_remaining = MAX_JUMPS
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	set_process_input(true)
	
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
	
	health = MAX_HEALTH
	
	# Configure hitbox/hurtbox layers
	if hitbox:
		hitbox.is_player = true
		hitbox.collision_layer = 16  # Layer 5 (PLAYER HITBOX)
		hitbox.collision_mask = 32   # Layer 6 (ENEMY HURTBOX)
	
	if hurtbox:
		hurtbox.is_player = true
		hurtbox.collision_layer = 8   # Layer 4 (PLAYER HURTBOX)
		hurtbox.collision_mask = 64   # Layer 7 (ENEMY HITBOX)

func _physics_process(delta: float) -> void:
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

	handle_jump_physics(delta)
	apply_gravity(delta)
	update_timers(delta)
	handle_state(delta)
	handle_combat(delta)
	move_and_slide()
	update_animations()
	
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			modulate = Color.WHITE
	
	# Update hitbox position based on direction
	var facing = -1 if animated_sprite_2d.flip_h else 1
	if hitbox:
		hitbox.position.x = abs(hitbox.position.x) * facing
		hitbox.scale.x = facing

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
		# Only slide if we can't climb
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
		wall_jump_control_timer = WALL_JUMP_CONTROL_DELAY  # Start control delay
		jumps_remaining = MAX_JUMPS
		return
	
	if !is_on_floor():  # Double jump
		if jumps_remaining > 0:  # Check if double jump is available
			velocity.y = DOUBLE_JUMP_FORCE
			jumps_remaining -= 1
			is_double_jumping = true
			double_jump_time = 0
			animated_sprite_2d.stop()
			animated_sprite_2d.play("double_jump")  # Play double jump animation
		return
	
	# Normal jump
	if jumps_remaining > 0: 
		jumps_remaining -= 1

	velocity.y = JUMP_FORCE
	is_jumping = true
	jump_time = 0
	coyote_timer = 0

func handle_ground_movement(direction: float) -> void:
	if direction:
		velocity.x = direction * SPEED
		animated_sprite_2d.flip_h = direction < 0
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
	if is_attacking:  # Remove ledge_grabbing check
		return
	
	previous_anim_state = current_anim_state
	
	# Update the animation state based on movement
	if is_wall_sliding:
		animated_sprite_2d.play("wall_slide")
		animated_sprite_2d.flip_h = wall_direction < 0
		return

	if is_on_floor():
		if abs(velocity.x) > 10:
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
			
			AnimState.RUN:
				if previous_anim_state == AnimState.FALL:
					animated_sprite_2d.play("landing")
				else:
					animated_sprite_2d.play("run")
			
			AnimState.JUMP:
				if previous_anim_state in [AnimState.IDLE, AnimState.RUN]:
					animated_sprite_2d.play("jump_start")
				elif jumps_remaining == 0:
					animated_sprite_2d.play("double_jump")
				else:
					animated_sprite_2d.play("jump")
			
			AnimState.FALL:
				animated_sprite_2d.play("fall")

func _on_animation_finished():
	if animated_sprite_2d.animation == "dash":
		if is_dashing:
			animated_sprite_2d.play("dash")  # Keep playing dash while dashing
		else:
			if is_on_floor():
				current_state = State.IDLE
				animated_sprite_2d.play("idle")
			else:
				current_state = State.FALL
				animated_sprite_2d.play("fall")
	elif animated_sprite_2d.animation.begins_with("attack") or animated_sprite_2d.animation == "wall_attack":
		is_attacking = false
		
		# Reset attack state if it was the final attack in combo or wall attack
		if (animated_sprite_2d.animation == "attack3" or 
			animated_sprite_2d.animation == "wall_attack" or 
			attack_combo_timer <= 0):
			current_attack_state = AttackState.NONE
			attack_combo_timer = 0
			next_attack_buffered = false
			
			# Reset attack buffer timer
			attack_buffer_timer = 0
		# Check for buffered next attack
		elif next_attack_buffered and attack_buffer_timer > 0:
			next_attack_buffered = false
			perform_attack()
		else:
			update_animations()

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
	
	# Handle attack buffer timing
	if attack_buffer_timer > 0:
		attack_buffer_timer -= delta
		if attack_buffer_timer <= 0:
			next_attack_buffered = false
	
	# Check for attack input
	if Input.is_action_just_pressed("attack"):
		if can_attack and !is_attacking:
			perform_attack()
		else:
			# Buffer the attack input
			next_attack_buffered = true
			attack_buffer_timer = ATTACK_BUFFER_TIME

func perform_attack() -> void:
	if is_wall_sliding:
		animated_sprite_2d.play("wall_attack")
		current_attack_state = AttackState.ATTACK1
		animated_sprite_2d.flip_h = wall_direction < 0
		attack_combo_timer = ATTACK_COMBO_WINDOW
		is_attacking = true
		enable_hitbox()
		return
	
	# Normal attack logic for when not wall sliding
	match current_attack_state:
		AttackState.NONE:
			animated_sprite_2d.play("attack1")
			current_attack_state = AttackState.ATTACK1
		AttackState.ATTACK1:
			if attack_combo_timer > 0:
				animated_sprite_2d.play("attack2")
				current_attack_state = AttackState.ATTACK2
		AttackState.ATTACK2:
			if attack_combo_timer > 0:
				animated_sprite_2d.play("attack3")
				current_attack_state = AttackState.ATTACK3
	
	attack_combo_timer = ATTACK_COMBO_WINDOW
	is_attacking = true
	enable_hitbox()

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_invincible:
		return
		
	health = max(0, health - amount)
	health_changed.emit(health)
	
	# Apply knockback
	if knockback_direction != Vector2.ZERO:
		velocity = knockback_direction * 400
	
	# Enable invincibility and disable hurtbox
	is_invincible = true
	invincibility_timer = INVINCIBILITY_TIME
	modulate = Color(1, 1, 1, 0.5)  # Visual feedback
	
	if hurtbox:
		hurtbox.monitoring = false
	
	if health <= 0:
		die()

func die() -> void:
	died.emit()
	# You can add death animation here
	queue_free()


func enable_hitbox() -> void:
	if hitbox:
		var facing = -1 if animated_sprite_2d.flip_h else 1
		var offset = Vector2(20, 0)
		hitbox.position = offset * facing
		hitbox.enable(0.2)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Skip if target is dead
	if area.get_parent().has_method("is_dead") and area.get_parent().is_dead():
		return
		
	if area.is_in_group("hurtbox"):
		_on_hitbox_hit(area)

func _on_hitbox_hit(area: Area2D) -> void:
	# Skip if target is dead
	if area.get_parent().has_method("is_dead") and area.get_parent().is_dead():
		return
		
	if area.has_method("take_damage"):
		var damage = 10
		var knockback_dir = (area.global_position - global_position).normalized()
		area.take_damage(damage, knockback_dir)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hitbox"):
		_on_hurtbox_hurt(area)

func _on_hurtbox_hurt(area: Area2D) -> void:
	if area.has_method("get_damage"):
		var damage = area.get_damage()
		var hit_info = "Player took %d damage" % damage
		hit_landed.emit(hit_info)
		var knockback_dir = (global_position - area.global_position).normalized()
		take_damage(damage, knockback_dir)

func perform_dash() -> void:
	is_attacking = false
	current_attack_state = AttackState.NONE
	
	ghost_timer = 0  # Reset ghost timer when starting dash
	is_dashing = true
	can_dash = false
	is_invincible = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	current_state = State.DASH
	
	set_collision_mask_value(3, false)
	animated_sprite_2d.play("dash")

func end_dash() -> void:
	is_dashing = false
	is_invincible = false
	modulate.a = 1.0
	set_collision_mask_value(3, true)
	velocity = Vector2.ZERO
	
	if is_attacking:
		is_attacking = false
		current_attack_state = AttackState.NONE
	
	if is_on_floor():
		current_state = State.IDLE
		animated_sprite_2d.play("idle")
	else:
		current_state = State.FALL
		animated_sprite_2d.play("fall")

# Add this function to create ghost sprites
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

func play_dash_ready_effect() -> void:
	var tween = create_tween()
	
	# Flash bright with blue tint
	tween.tween_property(self, "modulate", 
		DASH_READY_COLOR * DASH_READY_FLASH_INTENSITY, 
		DASH_READY_FLASH_DURATION * 0.2)
	
	# Return to normal
	tween.tween_property(self, "modulate", 
		Color.WHITE, 
		DASH_READY_FLASH_DURATION * 0.3)
