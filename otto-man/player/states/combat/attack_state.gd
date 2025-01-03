extends State

func enter():
	print("Entering Attack State")
	animation_tree.active = true
	animation_tree.set("parameters/conditions/movement_to_combat", true)
	player.velocity.x = 0

func physics_update(delta: float):
	if not player.is_on_floor():
		state_machine.transition_to("Fall")
		return
		
	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Jump")
		return
		
	var input_dir = Input.get_axis("left", "right")
	player.velocity.x = move_toward(player.velocity.x, player.speed * input_dir, player.acceleration * delta)
	player.move_and_slide()

func _on_animation_player_animation_finished(anim_name: String):
	if anim_name == "attack":
		state_machine.transition_to("Idle")

func exit():
	animation_tree.set("parameters/conditions/movement_to_combat", false) 
