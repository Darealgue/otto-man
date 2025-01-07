extends State

const COMBO_WINDOW_FRAMES = 20
const MAX_COMBO_COUNT = 3
const ATTACK_SPEED_MULTIPLIER = 0.5  # 50% movement speed during attacks
const MOMENTUM_PRESERVATION = 0.8     # Preserve 80% of previous momentum
const ANIMATION_SPEED = 1.25         # 25% faster animations

var combo_count := 0
var combo_window := 0
var current_attack := ""
var hitbox_enabled := false
var next_combo_ready := false  # Track if we've queued up the next combo
var input_locked := false      # Prevent multiple inputs during the same attack
var initial_velocity := Vector2.ZERO  # Store initial velocity for momentum preservation

func enter():
	hitbox_enabled = false
	next_combo_ready = false
	input_locked = false
	
	# Store initial velocity for momentum preservation
	initial_velocity = player.velocity
	
	# Get attack name based on combo count
	current_attack = "light_attack" + str(combo_count + 1)
	
	# Connect animation finished signal
	if not animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	
	# Stop any current animation and play the new one with increased speed
	animation_player.stop()
	animation_player.play(current_attack)
	animation_player.speed_scale = ANIMATION_SPEED  # Speed up the animation
	
	# Set up hitbox for current attack
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.enable_combo(current_attack, combo_count + 1)
		_update_hitbox_position(hitbox)

func exit():
	# Disconnect animation finished signal
	if animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_player_animation_finished)
	
	current_attack = ""
	input_locked = false
	
	# Reset animation speed
	animation_player.speed_scale = 1.0
	
	# Disable hitbox
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox and hitbox is PlayerHitbox:
		hitbox.disable()
		hitbox.disable_combo()
		hitbox_enabled = false
	
	# If we haven't queued up the next combo and we're transitioning to a different state,
	# reset the combo count
	if not next_combo_ready:
		combo_count = 0
		# Play idle animation when exiting without next combo
		animation_player.play("idle")

func update(delta: float):
	# Skip all processing if game is paused
	if get_tree().paused:
		return
		
	# Handle movement during attack
	_handle_movement(delta)
	
	# Handle attack cancels
	if _check_cancel_conditions():
		return
	
	# Check for next attack input at any time during the animation
	if Input.is_action_just_pressed("attack") and not input_locked and combo_count < MAX_COMBO_COUNT - 1:
		next_combo_ready = true
		input_locked = true  # Lock input until next attack
	
	# Enable/disable hitbox based on animation frames
	var current_frame = animation_player.current_animation_position * animation_player.current_animation_length
	var hitbox = player.get_node_or_null("Hitbox")
	
	if hitbox and hitbox is PlayerHitbox:
		# Enable hitbox during the middle frames of the animation
		var anim_length = animation_player.current_animation_length
		var start_frame = anim_length * 0.1  # Enable at 10% of animation
		var end_frame = anim_length * 0.7    # Disable at 70% of animation
		
		if current_frame >= start_frame and current_frame <= end_frame:
			if not hitbox_enabled:
				hitbox.enable()
				hitbox_enabled = true
				_update_hitbox_position(hitbox)
		else:
			if hitbox_enabled:
				hitbox.disable()
				hitbox_enabled = false

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
		
		# Update hitbox position when changing direction
		var hitbox = player.get_node_or_null("Hitbox")
		if hitbox and hitbox is PlayerHitbox:
			_update_hitbox_position(hitbox)
	
	# Apply movement
	player.move_and_slide()

func _check_cancel_conditions() -> bool:
	# Skip cancel checks if game is paused
	if get_tree().paused:
		return false
		
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
	
	# Preserve some momentum when canceling
	initial_velocity = player.velocity
	
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
		if next_combo_ready and combo_count < MAX_COMBO_COUNT - 1:
			# Increment combo count before starting next attack
			combo_count += 1
			var next_combo = combo_count  # Store the next combo count
			next_combo_ready = false
			# Clean up current state
			exit()
			# Reset combo count to what it should be
			combo_count = next_combo
			# Start new attack
			enter()
		else:
			# No next attack queued, return to idle
			combo_count = 0
			next_combo_ready = false
			state_machine.transition_to("Idle") 
