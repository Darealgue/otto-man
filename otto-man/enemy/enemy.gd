extends CharacterBody2D

signal health_changed(new_health: int)
signal died
signal state_changed(new_state: State)
signal attack_started
signal attack_finished

@export var speed = 150.0
@export var idle_duration = 5.0  # How long to stay idle

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox

# Add these onready vars for the collision shapes
@onready var hitbox_collision = $Hitbox/CollisionShape2D
@onready var hurtbox_collision = $Hurtbox/CollisionShape2D
@onready var hitbox_position = $Hitbox.position  # Store initial hitbox position

const MAX_HEALTH = 50
const INVINCIBILITY_TIME = 0.3
const KNOCKBACK_FORCE = 300
const PATROL_TIME = 10.0  # Fixed 10 seconds of patrol before idle
const ATTACK_RANGE = 50.0
const ATTACK_COOLDOWN = 1.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction = -1
var is_idle = false
var timer = 0.0
var health: int = MAX_HEALTH
var is_invincible: bool = false
var invincibility_timer: float = 0
var is_attacking: bool = false
var can_move = true  # Add this to control movement during hurt/attack
var attack_timer: float = 0.0
var player_detection_area: Area2D

enum State { IDLE, PATROL, ATTACK, HURT, DEAD }
var current_state: State = State.PATROL

func _ready() -> void:
	if !animated_sprite:
		push_error("AnimatedSprite2D node not found!")
		queue_free()
		return
		
	# Initialize components
	_init_components()
	_connect_signals()

func _init_components() -> void:
	# Set initial state
	current_state = State.PATROL
	health = MAX_HEALTH
	
	# Disable hitbox initially
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
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle invincibility
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			modulate = Color.WHITE
	
	# Handle attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# Only move if we can
	if can_move and !is_attacking:
		# Update hitbox position based on direction
		if hitbox:
			hitbox.position.x = abs(hitbox_position.x) * direction
	
		# Check for player in range and attack if possible
		if can_attack() and player_in_range():
			perform_attack()
	
	move_and_slide()

func handle_idle_state(delta: float) -> void:
	velocity.x = 0
	animated_sprite.play("idle")
	
	timer += delta
	if timer >= idle_duration:
		is_idle = false
		timer = 0

func handle_patrol_state(delta: float) -> void:
	timer += delta
	
	# Go idle after patrol duration
	if timer >= PATROL_TIME:
		is_idle = true
		timer = 0
		return
		
	# Check for wall collision or no floor ahead
	if is_on_wall() or !check_floor_ahead():
		direction *= -1
		animated_sprite.flip_h = direction < 0
		# Flip hitbox position
		if hitbox:
			hitbox.position.x = abs(hitbox_position.x) * direction
	
	# Set movement
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
		# Disable hitbox after a short delay
		await get_tree().create_timer(0.2).timeout
		hitbox_collision.disabled = true
		hitbox.monitoring = false
		is_attacking = false  # End attack state after hitbox is disabled

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_invincible:
		return
		
	health = max(0, health - amount)
	health_changed.emit(health)
	
	# Visual feedback
	modulate = Color(1, 0.5, 0.5, 1)  # Red tint
	is_invincible = true
	invincibility_timer = INVINCIBILITY_TIME
	
	# Temporarily disable movement and hurtbox
	can_move = false
	if hurtbox_collision:
		hurtbox_collision.disabled = true
	
	# Apply knockback
	if knockback_direction != Vector2.ZERO:
		velocity = knockback_direction * KNOCKBACK_FORCE
	
	# Play hurt animation
	animated_sprite.play("hurt")
	
	if health <= 0:
		die()

func die() -> void:
	died.emit()
	# Disable movement and collision
	can_move = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	# Play death animation
	animated_sprite.play("death")
	# Wait for animation to finish
	await animated_sprite.animation_finished
	queue_free()

func _on_hitbox_hit(area: Area2D) -> void:
	if area.has_method("take_damage"):
		var damage = 5  # Adjust enemy damage as needed
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
			can_move = true
			if hurtbox_collision:
				hurtbox_collision.disabled = false  # Re-enable hurtbox after hurt
			animated_sprite.play("idle")

func can_attack() -> bool:
	return !is_attacking and attack_timer <= 0

func player_in_range() -> bool:
	if !player_detection_area:
		return false
	var overlapping = player_detection_area.get_overlapping_bodies()
	return overlapping.any(func(body): return body.is_in_group("player"))

func handle_attack_state(delta: float) -> void:
	# Stop movement during attack
	velocity.x = 0
	if !is_attacking:
		current_state = State.PATROL

func handle_hurt_state(delta: float) -> void:
	# Movement and logic handled in take_damage()
	if can_move:
		current_state = State.PATROL

func handle_dead_state(delta: float) -> void:
	# Logic handled in die()
	velocity = Vector2.ZERO

func _on_damaged(amount: int) -> void:
	# Handle enemy damage here
	print("Enemy took ", amount, " damage")
	# Implement your health system
