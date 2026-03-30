extends "../state.gd"

func enter():
	# Önceki state (air attack vb.) speed_scale bırakmış olabilir; koşu her zaman 1.0
	animation_player.speed_scale = 1.0
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
		
	# Check for block input - sadece charge varsa işle
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_charges():
		if Input.is_action_just_pressed("block") or Input.is_action_pressed("block"):
			state_machine.transition_to("Block")
			return
		
	# Check for dodge/dash input (dash if item allows, otherwise dodge)
	if Input.is_action_just_pressed("dash"):
		# Check if dash item is active (Rüzgar Hançeri)
		var dash_state = state_machine.get_node_or_null("Dash")
		if dash_state and dash_state.has_method("can_start_dash") and dash_state.can_start_dash():
			state_machine.transition_to("Dash")
			return
		
		# Otherwise use dodge
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
		# print("[RunState] Jump input processed - transitioning to Jump")
		state_machine.transition_to("Jump")
		return
	elif Input.is_action_just_pressed("jump") and (player.jump_input_blocked or player.jump_block_timer > 0):
		print("[RunState] Jump input BLOCKED by dodge state (blocked:", player.jump_input_blocked, "timer:", player.jump_block_timer, ")")
		
	var input_dir = InputManager.get_flattened_axis(&"left", &"right")
	if input_dir == 0:
		state_machine.transition_to("Idle")
		return
		
	# Check if we're running into a wall
	var was_on_wall = player.is_on_wall()
	player.velocity.x = move_toward(player.velocity.x, input_dir * player.speed * player.speed_multiplier * player.extra_speed_multiplier, player.acceleration * delta)
	player.apply_move_and_slide()
	
	# If we hit a wall, stop the run animation and play idle
	if not was_on_wall and player.is_on_wall():
		animation_player.play("idle")
	elif not player.is_on_wall() and animation_player.current_animation == "idle":
		animation_player.play("run")

func exit():
	# Stop any current animation when exiting the run state
	if animation_player and animation_player.is_playing():
		animation_player.stop() 
