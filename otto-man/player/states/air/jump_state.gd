extends State

var is_double_jumping := false
var wall_jump_grace_timer := 0.0
const WALL_JUMP_GRACE_PERIOD := 0.2
const WALL_JUMP_HORIZONTAL_DECAY := 0.95  # How much horizontal velocity is maintained each frame
var wall_jump_sprite_direction := false  # Store initial wall jump direction

func enter():
	print("Entering Jump State")
	
	# Connect animation signals
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)
	
	# Check if we're coming from a wall jump
	if player.is_wall_jumping:
		wall_jump_grace_timer = WALL_JUMP_GRACE_PERIOD
		animation_player.play("wall_jump")
		# Store and set initial wall jump direction
		wall_jump_sprite_direction = player.wall_jump_direction < 0
		player.sprite.flip_h = wall_jump_sprite_direction
		# Enable double jump immediately after wall jump
		player.enable_double_jump()
	else:
		# Normal jump
		player.start_jump()
		player.enable_double_jump()
		animation_player.play("jump_upwards")

func physics_update(delta: float):
	# Update wall jump grace timer
	if wall_jump_grace_timer > 0:
		wall_jump_grace_timer -= delta
	
	# Apply horizontal movement
	var input_dir = Input.get_axis("left", "right")
	if player.is_wall_jumping:
		# During wall jump, blend between wall jump velocity and player input
		if input_dir != 0:
			# Allow some control during wall jump
			player.velocity.x = lerp(player.velocity.x, input_dir * player.speed, 0.1)
			# Only update sprite direction after wall jump animation finishes
			if not animation_player.current_animation == "wall_jump":
				player.sprite.flip_h = input_dir < 0
		else:
			# Maintain wall jump trajectory with decay
			player.velocity.x *= WALL_JUMP_HORIZONTAL_DECAY
			# Keep initial wall jump direction during animation
			player.sprite.flip_h = wall_jump_sprite_direction
	else:
		# Normal movement
		if input_dir != 0:
			player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed, player.acceleration * delta)
			player.sprite.flip_h = input_dir < 0
		else:
			player.apply_friction(delta)
	
	# Apply gravity with reduced effect during wall jump
	if player.is_wall_jumping:
		player.velocity.y += player.gravity * 0.7 * delta  # Reduced gravity during wall jump
		if player.velocity.y > 0:  # If we start falling after wall jump
			player.is_wall_jumping = false
			animation_player.play("jump_to_fall")
	else:
		player.velocity.y += player.gravity * player.current_gravity_multiplier * delta
	
	# Handle double jump
	if Input.is_action_just_pressed("jump") and player.can_double_jump and not player.has_double_jumped:
		is_double_jumping = true
		player.has_double_jumped = true
		player.start_double_jump()
		animation_player.play("double_jump")
	
	player.move_and_slide()
	
	# Check if we should transition to fall state
	if player.velocity.y > 0 and not is_double_jumping:
		if not animation_player.current_animation == "jump_to_fall" and not animation_player.current_animation == "fall":
			animation_player.play("jump_to_fall")
		state_machine.transition_to("Fall")
	elif player.is_on_floor():
		state_machine.transition_to("Idle")
	# Only allow wall slide after grace period and if not wall jumping
	elif player.is_on_wall_slide() and wall_jump_grace_timer <= 0 and not player.is_wall_jumping and not is_double_jumping:
		state_machine.transition_to("WallSlide")

func _on_animation_finished(anim_name: String):
	match anim_name:
		"wall_jump":
			if player.velocity.y > 0:
				animation_player.play("jump_to_fall")
			else:
				animation_player.play("jump_upwards")
		"double_jump":
			is_double_jumping = false
		"jump_to_fall":
			animation_player.play("fall")

func exit():
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
