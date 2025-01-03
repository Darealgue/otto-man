extends State

func enter():
	print("Entering Block State")
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
	player.velocity.x = move_toward(player.velocity.x, player.speed * input_dir * 0.3, player.acceleration * delta)
	
	if not Input.is_action_pressed("block"):
		animation_tree.set("parameters/combat/conditions/block_released", true)
		state_machine.transition_to("Idle")
		return
		
	player.move_and_slide()

func handle_block_impact():
	animation_tree.set("parameters/combat/conditions/block_hit", true)

func exit():
	animation_tree.set("parameters/conditions/movement_to_combat", false)
	animation_tree.set("parameters/combat/conditions/block_released", false)
	animation_tree.set("parameters/combat/conditions/block_hit", false) 
