class_name VillageVisitLayout
extends RefCounted
## Ziyaret edilen komşu köyün düzeni: yalnız veri üretir, sahne kurmaz (headless test edilebilsin diye).
## Girdi WorldManager.get_village_visit_info(); aynı köy ve aynı dünya tohumu her zaman aynı düzeni verir.
##
## Oyuncunun kendi köyü gibi kurulur: aynı 22 inşa parseli (400 px arayla), gerçek köy binaları
## (res://village/buildings/*) ve aynı ev katı kuralları (kat başına 4 kişi, en çok 4 kat, dükkân
## üstüne ev katı eklenebilir). Binaların sayısı, kat sayısı ve seviyesi köyün nüfusuna ve
## zenginliğine; hangi dükkânların olduğu köyün kişiliğine göre belirlenir.
## Sahneyi VillageVisitScene.gd bu veriden kurar (bkz. VillageVisitBuildings.gd). Kurallar: docs/VILLAGE_VISIT_PLAN.md.

const PLOT_SPACING: float = 400.0
const MAX_PLOTS: int = 22
const END_MARGIN: float = 900.0
const MIN_HALF_WIDTH: float = 2600.0
const EXIT_INSET: float = 300.0
const CAPACITY_PER_FLOOR: int = 4
const MAX_FLOORS: int = 4
const MIN_HOUSES: int = 2
const MIN_SHOPS: int = 4
const MAX_SHOPS: int = 10
const POP_PER_SHOP: float = 14.0

const STORAGE_SCENE := "res://village/buildings/StorageBuilding.tscn"
const HOUSE_SCENE_PATH := "res://village/buildings/House.tscn"
## Kaynak toplama binaları: sprite öneki seviyeye göre görseli belirler (BuildingUpgradeConfig.gather_sprite_path).
const GATHER_BUILDINGS: Array[Dictionary] = [
	{"scene": "res://village/buildings/WoodcutterCamp.tscn", "prefix": "wood"},
	{"scene": "res://village/buildings/StoneMine.tscn", "prefix": "stone"},
	{"scene": "res://village/buildings/HunterGathererHut.tscn", "prefix": "food"},
]
## Atölye / dükkânlar ve taban ağırlıkları (kişilik ağırlıkları bunun üstüne çarpılır).
const WORKSHOPS: Dictionary = {
	"res://village/buildings/Sawmill.tscn": 1.0,
	"res://village/buildings/Brickworks.tscn": 1.0,
	"res://village/buildings/Bakery.tscn": 1.4,
	"res://village/buildings/Weaver.tscn": 1.0,
	"res://village/buildings/Tailor.tscn": 1.0,
	"res://village/buildings/Blacksmith.tscn": 1.0,
	"res://village/buildings/Gunsmith.tscn": 0.6,
	"res://village/buildings/Herbalist.tscn": 0.8,
	"res://village/buildings/TeaHouse.tscn": 1.0,
	"res://village/buildings/SoapMaker.tscn": 0.8,
	"res://village/buildings/Barracks.tscn": 0.7,
}
const PERSONALITY_BIAS: Dictionary = {
	"warrior": {"res://village/buildings/Barracks.tscn": 3.0, "res://village/buildings/Blacksmith.tscn": 2.5, "res://village/buildings/Gunsmith.tscn": 3.0},
	"merchant": {"res://village/buildings/TeaHouse.tscn": 2.5, "res://village/buildings/Tailor.tscn": 2.5, "res://village/buildings/Weaver.tscn": 2.0, "res://village/buildings/SoapMaker.tscn": 2.5},
	"cautious": {"res://village/buildings/Barracks.tscn": 1.8, "res://village/buildings/Herbalist.tscn": 1.8},
	"ambitious": {"res://village/buildings/Blacksmith.tscn": 2.0, "res://village/buildings/Gunsmith.tscn": 2.0, "res://village/buildings/Brickworks.tscn": 2.0},
	"devout": {"res://village/buildings/Herbalist.tscn": 3.0, "res://village/buildings/TeaHouse.tscn": 2.0},
}
## Üstüne ev katı eklenebilen binalar (VillageManager._can_build_residential_on: kaynak kategorisi).
const EXTENDABLE: Array[String] = [
	"res://village/buildings/WoodcutterCamp.tscn", "res://village/buildings/StoneMine.tscn",
	"res://village/buildings/HunterGathererHut.tscn", "res://village/buildings/Sawmill.tscn",
	"res://village/buildings/Brickworks.tscn", "res://village/buildings/Bakery.tscn",
	"res://village/buildings/Weaver.tscn", "res://village/buildings/Tailor.tscn",
	"res://village/buildings/Blacksmith.tscn", "res://village/buildings/Gunsmith.tscn",
	"res://village/buildings/Herbalist.tscn", "res://village/buildings/TeaHouse.tscn",
	"res://village/buildings/SoapMaker.tscn",
]

## Arka plan setleri. Şimdilik tek set var ("green"); kullanıcı yeni set çizdikçe buraya eklenir
## (kıyı olmayan çimen, dağ köyü, orman köyü gibi) ve köy arazisine göre seçilir.
const BACKGROUND_SETS: Array[String] = ["green"]

## Gece 20:00 - 05:00 arası.
const NIGHT_START_HOUR: float = 20.0
const NIGHT_END_HOUR: float = 5.0
## Düşman köyde gündüz nöbetçilerin görüş konisi gecekinden bu kadar kat geniştir.
const HOSTILE_DAY_VISION_MULT: float = 2.4


static func is_night(hour: float) -> bool:
	return hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR


## Ziyaret kipi: "free" (dost köy, gündüz: gizlilik yok), "night_stealth" (dost köy, gece),
## "hostile_day" (düşman köy, gündüz: çok geniş görüş), "hostile_night" (düşman köy, gece).
static func visit_mode(hostile: bool, hour: float, infiltrate: bool = false) -> String:
	var night: bool = is_night(hour)
	if hostile:
		return "hostile_night" if night else "hostile_day"
	if night:
		return "night_stealth"
	# Sızma: dost köyde gündüz bile nöbetçiler uyanık ("infiltrate"); haritadan "Sız" seçilince.
	return "infiltrate" if infiltrate else "free"


static func stealth_required(mode: String) -> bool:
	return mode != "free"


## Nöbetçi görüş konisi çarpanı: gece 1, düşman köyde gündüz çok daha geniş, dost köyde gündüz yok (0).
static func vision_multiplier(mode: String) -> float:
	match mode:
		"hostile_day":
			return HOSTILE_DAY_VISION_MULT
		"hostile_night", "night_stealth", "infiltrate":
			return 1.0
	return 0.0


## Her konut katına (ev katları ve dükkân üstü ev katları) nüfusa dayalı yaşayan sayısı dağıtır: "residents" alanı.
## Düzen kat başına 4 kişilik kapasiteyi nüfusa göre kurduğu için doluluk nüfusla paralel gider: her konutun doluluk
## oranı rastgele (köyün genel doluluğu ~%80), bazı evler tamamen boş. Ayrı bir tohum kullanır, düzenin geri kalanını değiştirmez.
const FILL_MIN: float = 0.75
const FILL_MAX: float = 1.0
const EMPTY_HOUSE_CHANCE: float = 0.06

static func _assign_residents(buildings: Array[Dictionary], info: Dictionary, pop: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s#residents#%d" % [String(info.get("settlement_id", "")), int(info.get("world_seed", 0))]))
	for b in buildings:
		var floors: int = int(b.get("floors", 0)) + int(b.get("ext_floors", 0))
		var capacity: int = floors * CAPACITY_PER_FLOOR
		var residents: int = 0
		if capacity > 0 and not (String(b["kind"]) == "house" and rng.randf() < EMPTY_HOUSE_CHANCE):
			residents = clampi(int(round(float(capacity) * rng.randf_range(FILL_MIN, FILL_MAX))), 1, capacity)
		b["residents"] = residents


## Oyuncu köyündeki parsel konumları (x): 400, -400, 800, -800, ... 22 adet.
static func plot_positions() -> Array[float]:
	var out: Array[float] = []
	for i in range(1, (MAX_PLOTS >> 1) + 1):
		out.append(PLOT_SPACING * float(i))
		out.append(-PLOT_SPACING * float(i))
	return out


## Köy nüfusunun ev katı ihtiyacı (kat başına 4 kişi).
static func floors_needed(population: int) -> int:
	return int(ceil(float(maxi(population, 1)) / float(CAPACITY_PER_FLOOR)))


static func generate(info: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("%s#visit#%d" % [String(info.get("settlement_id", "")), int(info.get("world_seed", 0))]))
	var pop: int = maxi(20, int(info.get("population", 80)))
	var wealth: String = String(info.get("wealth_tier", "medium"))
	var wealth_bonus: int = 0 if wealth == "poor" else (1 if wealth == "medium" else 2)
	var personality: String = String(info.get("personality", "cautious"))

	# 1) Dükkânlar: depo her zaman, sonra kaynak binaları (odun, taş, yiyecek), kalanı kişilik ağırlıklı atölyeler.
	var shop_count: int = clampi(int(round(float(pop) / POP_PER_SHOP)), MIN_SHOPS, MAX_SHOPS)
	var works: Array[Dictionary] = []
	works.append({"scene": STORAGE_SCENE, "kind": "work", "level": 1, "prefix": "", "role": "storage"})
	var gather_n: int = mini(GATHER_BUILDINGS.size(), shop_count - 1)
	for i in range(gather_n):
		var g: Dictionary = GATHER_BUILDINGS[i]
		var level: int = clampi(1 + int(float(pop) / 35.0) + wealth_bonus + rng.randi_range(0, 2), 1, 8)
		works.append({"scene": String(g["scene"]), "kind": "work", "level": level, "prefix": String(g["prefix"]), "role": "house"})
	var pool: Dictionary = WORKSHOPS.duplicate()
	var bias: Dictionary = PERSONALITY_BIAS.get(personality, {})
	for sp in bias.keys():
		if pool.has(sp):
			pool[sp] = float(pool[sp]) * float(bias[sp])
	while works.size() < shop_count and not pool.is_empty():
		var pick: String = _pick_weighted(rng, pool)
		pool.erase(pick)
		var max_lv: int = BuildingUpgradeConfig.get_max_level(pick)
		var lv: int = clampi(1 + int(float(pop) / 80.0) + (1 if wealth == "rich" else 0) + rng.randi_range(0, 1), 1, max_lv)
		works.append({"scene": pick, "kind": "work", "level": lv, "prefix": "", "role": "house"})

	# 2) Evler: nüfusun ihtiyacı kadar kat, parsellere sığacak kadar ev; sığmayan katlar dükkân üstüne eklenir.
	var need_floors: int = floors_needed(pop)
	var house_count: int = clampi(int(ceil(float(need_floors) / 3.0)), MIN_HOUSES, MAX_PLOTS - works.size())
	var floors_per_house: Array[int] = []
	var remaining: int = need_floors
	for h in range(house_count):
		var f: int = clampi(int(floor(float(remaining) / float(house_count - h))), 1, MAX_FLOORS)
		floors_per_house.append(f)
		remaining -= f
	# Artan katları kapasitesi dolmamış evlere dağıt, kalanı dükkân üstüne ekle.
	var guard: int = 0
	while remaining > 0 and guard < 200:
		guard += 1
		var h2: int = rng.randi_range(0, house_count - 1)
		if floors_per_house[h2] < MAX_FLOORS:
			floors_per_house[h2] += 1
			remaining -= 1
		elif floors_per_house.all(func(v): return v >= MAX_FLOORS):
			break
	var extendable_idx: Array[int] = []
	for i in range(works.size()):
		if EXTENDABLE.has(String(works[i]["scene"])):
			extendable_idx.append(i)
	guard = 0
	while remaining > 0 and not extendable_idx.is_empty() and guard < 200:
		guard += 1
		var wi: int = extendable_idx[rng.randi_range(0, extendable_idx.size() - 1)]
		var cur: int = int(works[wi].get("ext_floors", 0))
		if cur < MAX_FLOORS:
			works[wi]["ext_floors"] = cur + 1
			remaining -= 1

	# 3) Parsellere yerleştir: en yakın N parsel, sıra rastgele karıştırılır.
	var all_buildings: Array[Dictionary] = []
	for w in works:
		all_buildings.append(w)
	for f2 in floors_per_house:
		all_buildings.append({"scene": HOUSE_SCENE_PATH, "kind": "house", "floors": f2, "level": 1, "prefix": "", "role": "house"})
	var plots: Array[float] = plot_positions()
	plots.sort_custom(func(a, b): return absf(a) < absf(b) or (absf(a) == absf(b) and a > b))
	var used: Array[float] = []
	for i in range(mini(all_buildings.size(), plots.size())):
		used.append(plots[i])
	for i in range(all_buildings.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = all_buildings[i]
		all_buildings[i] = all_buildings[j]
		all_buildings[j] = tmp
	var buildings: Array[Dictionary] = []
	for i in range(used.size()):
		var b: Dictionary = all_buildings[i]
		b["x"] = used[i]
		buildings.append(b)
	buildings.sort_custom(func(a, b): return float(a["x"]) < float(b["x"]))
	_assign_residents(buildings, info, pop)

	# 4) Roller: hazine odası rastgele bir bina (depo olmayan); esir varsa zindan başka bir ev.
	var candidates: Array[int] = []
	var storage_index: int = -1
	for i in range(buildings.size()):
		if String(buildings[i]["role"]) == "storage":
			storage_index = i
		else:
			candidates.append(i)
	for i in range(candidates.size() - 1, 0, -1):
		var j2: int = rng.randi_range(0, i)
		var t2: int = candidates[i]
		candidates[i] = candidates[j2]
		candidates[j2] = t2
	var treasure_index: int = candidates[0] if not candidates.is_empty() else 0
	buildings[treasure_index]["role"] = "treasure"
	var prisoners: int = int(info.get("prisoners", 0))
	var prison_index: int = -1
	if prisoners > 0:
		for ci in candidates:
			if ci != treasure_index and String(buildings[ci]["kind"]) == "house":
				prison_index = ci
				break
		if prison_index < 0 and candidates.size() > 1:
			prison_index = candidates[1]
		if prison_index >= 0:
			buildings[prison_index]["role"] = "prison"

	var max_abs_x: float = 0.0
	for b in buildings:
		max_abs_x = maxf(max_abs_x, absf(float(b["x"])))
	var half_width: float = maxf(MIN_HALF_WIDTH, max_abs_x + END_MARGIN)
	var exit_x: float = half_width - EXIT_INSET

	# Arka plan serpiştirme: çalı, ağaç, çimen tutamı. Sokak boyunca, binaların arkasında.
	var decor: Array[Dictionary] = []
	var decor_count: int = int(half_width / 140.0)
	for _i in range(decor_count):
		var kind_roll: float = rng.randf()
		var kind: String = "bush" if kind_roll < 0.55 else ("grass" if kind_roll < 0.85 else "tree")
		decor.append({
			"kind": kind,
			"x": rng.randf_range(-half_width + 200.0, half_width - 200.0),
			"variant": rng.randi_range(0, 4),
			"behind": rng.randf() < 0.65,
		})

	# Köylüler: sahnede görünen kişi sayısı nüfustan; her birinin evi ve (çoğunun) işyeri var.
	var house_indices: Array[int] = []
	var work_indices: Array[int] = []
	for i in range(buildings.size()):
		if String(buildings[i]["kind"]) == "house" and int(buildings[i].get("residents", 1)) > 0:
			house_indices.append(i)
		elif String(buildings[i]["role"]) != "storage":
			work_indices.append(i)
	var villager_count: int = clampi(int(round(float(pop) / 7.0)), 5, 16)
	var villagers: Array[Dictionary] = []
	for _v in range(villager_count):
		var home_idx: int = -1
		if not house_indices.is_empty():
			home_idx = house_indices[rng.randi_range(0, house_indices.size() - 1)]
		var work_idx: int = -1
		if not work_indices.is_empty() and rng.randf() < 0.7:
			work_idx = work_indices[rng.randi_range(0, work_indices.size() - 1)]
		villagers.append({
			"home": home_idx,
			"work": work_idx,
			"shift_shift": rng.randf_range(-0.6, 0.6),
			"female": rng.randf() < 0.45,
		})

	var soldiers: int = int(info.get("soldiers", 10))
	return {
		"half_width": half_width,
		"exit_x": exit_x,
		"buildings": buildings,
		"treasure_index": treasure_index,
		"storage_index": storage_index,
		"prison_index": prison_index,
		"decor": decor,
		"villagers": villagers,
		"coastal": bool(info.get("coastal", false)),
		"background_set": BACKGROUND_SETS[rng.randi() % BACKGROUND_SETS.size()],
		"guard_count": clampi(int(round(float(soldiers) / 4.0)), 2, 12),
		"prisoners": prisoners,
		"floors_needed": need_floors,
	}


static func _pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: float = 0.0
	for k in weights.keys():
		total += float(weights[k])
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	var last: String = ""
	for k in weights.keys():
		acc += float(weights[k])
		last = String(k)
		if roll < acc:
			return last
	return last
