class_name BuildingUpgradeConfig
extends RefCounted
## Bina yükseltme maliyetleri (SSOT). Seviye → maliyet sözlüğü.

const TIER1_WOOD := {
	2: {"gold": 20, "wood": 1},
	3: {"gold": 40, "wood": 2, "stone": 1},
	4: {"gold": 80, "wood": 3, "stone": 2},
}

const TIER1_STONE := {
	2: {"gold": 25, "stone": 1},
	3: {"gold": 50, "stone": 2, "wood": 1},
	4: {"gold": 100, "stone": 3, "wood": 2},
}

const TIER1_FOOD := {
	2: {"gold": 25, "food": 1},
	3: {"gold": 50, "food": 2, "wood": 1},
	4: {"gold": 75, "food": 3, "stone": 1},
}

const TIER1_WATER := {
	2: {"gold": 25, "water": 1, "stone": 1},
	3: {"gold": 50, "water": 2, "stone": 1},
	4: {"gold": 75, "water": 3, "stone": 2},
}

const TIER2_PROCESSING := {
	2: {"gold": 35, "wood": 2, "stone": 1},
	3: {"gold": 70, "wood": 2, "stone": 2, "lumber": 1},
}

const TIER3_CRAFT := {
	2: {"gold": 50, "lumber": 2, "brick": 1},
	3: {"gold": 95, "lumber": 3, "brick": 2},
}

const TIER4_MASTER := {
	2: {"gold": 85, "lumber": 2, "brick": 2, "stone": 1},
	3: {"gold": 150, "lumber": 3, "brick": 3, "metal": 1},
}

const TIER5_MILITARY := {
	2: {"gold": 130, "lumber": 3, "brick": 2, "metal": 2},
	3: {"gold": 200, "lumber": 4, "brick": 3, "metal": 3},
}

const BARRACKS := {
	2: {"gold": 100, "lumber": 3, "brick": 2, "metal": 1},
	3: {"gold": 180, "lumber": 4, "brick": 3, "metal": 2},
	4: {"gold": 260, "lumber": 5, "brick": 4, "metal": 3, "weapon": 1},
	5: {"gold": 350, "lumber": 6, "brick": 5, "metal": 4, "weapon": 2, "armor": 1},
}

const TIER2_STORAGE := {
	2: {"gold": 60, "wood": 2, "stone": 2},
	3: {"gold": 110, "wood": 3, "stone": 3, "lumber": 1},
}

const SCENE_LEVEL_COSTS: Dictionary = {
	"res://village/buildings/WoodcutterCamp.tscn": TIER1_WOOD,
	"res://village/buildings/StoneMine.tscn": TIER1_STONE,
	"res://village/buildings/HunterGathererHut.tscn": TIER1_FOOD,
	"res://village/buildings/Well.tscn": TIER1_WATER,
	"res://village/buildings/Sawmill.tscn": TIER2_PROCESSING,
	"res://village/buildings/Brickworks.tscn": TIER2_PROCESSING,
	"res://village/buildings/Bakery.tscn": TIER2_PROCESSING,
	"res://village/buildings/Weaver.tscn": TIER3_CRAFT,
	"res://village/buildings/Tailor.tscn": TIER3_CRAFT,
	"res://village/buildings/TeaHouse.tscn": TIER3_CRAFT,
	"res://village/buildings/SoapMaker.tscn": TIER3_CRAFT,
	"res://village/buildings/Blacksmith.tscn": TIER4_MASTER,
	"res://village/buildings/Herbalist.tscn": TIER4_MASTER,
	"res://village/buildings/Gunsmith.tscn": TIER5_MILITARY,
	"res://village/buildings/Armorer.tscn": TIER5_MILITARY,
	"res://village/buildings/Barracks.tscn": BARRACKS,
	"res://village/buildings/StorageBuilding.tscn": TIER2_STORAGE,
}


static func get_max_level(scene_path: String) -> int:
	var table: Dictionary = SCENE_LEVEL_COSTS.get(scene_path, {})
	if table.is_empty():
		return 1
	var best := 1
	for key in table.keys():
		best = maxi(best, int(key))
	return best


static func get_cost(scene_path: String, target_level: int) -> Dictionary:
	if target_level <= 1:
		return {}
	var table: Dictionary = SCENE_LEVEL_COSTS.get(scene_path, {})
	var raw: Variant = table.get(target_level, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}
