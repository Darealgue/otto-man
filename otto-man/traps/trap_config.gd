extends Resource
class_name TrapConfig

# Trap placement categories
enum TrapCategory {
	GROUND,		# Yerden çıkan tuzaklar
	WALL,		# Duvardan çıkan tuzaklar
	CEILING		# Tavandan sallanan tuzaklar
}

# Trap activation types
enum ActivationType {
	PROXIMITY,	# Oyuncu yaklaştığında
	TIMER,		# Belirli aralıklarla
	TRIGGER		# Özel koşullarda
}

# Trap damage types
enum DamageType {
	PHYSICAL,	# Fiziksel hasar
	FIRE,		# Yanma hasarı
	POISON,		# Zehir hasarı
	ICE			# Dondurucu hasar
}

# Basic trap type definitions
const TRAP_TYPES = {
	TrapCategory.GROUND: {
		"spike_trap": {
			"scene": "res://traps/ground/spike_trap.tscn",
			"weight": 40,
			"min_level": 1,
			"damage_type": DamageType.PHYSICAL
		},
		"fire_geyser": {
			"scene": "res://traps/ground/fire_geyser.tscn", 
			"weight": 30,
			"min_level": 2,
			"damage_type": DamageType.FIRE
		},
		"poison_spikes": {
			"scene": "res://traps/ground/poison_spikes.tscn",
			"weight": 25,
			"min_level": 3,
			"damage_type": DamageType.POISON
		}
	},
	TrapCategory.WALL: {
		"arrow_shooter": {
			"scene": "res://traps/wall/arrow_shooter.tscn",
			"weight": 40,
			"min_level": 1,
			"damage_type": DamageType.PHYSICAL
		},
		"cannon_trap": {
			"scene": "res://traps/wall/cannon_trap.tscn",
			"weight": 35,
			"min_level": 1,
			"damage_type": DamageType.PHYSICAL
		},
		"horizontal_saw": {
			"scene": "res://traps/wall/horizontal_saw.tscn",
			"weight": 25,
			"min_level": 3,
			"damage_type": DamageType.PHYSICAL
		}
	},
	TrapCategory.CEILING: {
		"pendulum_axe": {
			"scene": "res://traps/ceiling/pendulum_axe.tscn",
			"weight": 40,
			"min_level": 2,
			"damage_type": DamageType.PHYSICAL
		},
		"falling_spikes": {
			"scene": "res://traps/ceiling/falling_spikes.tscn",
			"weight": 35,
			"min_level": 1,
			"damage_type": DamageType.PHYSICAL
		}
	}
}

# Level-based trap weights
const LEVEL_WEIGHTS = {
	1: { "basic_weight_multiplier": 1.0, "advanced_weight_multiplier": 0.0 },
	2: { "basic_weight_multiplier": 0.8, "advanced_weight_multiplier": 0.3 },
	3: { "basic_weight_multiplier": 0.6, "advanced_weight_multiplier": 0.5 },
	4: { "basic_weight_multiplier": 0.4, "advanced_weight_multiplier": 0.7 },
	5: { "basic_weight_multiplier": 0.2, "advanced_weight_multiplier": 1.0 }
}

# Get available traps for category and level
func get_available_traps(category: TrapCategory, level: int) -> Array:
	var available = []
	var traps = TRAP_TYPES.get(category, {})
	
	for trap_name in traps:
		var trap_data = traps[trap_name]
		if trap_data.min_level <= level:
			available.append(trap_name)
	
	return available

# Select random trap type for category and level
func select_trap_type(category: TrapCategory, level: int) -> String:
	var available = get_available_traps(category, level)
	if available.is_empty():
		push_warning("No traps available for category %s at level %d" % [TrapCategory.keys()[category], level])
		return ""
	
	# Simple random selection for now
	return available[randi() % available.size()]

# Get trap data
func get_trap_data(category: TrapCategory, trap_name: String) -> Dictionary:
	return TRAP_TYPES.get(category, {}).get(trap_name, {})

# Available trap types per category
static func get_traps_for_category(category: TrapCategory) -> Array[String]:
	match category:
		TrapCategory.GROUND:
			return ["spike_trap", "fire_geyser"]
		TrapCategory.WALL:
			return ["arrow_shooter", "cannon_trap"]
		TrapCategory.CEILING:
			return ["pendulum_axe"]
		_:
			return [] 