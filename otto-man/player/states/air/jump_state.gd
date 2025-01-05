extends State

var is_double_jumping := false
var wall_jump_grace_timer := 0.0
const WALL_JUMP_GRACE_PERIOD := 0.2
const WALL_JUMP_HORIZONTAL_DECAY := 0.95  # How much horizontal velocity is maintained each frame
var wall_jump_sprite_direction := false  # Store initial wall jump direction

func enter():
	
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
		# Normal jump or coyote time jump
		player.start_jump()
		player.enable_double_jump()
		animation_player.play("jump_upwards")

func physics_update(delta: float):
	# Update fall attack cooldown
	get_parent().get_node("FallAttack").update_cooldown(delta)
	
	# Check for fall attack input first
	if Input.is_action_pressed("down") and Input.is_action_just_pressed("jump"):
		if not get_parent().get_node("FallAttack").is_on_cooldown():
			animation_player.stop()  # Stop any current animation
			state_machine.transition_to("FallAttack")
			return
		
	# Update wall jump grace timer
	if wall_jump_grace_timer > 0:
		wall_jump_grace_timer -= delta
	
	# Apply horizontal movement
	var input_dir = Input.get_axis("left", "right")
	if player.is_wall_jumping:
		# During wall jump, blend between wall jump velocity and player input
		if input_dir != 0:
			player.velocity.x = lerp(player.velocity.x, input_dir * player.speed, 0.1)
			if not animation_player.current_animation == "wall_jump":
				player.sprite.flip_h = input_dir < 0
		else:
			player.velocity.x *= WALL_JUMP_HORIZONTAL_DECAY
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
		player.velocity.y += player.gravity * 0.7 * delta
		if player.velocity.y > 0:
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
	
	# Check transitions in order of priority
	if player.is_on_floor():
		state_machine.transition_to("Idle")
	elif player.is_on_wall_slide():
		state_machine.transition_to("WallSlide")
	elif player.velocity.y > 0 and not is_double_jumping:
		var current_anim = animation_player.current_animation
		
		# Only handle fall transition if we're not already transitioning
		if current_anim != "jump_to_fall" and current_anim != "fall" and current_anim != "double_jump":
			
			# Play jump_to_fall transition and then transition to fall state
			animation_player.play("jump_to_fall")

func _on_animation_finished(anim_name: String):
	
	match anim_name:
		"wall_jump":
			if player.velocity.y > 0:
				animation_player.play("jump_to_fall")
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

func exit():
	is_double_jumping = false
	wall_jump_grace_timer = 0.0
	if animation_player.is_connected("animation_finished", _on_animation_finished):
		animation_player.disconnect("animation_finished", _on_animation_finished)
