extends "../state.gd"

func enter():
	animation_player.play("run")

func physics_update(delta: float):
	if !player:
		return
		
	# Check for attack input first
	if Input.is_action_just_pressed("attack") and player.attack_cooldown_timer <= 0:
		state_machine.transition_to("Attack")
		return
	# Heavy attack input while running
	if Input.is_action_just_pressed("attack_heavy") and player.attack_cooldown_timer <= 0:
		state_machine.transition_to("HeavyAttack")
		return
		
	# Check for block input
	if Input.is_action_pressed("block"):
		var block_state = state_machine.get_node("Block")
		if block_state.current_stamina > 0:  # Only try to block if we have stamina
			state_machine.transition_to("Block")
		return
		
	# Check for dodge input (only dodge available, dash locked until powerup)
	if Input.is_action_just_pressed("dash"):
		var dodge_state = state_machine.get_node("Dodge")
		if dodge_state and dodge_state.can_start_dodge():
			state_machine.transition_to("Dodge")
			return
		
	# Check for crouch input
	if Input.is_action_pressed("crouch"):
		state_machine.transition_to("Crouch")
		return
		
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump") and not player.jump_input_blocked and player.jump_block_timer <= 0:
		print("[RunState] Jump input processed - transitioning to Jump")
		state_machine.transition_to("Jump")
		return
	elif Input.is_action_just_pressed("jump") and (player.jump_input_blocked or player.jump_block_timer > 0):
		print("[RunState] Jump input BLOCKED by dodge state (blocked:", player.jump_input_blocked, "timer:", player.jump_block_timer, ")")
		
	var input_dir = Input.get_axis("left", "right")
	if input_dir == 0:
		state_machine.transition_to("Idle")
		return
		
	# Check if we're running into a wall
	var was_on_wall = player.is_on_wall()
	player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed, player.acceleration * delta)
	player.move_and_slide()
	
	# If we hit a wall, stop the run animation and play idle
	if not was_on_wall and player.is_on_wall():
		animation_player.play("idle")
	elif not player.is_on_wall() and animation_player.current_animation == "idle":
		animation_player.play("run")

func exit():
	# Stop any current animation when exiting the run state
	if animation_player and animation_player.is_playing():
		animation_player.stop() 
