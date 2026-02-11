extends Node2D
class_name TileEnemySpawner

# Tile-based enemy spawner - similar to DecorationSpawner but for enemies
@export var enemy_type: String = ""  # If set, forces this enemy type
@export var auto_spawn: bool = true
@export var spawn_chance: float = 0.8
@export var current_level: int = 1
@export var chunk_type: String = "basic"

# Internal variables
var _spawned_enemies: Array[Node] = []
var _spawn_config: SpawnConfig
var _is_active: bool = false

# Visual marker for editor
var spawn_marker: Node2D

# Debug toggle
const DEBUG_ENEMY: bool = true

# Enemy scenes with their spawn weights (same as EnemySpawner)
# Use load() instead of preload() for better export compatibility
var ENEMY_TYPES = {
	"turtle": {
		"scene_path": "res://enemy/turtle/turtle_enemy.tscn",
		"weight": 50,
		"min_level": 1
	},
	"heavy": {
		"scene_path": "res://enemy/heavy/heavy_enemy.tscn",
		"weight": 100,
		"min_level": 1
	},
	"flying": {
		"scene_path": "res://enemy/flying/flying_enemy.tscn",
		"weight": 35,
		"min_level": 2
	},
	"summoner": {
		"scene_path": "res://enemy/summoner/summoner_enemy.tscn",
		"weight": 25,
		"min_level": 3
	},
	"canonman": {
		"scene_path": "res://enemy/canonman/canonman_enemy.tscn",
		"weight": 30,
		"min_level": 2
	},
	"firemage": {
		"scene_path": "res://enemy/firemage/firemage_enemy.tscn",
		"weight": 20,
		"min_level": 3
	},
	"spearman": {
		"scene_path": "res://enemy/spearman/spearman_enemy.tscn",
		"weight": 30,
		"min_level": 2
	},
	"basic": {
		"scene_path": "res://enemy/basic/basic_enemy.tscn",
		"weight": 150,  # High weight for common spawning
		"min_level": 1  # Available from level 1
	}
}

const ENEMY_Z_INDEX = 4  # Enemies appear above all decorations but below player

func _ready() -> void:
	# Load spawn configuration
	_spawn_config = SpawnConfig.new()
	
	# Add to group for debugging
	add_to_group("TileEnemySpawner")
	
	# Hide visual marker
	spawn_marker = get_node_or_null("SpawnMarker")
	if spawn_marker:
		spawn_marker.visible = false
	
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Initialized - Level: %d, Chunk: %s" % [current_level, chunk_type])

func activate() -> bool:
	_is_active = true
	if auto_spawn:
		if randf() <= spawn_chance:
			_spawn_enemy()
			if DEBUG_ENEMY:
				print("[TileEnemySpawner] Activated and spawned")
			return true
		else:
			if DEBUG_ENEMY:
				print("[TileEnemySpawner] Activated but failed chance roll")
			_is_active = false
			return false
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Activated")
	return true

func deactivate() -> void:
	_is_active = false
	clear_enemies()
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Deactivated")

func _spawn_enemy() -> bool:
	# Select enemy type based on level and chunk type
	var selected_enemy_type = enemy_type if not enemy_type.is_empty() else _spawn_config.select_enemy_type(current_level, chunk_type)
	
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Selected enemy type: %s" % selected_enemy_type)
	
	# Check if enemy type exists
	if not ENEMY_TYPES.has(selected_enemy_type):
		if DEBUG_ENEMY:
			print("[TileEnemySpawner] Enemy type '%s' not found!" % selected_enemy_type)
		return false
	
	# Check minimum level requirement
	if ENEMY_TYPES[selected_enemy_type].min_level > current_level:
		if DEBUG_ENEMY:
			print("[TileEnemySpawner] Enemy type '%s' requires level %d, current level %d" % [selected_enemy_type, ENEMY_TYPES[selected_enemy_type].min_level, current_level])
		return false
	
	# Create enemy instance - load scene at runtime for export compatibility
	var enemy_scene_path = ENEMY_TYPES[selected_enemy_type].scene_path
	var enemy_scene = load(enemy_scene_path)
	if not enemy_scene:
		push_error("[TileEnemySpawner] Failed to load enemy scene: %s" % enemy_scene_path)
		return false
	
	# Verify it's a valid PackedScene
	if not enemy_scene is PackedScene:
		push_error("[TileEnemySpawner] Loaded resource is not a PackedScene: %s (type: %s)" % [enemy_scene_path, typeof(enemy_scene)])
		return false
	
	var enemy = enemy_scene.instantiate()
	
	if not enemy:
		push_error("[TileEnemySpawner] Failed to instantiate enemy: %s" % selected_enemy_type)
		return false
	
	# Add to scene
	get_parent().add_child(enemy)
	
	# Set position using the same system as decorations
	# Use spawner position directly (already calculated correctly in level_generator)
	enemy.global_position = global_position
	
	# DETAILED DEBUG (Reduced)
	print("[TileEnemySpawner] Spawned %s at: %s" % [enemy_type, enemy.global_position])
	
	# Set z-index
	enemy.z_index = ENEMY_Z_INDEX
	var enemy_sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if enemy_sprite:
		enemy_sprite.z_index = ENEMY_Z_INDEX
	
	# Store spawned enemy
	_spawned_enemies.append(enemy)
	
	# Scale enemy stats to current level
	# stats is an @export var in BaseEnemy, so it should always exist (but may be null)
	# get() returns null if property doesn't exist, so we can use it directly
	var stats = enemy.get("stats")
	if stats and stats.has_method("scale_to_level"):
		stats.scale_to_level(current_level - 1)
	elif not stats:
		push_warning("[TileEnemySpawner] Enemy %s has no stats resource assigned!" % selected_enemy_type)
	
	# Apply additional scaling for summoners
	if selected_enemy_type == "summoner":
		var summoner_scale = _spawn_config.get_summoner_scaling(current_level)
		var max_summons = enemy.get("max_summons")
		var summon_interval = enemy.get("summon_interval")
		if max_summons != null:
			enemy.set("max_summons", summoner_scale.max_summons)
		if summon_interval != null:
			enemy.set("summon_interval", summoner_scale.summon_interval)
	
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Enemy spawn complete at: %s" % enemy.global_position)
	
	return true

func get_spawned_enemies() -> Array[Node]:
	return _spawned_enemies

func clear_enemies() -> void:
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Cleared all enemies")

func set_level(level: int) -> void:
	current_level = level
	if DEBUG_ENEMY:
		print("[TileEnemySpawner] Level set to: %d" % level)
