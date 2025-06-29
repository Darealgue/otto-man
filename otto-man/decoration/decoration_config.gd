extends Resource
class_name DecorationConfig

# Dekorasyon türleri
enum DecorationType {
	GOLD,               # Altın objeler
	BACKGROUND,         # Arka plan süsleri (collision yok)
	PLATFORM,           # Platform objeler (collision var)
	BREAKABLE          # Kırılabilir objeler (altın drop)
}

# Spawn konumları
enum SpawnLocation {
	FLOOR_CENTER,       # Zeminin ortasında
	FLOOR_CORNER,       # Zeminin köşesinde
	WALL_LOW,           # Alçak duvarda
	WALL_HIGH,          # Yüksek duvarda
	CEILING,            # Tavanda/tavandan sallanan
	CORNER_HIGH,        # Yüksek köşede (örümcek ağı)
	CORNER_LOW         # Alçak köşede
}

# Altın türleri ve ağırlıkları
const GOLD_TYPES = {
	"single_coin": {
		"weight": 70,
		"gold_value": 5,
		"sprite": "res://assets/gold/single_coin.png"
	},
	"small_pile": {
		"weight": 20,
		"gold_value": 15,
		"sprite": "res://assets/gold/small_pile.png"
	},
	"large_pile": {
		"weight": 8,
		"gold_value": 30,
		"sprite": "res://assets/gold/large_pile.png"
	},
	"gold_pouch": {
		"weight": 2,
		"gold_value": 100,
		"sprite": "res://assets/gold/gold_pouch.png"
	}
}

# Arka plan dekorları
const BACKGROUND_DECORS = {
	"spider_web": {
		"weight": 30,
		"locations": [SpawnLocation.CORNER_HIGH, SpawnLocation.CEILING],
		"sprites": [
			"res://assets/decorations/spider_web_1.png",
			"res://assets/decorations/spider_web_2.png"
		]
	},
	"hanging_chains": {
		"weight": 25,
		"locations": [SpawnLocation.CEILING, SpawnLocation.WALL_HIGH],
		"sprites": [
			"res://assets/decorations/chain_1.png",
			"res://assets/decorations/chain_2.png"
		]
	},
	"moss_patch": {
		"weight": 20,
		"locations": [SpawnLocation.WALL_LOW, SpawnLocation.CORNER_LOW],
		"sprites": [
			"res://assets/decorations/moss_1.png",
			"res://assets/decorations/moss_2.png"
		]
	},
	"bone_pile": {
		"weight": 15,
		"locations": [SpawnLocation.FLOOR_CORNER],
		"sprites": [
			"res://assets/decorations/bones_1.png",
			"res://assets/decorations/bones_2.png"
		]
	},
	"wall_cracks": {
		"weight": 10,
		"locations": [SpawnLocation.WALL_LOW, SpawnLocation.WALL_HIGH],
		"sprites": [
			"res://assets/decorations/crack_1.png",
			"res://assets/decorations/crack_2.png"
		]
	}
}

# Platform dekorları
const PLATFORM_DECORS = {
	"large_pot": {
		"weight": 30,
		"locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
		"collision_size": Vector2(64, 96),
		"sprites": [
			"res://assets/decorations/large_pot_1.png",
			"res://assets/decorations/large_pot_2.png"
		]
	},
	"stone_block": {
		"weight": 25,
		"locations": [SpawnLocation.FLOOR_CENTER],
		"collision_size": Vector2(96, 64),
		"sprites": [
			"res://assets/decorations/stone_block_1.png",
			"res://assets/decorations/stone_block_2.png"
		]
	},
	"wooden_crate": {
		"weight": 20,
		"locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
		"collision_size": Vector2(64, 64),
		"sprites": [
			"res://assets/decorations/crate_1.png",
			"res://assets/decorations/crate_2.png"
		]
	},
	"ancient_pillar": {
		"weight": 15,
		"locations": [SpawnLocation.FLOOR_CENTER],
		"collision_size": Vector2(48, 128),
		"sprites": [
			"res://assets/decorations/pillar_1.png",
			"res://assets/decorations/pillar_2.png"
		]
	}
}

# Kırılabilir dekorlar
const BREAKABLE_DECORS = {
	"small_pot": {
		"weight": 40,
		"locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
		"collision_size": Vector2(32, 48),
		"hp": 1,
		"gold_drop": {"min": 1, "max": 3},
		"sprites": [
			"res://assets/decorations/small_pot_1.png",
			"res://assets/decorations/small_pot_2.png"
		],
		"break_effect": "res://effects/pot_break.tscn"
	},
	"wooden_barrel": {
		"weight": 30,
		"locations": [SpawnLocation.FLOOR_CENTER],
		"collision_size": Vector2(48, 64),
		"hp": 2,
		"gold_drop": {"min": 5, "max": 10},
		"sprites": [
			"res://assets/decorations/barrel_1.png",
			"res://assets/decorations/barrel_2.png"
		],
		"break_effect": "res://effects/barrel_break.tscn"
	},
	"treasure_chest": {
		"weight": 15,
		"locations": [SpawnLocation.FLOOR_CORNER],
		"collision_size": Vector2(64, 48),
		"hp": 3,
		"gold_drop": {"min": 20, "max": 50},
		"sprites": [
			"res://assets/decorations/chest_1.png"
		],
		"break_effect": "res://effects/chest_break.tscn"
	},
	"crystal_formation": {
		"weight": 10,
		"locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.WALL_LOW],
		"collision_size": Vector2(40, 60),
		"hp": 2,
		"gold_drop": {"min": 10, "max": 30},
		"sprites": [
			"res://assets/decorations/crystal_1.png",
			"res://assets/decorations/crystal_2.png"
		],
		"break_effect": "res://effects/crystal_break.tscn"
	}
}

# Chunk türüne göre dekorasyon yoğunluğu
const DECORATION_DENSITY = {
	"basic": {
		"gold_spawns": {"min": 2, "max": 4},
		"background_decorations": {"min": 3, "max": 6},
		"platform_decorations": {"min": 1, "max": 3},
		"breakable_decorations": {"min": 1, "max": 2}
	},
	"combat": {
		"gold_spawns": {"min": 3, "max": 5},
		"background_decorations": {"min": 4, "max": 8},
		"platform_decorations": {"min": 2, "max": 4},
		"breakable_decorations": {"min": 2, "max": 3}
	},
	"treasure": {
		"gold_spawns": {"min": 5, "max": 8},
		"background_decorations": {"min": 2, "max": 4},
		"platform_decorations": {"min": 1, "max": 2},
		"breakable_decorations": {"min": 3, "max": 5}
	}
}

# Dekorasyon türü için uygun objeler getir
func get_decorations_for_type(decoration_type: DecorationType) -> Dictionary:
	match decoration_type:
		DecorationType.GOLD:
			return GOLD_TYPES
		DecorationType.BACKGROUND:
			return BACKGROUND_DECORS
		DecorationType.PLATFORM:
			return PLATFORM_DECORS
		DecorationType.BREAKABLE:
			return BREAKABLE_DECORS
	return {}

# Belirli lokasyon için uygun dekorasyonları getir
func get_decorations_for_location(decoration_type: DecorationType, location: SpawnLocation) -> Array:
	var all_decorations = get_decorations_for_type(decoration_type)
	var suitable_decorations = []
	
	for decor_name in all_decorations:
		var decor_data = all_decorations[decor_name]
		if "locations" in decor_data and location in decor_data.locations:
			suitable_decorations.append(decor_name)
	
	return suitable_decorations

# Ağırlığa göre rasgele dekorasyon seç
func select_random_decoration(available_decorations: Array, decoration_type: DecorationType) -> String:
	if available_decorations.is_empty():
		return ""
	
	var all_decorations = get_decorations_for_type(decoration_type)
	var total_weight = 0
	
	# Toplam ağırlığı hesapla
	for decor_name in available_decorations:
		if decor_name in all_decorations:
			total_weight += all_decorations[decor_name].weight
	
	# Rasgele seçim
	var random_weight = randi() % total_weight
	var current_weight = 0
	
	for decor_name in available_decorations:
		if decor_name in all_decorations:
			current_weight += all_decorations[decor_name].weight
			if random_weight < current_weight:
				return decor_name
	
	return available_decorations[0]  # Fallback

# Chunk türü için dekorasyon yoğunluğu al
func get_decoration_density(chunk_type: String) -> Dictionary:
	return DECORATION_DENSITY.get(chunk_type, DECORATION_DENSITY["basic"]) 