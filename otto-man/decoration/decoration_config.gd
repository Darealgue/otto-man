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
		"sprites": ["res://assets/gold/single_coin.png"]
	},
	"small_pile": {
		"weight": 20,
		"gold_value": 15,
		"sprites": ["res://assets/gold/small_pile.png"]
	},
	"large_pile": {
		"weight": 8,
		"gold_value": 30,
		"sprites": ["res://assets/gold/large_pile.png"]
	},
	"gold_pouch": {
		"weight": 2,
		"gold_value": 100,
		"sprites": ["res://assets/gold/gold_pouch.png"]
	}
}

# Arka plan dekorları
const BACKGROUND_DECORS = {
    "spider_web": {
        "weight": 60,
        "locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER, SpawnLocation.WALL_LOW, SpawnLocation.WALL_HIGH, SpawnLocation.CEILING, SpawnLocation.CORNER_HIGH, SpawnLocation.CORNER_LOW],
        "sprites": [
            "res://assets/objects/dungeon/web1.png",
            "res://assets/objects/dungeon/web2.png"
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
			"res://assets/objects/dungeon/bone1.png",
			"res://assets/objects/dungeon/bone2.png"
        ]
    },
    "stone1": {
        "weight": 20,
        "locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
        "sprites": [
            "res://assets/objects/dungeon/stone1.png"
        ]
    },
    "box1": {
        "weight": 18,
        "locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
        "sprites": [
            "res://assets/objects/dungeon/box1.png"
        ]
    },
    "box2": {
        "weight": 10,
        "locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
        # 2x2 tile footprint, grows upward from floor
        "width_tiles": 2,
        "height_tiles": 2,
        "grow_dir": "up",
        "sprites": [
            "res://assets/objects/dungeon/box2.png"
        ]
    },
    "gate1": {
        "weight": 4,
        "locations": [SpawnLocation.FLOOR_CENTER],
		# 2x3 tile footprint, grows upward from floor
		"width_tiles": 2,
		"height_tiles": 3,
        "grow_dir": "up",
        "sprites": [
            "res://assets/objects/dungeon/gate1.png"
        ]
    },
    "gate2": {
        "weight": 3,
        "locations": [SpawnLocation.FLOOR_CENTER],
        # Same width as gate1, shorter height (2 tiles)
        "width_tiles": 2,
        "height_tiles": 2,
        "grow_dir": "up",
        "sprites": [
            "res://assets/objects/dungeon/gate2.png"
        ]
    },
    "pipe1": {
        "weight": 12,
        "locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
        # 1x1 tile
        "width_tiles": 1,
        "height_tiles": 1,
        "grow_dir": "up",
        "requires_background": true,
        "sprites": [
            "res://assets/objects/dungeon/pipe1.png"
        ]
    },
    "pipe2": {
        "weight": 10,
        "locations": [SpawnLocation.FLOOR_CENTER],
        # 1x5 tiles (vertical)
        "width_tiles": 1,
        "height_tiles": 5,
        "grow_dir": "up",
        "requires_background": true,
        "sprites": [
            "res://assets/objects/dungeon/pipe2.png"
        ]
    },
    "sculpture1": {
        "weight": 6,
        "locations": [SpawnLocation.FLOOR_CENTER],
        # 3x5 tiles, grows upward from floor
        "width_tiles": 3,
        "height_tiles": 5,
        "grow_dir": "up",
        "sprites": [
            "res://assets/objects/dungeon/sculpture1.png"
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

# ==============================================================================
# TILE-BASED DECORATION RULES
# ==============================================================================
# Bu kurallar, TileMap'teki custom data layer'larına göre çalışır.
# TileSet editöründe, 'decor_anchor' adında bir string custom data layer'ı oluşturun.
# Üzerine dekorasyon spawn olabilecek tile'lara (duvar, zemin vb.) bu layer'da
# aşağıdaki anahtarlarla eşleşen değerler atayın (örn: "wall_surface").

const TILE_DECOR_RULES = {
	"wall_surface": {
		"chance": 0.15, # Bu tile üzerinde dekorasyon spawn olma ihtimali
		"decoration_type": DecorationType.BACKGROUND, # Hangi dekor listesinden seçilecek
		"allowed_locations": [SpawnLocation.WALL_LOW, SpawnLocation.WALL_HIGH], # Hangi pozisyonlara spawn olabilir
		"allowed_decors": ["moss_patch", "wall_cracks", "hanging_chains", "spider_web"] # İzin verilen spesifik dekorlar
	},
	"floor_surface": {
		"chance": 0.05,
		"decoration_type": DecorationType.BACKGROUND,
		"allowed_locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
		"allowed_decors": ["bone_pile", "spider_web"]
	},
	"ceiling_surface": {
		"chance": 0.1,
		"decoration_type": DecorationType.BACKGROUND,
		"allowed_locations": [SpawnLocation.CEILING],
		"allowed_decors": ["hanging_chains", "spider_web"]
	},
	"floor_breakable": {
		"chance": 0.2,
		"decoration_type": DecorationType.BREAKABLE,
		"allowed_locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
		"allowed_decors": ["small_pot", "wooden_barrel"]
	}
}

# Tile'ın custom data'sına göre kuralı getirir
func get_rule_for_tile_data(custom_data: String) -> Dictionary:
	return TILE_DECOR_RULES.get(custom_data, {}) 

# ==============================================================================
# HİYERARŞİK (ÖNCELİKLİ) DEKORASYON KURALLARI
# ==============================================================================
# Tek bir tile etiketiyle (örn: 'floor') hem kırılabilir obje hem dekoratif obje spawn edilebilsin diye,
# önceliklendirilmiş bir kural listesi tanımlıyoruz. Kodda sırayla denenir, biri tutarsa diğerleri atlanır.

const PRIORITY_DECOR_RULES = {
    "floor_surface": [
        {
            "chance": 0.12,
            "decoration_type": DecorationType.BACKGROUND,
            "decoration_names": ["spider_web", "box2", "gate1", "gate2", "pipe1", "pipe2", "sculpture1"],
            "allowed_locations": [SpawnLocation.FLOOR_CENTER]
        },
		{
			"chance": 0.05, # %5
			"decoration_type": DecorationType.GOLD,
			"decoration_names": ["single_coin"]
		},
		{
			"chance": 0.05, # %5
			"decoration_type": DecorationType.BREAKABLE,
			"decoration_names": ["small_pot"]
		},
		{
			"chance": 0.05, # %5
            "decoration_type": DecorationType.BACKGROUND,
            "decoration_names": ["bone_pile"]
        },
    {
            "chance": 0.12,
            "decoration_type": DecorationType.BACKGROUND,
            "decoration_names": ["stone1", "box1"],
            "allowed_locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER]
        }
	],
    "floor": [
        {
            "chance": 0.04,
            "decoration_type": DecorationType.BACKGROUND,
            "decoration_names": ["spider_web", "box2", "gate2", "pipe1", "pipe2", "sculpture1"]
        },
		{
			"chance": 0.2, # %20 ihtimalle kırılabilir obje
			"decoration_type": DecorationType.BREAKABLE,
			"allowed_locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
			"allowed_decors": ["small_pot", "wooden_barrel"]
		},
		{
			"chance": 0.05, # %5 ihtimalle dekoratif obje (kemik yığını)
            "decoration_type": DecorationType.BACKGROUND,
            "allowed_locations": [SpawnLocation.FLOOR_CORNER],
            "allowed_decors": ["bone_pile"]
        },
        {
            "chance": 0.12,
            "decoration_type": DecorationType.BACKGROUND,
            "allowed_locations": [SpawnLocation.FLOOR_CENTER, SpawnLocation.FLOOR_CORNER],
            "allowed_decors": ["stone1", "box1"]
        }
	]
}

# Bir tile'ın custom data'sına göre öncelikli kural listesini getirir
func get_priority_rules_for_tile_data(custom_data: String) -> Array:
	return PRIORITY_DECOR_RULES.get(custom_data, []) 