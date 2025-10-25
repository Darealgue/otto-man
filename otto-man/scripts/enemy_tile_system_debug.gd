extends Node
class_name EnemyTileSystemDebug

# Debug script for tile-based enemy spawn system
# This script helps test and debug the new enemy spawn system

var debug_enabled: bool = true

func _ready() -> void:
	if debug_enabled:
		print("[EnemyTileSystemDebug] Debug system initialized")
		# Connect to level generator signals
		var level_generator = get_tree().get_first_node_in_group("level_generator")
		if level_generator:
			level_generator.level_started.connect(_on_level_started)
			level_generator.level_completed.connect(_on_level_completed)

func _on_level_started() -> void:
	if debug_enabled:
		print("[EnemyTileSystemDebug] Level started - checking enemy spawns...")
		_check_enemy_spawns()

func _on_level_completed() -> void:
	if debug_enabled:
		print("[EnemyTileSystemDebug] Level completed - counting remaining enemies...")
		_count_remaining_enemies()

func _check_enemy_spawns() -> void:
	var tile_enemy_spawners = get_tree().get_nodes_in_group("TileEnemySpawner")
	var total_spawners = tile_enemy_spawners.size()
	var active_spawners = 0
	var total_enemies = 0
	
	for spawner in tile_enemy_spawners:
		if spawner.has_method("get_spawned_enemies"):
			var enemies = spawner.get_spawned_enemies()
			if enemies.size() > 0:
				active_spawners += 1
				total_enemies += enemies.size()
	
	print("[EnemyTileSystemDebug] Tile-based spawners: %d total, %d active" % [total_spawners, active_spawners])
	print("[EnemyTileSystemDebug] Total enemies spawned: %d" % total_enemies)
	
	# Check for legacy spawners
	var legacy_spawners = get_tree().get_nodes_in_group("EnemySpawner")
	if legacy_spawners.size() > 0:
		print("[EnemyTileSystemDebug] WARNING: %d legacy EnemySpawner nodes still exist!" % legacy_spawners.size())
	else:
		print("[EnemyTileSystemDebug] No legacy EnemySpawner nodes found - good!")

func _count_remaining_enemies() -> void:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var tile_spawned_enemies = 0
	var legacy_spawned_enemies = 0
	
	for enemy in all_enemies:
		# Check if enemy was spawned by tile system
		var parent = enemy.get_parent()
		if parent and parent.get_script() and parent.get_script().get_global_name() == "TileEnemySpawner":
			tile_spawned_enemies += 1
		else:
			legacy_spawned_enemies += 1
	
	print("[EnemyTileSystemDebug] Remaining enemies: %d tile-spawned, %d legacy-spawned" % [tile_spawned_enemies, legacy_spawned_enemies])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and debug_enabled:
		print("[EnemyTileSystemDebug] Manual debug check triggered")
		_check_enemy_spawns()
		_count_remaining_enemies()
