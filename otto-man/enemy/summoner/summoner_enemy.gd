extends "res://enemy/base_enemy.gd"
class_name SummonerEnemy

@export var default_stats: Dictionary = {}

# Constants that are truly fixed behavior
const SUMMON_ANIMATION_TIMEOUT = 1.0  # Maximum time for summon animation
const WALK_START_THRESHOLD = 10.0  # Speed needed to start walking
const WALK_STOP_THRESHOLD = 5.0   # Speed needed to stop walking

# Node references
@onready var summon_timer: Timer = $SummonTimer
@onready var wall_detector: RayCast2D = $WallDetector

# State tracking
var active_birds: Array[Node] = []
var can_summon: bool = true
var is_summoning: bool = false
var return_cooldown_timer: float = 0.0
var summon_animation_timer: float = 0.0  # Track summon animation duration


func _ready() -> void:
	# Initialize default stats for summoner
	default_stats = {
		"health": 100.0,
		"movement_speed": 200.0,
		"detection_range": 400.0,
		"max_summon_count": 3,
		"summon_cooldown": 5.0,
		"return_cooldown": 3.0,
	}
	
	super._ready()
	
	# Add hurtbox to group with proper case
	if hurtbox:
		# Remove from any existing hurtbox groups to avoid duplicates
		if hurtbox.is_in_group("HurtBox"):
			hurtbox.remove_from_group("HurtBox")
		if hurtbox.is_in_group("hurtbox"):
			hurtbox.remove_from_group("hurtbox")
		if hurtbox.is_in_group("Hurtbox"):
			hurtbox.remove_from_group("Hurtbox")
		
		# Add to correct group
		hurtbox.add_to_group("hurtbox")
	
	# Initialize summon timer
	if summon_timer:
		summon_timer.wait_time = stats["summon_cooldown"] if "summon_cooldown" in stats else 5.0
		summon_timer.one_shot = true
		summon_timer.timeout.connect(_on_summon_timer_timeout)
	else:
		push_error("SummonTimer node not found!")
	
	# Connect animation signals
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)
	else:
		push_error("Sprite node not found!")

func _process(delta: float) -> void:
	_update_animation()

func _physics_process(delta: float) -> void:

	# Rest of the timers and state handling
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			invulnerable = false
			if hurtbox:
				hurtbox.monitoring = true
				hurtbox.monitorable = true
	
	if return_cooldown_timer > 0:
		return_cooldown_timer -= delta
		if return_cooldown_timer <= 0:
			can_summon = true

	# Always apply gravity (including during hurt) so launches arc properly
	apply_gravity(delta)
	
	match current_behavior:
		"hurt":
			handle_hurt_behavior(delta)
		"dead":
			velocity.x = 0
			var saved_x = global_position.x
			move_and_slide()
			global_position.x = saved_x
			return
		"idle":
			_handle_idle()
		"run":
			_handle_run(delta)
		"summon":
			_handle_summon(delta)
	
	move_and_slide()
	_update_animation()

func handle_hurt_behavior(delta: float) -> void:
	behavior_timer += delta
	
	# Ensure hurt animation is playing and freeze movement
	if sprite:
		if sprite.animation != "hurt":
			sprite.play("hurt")

	# During hurt we only stop horizontal motion; keep vertical for launch/gravity
	velocity.x = 0
	
	# Let the animation finish naturally through _on_animation_finished
	# Only force exit if we've been in hurt state too long
	if behavior_timer >= 0.5:  # Failsafe timeout
		change_behavior("run", true)

func _handle_idle() -> void:
	# Only reset horizontal velocity; don't cancel upward hurt launch
	if not (current_behavior == "hurt" and velocity.y < 0.0):
		velocity.x = 0
	
	# Clear target and ensure idle animation plays
	if target:
		target = null
		sprite.play("idle")
	
	# Check for new target
	var potential_target = get_nearest_player()
	if potential_target and is_instance_valid(potential_target):
		var distance_to_target = global_position.distance_to(potential_target.global_position)
		if distance_to_target <= (stats["detection_range"] if "detection_range" in stats else 400.0):
			target = potential_target
			change_behavior("run")

func _handle_run(delta: float) -> void:
	if not target or not is_instance_valid(target):
		change_behavior("idle")
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > (stats["detection_range"] if "detection_range" in stats else 400.0):
		change_behavior("idle")
		return
		
	var direction = global_position.direction_to(target.global_position)
	var desired_velocity = -direction * (stats["movement_speed"] if "movement_speed" in stats else 200.0)
	
	if wall_detector.is_colliding():
		desired_velocity = desired_velocity.rotated(PI/2)
	
	velocity.x = lerp(velocity.x, desired_velocity.x, 0.1)
	
	# Update animation based on movement
	if abs(velocity.x) > WALK_START_THRESHOLD:
		sprite.play("walk")
	elif abs(velocity.x) < WALK_STOP_THRESHOLD:
		sprite.play("idle")
	
	sprite.flip_h = target.global_position.x < global_position.x
	
	if can_summon and not is_summoning and active_birds.size() < (stats["max_summon_count"] if "max_summon_count" in stats else 3):
		change_behavior("summon")

func _handle_summon(delta: float) -> void:
	if not is_summoning:
		change_behavior("run")
		return
	
	# Only reset horizontal movement while summoning; preserve upward hurt motion
	if not (current_behavior == "hurt" and velocity.y < 0.0):
		velocity.x = 0
	
	# Start summon animation if not already playing
	if sprite.animation != "summon":
		can_summon = false
		sprite.play("summon")
		summon_animation_timer = 0.0
		return
	
	# Handle animation timeout
	summon_animation_timer += delta
	if summon_animation_timer >= SUMMON_ANIMATION_TIMEOUT:
		_force_complete_summon()

func _force_complete_summon() -> void:
	_complete_summon()
	is_summoning = false
	sprite.play("walk")
	change_behavior("run")

func _complete_summon() -> void:
	# Check if we're still in a valid state to summon
	if not is_summoning:
		return
		
	# Calculate how many birds to summon
	var birds_to_summon = (stats["max_summon_count"] if "max_summon_count" in stats else 3) - active_birds.size()
	
	# Summon all birds at once
	for i in range(birds_to_summon):
		var bird_scene = preload("res://enemy/flying/flying_enemy.tscn")
		var bird = bird_scene.instantiate()
		
		# Add bird to scene first so it can properly initialize
		get_parent().add_child(bird)
		
		# Set position to be slightly above and to the side of summoner
		var angle = (PI / (birds_to_summon + 1)) * (i + 1)
		var radius = 100
		var offset = Vector2(cos(angle) * radius, -sin(angle) * radius)
		bird.global_position = global_position + offset
		
		# Set summoner reference
		if bird.has_method("set_summoner"):
			bird.set_summoner(self)
		
		# Track the bird
		active_birds.append(bird)
		bird.tree_exiting.connect(_on_bird_died.bind(bird))
	
	# Start cooldown
	summon_timer.start()
	
	# Reset summoning state
	is_summoning = false
	change_behavior("run")

func _update_animation() -> void:
	# Don't change animations during special states
	if current_behavior in ["summon", "hurt", "dead"]:
		match current_behavior:
			"summon":
				if sprite.animation != "summon":
					sprite.play("summon")
			"hurt":
				if sprite.animation != "hurt":
					sprite.play("hurt")
			"dead":
				if sprite.animation != "dead":
					sprite.play("dead")
		return
	
	# Handle idle and run states
	match current_behavior:
		"idle":
			if sprite.animation != "idle":
				sprite.play("idle")
		"run":
			if abs(velocity.x) > WALK_START_THRESHOLD and sprite.animation != "walk":
				sprite.play("walk")
			elif abs(velocity.x) < WALK_STOP_THRESHOLD and sprite.animation != "idle":
				sprite.play("idle")

func _on_summon_timer_timeout() -> void:
	can_summon = true

func _on_bird_died(bird: Node) -> void:
	if bird in active_birds:  # Only remove if it's still in our array
		active_birds.erase(bird)

func die() -> void:
	
	# Reset summoning state
	is_summoning = false
	can_summon = false
	
	# Make all birds neutral when summoner dies
	for bird in active_birds:
		if is_instance_valid(bird):
			bird.set_neutral_state()
	active_birds.clear()
	
	# Change behavior to dead first
	change_behavior("dead", true)
	
	# Set z_index above player (player z_index = 5)
	if sprite:
		sprite.z_index = 6
	
	# Disable ALL collision except with ground
	collision_layer = CollisionLayers.NONE  # No collision with anything
	collision_mask = CollisionLayers.WORLD  # Only collide with environment
	set_collision_layer_value(1, false)  # Ensure no world collision
	set_collision_layer_value(2, false)  # Ensure no player collision
	set_collision_layer_value(3, false)  # Ensure no enemy collision
	set_collision_mask_value(2, false)   # Don't collide with player
	
	# Disable combat components
	if hitbox:
		hitbox.disable()
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Emit signal and notify PowerupManager
	emit_signal("enemy_defeated")
	PowerupManager.on_enemy_killed()
	
	# Don't fade out or queue_free - let corpse persist
	# await get_tree().create_timer(4.0).timeout
	# var tween = create_tween()
	# tween.tween_property(self, "modulate:a", 0.0, 2.0)
	# await tween.finished
	# queue_free()

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0) -> void:
	if current_behavior == "dead" or invulnerable:
		return
		
	
	# Update health
	health -= amount
	
	# Update health bar
	if health_bar:
		health_bar.update_health(health)
	
	# Spawn damage number
	var damage_number = preload("res://effects/damage_number.tscn").instantiate()
	add_child(damage_number)
	damage_number.global_position = global_position + Vector2(0, -50)
	damage_number.setup(int(amount))
	
	# Apply knockback
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dir = (global_position - player.global_position).normalized()
		var up = -knockback_force * 0.5
		if knockback_up_force >= 0.0:
			up = -knockback_up_force
		velocity = Vector2(dir.x * knockback_force, up)
		# Start float if launched upward
		if up < 0.0:
			air_float_timer = air_float_duration
		# If launched upward, start float window so player can juggle
		if up < 0.0 and has_node("."):
			if has_method("set"):
				air_float_timer = air_float_duration
		# If launched upward, briefly disable floor snap behavior so takeoff is visible
		if up < 0.0:
			var prev_snap = floor_snap_length
			floor_snap_length = 0.0
			var t = get_tree().create_timer(0.1)
			t.timeout.connect(func():
				if is_instance_valid(self):
					floor_snap_length = prev_snap
			)
	
	# Enter hurt state and play animation
	change_behavior("hurt", true)  # Force the behavior change
	if sprite:
		sprite.play("hurt")  # Explicitly play hurt animation
	behavior_timer = 0.0
	
	# Brief invulnerability and disable hurtbox
	invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0, 0, 1)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1, 1), HURT_FLASH_DURATION)
	
	# Check for death
	if health <= 0:
		die()
	

func _on_animation_finished() -> void:
	match sprite.animation:
		"hurt":
			if current_behavior == "hurt":
				change_behavior("run", true)
				velocity = Vector2.ZERO
				sprite.play("walk")
		"summon":
			_complete_summon()
			is_summoning = false
			sprite.play("walk")
			change_behavior("run", true)

func _on_bird_returned(bird: Node) -> void:
	if bird in active_birds:
		active_birds.erase(bird)
		
	# If all birds have returned, reset cooldown
	if active_birds.is_empty():
		can_summon = true
		if summon_timer:
			summon_timer.stop()  # Stop current cooldown timer
		# Start return cooldown to prevent immediate re-summon
		can_summon = false
		return_cooldown_timer = stats["return_cooldown"] if "return_cooldown" in stats else 3.0

func change_behavior(new_behavior: String, force: bool = false) -> void:
	if current_behavior == new_behavior:
		return
		
	if current_behavior == "summon" and not force:
		return
	
	if current_behavior == "hurt" and not force and behavior_timer < 0.3:
		return
	
	current_behavior = new_behavior
	
	match new_behavior:
		"summon":
			is_summoning = true
			sprite.play("summon")
			summon_animation_timer = 0.0
		"idle":
			sprite.play("idle")
		"hurt":
			sprite.play("hurt")
		"dead":
			sprite.play("dead")
		"run":
			if not is_summoning:
				if abs(velocity.x) > WALK_START_THRESHOLD:
					sprite.play("walk")
				else:
					sprite.play("idle")

func apply_gravity(delta: float) -> void:
	# Apply normal gravity from BaseEnemy
	super.apply_gravity(delta)

func get_behavior() -> String:
	return current_behavior
