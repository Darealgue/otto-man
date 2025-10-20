extends Node

# Test script to verify new enemies are properly configured for dungeon spawning

func _ready():
	print("=== Dungeon Enemy Configuration Test ===")
	print("Note: Hunter and Miniboss removed from spawn system")
	print("Hunter: Not fully functional yet")
	print("Miniboss: Should only spawn at level/boss endings")
	print("Added: Spearman (working enemy)")
	
	# Test spawn configuration
	var spawn_config = SpawnConfig.new()
	
	# Test regular enemy weights
	print("\n--- Regular Enemy Weights ---")
	for level in range(1, 6):
		var weights = spawn_config.get_enemy_weights(level)
		print("Level ", level, ": ", weights)
	
	# Test dungeon enemy weights
	print("\n--- Dungeon Enemy Weights ---")
	for level in range(1, 6):
		var weights = spawn_config.get_dungeon_enemy_weights(level)
		print("Level ", level, ": ", weights)
	
	# Test enemy type selection for dungeon
	print("\n--- Dungeon Enemy Selection Test ---")
	for i in range(10):
		var enemy_type = spawn_config.select_enemy_type(3, "dungeon")
		print("Selected enemy type: ", enemy_type)
	
	# Test enemy type selection for regular areas
	print("\n--- Regular Enemy Selection Test ---")
	for i in range(10):
		var enemy_type = spawn_config.select_enemy_type(3, "basic")
		print("Selected enemy type: ", enemy_type)
	
	print("\n=== Test Complete ===")
