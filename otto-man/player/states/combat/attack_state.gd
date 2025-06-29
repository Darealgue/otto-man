extends State

const ATTACK_SPEED_MULTIPLIER = 0.5  # 50% movement speed during attacks
const MOMENTUM_PRESERVATION = 0.8     # Preserve 80% of previous momentum
const ANIMATION_SPEED = 1.25         # 25% faster animations
const GROUND_ATTACK_ANIMATIONS = ["attack_1.1"]  # Attacks only available on ground
const AIR_ATTACK_ANIMATIONS = ["air_attack1", "air_attack2", "air_attack3"]  # Attacks only available in air
const DAMAGE_MULTIPLIER = 1  # Fixed damage multiplier for all attacks

var current_attack := ""
var hitbox_enabled := false
var initial_velocity := Vector2.ZERO
var has_activated_hitbox := false  # Track if we've already activated the hitbox in this attack
var can_use_attack_1_2 := false    # Track if attack_1.2 can be used (only after attack_1.1)
var next_attack_queued := ""       # For storing the next attack in the sequence
var hitbox_start_time := 0.0      # Track when the hitbox was enabled
var hitbox_end_time := 0.0        # Track when the hitbox was disabled

func enter():
	hitbox_start_time = 0.0
	hitbox_end_time = 0.0
	
	# Store initial velocity for momentum preservation
	initial_velocity = player.velocity
	
	# Disconnect previous animation signal if connected
	if animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
	
	# Connect animation finished signal
	animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	
	
	# Use queued attack if available, otherwise choose randomly
	if next_attack_queued == "attack_1.2" and can_use_attack_1_2:
		current_attack = "attack_1.2"
		next_attack_queued = ""
		can_use_attack_1_2 = false
	else:
		# Choose a random attack animation based on whether the player is in the air or on ground
		if player.is_on_floor():
			if GROUND_ATTACK_ANIMATIONS.size() > 0:
				current_attack = GROUND_ATTACK_ANIMATIONS[randi() % GROUND_ATTACK_ANIMATIONS.size()]
			else:
				state_machine.transition_to("Idle")
				return
		else:
			if AIR_ATTACK_ANIMATIONS.size() > 0:
				current_attack = AIR_ATTACK_ANIMATIONS[randi() % AIR_ATTACK_ANIMATIONS.size()]
			else:
				state_machine.transition_to("Fall")
				return
		
		# Reset attack_1.2 availability unless we're doing attack_1.1
		if current_attack == "attack_1.1":
			can_use_attack_1_2 = true
		else:
			can_use_attack_1_2 = false
	
	# Ensure animation player is reset before playing new animation
	animation_player.stop()
	animation_player.speed_scale = ANIMATION_SPEED
	
	# Check if animation exists before playing
	if animation_player.has_animation(current_attack):
		animation_player.play(current_attack)
	else:
		# Fall back to a default animation or return to previous state
		if player.is_on_floor():
			state_machine.transition_to("Idle")
		else:
			state_machine.transition_to("Fall")
		return
	
	# Reset hitbox state
	hitbox_enabled = false
	has_activated_hitbox = false
	
	# Set up hitbox for current attack and make sure it's disabled at start
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()  # Always start with hitbox disabled
		
		# Prepare the attack type based on whether it's an air attack or ground attack
		var attack_type = "light"
		hitbox.enable_combo(current_attack, DAMAGE_MULTIPLIER) 
		_update_hitbox_position(hitbox)

func exit():
	
	# Disconnect animation finished signal
	if animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
	
	# Disable hitbox
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
	
	# Reset animation speed
	animation_player.speed_scale = 1.0

func update(delta: float):
	# Skip all processing if game is paused
	if get_tree().paused:
		return
		
	# Handle movement during attack
	_handle_movement(delta)
	
	# Check for attack_1.2 input if we just performed attack_1.1 and still on ground
	if can_use_attack_1_2 and Input.is_action_just_pressed("attack") and player.is_on_floor():
		next_attack_queued = "attack_1.2"
	
	# Check for air attack input
	if Input.is_action_just_pressed("attack") and not player.is_on_floor() and not _is_air_attack(current_attack):
		# If player is in air and not already performing an air attack, transition to a new attack state
		state_machine.transition_to("Attack")
		return
	
	# Handle attack cancels
	if _check_cancel_conditions():
		return
	
	# Handle hitbox based on animation progress
	_update_hitbox()
	
	# Check if we need to transition to fall state if player is no longer on floor
	if not player.is_on_floor() and _is_ground_attack(current_attack) and animation_player.current_animation_position > 0.6:
		state_machine.transition_to("Fall")
		return

# Helper function to check if the current attack is an air attack
func _is_air_attack(attack_name: String) -> bool:
	var is_air = AIR_ATTACK_ANIMATIONS.has(attack_name)
	return is_air

# Helper function to check if the current attack is a ground attack
func _is_ground_attack(attack_name: String) -> bool:
	var is_ground = GROUND_ATTACK_ANIMATIONS.has(attack_name) or attack_name == "attack_1.2"
	return is_ground

func _update_hitbox():
	# If we've already activated the hitbox in this attack, don't activate it again
	if has_activated_hitbox:
		return
		
	# Get current animation progress as a percentage (0.0 to 1.0)
	var anim_progress = animation_player.current_animation_position / animation_player.current_animation_length
	
	var hitbox = player.get_node_or_null("Hitbox")
	if not hitbox or not hitbox is PlayerHitbox:
		return
	
	# Enable hitbox during a very specific part of the animation (30% to 40%)
	if anim_progress >= 0.3 and anim_progress <= 0.4 and not hitbox_enabled:
		hitbox.disable()  # Ensure it's disabled first
		
		# Update the hitbox with the current attack type
		hitbox.enable_combo(current_attack, DAMAGE_MULTIPLIER)
		
		hitbox.enable()
		hitbox_enabled = true
		hitbox_start_time = Time.get_ticks_msec() / 1000.0
		
		# Set a timer to disable the hitbox after a short duration (Increased by 50%)
		await get_tree().create_timer(0.15).timeout
		if hitbox and is_instance_valid(hitbox) and hitbox_enabled:
			hitbox.disable()
			hitbox_enabled = false
			hitbox_end_time = Time.get_ticks_msec() / 1000.0
			var duration = hitbox_end_time - hitbox_start_time
	
	# Update hitbox position
	_update_hitbox_position(hitbox)

func _handle_movement(delta: float) -> void:
	# Get horizontal movement only
	var input_dir_x = Input.get_axis("ui_left", "ui_right")
	
	# Calculate velocity with attack speed multiplier
	var target_velocity = Vector2(
		input_dir_x * player.speed * ATTACK_SPEED_MULTIPLIER,
		player.velocity.y  # Keep vertical velocity unchanged
	)
	
	# Apply momentum preservation
	player.velocity.x = lerp(player.velocity.x, target_velocity.x, 1.0 - MOMENTUM_PRESERVATION)
	
	# Update player facing direction if moving
	if input_dir_x != 0:
		player.sprite.flip_h = input_dir_x < 0
	
	# Apply movement
	player.move_and_slide()

func _check_cancel_conditions() -> bool:
	# Cancel into dash
	if Input.is_action_just_pressed("dash") and state_machine.has_node("Dash"):
		_cancel_into_state("Dash")
		return true
	
	# Cancel into jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and state_machine.has_node("Jump"):
		_cancel_into_state("Jump")
		return true
	
	# Cancel into block
	if Input.is_action_just_pressed("block") and state_machine.has_node("Block"):
		_cancel_into_state("Block")
		return true
	
	return false

func _cancel_into_state(state_name: String) -> void:
	# Clean up current attack state
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
	
	# Transition to new state
	state_machine.transition_to(state_name)

func _update_hitbox_position(hitbox: Node2D) -> void:
	var collision_shape = hitbox.get_node("CollisionShape2D")
	if collision_shape:
		var position = collision_shape.position
		position.x = abs(position.x) * (-1 if player.sprite.flip_h else 1)
		collision_shape.position = position

func _on_animation_player_animation_finished(anim_name: String):

	if anim_name == current_attack:
		
		# Disable hitbox if still active
		if hitbox_enabled:
			var hitbox = player.get_node_or_null("Hitbox")
			if hitbox and hitbox is PlayerHitbox:
				hitbox.disable()
				hitbox_enabled = false
		
		# If we have a queued attack_1.2 after attack_1.1 and still on ground, transition to it
		if next_attack_queued == "attack_1.2" and can_use_attack_1_2 and player.is_on_floor():
			# Avoid transitioning through the state machine to prevent animation glitches
			# Just play the new animation directly
			current_attack = "attack_1.2"
			next_attack_queued = ""
			can_use_attack_1_2 = false
			
			# Reset hitbox state for new attack
			hitbox_enabled = false
			has_activated_hitbox = false
			
			# Play the new animation
			animation_player.stop()
			animation_player.play(current_attack)

			return
		
		# Return to appropriate state based on whether player is on ground
		if player.is_on_floor():
			state_machine.transition_to("Idle")
		else:
			player.attack_cooldown_timer = 0.1 # <<< YENİ SATIR (0.1 saniye cooldown) >>>
			state_machine.transition_to("Fall")

func _on_enemy_hit(enemy: Node):
	if not has_activated_hitbox:
		has_activated_hitbox = true
