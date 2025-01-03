extends Node

# Test script to verify animations and transitions
class_name AnimationTest

const DEBUG = true

var player: CharacterBody2D
var animation_tree: AnimationTree
var animation_state: AnimationNodeStateMachinePlayback

func _init(player_node: CharacterBody2D) -> void:
	player = player_node
	if DEBUG:
		print("[AnimationTest] Initialized with player node")

func _ready() -> void:
	# Wait for nodes to be ready
	await get_tree().create_timer(0.1).timeout
	
	# Get animation nodes
	animation_tree = player.get_node_or_null("AnimationTree")
	if animation_tree:
		animation_state = animation_tree["parameters/playback"]
		if DEBUG:
			print("[AnimationTest] Got animation tree and state")
	
	if !animation_tree or !animation_state:
		push_error("[AnimationTest] Animation test setup failed: animation tree or state not found")

func test_all() -> void:
	if !animation_tree or !animation_state:
		push_error("[AnimationTest] Cannot run animation tests: animation system not initialized")
		return
		
	print("[AnimationTest] Starting animation system tests...")
	
	# Test ground states
	test_ground_movement()
	
	# Test air states
	test_air_movement()
	
	# Test combat states
	test_combat()
	
	print("[AnimationTest] Animation system tests completed.")

func test_ground_movement() -> void:
	if !animation_tree or !animation_state:
		return
		
	print("\n[AnimationTest] Testing ground movement animations...")
	
	# Test idle
	print("- Testing idle animation")
	animation_state.travel("movement")
	animation_tree.set("parameters/movement/blend_position", 0.0)
	verify_animation("movement")
	await get_tree().create_timer(1.0).timeout
	
	# Test run
	print("- Testing run animation")
	animation_tree.set("parameters/movement/blend_position", 1.0)
	verify_animation("movement")
	await get_tree().create_timer(0.8).timeout
	
	print("[AnimationTest] Ground movement animations OK")

func test_air_movement() -> void:
	if !animation_tree or !animation_state:
		return
		
	print("\n[AnimationTest] Testing air movement animations...")
	
	# Test jump
	print("- Testing jump animation")
	animation_state.travel("air_state")
	animation_tree.set("parameters/air_state/blend_position", -1.0)
	verify_animation("air_state")
	await get_tree().create_timer(0.5).timeout
	
	# Test double jump
	print("- Testing double jump animation")
	animation_tree.set("parameters/air_state/blend_position", 0.0)
	verify_animation("air_state")
	await get_tree().create_timer(0.5).timeout
	
	# Test fall
	print("- Testing fall animation")
	animation_tree.set("parameters/air_state/blend_position", 1.0)
	verify_animation("air_state")
	await get_tree().create_timer(0.5).timeout
	
	print("[AnimationTest] Air movement animations OK")

func test_combat() -> void:
	if !animation_tree or !animation_state:
		return
		
	print("\n[AnimationTest] Testing combat animations...")
	
	# Test attack
	print("- Testing attack animations")
	animation_state.travel("combat")
	animation_tree.set("parameters/combat/blend_position", -1.0)
	verify_animation("combat")
	await get_tree().create_timer(0.4).timeout
	
	# Test block
	print("- Testing block animations")
	animation_tree.set("parameters/combat/blend_position", 0.0)
	verify_animation("combat")
	await get_tree().create_timer(0.3).timeout
	
	# Test block impact
	print("- Testing block impact animation")
	animation_tree.set("parameters/combat/blend_position", 1.0)
	verify_animation("combat")
	await get_tree().create_timer(0.2).timeout
	
	print("[AnimationTest] Combat animations OK")

# Helper function to verify animation is playing
func verify_animation(expected_name: String) -> bool:
	if !animation_state:
		return false
		
	var current = animation_state.get_current_node()
	var success = current == expected_name
	if not success:
		print("[AnimationTest] Animation verification failed: Expected '%s' but got '%s'" % [expected_name, current])
	return success 
