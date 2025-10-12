extends "../state.gd"

func enter():
	if !player:
		push_error("Player reference not set in idle state!")
		return
	
	# Play appropriate idle animation based on combat state
	var in_combat = player.is_in_combat_state()
	if animation_player:
		if in_combat:
			animation_player.play("idle_combat")
		else:
			animation_player.play("idle")
	
	if player.has_method("reset_jump_state"):
		player.reset_jump_state()
	else:
		push_error("Player is missing reset_jump_state method!")

func physics_update(delta: float):
	if !player:
		return
		
	# Check for attack input first
	if Input.is_action_just_pressed("attack") and player.attack_cooldown_timer <= 0:
		state_machine.transition_to("Attack")
		return

	# Heavy attack input
	if Input.is_action_just_pressed("attack_heavy") and player.attack_cooldown_timer <= 0:
		state_machine.transition_to("HeavyAttack")
		return
		
	# Check for block input - sadece charge varsa işle
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and stamina_bar.has_charges():
		if Input.is_action_just_pressed("block") or Input.is_action_pressed("block"):
			# Check if block input is blocked by dodge state (only for just_pressed)
			if Input.is_action_just_pressed("block"):
				if player.block_input_blocked_timer > 0:
					# Input'u tüket - sürekli basılı kalmasını engelle
					get_viewport().set_input_as_handled()
					return
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
		print("[IdleState] Jump input processed - transitioning to Jump")
		state_machine.transition_to("Jump")
		return
	elif Input.is_action_just_pressed("jump") and (player.jump_input_blocked or player.jump_block_timer > 0):
		print("[IdleState] Jump input BLOCKED by dodge state (blocked:", player.jump_input_blocked, "timer:", player.jump_block_timer, ")")
		
	var input_dir = Input.get_axis("left", "right")
	if input_dir != 0:
		state_machine.transition_to("Run")
		return
		
	player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	player.move_and_slide()
	
	# Play appropriate idle animation based on combat state
	var target_animation = "idle_combat" if player.is_in_combat_state() else "idle"
	if animation_player.current_animation != target_animation:
		animation_player.play(target_animation)

func exit():
	pass
