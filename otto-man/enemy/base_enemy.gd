class_name BaseEnemy
extends CharacterBody2D

# Core components
@export var stats: EnemyStats
@export var debug_enabled: bool = false

# Node references
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox

# Basic state tracking
var current_behavior: String = "idle"
var target: Node2D = null
var can_attack: bool = true
var attack_timer: float = 0.0
var health: float
var direction: int = 1
var behavior_timer: float = 0.0  # Timer for behavior state changes
var health_bar = null  # Add health bar reference

# Constants
const GRAVITY: float = 980.0
const FLOOR_SNAP: float = 32.0
const HURT_FLASH_DURATION := 0.1  # Duration of the red flash
const DEATH_KNOCKBACK_FORCE := 300.0  # Force applied when dying
const DEATH_UP_FORCE := 200.0  # Upward force when dying
const FALL_DELETE_TIME := 2.0  # Time after falling before deleting
const DEATH_FADE_INTERVAL := 0.4  # How often to fade in/out
const DEATH_FADE_MIN := 0.3  # Minimum opacity during fade
const DEATH_FADE_MAX := 0.8  # Maximum opacity during fade
const DEATH_FADE_SPEED := 2.0  # How fast to fade

var death_fade_timer: float = 0.0
var fade_out: bool = true  # Whether we're currently fading out or in

func _ready() -> void:
	add_to_group("enemies")
	if stats:
		health = stats.max_health
	else:
		push_warning("No stats resource assigned to enemy!")
		health = 100.0  # Default value
	
	# Create and setup health bar
	var health_bar_scene = preload("res://ui/enemy_health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	health_bar.position = Vector2(0, -60)  # Position above enemy
	health_bar.setup(health)  # Initialize with current health

func _physics_process(delta: float) -> void:
	if current_behavior != "dead":
		# Update attack cooldown
		if not can_attack:
			attack_timer -= delta
			if attack_timer <= 0:
				can_attack = true
				attack_timer = 0.0
		
		handle_behavior(delta)
		apply_gravity(delta)
		move_and_slide()
	else:
		# Apply gravity during death
		velocity.y += GRAVITY * delta
		# Don't use move_and_slide to prevent floor collision
		position += velocity * delta
		
		# Handle death fade effect
		if sprite:
			var current_alpha = sprite.modulate.a
			if fade_out:
				current_alpha = move_toward(current_alpha, DEATH_FADE_MIN, DEATH_FADE_SPEED * delta)
				if current_alpha <= DEATH_FADE_MIN:
					fade_out = false
			else:
				current_alpha = move_toward(current_alpha, DEATH_FADE_MAX, DEATH_FADE_SPEED * delta)
				if current_alpha >= DEATH_FADE_MAX:
					fade_out = true
			
			sprite.modulate = Color(1, 1, 1, current_alpha)

func handle_behavior(_delta: float) -> void:
	# Override in child classes
	pass

func get_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	var nearest_player = null
	var min_distance = stats.detection_range if stats else 300.0
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_player = player
	
	return nearest_player

func start_attack_cooldown() -> void:
	can_attack = false
	attack_timer = stats.attack_cooldown if stats else 2.0

func take_damage(amount: float, knockback_force: float = 200.0) -> void:
	if stats:
		health -= amount
		
		# Update health bar
		if health_bar:
			health_bar.update_health(health)
		
		# Spawn damage number
		var damage_number = preload("res://effects/damage_number.tscn").instantiate()
		add_child(damage_number)
		damage_number.global_position = global_position + Vector2(0, -50)  # Offset above enemy
		damage_number.setup(int(amount))
		
		# Apply knockback with increased forces
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			var dir = (global_position - player.global_position).normalized()
			# Increase base knockback and add more upward force
			var actual_knockback = knockback_force * 1.5  # 50% stronger knockback
			velocity = Vector2(
				dir.x * actual_knockback,
				-actual_knockback * 0.8  # 80% of knockback force as upward force
			)
		
		if health <= 0:
			change_behavior("dead", true)  # Force immediate change
			_apply_death_knockback()
		else:
			change_behavior("hurt", true)  # Force hurt state
			_flash_hurt()

func _flash_hurt() -> void:
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)  # Red flash
		await get_tree().create_timer(HURT_FLASH_DURATION).timeout
		sprite.modulate = Color(1, 1, 1, 1)  # Reset color

func _apply_death_knockback() -> void:
	# Get direction from the last hit (player position)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (global_position - player.global_position).normalized()
		
		# Apply knockback force
		velocity = Vector2(
			dir.x * DEATH_KNOCKBACK_FORCE,
			-DEATH_UP_FORCE  # Negative for upward force
		)
		
		# Start fall delete timer when off screen or after maximum time
		var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
		fall_timer.timeout.connect(_on_fall_timer_timeout)

func handle_hurt() -> void:
	if sprite and sprite.has_animation("hurt"):
		sprite.play("hurt")
		# Don't change animation until knockback is mostly done
		if abs(velocity.x) > 50 or abs(velocity.y) > 50:
			sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)
	current_behavior = "hurt"

func _on_hurt_animation_finished() -> void:
	if current_behavior == "hurt":
		# Only change behavior if we're still in hurt state and knockback has slowed down
		if abs(velocity.x) <= 50 and abs(velocity.y) <= 50:
			change_behavior("chase")
		else:
			# Still being knocked back, play hurt animation again
			if sprite and sprite.has_animation("hurt"):
				sprite.play("hurt")
				sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)

func handle_death() -> void:
	if sprite and sprite.has_animation("dead"):
		sprite.play("dead")
		# Start fade effect
		sprite.modulate = Color(1, 1, 1, DEATH_FADE_MAX)
		fade_out = true
	
	current_behavior = "dead"
	
	# Disable ALL collision to ensure falling through platforms
	collision_layer = 0
	collision_mask = 0
	
	# Disable combat collision
	if has_node("Hitbox"):
		get_node("Hitbox").set_deferred("monitoring", false)
		get_node("Hitbox").set_deferred("monitorable", false)
	
	if has_node("Hurtbox"):
		get_node("Hurtbox").set_deferred("monitoring", false)
		get_node("Hurtbox").set_deferred("monitorable", false)
	
	# Handle powerup drop
	if stats and stats.can_drop_powerup:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() <= stats.powerup_drop_chance:
			await get_tree().create_timer(0.5).timeout
			PowerupManager.show_powerup_selection()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.y = minf(velocity.y, GRAVITY)

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if not force and current_behavior == "dead":
		# Don't change behavior if already dead unless forced
		return
	
	# Reset behavior timer if forcing the change
	if force:
		behavior_timer = 0.0
		
	current_behavior = new_behavior
	match new_behavior:
		"hurt":
			handle_hurt()
		"dead":
			handle_death()

func _on_fall_timer_timeout() -> void:
	# Check if we're off screen or far below the ground
	if not is_on_screen() or global_position.y > 1000:
		queue_free()
	else:
		# Start another timer if still on screen
		var fall_timer = get_tree().create_timer(FALL_DELETE_TIME)
		fall_timer.timeout.connect(_on_fall_timer_timeout)

func is_on_screen() -> bool:
	if not is_instance_valid(self):
		return false
		
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return false
		
	var screen_rect = get_viewport_rect()
	var camera_pos = camera.get_screen_center_position()
	var top_left = camera_pos - screen_rect.size / 2
	var bottom_right = camera_pos + screen_rect.size / 2
	
	return global_position.x >= top_left.x - 100 and global_position.x <= bottom_right.x + 100 and \
		   global_position.y >= top_left.y - 100 and global_position.y <= bottom_right.y + 100
 
