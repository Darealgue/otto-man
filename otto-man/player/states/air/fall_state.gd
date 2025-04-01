extends State

var is_double_jumping := false
var double_jump_animation_finished := false
var is_transitioning := false
var wall_transition_timer := 0.0
const WALL_TRANSITION_DELAY := 0.15
const MIN_WALL_CONTACT_TIME := 0.05
const WALL_DETACH_GRACE := 0.2  # Grace period after detaching from wall

var wall_contact_timer := 0.0
var wall_detach_grace_timer := 0.0
var last_wall_normal := Vector2.ZERO
var wall_slide_state = null  # Store reference to wall slide state

func enter():
	wall_transition_timer = WALL_TRANSITION_DELAY
	wall_contact_timer = 0.0
	
	# If coming from wall slide, start grace period
	if state_machine.previous_state and state_machine.previous_state.name == "WallSlide":
		wall_detach_grace_timer = WALL_DETACH_GRACE
		last_wall_normal = player.wall_normal  # Store the wall normal we detached from
	else:
		wall_detach_grace_timer = 0.0
		last_wall_normal = Vector2.ZERO
	
	# Get reference to wall slide state
	wall_slide_state = get_parent().get_node("WallSlide")
	
	# Only play fall animation if we're not in a special animation
	var current_anim = animation_player.current_animation
	
	# If we're in the middle of a transition animation, let it finish
	if current_anim == "jump_to_fall":
		is_transitioning = true
	elif current_anim == "double_jump":
		is_double_jumping = true
	elif current_anim == "ledge_grab" or current_anim == "ledge_mount":
		# Coming from ledge grab, check if we're on floor
		if player.is_on_floor():
			state_machine.transition_to("Idle")
			return
		else:
			animation_player.play("fall")
	elif current_anim != "fall" and current_anim != "jump_upwards" and current_anim != "double_jump":
		animation_player.play("fall")
	
	# Enable double jump if we walked off a platform and have coyote time
	if not player.is_jumping and not player.has_double_jumped and player.has_coyote_time():
		player.enable_double_jump()
	
	# Connect to animation finished signal
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)

func physics_update(delta: float):
	# Update fall attack cooldown
	get_parent().get_node("FallAttack").update_cooldown(delta)
	
	# Update wall slide cooldown
	if wall_slide_state:
		wall_slide_state.update_cooldown(delta)
	
	# Update grace period timer
	if wall_detach_grace_timer > 0:
		wall_detach_grace_timer -= delta
	
	# Check for normal attack input first, highest priority for responsive controls
	if Input.is_action_just_pressed("attack"):
		print("[Fall State] Attack button pressed, transitioning to Attack state for air attack")
		state_machine.transition_to("Attack")
		return
	
	# Check for fall attack input second (special air attack)
	if Input.is_action_pressed("down"):
		# Make fall attack easier to execute by checking for jump input more frequently
		if Input.is_action_just_pressed("jump"):
			var fall_attack_state = get_parent().get_node("FallAttack")
			if fall_attack_state and not fall_attack_state.is_on_cooldown():
				# Force immediate transition to fall attack
				is_double_jumping = false
				is_transitioning = false
				double_jump_animation_finished = true
				animation_player.stop()  # Stop any current animation
				
				# Almost eliminate horizontal momentum for more vertical fall attack
				player.velocity.x *= 0.1  # Reduced from 0.5 to 0.1
				
				state_machine.transition_to("FallAttack")
				return
	
	# Handle jump during fall (if we have coyote time or can double jump)
	if Input.is_action_just_pressed("jump"):
		if player.has_coyote_time() and not player.has_double_jumped:
			player.start_jump()
			state_machine.transition_to("Jump")
			return
		elif player.can_double_jump and not player.has_double_jumped:
			player.has_double_jumped = true
			is_double_jumping = true
			# Use player's double jump function instead of setting velocity directly
			player.start_double_jump()
			animation_player.play("double_jump")
			return
	
	# Get input for horizontal movement
	var input_dir = Input.get_axis("left", "right")
	
	# Handle horizontal movement using new air movement system
	player.apply_movement(delta, input_dir)
	
	# Only flip sprite if:
	# 1. We're not in wall detach grace period, OR
	# 2. We're pressing in the opposite direction of our last wall
	if input_dir != 0:
		if wall_detach_grace_timer <= 0:
			# Normal sprite control
			player.sprite.flip_h = input_dir < 0
		elif (last_wall_normal.x < 0 and input_dir > 0):
			# Only flip if explicitly moving away from the wall we detached from
			player.sprite.flip_h = false  # Face right when moving right
		elif (last_wall_normal.x > 0 and input_dir < 0):
			# Only flip if explicitly moving away from the wall we detached from
			player.sprite.flip_h = true  # Face left when moving left
	
	# Apply gravity with increased falling speed, except during double jump
	if is_double_jumping:
		# Use normal gravity during double jump
		player.velocity.y += player.gravity * delta
	else:
		# Use increased gravity for normal falling
		player.velocity.y += player.gravity * delta * player.fall_gravity_multiplier
	
	# Apply maximum fall speed
	if player.velocity.y > player.max_fall_speed:
		player.velocity.y = player.max_fall_speed
	
	player.move_and_slide()
	
	# Check for ledge grab first
	var ledge_state = get_parent().get_node("LedgeGrab")
	if ledge_state and ledge_state.can_ledge_grab():
		state_machine.transition_to("LedgeGrab")
		return
	
	# Then check for wall slide with improved logic
	if player.is_on_wall():
		# Track wall contact time
		wall_contact_timer += delta
		
		# Only transition if:
		# 1. We've been in contact with the wall for minimum time
		# 2. The wall slide state is available and can be entered (not on cooldown)
		if wall_contact_timer >= MIN_WALL_CONTACT_TIME and wall_slide_state and wall_slide_state.can_enter():
			wall_slide_state.reset_cooldown()  # Reset cooldown before entering
			state_machine.transition_to("WallSlide")
			return
	else:
		wall_contact_timer = 0.0
	
	# Finally check for landing
	if player.is_on_floor():
		# Only play landing animation if we're not already playing it
		if animation_player.current_animation != "landing":
			animation_player.play("landing")
		return

func _on_animation_finished(anim_name: String):
	match anim_name:
		"double_jump":
			double_jump_animation_finished = true
			is_double_jumping = false
			animation_player.play("fall")
		"jump_to_fall":
			is_transitioning = false
			animation_player.play("fall")
		"landing":
			# Always transition to idle when landing animation finishes
			state_machine.transition_to("Idle")
		"fall":
			# If we're on the floor and fall animation finishes, play landing
			if player.is_on_floor():
				animation_player.play("landing")

func exit():
	is_double_jumping = false
	double_jump_animation_finished = false
	is_transitioning = false
	wall_contact_timer = 0.0
	wall_detach_grace_timer = 0.0
	last_wall_normal = Vector2.ZERO
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
