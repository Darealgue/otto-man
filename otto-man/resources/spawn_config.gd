extends Resource
class_name SpawnConfig

# Spawn point activation rules per chunk type (1–9 seviye: 1. seviye hafif, ilerledikçe artar)
const DEBUG_SPAWN_CONFIG: bool = false
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
	},
	"dungeon": {
		1: { "min_spawns": 2, "max_spawns": 5 },
		2: { "min_spawns": 3, "max_spawns": 6 },
		3: { "min_spawns": 4, "max_spawns": 8 },
		4: { "min_spawns": 5, "max_spawns": 10 },
		5: { "min_spawns": 6, "max_spawns": 12 },
		6: { "min_spawns": 7, "max_spawns": 14 },
		7: { "min_spawns": 8, "max_spawns": 15 },
		8: { "min_spawns": 9, "max_spawns": 16 },
		9: { "min_spawns": 10, "max_spawns": 18 }
	}
}

# Enemy type weights per level
const ENEMY_WEIGHTS = {
	1: {
		"turtle": 25,
		"heavy": 20,
		"flying": 0,
		"summoner": 15,
		"canonman": 20,
		"firemage": 20,
		"spearman": 20,
		"basic": 0  # Not spawned in regular levels
	},
	2: {
		"turtle": 35,
		"heavy": 20,
		"flying": 15,
		"summoner": 0,
		"canonman": 15,
		"firemage": 0,
		"spearman": 15,
		"basic": 0
	},
	3: {
		"turtle": 25,
		"heavy": 20,
		"flying": 20,
		"summoner": 5,
		"canonman": 15,
		"firemage": 5,
		"spearman": 10,
		"basic": 0
	},
	4: {
		"turtle": 15,
		"heavy": 15,
		"flying": 20,
		"summoner": 10,
		"canonman": 15,
		"firemage": 15,
		"spearman": 10,
		"basic": 0
	},
	5: {
		"turtle": 10,
		"heavy": 15,
		"flying": 20,
		"summoner": 15,
		"canonman": 15,
		"firemage": 15,
		"spearman": 10,
		"basic": 0
	}
}

# Summoner ability scaling
const SUMMONER_SCALING = {
	1: { "max_summons": 1, "summon_interval": 5.0 },
	3: { "max_summons": 2, "summon_interval": 4.0 },
	5: { "max_summons": 3, "summon_interval": 3.0 }
}

# Zindan düşman ağırlıkları artık get_dungeon_enemy_weights() ile seviyeye göre sürekli aralıkta
# hesaplanıyor (tablo atlama yok); erken seviye basic+ağır, sonra mızrak/uçan/topol/charger/summoner/fire.
const DUNGEON_WEIGHT_TOTAL := 160.0
const DUNGEON_BASIC_FLOOR := 25

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

static func _smoothstep01(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# Her tür için: hangi seviyede görünmeye başlar, kaç seviyede tam ağırlığa yaklaşır, tavan ağırlık.
# canonman = charger hissi. Toplam specialty + basic ≈ DUNGEON_WEIGHT_TOTAL (yumuşak geçiş).
func get_dungeon_enemy_weights(level: int) -> Dictionary:
	var L := float(maxi(level, 1))
	var heavy := 10.0 + 13.0 * _smoothstep01((L - 1.0) / 7.0)
	var spearman := 12.0 * _smoothstep01((L - 2.0) / 5.0)
	var flying := 16.0 * _smoothstep01((L - 3.0) / 6.0)
	var turtle := 8.0 * _smoothstep01((L - 4.0) / 6.0)
	var canonman := 16.0 * _smoothstep01((L - 4.0) / 7.0)
	var summoner := 20.0 * _smoothstep01((L - 5.0) / 7.0)
	var firemage := 18.0 * _smoothstep01((L - 6.0) / 7.0)
	var specialty := heavy + spearman + flying + turtle + canonman + summoner + firemage
	var basic := maxf(float(DUNGEON_BASIC_FLOOR), DUNGEON_WEIGHT_TOTAL - specialty)
	return {
		"basic": int(round(basic)),
		"heavy": int(round(heavy)),
		"spearman": int(round(spearman)),
		"flying": int(round(flying)),
		"turtle": int(round(turtle)),
		"canonman": int(round(canonman)),
		"summoner": int(round(summoner)),
		"firemage": int(round(firemage))
	}

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

# Select enemy type based on level weights and chunk type
func select_enemy_type(level: int, chunk_type: String = "basic") -> String:
	var weights: Dictionary
	if chunk_type == "dungeon":
		weights = get_dungeon_enemy_weights(level)
		if DEBUG_SPAWN_CONFIG:
			print("[SpawnConfig] Using dungeon weights for level ", level, ": ", weights)
	else:
		weights = get_enemy_weights(level)
		if DEBUG_SPAWN_CONFIG:
			print("[SpawnConfig] Using regular weights for level ", level, ": ", weights)
	
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	if DEBUG_SPAWN_CONFIG:
		print("[SpawnConfig] Total weight: ", total_weight)
	
	var roll = randf_range(0, total_weight)
	var current_weight = 0
	
	if DEBUG_SPAWN_CONFIG:
		print("[SpawnConfig] Roll: ", roll)
	
	for enemy_type in weights:
		current_weight += weights[enemy_type]
		if DEBUG_SPAWN_CONFIG:
			print("[SpawnConfig] Checking ", enemy_type, " (weight: ", weights[enemy_type], ", current: ", current_weight, ")")
		if roll <= current_weight:
			if DEBUG_SPAWN_CONFIG:
				print("[SpawnConfig] Selected: ", enemy_type)
			return enemy_type
	
	if DEBUG_SPAWN_CONFIG:
		print("[SpawnConfig] Fallback to heavy")
	return "heavy"  # Fallback to heavy enemy 