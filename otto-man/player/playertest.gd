extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D

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
const WALL_JUMP_FORCE = Vector2(400, -500)
const WALL_SLIDE_SPEED = 100
const WALL_JUMP_TIME = 0.15

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE }
enum AnimState { IDLE, RUN, JUMP, FALL }

var current_state: State
var current_anim_state: AnimState
var previous_anim_state: AnimState

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

func _ready():
	current_state = State.IDLE
	current_anim_state = AnimState.IDLE
	previous_anim_state = AnimState.IDLE
	jumps_remaining = MAX_JUMPS  # Initialize jumps
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	handle_jump_physics(delta)
	apply_gravity(delta)
	update_timers(delta)
	handle_state(delta)
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
	wall_jump_timer = max(wall_jump_timer - delta, 0)
	
	# Check if on the floor
	var was_on_floor = is_on_floor()
	
	# Apply gravity if not on the floor
	if !was_on_floor:
		apply_gravity(delta)
	
	var direction = Input.get_axis("left", "right")
	
	# Wall slide check
	wall_direction = get_wall_direction()
	is_wall_sliding = is_near_wall() and !is_on_floor() and velocity.y > 0
	
	if is_wall_sliding:
		velocity.y = WALL_SLIDE_SPEED
		current_state = State.WALL_SLIDE
		jumps_remaining = MAX_JUMPS  # Reset double jump when wall sliding
	else:
		if is_on_floor():
			if direction == 0:
				velocity.x = 0
			current_state = State.IDLE  # Set to IDLE when on the floor
		else:
			# Check if the character is no longer sliding on the wall
			if !is_near_wall() or velocity.y > 0:
				current_state = State.FALL  # Set to FALL when not on the floor or wall sliding
	
	match current_state:
		State.IDLE, State.RUN:
			handle_ground_movement(direction)
		State.JUMP, State.FALL, State.WALL_SLIDE:
			handle_air_movement(direction, delta)
	
	if can_jump() and (jump_buffer_timer > 0 or Input.is_action_just_pressed("jump")):
		perform_jump()

func perform_jump() -> void:
	current_state = State.JUMP
	jump_buffer_timer = 0
	
	if is_wall_sliding:  # Wall jump
		velocity = Vector2(WALL_JUMP_FORCE.x * -wall_direction, WALL_JUMP_FORCE.y)
		animated_sprite_2d.stop()
		animated_sprite_2d.play("wall_jump")  # Play wall jump animation
		is_wall_sliding = false
		jumps_remaining = MAX_JUMPS  # Reset double jump
		return
	
	if !is_on_floor():  # Double jump
		if jumps_remaining > 0:  # Check if double jump is available
			print("Double Jump Triggered")
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
	if direction != 0:
		# Smoother acceleration to target speed
		var target_speed = direction * AIR_SPEED
		velocity.x = move_toward(velocity.x, target_speed, AIR_ACCELERATION * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		# Very quick slow-down when no input
		velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0 or jumps_remaining > 0

func update_animations() -> void:
	previous_anim_state = current_anim_state
	
	if is_wall_sliding:
		animated_sprite_2d.play("wall_slide")  # Play wall slide animation
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
			print("animstate jump oldu")
			if previous_anim_state in [AnimState.IDLE, AnimState.RUN]:
				animated_sprite_2d.play("jump_start")
			elif jumps_remaining == 0: 
				animated_sprite_2d.play("double_jump")
			else:
				animated_sprite_2d.play("jump")
				print("animstate run yada idle değil")
		
		AnimState.FALL:
			animated_sprite_2d.play("fall")

func _on_animation_finished():
	print("Animation Finished:", animated_sprite_2d.animation)
	if animated_sprite_2d.animation == "double_jump":
		print("animasyon bitti double jump")
		is_double_jump_rising = false  # Reset physics flag
		if velocity.y >= 0:
			animated_sprite_2d.play("fall")
		else:
			animated_sprite_2d.play("jump")
			print("doublejump sonrası velocity")
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

func is_near_wall() -> bool:# bitanem, seni yar diye koynuma aldığım danberi korkardım gideceğinden
	return is_on_wall() and Input.get_axis("left", "right") != 0

func get_wall_direction() -> float:
	if !is_on_wall(): return 0.0
	return -1.0 if get_wall_normal().x < 0 else 1.0
