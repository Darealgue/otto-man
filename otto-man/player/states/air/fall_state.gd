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
	print("Entering Fall State")
	wall_transition_timer = WALL_TRANSITION_DELAY
	wall_contact_timer = 0.0
	last_wall_normal = Vector2.ZERO
	# Only play fall animation if we're not already playing double_jump or jump_to_fall
	var current_anim = animation_player.current_animation
	if current_anim != "double_jump" and current_anim != "jump_to_fall":
		animation_player.play("fall")
	print("Playing animation:", animation_player.current_animation)
	
	# Enable double jump if we walked off a platform
	if not player.is_jumping and not player.has_double_jumped:
		player.enable_double_jump()
	
	# Connect to animation finished signal
	if not animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.connect("animation_finished", _on_animation_finished)

func physics_update(delta: float):
	# Apply gravity
	player.velocity.y += player.gravity * delta * player.current_gravity_multiplier
	
	# Get input for horizontal movement
	var input_dir = Input.get_axis("left", "right")
	
	# Handle horizontal movement
	if input_dir != 0:
		player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed, player.acceleration * delta)
	else:
		player.apply_friction(delta)
	
	player.move_and_slide()
	
	# Check for ledge grab first
	var ledge_state = get_parent().get_node("LedgeGrab")
	if ledge_state and ledge_state.can_ledge_grab():
		print("DEBUG: Transitioning to ledge grab")
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
	
	# Handle jump during fall (if we walked off a platform)
	if Input.is_action_just_pressed("jump"):
		if not player.is_jumping and not player.has_double_jumped:
			print("Jump triggered during fall!")
			player.has_double_jumped = true  # Consume the double jump
			player.velocity.y = -player.double_jump_velocity
			animation_player.play("double_jump")
			return
		elif player.can_double_jump and not player.has_double_jumped:
			print("Double jump triggered during fall!")
			player.has_double_jumped = true
			player.velocity.y = -player.double_jump_velocity
			animation_player.play("double_jump")
			return

func _on_animation_finished(anim_name: String):
	match anim_name:
		"double_jump":
			print("Double jump animation finished")
			double_jump_animation_finished = true
			is_double_jumping = false
			if not is_transitioning:
				animation_player.play("fall")
		"jump_to_fall":
			print("Transition animation finished, playing fall")
			if not is_transitioning:
				animation_player.play("fall")
		"landing":
			print("Landing animation finished")
			if player.is_on_floor():
				state_machine.transition_to("Idle")

func exit():
	print("Exiting Fall State")
	is_double_jumping = false
	double_jump_animation_finished = false
	is_transitioning = false
	wall_contact_timer = 0.0
	last_wall_normal = Vector2.ZERO
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
