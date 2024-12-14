extends CharacterBody2D

signal health_changed(new_health: int)
signal died

@export var speed = 150.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox_collision = $Hurtbox/CollisionShape2D
@onready var hitbox_position = $Hitbox.position

const MAX_HEALTH = 50
const INVINCIBILITY_TIME = 0.01
const KNOCKBACK_FORCE = 300
const MIN_PATROL_TIME = 10.0
const MAX_PATROL_TIME = 15.0
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.0
const HURT_STATE_TIME = 0.5  # Slightly shorter stun
const KNOCKBACK_FRICTION = 300  # Slightly faster recovery
const KNOCKBACK_FORCE_X = 350  # Slightly less horizontal knockback
const KNOCKBACK_FORCE_Y = -250  # Slightly more vertical knockback

# Constants for behavior variety
const MIN_IDLE_TIME = 3.0
const MAX_IDLE_TIME = 7.0
const MIN_SPEED = 60.0
const MAX_SPEED = 100.0
const DIRECTION_CHANGE_CHANCE = 0.01  # 1% chance per frame to change direction during patrol

# Add these constants with the other behavior constants
const MIN_DIRECTION_CHANGE_TIME = 3.0  # Minimum seconds between direction changes

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction = -1
var is_idle = false
var timer = 0.0
var health: int = MAX_HEALTH
var is_invincible: bool = false
var invincibility_timer: float = 0
var is_attacking: bool = false
var can_move = true
var attack_timer: float = 0.0
var player_detection_area: Area2D
var last_hit_direction: float = 1.0
var hurt_timer: float = 0
var current_patrol_time: float = MIN_PATROL_TIME
var rng = RandomNumberGenerator.new()

enum State { IDLE, PATROL, ATTACK, HURT, DEAD }
var current_state: State = State.PATROL

# Add these variables with other variables
var current_idle_time: float = MIN_IDLE_TIME
var base_speed: float = speed  # Store the original speed

# Add this variable with other variables
var direction_change_timer: float = 0.0

func _ready() -> void:
	if !animated_sprite:
		push_error("AnimatedSprite2D node not found!")
		queue_free()
		return
		
	_init_components()
	_connect_signals()
	rng.randomize()  # Initialize the random number generator

func _init_components() -> void:
	current_state = State.PATROL
	health = MAX_HEALTH
	
	# Randomize initial values
	current_patrol_time = rng.randf_range(MIN_PATROL_TIME, MAX_PATROL_TIME)
	current_idle_time = rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)
	speed = rng.randf_range(MIN_SPEED, MAX_SPEED)
	
	if hitbox_collision:
		hitbox_collision.disabled = true

func _connect_signals() -> void:
	if hitbox:
		
		hitbox.hit.connect(_on_hitbox_hit)
		hitbox.add_to_group("hitbox")
	if hurtbox:
		hurtbox.hurt.connect(_on_hurtbox_hurt)
		hurtbox.add_to_group("hurtbox")
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity.y += gravity * delta
		move_and_slide()
		return
		
	if current_state == State.HURT:
		pass
	
	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		
		State.PATROL:
			
			handle_patrol_state(delta)
		
		State.ATTACK:
			handle_attack_state(delta)
		
		State.HURT:
			handle_hurt_state(delta)
		
		State.DEAD:
			handle_dead_state(delta)
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			if hurtbox_collision:
				hurtbox_collision.disabled = false
	
	if attack_timer > 0:
		attack_timer -= delta
	
	if can_move and !is_attacking:
		if hitbox:
			hitbox.position.x = abs(hitbox_position.x) * direction
	
		if can_attack() and player_in_range():
			perform_attack()
	
	move_and_slide()

func handle_idle_state(delta: float) -> void:
	velocity.x = 0
	animated_sprite.play("idle")
	
	timer += delta
	if timer >= current_idle_time:
		current_state = State.PATROL
		timer = 0
		# Set new random values for next cycle
		current_idle_time = rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)
		speed = rng.randf_range(MIN_SPEED, MAX_SPEED)

func handle_patrol_state(delta: float) -> void:
	timer += delta
	direction_change_timer += delta
	
	# Only allow direction change after minimum time has passed
	if direction_change_timer >= MIN_DIRECTION_CHANGE_TIME:
		if rng.randf() < DIRECTION_CHANGE_CHANCE:
			direction *= -1
			animated_sprite.flip_h = direction < 0
			if hitbox:
				hitbox.position.x = abs(hitbox_position.x) * direction
			direction_change_timer = 0  # Reset the timer after changing direction
	
	if timer >= current_patrol_time:
		current_state = State.IDLE
		timer = 0
		velocity.x = 0
		animated_sprite.play("idle")
		current_patrol_time = rng.randf_range(MIN_PATROL_TIME, MAX_PATROL_TIME)
		direction_change_timer = 0  # Reset direction timer when entering idle
		return
		
	if is_on_wall() or !check_floor_ahead():
		direction *= -1
		animated_sprite.flip_h = direction < 0
		if hitbox:
			hitbox.position.x = abs(hitbox_position.x) * direction
	
	velocity.x = direction * speed
	if !is_attacking:
		animated_sprite.play("walk")

func check_floor_ahead() -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(direction * 30, 50),
		collision_mask
	)
	var result = space.intersect_ray(query)
	return !result.is_empty()

func perform_attack() -> void:
	if is_attacking:
		return
		
	is_attacking = true
	animated_sprite.play("attack")
	enable_hitbox()

func enable_hitbox() -> void:
	if hitbox and hitbox_collision:
		hitbox_collision.disabled = false
		hitbox.monitoring = true
		await get_tree().create_timer(0.2).timeout
		hitbox_collision.disabled = true
		hitbox.monitoring = false
		is_attacking = false

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or health <= 0:
		return
		
	last_hit_direction = sign(knockback_direction.x) if knockback_direction.x != 0 else direction
	
	if knockback_direction.x != 0:
		animated_sprite.flip_h = knockback_direction.x > 0
		direction = -sign(knockback_direction.x)  # Set direction opposite to knockback
	
	health = max(0, health - amount)
	health_changed.emit(health)
	
	modulate = Color(1, 0.5, 0.5, 1)  # Turn red
	is_invincible = true
	invincibility_timer = INVINCIBILITY_TIME
	
	current_state = State.HURT
	can_move = false
	hurt_timer = HURT_STATE_TIME
	
	if knockback_direction != Vector2.ZERO:
		var knockback_force_x = 300
		var knockback_force_y = -200
		velocity = Vector2(knockback_direction.x * knockback_force_x, knockback_force_y)
	
	animated_sprite.play("hurt")
	
	if health <= 0:
		die()

func die() -> void:
	if current_state == State.DEAD:
		return
		
	current_state = State.DEAD
	died.emit()
	
	is_invincible = true
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		if hurtbox.has_node("CollisionShape2D"):
			hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	var death_knockback = Vector2(last_hit_direction * 300, -200)
	velocity = death_knockback
	
	# Play death animation (now looping)
	animated_sprite.play("death")
	
	# Create fade out tween
	var tween = create_tween()
	tween.tween_interval(0.8)  # Wait before starting fade
	tween.tween_property(self, "modulate:a", 0.0, 0.5)  # Fade out
	tween.tween_interval(0.2)  # Short pause after fade
	tween.tween_callback(queue_free)  # Remove enemy
	
	set_physics_process(true)

func _on_hitbox_hit(area: Area2D) -> void:
	if area.has_method("take_damage"):
		var damage = 5
		var knockback_dir = (area.global_position - global_position).normalized()
		area.take_damage(damage, knockback_dir)

func _on_hurtbox_hurt(area: Area2D) -> void:
	if area.has_method("get_damage"):
		var damage = area.get_damage()
		var knockback_dir = (global_position - area.global_position).normalized()
		take_damage(damage, knockback_dir)

func _on_animation_finished() -> void:
	match animated_sprite.animation:
		"attack":
			is_attacking = false
			animated_sprite.play("idle")
		"hurt":
			modulate = Color.WHITE
			if hurtbox_collision:
				hurtbox_collision.disabled = false
			animated_sprite.play("idle")

func can_attack() -> bool:
	return !is_attacking and attack_timer <= 0

func player_in_range() -> bool:
	if !player_detection_area:
		return false
	var overlapping = player_detection_area.get_overlapping_bodies()
	return overlapping.any(func(body): return body.is_in_group("player"))

func handle_attack_state(delta: float) -> void:
	velocity.x = 0
	if !is_attacking:
		current_state = State.PATROL

func handle_hurt_state(delta: float) -> void:
	# Apply friction to slow down knockback
	velocity.x = move_toward(velocity.x, 0, KNOCKBACK_FRICTION * delta)
	
	# Update hurt timer
	hurt_timer -= delta
	
	# Check if we should exit hurt state
	if hurt_timer <= 0 and is_on_floor():
		velocity = Vector2.ZERO
		current_state = State.PATROL
		can_move = true
		direction = -last_hit_direction
		animated_sprite.flip_h = direction < 0
		hurt_timer = 0

func handle_dead_state(delta: float) -> void:
	# Let physics handle the falling
	pass

func _on_damaged(amount: int) -> void:
	pass

func _process(_delta: float) -> void:
	# Only flash during death animation
	if current_state == State.DEAD and is_invincible:
		modulate.a = 0.5 + (sin(Time.get_ticks_msec() * 0.03) * 0.5)

func is_dead() -> bool:
	return current_state == State.DEAD
