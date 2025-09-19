extends Resource
class_name SpawnConfig

# Spawn point activation rules per chunk type
const CHUNK_SPAWN_RULES = {
	"basic": {
		1: { "min_spawns": 1, "max_spawns": 2 },
		3: { "min_spawns": 2, "max_spawns": 3 },
		5: { "min_spawns": 2, "max_spawns": 4 }
	},
	"combat": {
		1: { "min_spawns": 2, "max_spawns": 3 },
		3: { "min_spawns": 3, "max_spawns": 4 },
		5: { "min_spawns": 3, "max_spawns": 5 }
	}
}

# Enemy type weights per level
const ENEMY_WEIGHTS = {
	1: {
		"turtle": 60,
		"heavy": 30,
		"flying": 10,
		"summoner": 0
	},
	3: {
		"turtle": 40,
		"heavy": 35,
		"flying": 20,
		"summoner": 5
	},
	5: {
		"turtle": 25,
		"heavy": 30,
		"flying": 30,
		"summoner": 15
	}
}

# Summoner ability scaling
const SUMMONER_SCALING = {
	1: { "max_summons": 1, "summon_interval": 5.0 },
	3: { "max_summons": 2, "summon_interval": 4.0 },
	5: { "max_summons": 3, "summon_interval": 3.0 }
}

# Get spawn count for a chunk at given level
func get_spawn_count(chunk_type: String, level: int) -> Dictionary:
	# Find the appropriate rule set
	var rules = CHUNK_SPAWN_RULES.get(chunk_type, CHUNK_SPAWN_RULES["basic"])
	
	# Find the highest level that's less than or equal to current level
	var applicable_level = 1
	for rule_level in rules:
		if rule_level <= level and rule_level > applicable_level:
			applicable_level = rule_level
	
	return rules[applicable_level]

# Get enemy weights for a given level
func get_enemy_weights(level: int) -> Dictionary:
	var applicable_level = 1
	for weight_level in ENEMY_WEIGHTS:
		if weight_level <= level and weight_level > applicable_level:
			applicable_level = weight_level
	
	return ENEMY_WEIGHTS[applicable_level]

# Get summoner abilities for a given level
func get_summoner_scaling(level: int) -> Dictionary:
	var applicable_level = 1
	for scale_level in SUMMONER_SCALING:
		if scale_level <= level and scale_level > applicable_level:
			applicable_level = scale_level
	
	return SUMMONER_SCALING[applicable_level]

# Select which spawn points to activate
func select_spawn_points(available_points: Array[EnemySpawner], chunk_type: String, level: int) -> Array[EnemySpawner]:
	var rules = get_spawn_count(chunk_type, level)
	var count = randi_range(rules.min_spawns, rules.max_spawns)
	
	# Ensure we don't try to activate more points than available
	count = mini(count, available_points.size())
	
	# Create a typed array for selected points
	var selected_points: Array[EnemySpawner] = []
	
	# Create a temporary array for shuffling
	var points_to_process = available_points.duplicate()
	points_to_process.shuffle()
	
	# Select points with consideration for spacing
	var min_distance = 200.0  # Minimum distance between spawn points
	
	for point in points_to_process:
		var too_close = false
		for selected in selected_points:
			if point.global_position.distance_to(selected.global_position) < min_distance:
				too_close = true
				break
		
		if not too_close:
			selected_points.append(point)
			if selected_points.size() >= count:
				break
	
	return selected_points

# Select enemy type based on level weights
func select_enemy_type(level: int) -> String:
	var weights = get_enemy_weights(level)
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	var roll = randf_range(0, total_weight)
	var current_weight = 0
	
	for enemy_type in weights:
		current_weight += weights[enemy_type]
		if roll <= current_weight:
			return enemy_type
	
	return "heavy"  # Fallback to heavy enemy 