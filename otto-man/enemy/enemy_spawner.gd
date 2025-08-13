extends Node2D
class_name EnemySpawner

# Enemy scenes with their spawn weights
const ENEMY_TYPES = {
	"heavy": {
		"scene": preload("res://enemy/heavy/heavy_enemy.tscn"),
		"weight": 40,  # Higher weight = more common
		"min_level": 1  # Minimum level to start spawning
	},
	"flying": {
		"scene": preload("res://enemy/flying/flying_enemy.tscn"),
		"weight": 35,
		"min_level": 2
	},
	"summoner": {
		"scene": preload("res://enemy/summoner/summoner_enemy.tscn"),
		"weight": 25,
		"min_level": 3
	}
}

# Configuration
@export var auto_spawn: bool = true  # Whether to spawn automatically on ready
@export var spawn_on_level_start: bool = false  # Whether to wait for level start signal
@export var current_level: int = 1  # Current level number (will be set by level generator)
@export var chunk_type: String = "basic"  # Type of chunk this spawner is in

# Optional configuration
@export var force_enemy_type: String = ""  # If set, only spawns this type of enemy
@export var spawn_radius: float = 100.0  # Random spawn radius around the spawner

# Internal variables
var _spawned_enemies: Array[Node] = []
var _level_generator: Node = null
var _spawn_config: SpawnConfig
var _is_active: bool = false  # Whether this spawn point is active

const ENEMY_Z_INDEX = 5  # Ensure enemies appear above tiles

func _ready() -> void:
	# Load spawn configuration
	_spawn_config = SpawnConfig.new()
	
	# Find level generator
	_level_generator = get_tree().get_first_node_in_group("level_generator")
	if _level_generator:
		current_level = _level_generator.current_level
		
	# Hide visual marker
	$SpawnMarker.visible = false
	
	if auto_spawn and not spawn_on_level_start:
		# Don't spawn immediately, wait for activation
		pass
	elif spawn_on_level_start:
		_level_generator.level_started.connect(_on_level_started)

func activate() -> void:
	_is_active = true
	if auto_spawn:
		spawn_enemies()

func deactivate() -> void:
	_is_active = false
	clear_enemies()

func _on_level_started() -> void:
	if _is_active:
		spawn_enemies()

func spawn_enemies() -> void:
	if not _is_active:
		return
		
	# Clear any existing enemies
	clear_enemies()
	
	# Select enemy type based on level
	var enemy_type = force_enemy_type if not force_enemy_type.is_empty() else _spawn_config.select_enemy_type(current_level)
	
	# Get the spawn position before instantiating
	var spawn_pos = global_position
	print("[EnemySpawner] Preparing to spawn at: ", spawn_pos)
	
	# Spawn the enemy
	var enemy_scene = ENEMY_TYPES[enemy_type].scene
	var enemy = enemy_scene.instantiate()
	
	# Add to scene
	add_child(enemy)
	
	# Ensure the enemy was added successfully
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		push_error("[EnemySpawner] Failed to add enemy to scene")
		return
		
	print("[EnemySpawner] Enemy added to scene, setting position...")
	
	# Set the global position
	enemy.global_position = spawn_pos
	
	# Ensure enemy is on the floor by raycasting down
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(spawn_pos, spawn_pos + Vector2.DOWN * 500.0)  # Increased raycast distance
	query.collision_mask = CollisionLayers.WORLD  # Environment layer
	var result = space_state.intersect_ray(query)
	
	if result:
		# Place slightly above the ground to ensure proper floor detection
		enemy.global_position = result.position - Vector2(0, 32)  # Offset up by 32 pixels
		print("[EnemySpawner] Adjusted enemy position to floor: ", enemy.global_position)
		
		# Force an immediate physics update to ensure floor detection
		enemy.move_and_slide()
	else:
		push_warning("[EnemySpawner] Could not find floor below spawn point")
	
	print("[EnemySpawner] Position set to: ", enemy.global_position)
	
	# Ensure enemy appears above tiles
	enemy.z_index = ENEMY_Z_INDEX
	_spawned_enemies.append(enemy)
	
	# Scale enemy stats to current level
	if enemy.stats:
		enemy.stats.scale_to_level(current_level - 1)  # -1 because level 1 is base stats
		
		# Apply additional scaling for summoners
		if enemy_type == "summoner":
			var summoner_scale = _spawn_config.get_summoner_scaling(current_level)
			enemy.max_summons = summoner_scale.max_summons
			enemy.summon_interval = summoner_scale.summon_interval
	
	print("[EnemySpawner] Enemy spawn complete at: ", enemy.global_position)

func get_spawned_enemies() -> Array[Node]:
	return _spawned_enemies

func clear_enemies() -> void:
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()

func set_level(level: int) -> void:
	current_level = level

# Optional: Spawn with cooldown
func start_spawning(interval: float = 5.0) -> void:
	if not _is_active:
		return
		
	while _is_active:
		spawn_enemies()
		await get_tree().create_timer(interval).timeout 
