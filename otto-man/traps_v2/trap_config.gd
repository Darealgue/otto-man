extends Resource
class_name TrapConfigV2

enum SurfaceType {
	FLOOR,
	CEILING,
	LEFT_WALL,
	RIGHT_WALL
}

enum TrapType {
	SPIKE,
	FIRE_TRAP,
	ARROW_SHOOTER,
	CANNON_TRAP,
	POISON_DRIP
}

const TRAP_DATA = {
	TrapType.SPIKE: {
		"scene_path": "res://traps_v2/ground/spike_trap.tscn",
		"surface": SurfaceType.FLOOR,
		"weight": 50,
		"min_level": 1,
		"base_damage": 10.0
	},
	TrapType.FIRE_TRAP: {
		"scene_path": "res://traps_v2/ground/fire_trap.tscn",
		"surface": SurfaceType.FLOOR,
		"weight": 30,
		"min_level": 1,
		"base_damage": 8.0
	},
	TrapType.ARROW_SHOOTER: {
		"scene_path": "res://traps_v2/wall/arrow_shooter.tscn",
		"surface": SurfaceType.LEFT_WALL,  # overridden at spawn
		"weight": 45,
		"min_level": 1,
		"base_damage": 12.0
	},
	TrapType.CANNON_TRAP: {
		"scene_path": "res://traps_v2/wall/cannon_trap.tscn",
		"surface": SurfaceType.LEFT_WALL,  # overridden at spawn
		"weight": 25,
		"min_level": 1,
		"base_damage": 20.0
	},
	TrapType.POISON_DRIP: {
		"scene_path": "res://traps_v2/ceiling/poison_drip.tscn",
		"surface": SurfaceType.CEILING,
		"weight": 35,
		"min_level": 1,
		"base_damage": 2.0
	}
}

static func get_traps_for_surface(surface: SurfaceType, level: int) -> Array[TrapType]:
	var result: Array[TrapType] = []
	for trap_type in TRAP_DATA:
		var data: Dictionary = TRAP_DATA[trap_type]
		if data.min_level > level:
			continue
		match surface:
			SurfaceType.FLOOR:
				if data.surface == SurfaceType.FLOOR:
					result.append(trap_type)
			SurfaceType.CEILING:
				if data.surface == SurfaceType.CEILING:
					result.append(trap_type)
			SurfaceType.LEFT_WALL, SurfaceType.RIGHT_WALL:
				if data.surface == SurfaceType.LEFT_WALL or data.surface == SurfaceType.RIGHT_WALL:
					result.append(trap_type)
	return result

static func select_random_trap(surface: SurfaceType, level: int) -> TrapType:
	var available := get_traps_for_surface(surface, level)
	if available.is_empty():
		return TrapType.SPIKE
	var total_weight: int = 0
	for t in available:
		var w: int = TRAP_DATA[t].weight
		# Bias: more cannon on left wall so both wall sides get cannons
		if surface == SurfaceType.LEFT_WALL and t == TrapType.CANNON_TRAP:
			w = int(w * 1.8)
		total_weight += w
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for t in available:
		var w: int = TRAP_DATA[t].weight
		if surface == SurfaceType.LEFT_WALL and t == TrapType.CANNON_TRAP:
			w = int(w * 1.8)
		cumulative += w
		if roll < cumulative:
			return t
	return available[0]

static func get_group_size_range(level: int) -> Vector2i:
	match level:
		1: return Vector2i(1, 2)
		2: return Vector2i(1, 3)
		3: return Vector2i(2, 4)
		4: return Vector2i(2, 5)
		_: return Vector2i(3, 6)

static func get_scene_path(trap_type: TrapType) -> String:
	return TRAP_DATA[trap_type].scene_path

static func get_base_damage(trap_type: TrapType) -> float:
	return TRAP_DATA[trap_type].base_damage

static func surface_from_string(s: String) -> SurfaceType:
	match s.to_lower():
		"floor", "floor_surface": return SurfaceType.FLOOR
		"ceiling", "ceiling_surface": return SurfaceType.CEILING
		"left_wall", "left_wall_surface", "lef_wall_surface": return SurfaceType.LEFT_WALL
		"right_wall", "right_wall_surface": return SurfaceType.RIGHT_WALL
		_: return SurfaceType.FLOOR
