extends BaseEnemy
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

# Add debug print function
func _debug_print_hurtbox_state(context: String) -> void:
	if hurtbox:
		print("[DEBUG] Summoner Hurtbox State - ", context)
		print("- Monitoring: ", hurtbox.monitoring)
		print("- Monitorable: ", hurtbox.monitorable)
		print("- Groups: ", hurtbox.get_groups())
		print("- Process Mode: ", hurtbox.process_mode)
		print("- Visible: ", hurtbox.visible)
		print("- Owner: ", hurtbox.owner.name if hurtbox.owner else "None")

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
	_debug_print_hurtbox_state("Initial State")
	
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
		print("[DEBUG] Summoner - Added hurtbox to group 'hurtbox'")
		print("[DEBUG] Summoner - Current groups: ", hurtbox.get_groups())
	
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
	# Don't process anything if dead
	if current_behavior == "dead":
		return
		
	# Apply gravity first
	super.apply_gravity(delta)
	
	# Check for player in range
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= (stats["detection_range"] if "detection_range" in stats else 400.0) and can_summon and active_birds.size() < (stats["max_summon_count"] if "max_summon_count" in stats else 3):
			print("[Summoner] Attempting to summon. Can summon: ", can_summon, ", Active birds: ", active_birds.size())
			is_summoning = true
			sprite.play("summon")
			change_behavior("summon")
	
	# Handle behavior after gravity
	_handle_child_behavior(delta)
	
	# Apply movement
	move_and_slide()

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"idle":
			_handle_idle()
		"run":
			_handle_run(delta)
		"summon":
			_handle_summon(delta)
			
	if not can_summon:
		return_cooldown_timer -= delta
		if return_cooldown_timer <= 0:
			can_summon = true
			return_cooldown_timer = 0.0

func _handle_idle() -> void:
	# Only reset horizontal velocity, keep vertical for gravity
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
			print("[Summoner] Player detected at distance: ", distance_to_target)
			target = potential_target
			change_behavior("run")

func _handle_run(delta: float) -> void:
	if not target or not is_instance_valid(target):
		print("[Summoner] Lost target, returning to idle")
		change_behavior("idle")
		return
		
	# Check if player is out of detection range
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > (stats["detection_range"] if "detection_range" in stats else 400.0):
		print("[Summoner] Target out of detection range: ", distance_to_target)
		change_behavior("idle")
		return
		
	# Run away from player
	var direction = global_position.direction_to(target.global_position)
	var desired_velocity = -direction * (stats["movement_speed"] if "movement_speed" in stats else 200.0)
	
	# Check wall collision
	if wall_detector.is_colliding():
		# Try to move parallel to wall
		desired_velocity = desired_velocity.rotated(PI/2)
	
	# Only lerp the horizontal component, preserve vertical for gravity
	velocity.x = lerp(velocity.x, desired_velocity.x, 0.1)
	move_and_slide()
	
	# Face the player even while running
	sprite.flip_h = target.global_position.x < global_position.x
	
	# Try to summon if possible
	if can_summon and not is_summoning and active_birds.size() < (stats["max_summon_count"] if "max_summon_count" in stats else 3):
		print("[Summoner] Attempting to summon. Can summon: ", can_summon, ", Active birds: ", active_birds.size())
		change_behavior("summon")

func _handle_summon(delta: float) -> void:
	if not is_summoning:
		change_behavior("run")
		return
	
	# Only reset horizontal movement while summoning, keep vertical for gravity
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
	var old_anim = sprite.animation
	
	# Don't change animations during summon or hurt states
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
			# Animation is now handled in _handle_run to match desired movement
			pass

func _on_summon_timer_timeout() -> void:
	can_summon = true
	print("[Summoner] Summon cooldown finished - can summon again")

func _on_bird_died(bird: Node) -> void:
	if bird in active_birds:  # Only remove if it's still in our array
		active_birds.erase(bird)
		print("[Summoner] Bird died, remaining birds: ", active_birds.size())

func die() -> void:
	_debug_print_hurtbox_state("Before Death Handler")
	
	# Reset summoning state
	is_summoning = false
	can_summon = false
	
	# Make all birds neutral when summoner dies, but keep their hurtboxes active
	for bird in active_birds:
		if is_instance_valid(bird):
			bird.set_neutral_state()
	active_birds.clear()  # Clear the array since we don't control these birds anymore
	
	# Change behavior to dead first
	change_behavior("dead", true)
	
	# Keep our own hurtbox active for bouncing
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
		print("[DEBUG] Summoner - Explicitly enabled hurtbox after death")
	
	# Keep collision with environment active
	set_collision_layer_value(3, true)  # Layer 3 is typically for enemy collision
	set_collision_mask_value(1, true)   # Layer 1 is typically for environment
	
	# Emit signal and notify PowerupManager
	emit_signal("enemy_defeated")
	PowerupManager.on_enemy_killed()
	
	# Start fade out and return to pool
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 2.0)
	await tween.finished
	
	# Return to pool after fade out
	print("[Enemy] Returning to pool")
	queue_free()  # This will trigger the object pool to handle the return
	
	await get_tree().create_timer(0.1).timeout
	_debug_print_hurtbox_state("After Death Handler")

func take_damage(amount: float, knockback_force: float = 200.0) -> void:
	if current_behavior == "dead":
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
	velocity.x = -direction * knockback_force
	velocity.y = -knockback_force * 0.5
	
	# Enter hurt state
	change_behavior("hurt")
	behavior_timer = 0.0
	
	# Brief invulnerability
	invulnerable = true
	invulnerability_timer = INVULNERABILITY_DURATION
	
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
			change_behavior("run")
		"summon":
			_complete_summon()
			is_summoning = false
			sprite.play("walk")
			change_behavior("run", true)

func _on_bird_returned(bird: Node) -> void:
	print("[Summoner] Bird returned")
	if bird in active_birds:
		active_birds.erase(bird)
		
	# If all birds have returned, reset cooldown
	if active_birds.is_empty():
		print("[Summoner] All birds returned, resetting cooldown")
		can_summon = true
		if summon_timer:
			summon_timer.stop()  # Stop current cooldown timer
		# Start return cooldown to prevent immediate re-summon
		can_summon = false
		return_cooldown_timer = stats["return_cooldown"] if "return_cooldown" in stats else 3.0

func change_behavior(new_behavior: String, force: bool = false) -> void:
	# Don't change behavior if we're in the middle of summoning, unless forced
	if current_behavior == "summon" and not force:
		return
	
	current_behavior = new_behavior
	
	# Handle animation changes based on new behavior
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
			if not is_summoning:  # Don't interrupt summon animation
				sprite.play("walk")

func apply_gravity(delta: float) -> void:
	# Apply normal gravity from BaseEnemy
	super.apply_gravity(delta)
