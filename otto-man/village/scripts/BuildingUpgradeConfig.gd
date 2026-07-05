class_name BuildingUpgradeConfig
extends RefCounted
## Bina yükseltme maliyetleri (SSOT). Seviye → maliyet sözlüğü.
## Katlanarak artan eğri: L2 taban, L3 ~×2.5, L4 ~×6 (gold + kaynak).

const GATHER_MAX_LEVEL := 8
## Kaynak binaları: 4 sprite (wood/stone/food 1..4), 2 oyun seviyesi = 1 görsel.
const GATHER_VISUAL_SPRITE_TIERS := 4

const TIER1_WOOD := {
	2: {"gold": 15, "wood": 1},
	3: {"gold": 40, "wood": 3, "stone": 1},
	4: {"gold": 100, "wood": 6, "stone": 3},
	5: {"gold": 200, "wood": 10, "stone": 5},
	6: {"gold": 350, "wood": 14, "stone": 8},
	7: {"gold": 550, "wood": 18, "stone": 10, "lumber": 2},
	8: {"gold": 800, "wood": 22, "stone": 12, "lumber": 4},
}

const TIER1_STONE := {
	2: {"gold": 15, "stone": 1},
	3: {"gold": 40, "stone": 3, "wood": 1},
	4: {"gold": 100, "stone": 6, "wood": 3},
	5: {"gold": 200, "stone": 10, "wood": 5},
	6: {"gold": 350, "stone": 14, "wood": 8},
	7: {"gold": 550, "stone": 18, "wood": 10, "brick": 2},
	8: {"gold": 800, "stone": 22, "wood": 12, "brick": 4},
}

const TIER1_FOOD := {
	2: {"gold": 15, "food": 1},
	3: {"gold": 40, "food": 3, "wood": 1},
	4: {"gold": 100, "food": 6, "stone": 2},
	5: {"gold": 200, "food": 10, "wood": 5},
	6: {"gold": 350, "food": 14, "wood": 8},
	7: {"gold": 550, "food": 18, "wood": 10, "stone": 4},
	8: {"gold": 800, "food": 22, "wood": 12, "stone": 6},
}

const TIER2_PROCESSING := {
	2: {"gold": 50, "wood": 2, "stone": 2},
	3: {"gold": 125, "wood": 5, "stone": 4, "lumber": 2},
}

const TIER3_CRAFT := {
	2: {"gold": 75, "lumber": 3, "brick": 2},
	3: {"gold": 175, "lumber": 6, "brick": 4},
}

const TIER4_MASTER := {
	2: {"gold": 120, "lumber": 4, "brick": 3, "stone": 2},
	3: {"gold": 280, "lumber": 8, "brick": 6, "metal": 2},
}

## Silahçı yükseltmesi: seviye 2 kereste+tuğla (2.sv silah), seviye 3 metal+kumaş (3.sv silah) tarifini açar.
const TIER5_MILITARY := {
	2: {"gold": 180, "lumber": 5, "brick": 4, "metal": 3},
	3: {"gold": 400, "lumber": 8, "brick": 6, "metal": 5},
}

## Kışla yükseltme maliyetleri artık üretilebilen silah seviyelerini talep eder (zırh kaldırıldı).
const BARRACKS := {
	2: {"gold": 150, "lumber": 4, "brick": 3, "metal": 2},
	3: {"gold": 320, "lumber": 6, "brick": 5, "metal": 4},
	4: {"gold": 600, "lumber": 8, "brick": 7, "metal": 6, "weapon_t1": 2},
	5: {"gold": 950, "lumber": 10, "brick": 9, "metal": 8, "weapon_t2": 2},
}

const TIER2_STORAGE := {
	2: {"gold": 55, "wood": 3, "stone": 3},
	3: {"gold": 130, "wood": 6, "stone": 5, "lumber": 2},
}

const SCENE_LEVEL_COSTS: Dictionary = {
	"res://village/buildings/WoodcutterCamp.tscn": TIER1_WOOD,
	"res://village/buildings/StoneMine.tscn": TIER1_STONE,
	"res://village/buildings/HunterGathererHut.tscn": TIER1_FOOD,
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


## Kaynak binaları: 1–2→görsel1, 3–4→2, 5–6→3, 7–8→4.
static func gather_visual_tier(level: int) -> int:
	return clampi((level + 1) / 2, 1, GATHER_MAX_LEVEL)


static func gather_sprite_path(sprite_prefix: String, level: int) -> String:
	var tier := gather_visual_tier(level)
	tier = mini(tier, GATHER_VISUAL_SPRITE_TIERS)
	return "res://village/buildings/sprite/%s%d.png" % [sprite_prefix, tier]
