extends Node

const DEBUG = true

func _ready() -> void:
	# Wait a bit to ensure all nodes are ready
	await get_tree().create_timer(0.1).timeout
	check_player_setup()

func check_player_setup() -> void:
	var player = get_parent()
	if !player:
		print("[DEBUG] ERROR: Could not get player node")
		return
		
	print("\n=== PLAYER DEBUG REPORT ===")
	
	# Check basic node structure
	print("\nNode Structure:")
	print("- AnimatedSprite2D: ", player.has_node("AnimatedSprite2D"))
	print("- AnimationPlayer: ", player.has_node("AnimationPlayer"))
	print("- AnimationTree: ", player.has_node("AnimationTree"))
	print("- StateMachine: ", player.has_node("StateMachine"))
	
	# Check AnimatedSprite2D
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if sprite:
		print("\nAnimatedSprite2D Status:")
		print("- Visible: ", sprite.visible)
		print("- Sprite Frames: ", sprite.sprite_frames != null)
		if sprite.sprite_frames:
			print("- Available Animations: ", sprite.sprite_frames.get_animation_names())
			print("- Current Animation: ", sprite.animation)
	else:
		print("\nERROR: AnimatedSprite2D not found!")
	
	# Check AnimationPlayer
	var anim_player = player.get_node_or_null("AnimationPlayer")
	if anim_player:
		print("\nAnimationPlayer Status:")
		print("- Has Default Library: ", anim_player.has_animation_library(""))
		if anim_player.has_animation_library(""):
			print("- Available Animations: ", anim_player.get_animation_list())
			print("- Current Animation: ", anim_player.current_animation)
	else:
		print("\nERROR: AnimationPlayer not found!")
	
	# Check AnimationTree
	var anim_tree = player.get_node_or_null("AnimationTree")
	if anim_tree:
		print("\nAnimationTree Status:")
		print("- Active: ", anim_tree.active)
		print("- Has Root: ", anim_tree.tree_root != null)
		print("- Animation Player Path: ", anim_tree.anim_player)
		if anim_tree.active:
			var state_machine = anim_tree.get("parameters/playback")
			if state_machine:
				print("- Current State: ", state_machine.get_current_node())
			print("- Movement Blend: ", anim_tree.get("parameters/movement/blend_position"))
			print("- Air Blend: ", anim_tree.get("parameters/air_state/blend_position"))
			print("- Combat Blend: ", anim_tree.get("parameters/combat/blend_position"))
	else:
		print("\nERROR: AnimationTree not found!")
	
	# Check StateMachine
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine:
		print("\nStateMachine Status:")
		print("- Current State: ", state_machine.current_state.name if state_machine.current_state else "None")
		print("- Available States: ", state_machine.states.keys())
	else:
		print("\nERROR: StateMachine not found!")
	
	print("\n=== END PLAYER DEBUG REPORT ===\n") 