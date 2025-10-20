extends Node

# Debug test to check spawn system

func _ready():
	print("=== Spawn System Debug Test ===")
	
	# Test spawn configuration
	var spawn_config = SpawnConfig.new()
	
	# Test different levels and chunk types
	print("\n--- Testing Regular Areas ---")
	for level in range(1, 6):
		print("\nLevel ", level, ":")
		for i in range(5):
			var enemy_type = spawn_config.select_enemy_type(level, "basic")
			print("  Spawn ", i+1, ": ", enemy_type)
	
	print("\n--- Testing Dungeon Areas ---")
	for level in range(1, 6):
		print("\nDungeon Level ", level, ":")
		for i in range(5):
			var enemy_type = spawn_config.select_enemy_type(level, "dungeon")
			print("  Spawn ", i+1, ": ", enemy_type)
	
	print("\n=== Debug Test Complete ===")
