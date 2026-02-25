extends State

var is_double_jumping := false
var wall_jump_grace_timer := 0.0
const WALL_JUMP_GRACE_PERIOD := 0.4  # Increased grace period for better control
const WALL_JUMP_HORIZONTAL_DECAY := 0.95  # How much horizontal velocity is maintained each frame
var wall_jump_sprite_direction := false  # Store initial wall jump direction

func enter():
	# print("[WALL_SLIDE_DEBUG] Jump State: ENTERING jump state")
	# Connect animation signals
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)
	
	# Track jump count for triple jump (Kuş Kanadı)
	var can_triple_jump = player.has_meta("kus_kanadi_active")
	var current_jump_count = 0
	if can_triple_jump:
		# Reset jump count if jumping from ground (first jump)
		if player.is_on_floor():
			player.set_meta("kus_kanadi_jump_count", 0)
			current_jump_count = 0
		else:
			current_jump_count = player.get_meta("kus_kanadi_jump_count", 0)
		# Don't increment yet - we need to check the count first for animation selection
	
	# If wall jumping, face away from the wall
	if player.is_wall_jumping:
		wall_jump_grace_timer = WALL_JUMP_GRACE_PERIOD
		animation_player.play("wall_jump")
		# Face away from the wall we jumped from and store the direction
		wall_jump_sprite_direction = player.wall_jump_direction < 0
		player.sprite.flip_h = wall_jump_sprite_direction
		# Enable double jump immediately after wall jump
		player.enable_double_jump()
		# Increment jump count after animation selection (for wall jump, always increment)
		if can_triple_jump:
			player.set_meta("kus_kanadi_jump_count", current_jump_count + 1)
	else:
		# For normal jumps, set sprite direction based on movement
		var input_dir = InputManager.get_flattened_axis(&"left", &"right")
		if input_dir != 0:
			player.sprite.flip_h = input_dir < 0
		# Only start jump if not pressing down
		if not Input.is_action_pressed("down"):
			# Check if this is a double/triple jump (2nd or 3rd jump) - BEFORE incrementing
			if can_triple_jump and current_jump_count > 0:
				# This is 2nd or 3rd jump - play double jump animation immediately
				var double_jump_animations = ["double_jump", "double_jump_alt"]
				var random_animation = double_jump_animations[randi() % double_jump_animations.size()]
				animation_player.play(random_animation)
				is_double_jumping = true
			else:
				# First jump - play jump prepare animation
				animation_player.play("jump_prepare")
			player.enable_double_jump()
			# Increment jump count AFTER animation selection
			if can_triple_jump:
				player.set_meta("kus_kanadi_jump_count", current_jump_count + 1)
		else:
			# If pressing down, transition to fall state
			state_machine.transition_to("Fall")

func physics_update(delta: float):
	# Update wall jump grace timer
	if wall_jump_grace_timer > 0:
		wall_jump_grace_timer -= delta
	
	# PRIORITY 1: Check for wall slide FIRST - highest priority for consistent wall sliding
	if player.is_on_wall():
		# print("[WALL_SLIDE_DEBUG] Jump State: Wall detected, checking wall slide state...")
		var wall_slide_state = get_parent().get_node("WallSlide")
		if wall_slide_state and wall_slide_state.can_enter():
			# print("[WALL_SLIDE_DEBUG] Jump State: Wall slide can enter, transitioning to WallSlide")
			# Force reset any animation cooldowns that might interfere
			wall_slide_state.reset_cooldown()
			state_machine.transition_to("WallSlide")
			return
		else:
			pass
	
	# Get input state
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	var down_pressed = Input.is_action_pressed("down")
	var jump_pressed = Input.is_action_just_pressed("jump")
	
	# PRIORITY 1.5: Check for dodge/dash input (dash if item allows, otherwise air dodge)
	if Input.is_action_just_pressed("dash"):
		# Check if dash item is active (Rüzgar Hançeri)
		var dash_state = get_parent().get_node_or_null("Dash")
		if dash_state and dash_state.has_method("can_start_dash") and dash_state.can_start_dash():
			state_machine.transition_to("Dash")
			return
		
		# Otherwise check for air dodge
		var dodge_state = get_parent().get_node_or_null("Dodge")
		if dodge_state and dodge_state.has_method("can_start_dodge") and dodge_state.can_start_dodge():
			state_machine.transition_to("Dodge")
			return
	
	# PRIORITY 2: Check for attack input - high priority for responsive controls
	if Input.is_action_just_pressed("attack"):
		# Check for up/down input to determine attack type
		var up_strength = Input.get_action_strength("up")
		var down_strength = Input.get_action_strength("down")
		if up_strength > 0.6:
			# Up attack - transition to AirAttackUp state
			state_machine.transition_to("AirAttackUp")
			return
		elif down_strength > 0.6:
			# Down attack - transition to AirAttackDown state
			state_machine.transition_to("AirAttackDown")
			return
		else:
			# Normal air attack
			state_machine.transition_to("Attack")
			return
	
	# PRIORITY 3: Check for fall attack
	if down_pressed and jump_pressed and not player.jump_input_blocked and player.jump_block_timer <= 0:
		var fall_attack_state = get_parent().get_node("FallAttack")
		if fall_attack_state:
			if not fall_attack_state.is_on_cooldown():
				fall_attack_state.reset_cooldown()  # Reset cooldown before transition
				state_machine.transition_to("FallAttack")
				return
	# PRIORITY 4: Only check for double jump if not trying to fall attack
	elif jump_pressed and not down_pressed and not player.jump_input_blocked and player.jump_block_timer <= 0:
		# Check for triple jump item (Kuş Kanadı)
		var can_triple_jump = player.has_meta("kus_kanadi_active")
		var jump_count = player.get_meta("kus_kanadi_jump_count", 0) if can_triple_jump else 0
		
		# Allow jump if: normal double jump OR (triple jump item AND jump count < 2, meaning max 3 jumps: 0, 1, 2)
		if not player.has_double_jumped or (can_triple_jump and jump_count < 2):
			is_double_jumping = true
			if can_triple_jump:
				# Jump count will be incremented in enter() function
				# Don't set has_double_jumped to allow third jump
				pass
			else:
				player.has_double_jumped = true
			player.start_double_jump()
			# Randomly choose between two double jump animations
			var double_jump_animations = ["double_jump", "double_jump_alt"]
			var random_animation = double_jump_animations[randi() % double_jump_animations.size()]
			animation_player.play(random_animation)
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
		# Normal air movement (air control already reduced by item if active)
		player.apply_movement(delta, input_dir)
		if input_dir != 0:
			player.sprite.flip_h = input_dir < 0
	
	# Apply gravity with Hollow Knight style
	if player.is_wall_jumping:
		player.velocity.y += player.gravity * 0.7 * delta
		if player.velocity.y > 0:
			player.is_wall_jumping = false
			animation_player.play("jump_to_fall")
	else:
		# Use Hollow Knight style gravity calculation
		var gravity_multiplier = player.calculate_hollow_knight_gravity()
		player.velocity.y += player.gravity * gravity_multiplier * delta
	
	# Move the player
	player.apply_move_and_slide()
	
	# Check for ledge grab
	var ledge_state = get_parent().get_node("LedgeGrab")
	if ledge_state and ledge_state.can_ledge_grab():
		state_machine.transition_to("LedgeGrab")
		return
	
	# Check for landing
	if player.is_on_floor():
		# Reset triple jump tracking
		if player.has_meta("kus_kanadi_jump_count"):
			player.remove_meta("kus_kanadi_jump_count")
		
		# If we recently did a ledgegrab, transition to crouch to prevent getting stuck
		if player.ledge_grab_cooldown_timer > 0:
			state_machine.transition_to("Crouch")
		else:
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
		"double_jump", "double_jump_alt":
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
	# print("[WALL_SLIDE_DEBUG] Jump State: EXITING jump state")
	is_double_jumping = false
	wall_jump_grace_timer = 0.0
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
