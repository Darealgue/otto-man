extends "../state.gd"

func enter():
	if !player:
		push_error("Player reference not set in idle state!")
		return
		
	if animation_player:
		animation_player.play("idle")
	
	if player.has_method("reset_jump_state"):
		player.reset_jump_state()
	else:
		push_error("Player is missing reset_jump_state method!")

func physics_update(delta: float):
	if !player:
		return
		
	# Check for attack input first
	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("Attack")
		return
		
	# Check for block input
	if Input.is_action_pressed("block"):
		var block_state = state_machine.get_node("Block")
		if block_state.current_stamina > 0:  # Only try to block if we have stamina
			state_machine.transition_to("Block")
		return
		
	# Check for crouch input
	if Input.is_action_pressed("crouch"):
		state_machine.transition_to("Crouch")
		return
		
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Jump")
		return
		
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		state_machine.transition_to("Run")
		return
		
	player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	player.move_and_slide()
	
	if animation_player.current_animation != "idle":
		animation_player.play("idle")

func exit():
	pass
