extends Node

# Debug test to check spawn system

func _ready():
	
	# Test spawn configuration
	var spawn_config = SpawnConfig.new()
	
	# Test different levels and chunk types
	for level in range(1, 6):
		for i in range(5):
			var enemy_type = spawn_config.select_enemy_type(level, "basic")
	
	for level in range(1, 6):
		for i in range(5):
			var enemy_type = spawn_config.select_enemy_type(level, "dungeon")
	
