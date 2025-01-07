extends State

var is_double_jumping := false
var double_jump_animation_finished := false
var is_transitioning := false
var wall_transition_timer := 0.0
const WALL_TRANSITION_DELAY := 0.15
const MIN_WALL_CONTACT_TIME := 0.05

var wall_contact_timer := 0.0
var last_wall_normal := Vector2.ZERO

func enter():
	
	wall_transition_timer = WALL_TRANSITION_DELAY
	wall_contact_timer = 0.0
	last_wall_normal = Vector2.ZERO
	
	# Only play fall animation if we're not already playing double_jump or jump_to_fall
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
	elif current_anim != "fall":
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
	
	# Check for fall attack input first (before any animation checks)
	if Input.is_action_pressed("down") and Input.is_action_just_pressed("jump"):
		if not get_parent().get_node("FallAttack").is_on_cooldown():
			
			# Force immediate transition to fall attack
			is_double_jumping = false
			is_transitioning = false
			double_jump_animation_finished = true
			animation_player.stop()  # Stop any current animation
			state_machine.transition_to("FallAttack")
			return
		else:
			return  # Added return to prevent the code below from executing
	
	# Handle jump during fall (if we have coyote time or can double jump)
	if Input.is_action_just_pressed("jump"):
		
		if player.has_coyote_time() and not player.has_double_jumped:
			player.start_jump()
			state_machine.transition_to("Jump")
			return
		elif player.can_double_jump and not player.has_double_jumped:
			player.has_double_jumped = true
			is_double_jumping = true
			var boost_multiplier = 1.1
			if player.velocity.y > 400:
				player.velocity.y = -player.double_jump_velocity * boost_multiplier
			else:
				player.velocity.y = -player.double_jump_velocity
			animation_player.play("double_jump")
			return
	
	# Apply gravity with increased falling speed, except during double jump
	if is_double_jumping:
		# Use normal gravity during double jump
		player.velocity.y += player.gravity * delta
	else:
		# Use increased gravity for normal falling
		player.velocity.y += player.gravity * delta * player.fall_gravity_multiplier
	
	# Get input for horizontal movement
	var input_dir = Input.get_axis("left", "right")
	
	# Handle horizontal movement
	if input_dir != 0:
		player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed, player.acceleration * delta)
		player.sprite.flip_h = input_dir < 0
	else:
		player.apply_friction(delta)
	
	# Apply maximum fall speed
	if player.velocity.y > player.max_fall_speed:
		player.velocity.y = player.max_fall_speed
	
	player.move_and_slide()
	
	# Check for ledge grab first
	var ledge_state = get_parent().get_node("LedgeGrab")
	if ledge_state and ledge_state.can_ledge_grab():
		state_machine.transition_to("LedgeGrab")
		return
	
	# Then check for wall slide
	if player.is_on_wall():
		state_machine.transition_to("WallSlide")
		return
	
	# Finally check for landing
	if player.is_on_floor():
		state_machine.transition_to("Idle")
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
			if player.is_on_floor():
				state_machine.transition_to("Idle")

func exit():
	
	is_double_jumping = false
	double_jump_animation_finished = false
	is_transitioning = false
	wall_contact_timer = 0.0
	last_wall_normal = Vector2.ZERO
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
