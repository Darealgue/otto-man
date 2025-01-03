extends State

func enter():
	if !player:
		push_error("Player reference not set in idle state!")
		return
		
	print("Entering Idle State")
	if animation_player:
		animation_player.play("idle")
		print("Playing animation:", animation_player.current_animation)
	
	if player.has_method("reset_jump_state"):
		player.reset_jump_state()
	else:
		push_error("Player is missing reset_jump_state method!")

func physics_update(delta: float):
	if !player:
		return
		
	if not player.is_on_floor() and player.coyote_timer <= 0:
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump") and player.can_jump():
		state_machine.transition_to("Jump")
		return
		
	var input_dir = Input.get_axis("left", "right")
	if input_dir:
		state_machine.transition_to("Run")
		return
		
	player.apply_friction(delta)
	player.move_and_slide()

func exit():
	pass
