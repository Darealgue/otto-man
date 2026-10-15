extends Node

# Test script to verify new enemies are properly configured for dungeon spawning

func _ready():
	
	# Test spawn configuration
	var spawn_config = SpawnConfig.new()
	
	# Test regular enemy weights
	for level in range(1, 6):
		var weights = spawn_config.get_enemy_weights(level)
	
	# Test dungeon enemy weights
	for level in range(1, 6):
		var weights = spawn_config.get_dungeon_enemy_weights(level)
	
	# Test enemy type selection for dungeon
	for i in range(10):
		var enemy_type = spawn_config.select_enemy_type(3, "dungeon")
	
	# Test enemy type selection for regular areas
	for i in range(10):
		var enemy_type = spawn_config.select_enemy_type(3, "basic")
	
