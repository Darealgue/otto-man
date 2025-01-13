extends BaseEnemy
class_name SummonerEnemy

# Constants for behavior
const MIN_DISTANCE_FROM_PLAYER = 300.0
const MAX_SUMMON_COUNT = 2  # Maximum birds active at once
const SUMMON_COOLDOWN = 5.0  # Cooldown between summons
const RETURN_COOLDOWN = 3.0  # Cooldown after birds return before allowing new summons
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
		summon_timer.wait_time = SUMMON_COOLDOWN
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
	super._physics_process(delta)  # This will handle gravity and movement
	
	# Handle cooldown timer
	if not can_summon:
		return_cooldown_timer -= delta
		if return_cooldown_timer <= 0:
			can_summon = true
			return_cooldown_timer = 0.0

func _handle_child_behavior(delta: float) -> void:
	match current_behavior:
		"idle":
			_handle_idle()
		"run":
			_handle_run(delta)
		"summon":
			_handle_summon(delta)  # Pass delta to handle timeout
		# Remove custom hurt and dead handling - let base class handle these
			
	if not can_summon:
		return_cooldown_timer -= delta
		if return_cooldown_timer <= 0:
			can_summon = true
			return_cooldown_timer = 0.0
	
	# Apply gravity from base enemy class
	super.apply_gravity(delta)

func _handle_idle() -> void:
	# Only reset horizontal velocity, keep vertical for gravity
	velocity.x = 0
	
	# Clear target and ensure idle animation plays
	if target:
		target = null
		sprite.play("idle")  # Force idle animation when losing target
		
	# Check for new target
	var potential_target = get_nearest_player()
	if potential_target and is_instance_valid(potential_target):
		var distance_to_target = global_position.distance_to(potential_target.global_position)
		if distance_to_target <= stats.detection_range:
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
	if distance_to_target > stats.detection_range:
		print("[Summoner] Target out of detection range: ", distance_to_target)
		change_behavior("idle")
		return
		
	# Run away from player
	var direction = global_position.direction_to(target.global_position)
	var desired_velocity = -direction * stats.movement_speed
	
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
	if can_summon and not is_summoning and active_birds.size() < MAX_SUMMON_COUNT:
		print("[Summoner] Attempting to summon. Can summon: ", can_summon, ", Active birds: ", active_birds.size())
		change_behavior("summon")

func _handle_summon(delta: float) -> void:
	if not is_summoning:
		change_behavior("run")
		return
	
	# Stop all movement while summoning
	velocity = Vector2.ZERO
	
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
	var birds_to_summon = MAX_SUMMON_COUNT - active_birds.size()
	
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

func handle_death() -> void:
	_debug_print_hurtbox_state("Before Death Handler")
	
	# Reset summoning state
	is_summoning = false
	can_summon = false
	
	# Make all birds neutral when summoner dies, but keep their hurtboxes active
	for bird in active_birds:
		if is_instance_valid(bird):
			bird.set_neutral_state()
	
	super.handle_death()
	
	# Keep our own hurtbox active for bouncing
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
		print("[DEBUG] Summoner - Explicitly enabled hurtbox after death")
	
	await get_tree().create_timer(0.1).timeout
	_debug_print_hurtbox_state("After Death Handler")

func take_damage(amount: float, knockback_force: float = 200.0) -> void:
	_debug_print_hurtbox_state("Before Taking Damage")
	
	# Reset summoning state if interrupted by damage
	if is_summoning:
		is_summoning = false
		can_summon = false
		return_cooldown_timer = RETURN_COOLDOWN
	
	# Call parent's take_damage
	super.take_damage(amount, knockback_force)
	
	# Play hurt animation and change state
	if sprite and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		change_behavior("hurt")
	
	await get_tree().create_timer(0.1).timeout
	_debug_print_hurtbox_state("After Taking Damage")

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
		return_cooldown_timer = RETURN_COOLDOWN

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
