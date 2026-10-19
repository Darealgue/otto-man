class_name VillageVisitBuildings
extends RefCounted
## Ziyaret köyünün binalarını oyuncu köyündeki GERÇEK bina sahnelerinden (res://village/buildings/*) kurar,
## ama köy ekonomisinden ayrı: bina betikleri (üretim, işçi, VillageManager kaydı) kaldırılır, gruplardan
## çıkarılır; geriye yalnız görsel ve çatı/kat platformları kalır. Böylece komşu köy senin köyün gibi
## görünür ama senin üretimine karışmaz.
## Ev: HouseFloorGround/Upper katları (kat yüksekliği 123 px). Kaynak binaları: seviyeye göre sprite ve
## çatı çarpışması (WoodcutterCamp / StoneMine / HunterGathererHut betiklerindeki kuralların aynısı).
## Dükkân üstüne ev katı: VillageManager'daki ResidentialHousingExtension kalıbı.

const FLOOR_HEIGHT: float = 123.0
const EXTENSION_OVERLAP_PX: float = 10.0
const GROUND_FLOOR_SCENE := "res://village/buildings/HouseFloorGround.tscn"
const UPPER_FLOOR_SCENE := "res://village/buildings/HouseFloorUpper.tscn"
const EXTENSION_NODE := "ResidentialHousingExtension"
const PLATFORM_LAYER: int = 512  # CollisionLayers.PLATFORM (layer 10)
const NIGHT_LIT_FLOOR_MIN_OCCUPANTS: int = 1

## Seviyeden görsel kademe -> açık olacak çatı çarpışmaları (kaynak betiklerindeki COLLISION_BY_VISUAL_TIER).
const COLLISION_BY_TIER: Dictionary = {
	"wood": {1: ["CollisionLevel1"], 2: ["CollisionLevel2"], 3: ["CollisionLevel2", "CollisionLevel3"], 4: ["CollisionLevel2", "CollisionLevel3"]},
	"stone": {1: ["CollisionLevel1"], 2: ["CollisionLevel1"], 3: ["CollisionLevel1"], 4: ["CollisionLevel1"]},
	"food": {1: ["CollisionLevel1"], 2: ["CollisionLevel2"], 3: ["CollisionLevel2", "CollisionLevel3"], 4: ["CollisionLevel2", "CollisionLevel4"]},
}


## Tanım (VillageVisitLayout.buildings girdisi) -> sahneye eklenmeye hazır, betiksiz bina düğümü.
static func build(def: Dictionary) -> Node2D:
	if String(def.get("kind", "work")) == "house":
		return _build_house(int(def.get("floors", 1)))
	return _build_work(def)


static func _build_house(floors: int) -> Node2D:
	var root := Node2D.new()
	root.name = "House"
	root.add_to_group("visit_house")
	var container := Node2D.new()
	container.name = "FloorsContainer"
	root.add_child(container)
	_add_floors(container, floors, false)
	return root


## Katları üst üste dizer; is_extension true ise hepsi pencereli üst kat sprite'ıdır (zemin kat dükkânın kendisi).
static func _add_floors(container: Node2D, floors: int, is_extension: bool) -> void:
	var ground: PackedScene = load(GROUND_FLOOR_SCENE) as PackedScene
	var upper: PackedScene = load(UPPER_FLOOR_SCENE) as PackedScene
	var list: Array = container.get_meta("floor_nodes", [])
	for i in range(floors):
		var use_ground: bool = i == 0 and not is_extension
		var scene: PackedScene = ground if use_ground else upper
		if scene == null:
			break
		var inst: Node2D = scene.instantiate()
		inst.position = Vector2(0.0, -FLOOR_HEIGHT * float(i))
		container.add_child(inst)
		list.append(inst)
	container.set_meta("floor_nodes", list)


static func _build_work(def: Dictionary) -> Node2D:
	var packed: PackedScene = load(String(def.get("scene", ""))) as PackedScene
	if packed == null:
		return null
	var node: Node2D = packed.instantiate() as Node2D
	if node == null:
		return null
	# Ekonomiye bağlı kök betik kalkar (ağaca girmeden önce), WorkBuildings / Housing gruplarından çıkar:
	# VillageManager bu grupları tarayıp binayı kendi köyüne sayardı.
	node.set_script(null)
	for g in node.get_groups():
		node.remove_from_group(g)
	node.add_to_group("visit_building")
	var prefix: String = String(def.get("prefix", ""))
	if not prefix.is_empty():
		_apply_gather_level(node, prefix, int(def.get("level", 1)))
	var ext: int = int(def.get("ext_floors", 0))
	if ext > 0:
		_add_extension(node, ext)
	return node


## Kaynak binası görseli: seviyeye göre sprite, alt kenar zemine hizalı, uygun çatı çarpışması açık.
static func _apply_gather_level(node: Node2D, prefix: String, level: int) -> void:
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		var path: String = BuildingUpgradeConfig.gather_sprite_path(prefix, level)
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			sprite.texture = tex
			sprite.scale = Vector2.ONE
			sprite.offset = Vector2(0.0, -float(tex.get_height()) / 2.0)
	var body: StaticBody2D = node.get_node_or_null("StaticBody2D") as StaticBody2D
	if body == null:
		return
	body.collision_layer = PLATFORM_LAYER
	body.collision_mask = 0
	var offset_y: float = sprite.offset.y if sprite != null and sprite.texture != null else 0.0
	var tier: int = mini(BuildingUpgradeConfig.gather_visual_tier(level), 4)
	var enabled: Array = (COLLISION_BY_TIER.get(prefix, COLLISION_BY_TIER["wood"]) as Dictionary).get(tier, ["CollisionLevel1"])
	for child in body.get_children():
		if child is CollisionShape2D and String(child.name).begins_with("CollisionLevel"):
			var col: CollisionShape2D = child as CollisionShape2D
			col.position += Vector2(0.0, offset_y)
			col.one_way_collision = true
			col.one_way_collision_margin = 12.0
			col.disabled = not enabled.has(String(col.name))


## Dükkân üstüne ev katı: House sahnesi yerine yalnız görsel katlar (VillageManager kalıbıyla aynı konum).
static func _add_extension(node: Node2D, floors: int) -> void:
	var ext := Node2D.new()
	ext.name = EXTENSION_NODE
	ext.position = Vector2(0.0, _residential_y_offset(node))
	ext.add_to_group("visit_house")
	node.add_child(ext)
	var container := Node2D.new()
	container.name = "FloorsContainer"
	ext.add_child(container)
	_add_floors(container, mini(floors, 4), true)


## VillageManager._get_building_residential_y_offset ile aynı kural.
static func _residential_y_offset(building: Node2D) -> float:
	if building.get_node_or_null("FloorPlatform/TopCollision") != null:
		return -FLOOR_HEIGHT
	var best_top: float = INF
	for child in building.get_children():
		if child is Sprite2D:
			var spr: Sprite2D = child as Sprite2D
			if spr.texture == null:
				continue
			var tex_h: float = float(spr.texture.get_height()) * absf(spr.scale.y)
			var top_y: float = spr.position.y - tex_h / 2.0
			if top_y < best_top:
				best_top = top_y
	if best_top < INF:
		return best_top + EXTENSION_OVERLAP_PX
	return -100.0


## Binanın en yüksek yürünebilir çatı / kat noktası (bina düğümüne göre yerel koordinat): açık çarpışma
## segmentlerinin en yüksekte olanının orta noktası. Hazine kapağı gibi çatı hedefleri için.
static func roof_point(building: Node2D) -> Vector2:
	var best: Vector2 = Vector2(0.0, 0.0)
	var best_y: float = INF
	var stack: Array[Node] = [building]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is CollisionShape2D and not (n as CollisionShape2D).disabled and (n as CollisionShape2D).shape is SegmentShape2D:
			var col: CollisionShape2D = n as CollisionShape2D
			var seg: SegmentShape2D = col.shape as SegmentShape2D
			var mid_local: Vector2 = (seg.a + seg.b) * 0.5
			var in_building: Vector2 = building.to_local(col.to_global(mid_local)) if building.is_inside_tree() else _accumulate_local(col, building) + mid_local
			if in_building.y < best_y:
				best_y = in_building.y
				best = in_building
	if best_y == INF:
		return Vector2(0.0, -128.0)
	return best


## Ağaçta değilken (transform global değil) kolondan binaya kadar konumları toplar.
static func _accumulate_local(node: Node2D, root: Node2D) -> Vector2:
	var p: Vector2 = Vector2.ZERO
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node2D:
			p += (cur as Node2D).position
		cur = cur.get_parent()
	return p


## Tüm ev katlarını (evlerdeki ve dükkân üstündekiler) sırayla döndürür: Array[Node2D] (HouseFloorVisual).
static func floor_nodes(building: Node2D) -> Array:
	var out: Array = []
	for container_path in ["FloorsContainer", "%s/FloorsContainer" % EXTENSION_NODE]:
		var c: Node = building.get_node_or_null(container_path)
		if c != null:
			for f in c.get_meta("floor_nodes", []):
				if is_instance_valid(f):
					out.append(f)
	return out


## Pencereleri evde YAŞAYAN kişi sayısına göre güncelle; oyuncu köyündeki House.gd kuralının aynısı: bir katın kapasitesi
## pencerelere bölünür (kat başı 4 kişi, 2 pencere = pencere başı 2 kişi), pencerede 1 kişi yaşıyorsa yarı açık,
## 2 kişi yaşıyorsa tam açık, kimse yoksa kapalı. Köylünün o an dışarıda olması pencereyi kapatmaz.
const CAPACITY_PER_FLOOR: int = 4  # ResidentialHousing.capacity_per_floor varsayılanı

static func apply_windows(building: Node2D, residents: int, is_night: bool) -> void:
	var floors: Array = floor_nodes(building)
	var remaining: int = residents
	for f in floors:
		var states: Array = []
		var count: int = int(f.call("get_window_count")) if f.has_method("get_window_count") else 0
		if count > 0:
			var units_per_window: int = max(1, int(round(float(CAPACITY_PER_FLOOR) / float(count))))
			units_per_window = min(units_per_window, HouseFloorVisual.NUM_WINDOW_STATES - 1)
			for _w in range(count):
				var units: int = clampi(remaining, 0, units_per_window)
				states.append(units)
				remaining -= units
		if f.has_method("apply_window_states"):
			f.call("apply_window_states", states, is_night)
