extends State

var is_double_jumping := false
var wall_jump_grace_timer := 0.0
const WALL_JUMP_GRACE_PERIOD := 0.4  # Increased grace period for better control
const WALL_JUMP_HORIZONTAL_DECAY := 0.95  # How much horizontal velocity is maintained each frame
var wall_jump_sprite_direction := false  # Store initial wall jump direction

func enter():
	# Connect animation signals
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)
	
	# If wall jumping, face away from the wall
	if player.is_wall_jumping:
		wall_jump_grace_timer = WALL_JUMP_GRACE_PERIOD
		animation_player.play("wall_jump")
		# Face away from the wall we jumped from and store the direction
		wall_jump_sprite_direction = player.wall_jump_direction < 0
		player.sprite.flip_h = wall_jump_sprite_direction
		# Enable double jump immediately after wall jump
		player.enable_double_jump()
	else:
		# For normal jumps, set sprite direction based on movement
		var input_dir = Input.get_axis("left", "right")
		if input_dir != 0:
			player.sprite.flip_h = input_dir < 0
		# Only start jump if not pressing down
		if not Input.is_action_pressed("down"):
			# Play jump prepare animation first
			animation_player.play("jump_prepare")
			player.enable_double_jump()
		else:
			# If pressing down, transition to fall state
			state_machine.transition_to("Fall")

func physics_update(delta: float):
	# Update wall jump grace timer
	if wall_jump_grace_timer > 0:
		wall_jump_grace_timer -= delta
	
	# Get input state
	var input_dir = Input.get_axis("left", "right")
	var down_pressed = Input.is_action_pressed("down")
	var jump_pressed = Input.is_action_just_pressed("jump")
	
	# Check for attack input first - highest priority for responsive controls
	if Input.is_action_just_pressed("attack"):
		print("[Jump State] Attack button pressed, transitioning to Attack state for air attack")
		state_machine.transition_to("Attack")
		return
	
	# Check for fall attack first - highest priority
	if down_pressed and jump_pressed:
		var fall_attack_state = get_parent().get_node("FallAttack")
		if fall_attack_state:
			if not fall_attack_state.is_on_cooldown():
				fall_attack_state.reset_cooldown()  # Reset cooldown before transition
				state_machine.transition_to("FallAttack")
				return
	# Only check for double jump if not trying to fall attack
	elif jump_pressed and not player.has_double_jumped and not down_pressed:
		is_double_jumping = true
		player.has_double_jumped = true
		player.start_double_jump()
		animation_player.play("double_jump")
		return
	
	# Check for wall slide
	if player.is_on_wall():
		var wall_slide_state = get_parent().get_node("WallSlide")
		if wall_slide_state and wall_slide_state.can_enter():
			state_machine.transition_to("WallSlide")
			return
	
	# Handle horizontal movement
	if player.is_wall_jumping:
		# During wall jump grace period, maintain momentum and ignore input direction
		if wall_jump_grace_timer > 0:
			player.velocity.x *= WALL_JUMP_HORIZONTAL_DECAY
			player.sprite.flip_h = wall_jump_sprite_direction
		else:
			player.is_wall_jumping = false
			if input_dir != 0:
				var target_velocity = input_dir * player.speed
				player.velocity.x = lerp(player.velocity.x, target_velocity, 0.15)
				player.sprite.flip_h = input_dir < 0
			else:
				player.velocity.x *= WALL_JUMP_HORIZONTAL_DECAY
	else:
		# Normal air movement
		player.apply_movement(delta, input_dir)
		if input_dir != 0:
			player.sprite.flip_h = input_dir < 0
	
	# Apply gravity
	if player.is_wall_jumping:
		player.velocity.y += player.gravity * 0.7 * delta
		if player.velocity.y > 0:
			player.is_wall_jumping = false
			animation_player.play("jump_to_fall")
	else:
		player.velocity.y += player.gravity * delta
	
	# Move the player
	player.move_and_slide()
	
	# Check for landing
	if player.is_on_floor():
		state_machine.transition_to("Idle")
		return
	
	# Check for falling
	if player.velocity.y > 0 and not is_double_jumping and not player.is_wall_jumping:
		var current_anim = animation_player.current_animation
		if current_anim != "jump_to_fall" and current_anim != "fall" and current_anim != "double_jump" and current_anim != "wall_jump":
			animation_player.play("jump_to_fall")

func _on_animation_finished(anim_name: String):
	match anim_name:
		"wall_jump":
			if player.velocity.y > 0:
				animation_player.play("fall")
				state_machine.transition_to("Fall")
			else:
				animation_player.play("jump_upwards")
		"double_jump":
			is_double_jumping = false
			if player.velocity.y > 0:
				animation_player.play("fall")
				state_machine.transition_to("Fall")
		"jump_to_fall":
			animation_player.play("fall")
			state_machine.transition_to("Fall")
		"jump_upwards":
			if player.velocity.y > 0:
				animation_player.play("jump_to_fall")
			elif player.is_on_floor():
				state_machine.transition_to("Idle")
		"jump_prepare":
			# After jump prepare animation, start the actual jump
			animation_player.play("jump_upwards")

func exit():
	is_double_jumping = false
	wall_jump_grace_timer = 0.0
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
