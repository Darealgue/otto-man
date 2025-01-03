extends State

func enter():
	print("Entering Run State")
	animation_player.play("run")
	print("Playing animation:", animation_player.current_animation)

func physics_update(delta: float):
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Jump")
		return
		
	var input_dir = Input.get_axis("left", "right")
	if input_dir == 0:
		state_machine.transition_to("Idle")
		return
		
	# Check if we're running into a wall
	var was_on_wall = player.is_on_wall()
	player.velocity.x = move_toward(player.velocity.x, player.speed * input_dir, player.acceleration * delta)
	player.move_and_slide()
	
	# If we hit a wall, stop the run animation and play idle
	if not was_on_wall and player.is_on_wall():
		animation_player.play("idle")
	elif not player.is_on_wall() and animation_player.current_animation == "idle":
		animation_player.play("run")

func exit():
	animation_tree.set("parameters/conditions/air_to_movement", false) 
