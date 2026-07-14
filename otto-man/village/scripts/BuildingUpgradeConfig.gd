class_name BuildingUpgradeConfig
extends RefCounted
## Bina yükseltme maliyetleri (SSOT). Her kaynak, ilk istendiği seviyeden ("from") itibaren
## GROWTH_MULTIPLIER ile katlanarak (compounding) artar — mobil oyunlardaki gibi her
## yükseltme bir öncekinden belirgin şekilde daha pahalı olsun, oyuncu tek seferde büyük
## atılım yapamasın diye. Hem altın hem hammadde bu formülle hesaplanır.

const GATHER_MAX_LEVEL := 8
## Kaynak binaları: 4 sprite (wood/stone/food 1..4), 2 oyun seviyesi = 1 görsel.
const GATHER_VISUAL_SPRITE_TIERS := 4

## Her seviyede maliyetin çarpıldığı sabit oran.
const GROWTH_MULTIPLIER := 1.85

## {resource_key: {"base": taban_miktar, "from": ilk_istenen_seviye}}
## target_level >= from ise: miktar = base * GROWTH_MULTIPLIER ^ (target_level - from)
const TIER1_WOOD := {
	"gold": {"base": 15, "from": 2},
	"wood": {"base": 1, "from": 2},
	"stone": {"base": 1, "from": 3},
	"lumber": {"base": 2, "from": 7},
}
const TIER1_WOOD_MAX_LEVEL := 8

const TIER1_STONE := {
	"gold": {"base": 15, "from": 2},
	"stone": {"base": 1, "from": 2},
	"wood": {"base": 1, "from": 3},
	"brick": {"base": 2, "from": 7},
}
const TIER1_STONE_MAX_LEVEL := 8

const TIER1_FOOD := {
	"gold": {"base": 15, "from": 2},
	"food": {"base": 1, "from": 2},
	"wood": {"base": 1, "from": 3},
	"stone": {"base": 2, "from": 4},
}
const TIER1_FOOD_MAX_LEVEL := 8

const TIER2_PROCESSING := {
	"gold": {"base": 50, "from": 2},
	"wood": {"base": 2, "from": 2},
	"stone": {"base": 2, "from": 2},
	"lumber": {"base": 2, "from": 3},
}
const TIER2_PROCESSING_MAX_LEVEL := 3

const TIER3_CRAFT := {
	"gold": {"base": 75, "from": 2},
	"lumber": {"base": 3, "from": 2},
	"brick": {"base": 2, "from": 2},
}
const TIER3_CRAFT_MAX_LEVEL := 3

const TIER4_MASTER := {
	"gold": {"base": 120, "from": 2},
	"lumber": {"base": 4, "from": 2},
	"brick": {"base": 3, "from": 2},
	"stone": {"base": 2, "from": 2},
	"metal": {"base": 2, "from": 3},
}
const TIER4_MASTER_MAX_LEVEL := 3

## Silahçı yükseltmesi: seviye 2 kereste+tuğla (2.sv silah), seviye 3 metal+kumaş (3.sv silah) tarifini açar.
const TIER5_MILITARY := {
	"gold": {"base": 180, "from": 2},
	"lumber": {"base": 5, "from": 2},
	"brick": {"base": 4, "from": 2},
	"metal": {"base": 3, "from": 2},
}
const TIER5_MILITARY_MAX_LEVEL := 3

## Kışla yükseltme maliyetleri artık üretilebilen silah seviyelerini talep eder (zırh kaldırıldı).
## weapon_t1/weapon_t2 üretilmiş eşya kilidi olduğu için (ham madde değil) katlanarak büyümez,
## sadece kendi seviyesinde sabit bir miktar ister.
const BARRACKS := {
	"gold": {"base": 150, "from": 2},
	"lumber": {"base": 4, "from": 2},
	"brick": {"base": 3, "from": 2},
	"metal": {"base": 2, "from": 2},
	"weapon_t1": {"base": 2, "from": 4},
	"weapon_t2": {"base": 2, "from": 5},
}
const BARRACKS_MAX_LEVEL := 5

const TIER2_STORAGE := {
	"gold": {"base": 55, "from": 2},
	"wood": {"base": 3, "from": 2},
	"stone": {"base": 3, "from": 2},
	"lumber": {"base": 2, "from": 3},
}
const TIER2_STORAGE_MAX_LEVEL := 3

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

const SCENE_MAX_LEVELS: Dictionary = {
	"res://village/buildings/WoodcutterCamp.tscn": TIER1_WOOD_MAX_LEVEL,
	"res://village/buildings/StoneMine.tscn": TIER1_STONE_MAX_LEVEL,
	"res://village/buildings/HunterGathererHut.tscn": TIER1_FOOD_MAX_LEVEL,
	"res://village/buildings/Sawmill.tscn": TIER2_PROCESSING_MAX_LEVEL,
	"res://village/buildings/Brickworks.tscn": TIER2_PROCESSING_MAX_LEVEL,
	"res://village/buildings/Bakery.tscn": TIER2_PROCESSING_MAX_LEVEL,
	"res://village/buildings/Weaver.tscn": TIER3_CRAFT_MAX_LEVEL,
	"res://village/buildings/Tailor.tscn": TIER3_CRAFT_MAX_LEVEL,
	"res://village/buildings/TeaHouse.tscn": TIER3_CRAFT_MAX_LEVEL,
	"res://village/buildings/SoapMaker.tscn": TIER3_CRAFT_MAX_LEVEL,
	"res://village/buildings/Blacksmith.tscn": TIER4_MASTER_MAX_LEVEL,
	"res://village/buildings/Herbalist.tscn": TIER4_MASTER_MAX_LEVEL,
	"res://village/buildings/Gunsmith.tscn": TIER5_MILITARY_MAX_LEVEL,
	"res://village/buildings/Barracks.tscn": BARRACKS_MAX_LEVEL,
	"res://village/buildings/StorageBuilding.tscn": TIER2_STORAGE_MAX_LEVEL,
}


static func get_max_level(scene_path: String) -> int:
	return int(SCENE_MAX_LEVELS.get(scene_path, 1))


static func get_cost(scene_path: String, target_level: int) -> Dictionary:
	if target_level <= 1:
		return {}
	var table: Dictionary = SCENE_LEVEL_COSTS.get(scene_path, {})
	if table.is_empty():
		return {}
	var result: Dictionary = {}
	for resource_key in table.keys():
		var entry: Dictionary = table[resource_key]
		var from_level: int = int(entry.get("from", 2))
		if target_level < from_level:
			continue
		var base_amount: float = float(entry.get("base", 0))
		var value: float = base_amount * pow(GROWTH_MULTIPLIER, target_level - from_level)
		var rounded: int
		if resource_key == "gold":
			rounded = maxi(5, int(round(value / 5.0)) * 5) # 5'in katına yuvarla, daha okunaklı
		else:
			rounded = maxi(1, int(round(value)))
		result[resource_key] = rounded
	return result


## Kaynak binaları: 1–2→görsel1, 3–4→2, 5–6→3, 7–8→4.
static func gather_visual_tier(level: int) -> int:
	return clampi((level + 1) / 2, 1, GATHER_MAX_LEVEL)


static func gather_sprite_path(sprite_prefix: String, level: int) -> String:
	var tier := gather_visual_tier(level)
	tier = mini(tier, GATHER_VISUAL_SPRITE_TIERS)
	return "res://village/buildings/sprite/%s%d.png" % [sprite_prefix, tier]
