extends Node
class_name TrapManager

var _trap_config: TrapConfig
var _trap_spawners: Array[TrapSpawner] = []
var _active_spawners: Array[TrapSpawner] = []
var _chunk_type: String = "basic"
var _current_level: int = 1

func _ready() -> void:
	_trap_config = TrapConfig.new()
	print("[TrapManager] Initialized")
	
	# Collect all trap spawners in the chunk immediately
	_collect_trap_spawners()

func _collect_trap_spawners() -> void:
	# Look for TrapSpawner nodes in the parent (chunk)
	var parent = get_parent()
	if not parent:
		return
	
	_find_trap_spawners_recursive(parent)
	print("[TrapManager] Found %d trap spawners" % _trap_spawners.size())

func _find_trap_spawners_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is TrapSpawner:
			_trap_spawners.append(child as TrapSpawner)
			child.chunk_type = _chunk_type
			print("[TrapManager] Added spawner: %s (Category: %s)" % [child.name, TrapConfig.TrapCategory.keys()[child.trap_category]])
		else:
			_find_trap_spawners_recursive(child)

func initialize(chunk_type: String, level: int) -> void:
	_chunk_type = chunk_type
	_current_level = level
	
	print("[TrapManager] Initializing with chunk type: %s, level: %d" % [chunk_type, level])
	
	# Update all spawners with current settings
	for spawner in _trap_spawners:
		spawner.chunk_type = chunk_type
		spawner.current_level = level
	
	# Select which spawners to activate
	_active_spawners = _select_trap_spawners(_trap_spawners, chunk_type, level)
	
	# Activate selected spawners
	for spawner in _trap_spawners:
		if spawner in _active_spawners:
			spawner.activate()
		else:
			spawner.deactivate()
	
	print("[TrapManager] Activated %d out of %d spawners" % [_active_spawners.size(), _trap_spawners.size()])

# Select which trap spawners to activate based on chunk type and level
func _select_trap_spawners(available_spawners: Array[TrapSpawner], chunk_type: String, level: int) -> Array[TrapSpawner]:
	# For now, simple selection logic
	# Later we can make this more sophisticated
	
	var max_traps = _get_max_traps_for_level(level)
	var selected: Array[TrapSpawner] = []
	
	# Group spawners by category to ensure variety
	var ground_spawners: Array[TrapSpawner] = []
	var wall_spawners: Array[TrapSpawner] = []
	var ceiling_spawners: Array[TrapSpawner] = []
	
	for spawner in available_spawners:
		match spawner.trap_category:
			TrapConfig.TrapCategory.GROUND:
				ground_spawners.append(spawner)
				print("[TrapManager] Added GROUND spawner: %s" % spawner.name)
			TrapConfig.TrapCategory.WALL:
				wall_spawners.append(spawner)
				print("[TrapManager] Added WALL spawner: %s" % spawner.name)
			TrapConfig.TrapCategory.CEILING:
				ceiling_spawners.append(spawner)
				print("[TrapManager] Added CEILING spawner: %s" % spawner.name)
	
	# Select spawners with some variety
	var categories = [ground_spawners, wall_spawners, ceiling_spawners]
	var category_index = 0
	
	while selected.size() < max_traps and _has_available_spawners(categories):
		var current_category = categories[category_index % categories.size()]
		
		if not current_category.is_empty():
			# Select a random spawner from current category
			var spawner = current_category[randi() % current_category.size()]
			
			# Check if it's not too close to already selected spawners
			if _is_valid_placement(spawner, selected):
				selected.append(spawner)
				current_category.erase(spawner)
				print("[TrapManager] Selected spawner: %s (Category: %s)" % [spawner.name, TrapConfig.TrapCategory.keys()[spawner.trap_category]])
		
		category_index += 1
		
		# Prevent infinite loop
		if category_index > 100:
			break
	
	return selected

func _get_max_traps_for_level(level: int) -> int:
	# Scale number of traps with level
	match level:
		1: return 3  # Increased for testing
		2: return 3
		3: return 4
		4: return 4
		5: return 5
		_: return 5

func _has_available_spawners(categories: Array) -> bool:
	for category in categories:
		if not category.is_empty():
			return true
	return false

func _is_valid_placement(spawner: TrapSpawner, selected: Array[TrapSpawner]) -> bool:
	var min_distance = 300.0  # Minimum distance between traps
	
	for other_spawner in selected:
		if spawner.global_position.distance_to(other_spawner.global_position) < min_distance:
			return false
	
	return true

func get_active_trap_spawners() -> Array[TrapSpawner]:
	return _active_spawners

func get_active_traps() -> Array[BaseTrap]:
	var traps: Array[BaseTrap] = []
	for spawner in _active_spawners:
		var trap = spawner.get_spawned_trap()
		if trap:
			traps.append(trap)
	return traps

func clear_all_traps() -> void:
	for spawner in _trap_spawners:
		spawner.clear_trap()
	print("[TrapManager] Cleared all traps")

func set_level(level: int) -> void:
	_current_level = level
	initialize(_chunk_type, level)  # Re-initialize with new level

func activate_all_traps() -> void:
	for trap in get_active_traps():
		trap.activate()

func deactivate_all_traps() -> void:
	for trap in get_active_traps():
		trap.deactivate()

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"total_spawners": _trap_spawners.size(),
		"active_spawners": _active_spawners.size(),
		"chunk_type": _chunk_type,
		"current_level": _current_level,
		"spawner_categories": _get_spawner_category_counts()
	}

func _get_spawner_category_counts() -> Dictionary:
	var counts = {
		"ground": 0,
		"wall": 0,
		"ceiling": 0
	}
	
	for spawner in _trap_spawners:
		match spawner.trap_category:
			TrapConfig.TrapCategory.GROUND:
				counts.ground += 1
			TrapConfig.TrapCategory.WALL:
				counts.wall += 1
			TrapConfig.TrapCategory.CEILING:
				counts.ceiling += 1
	
	return counts 