class_name VillageVisitScene
extends Node2D
## Dünya haritasından girilen komşu köy. Oyuncunun kendi köy sahnesinin (VillageScene) görünümünü kodla kurar:
## düz zemin, paralaks arka plan, gün/gece, (kıyı köyünde) su; binalar köyün nüfus ve zenginliğine göre
## betiksiz ev prefab'larından (chunks/city/neighborhoods) dizilir. Düzen VillageVisitLayout'tan gelir.
##
## C0 iskelet: gez, kenardaki çıkıştan haritaya dön. Nöbetçi, hedefler ve alarm sonraki dilimlerde
## (docs/VILLAGE_VISIT_PLAN.md). Çıkışa yaklaşınca yukarı tuşu haritaya döndürür.

const Layout = preload("res://village/visit/VillageVisitLayout.gd")
const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")

const PLAYER_SCENE_PATH := "res://player/player.tscn"
const GAME_UI_SCENE_PATH := "res://scenes/game_ui.tscn"
const PAUSE_MENU_SCENE_PATH := "res://ui/PauseMenu.tscn"
const DAY_NIGHT_SCRIPT_PATH := "res://village/scripts/DayNightController.gd"
const WATER_SHADER_PATH := "res://village/scenes/water_reflection.gdshader"
const WATER_TEXTURE_PATH := "res://assets/Sprite-0001.png"

## Arka plan setleri: katman adı -> {doku, katman konumu, hareket, z, sprite konumları}. Kaynak: VillageScene.tscn.
const BACKGROUND_LAYERS: Dictionary = {
	"green": [
		{"tex": "res://village/assets/green_background.png", "layer_pos": Vector2(0, -1), "motion": Vector2(0.7, 0.9), "z": -2,
			"sprites": [Vector2(66, -294)], "sprite_z": -4},
		{"tex": "res://village/assets/green_backgroundtrees.png", "layer_pos": Vector2(0, -1), "motion": Vector2(0.5, 0.7), "z": -2,
			"sprites": [Vector2(53, -165)], "sprite_z": -5},
		{"tex": "res://village/assets/green_bgmountain1.png", "layer_pos": Vector2(1482, -80), "motion": Vector2(0.3, 0.5), "z": -3,
			"sprites": [Vector2(-1656, 80)], "sprite_z": -6},
		{"tex": "res://village/assets/green_bgmountain2.png", "layer_pos": Vector2(0, -1), "motion": Vector2(0.2, 0.4), "z": -4,
			"sprites": [Vector2(1053, 103)], "sprite_z": -7},
	],
}
## Kıyı köyünde dolgulu zemin (altında su), iç köyde tam çimen zemin (green_ground2).
const GROUND_TEXTURES: Dictionary = {"green": "res://village/assets/green_ground.png"}
const GROUND_TEXTURE_INLAND: String = "res://village/assets/green_ground2.png"
## En öndeki çalılar: kameraya en yakın katman, oyuncunun önünde, kamerayla ters yönde biraz hızlı kayar.
const FOREGROUND_BUSH_TEXTURE: String = "res://village/assets/bush_frontground.png"
const FOREGROUND_SPEED: float = 1.35
var _foreground: Node2D = null
## Çalı şeridinin alt kenarının dünya y'si: oyuncu yerdeyken ekranın tam alt kenarına denk gelir (ölçüldü).
const FOREGROUND_BOTTOM_WORLD_Y: float = 330.0
const GROUND_ORIGIN := Vector2(-5330, -799)
## Zemin katmanlarının z sırası (alttan üste): ağaç -6, zemin altı -5, zemin resmi -4, çalı/çimen ve arka süsler -3,
## bina kalınlık katmanı -2, binalar 0. Böylece arka süsler kalınlık katmanının da arkasında kalır.
const GROUND_Z_BASE: int = -4
const DECOR_BEHIND_Z: int = -3
## Köyün zenginlik kademesi -> refah (0..1): pencere süslerinin sıklığını ve türünü belirler.
const PROSPERITY_BY_WEALTH: Dictionary = {"poor": 0.2, "medium": 0.55, "rich": 0.9}
## Çalı / çimen / ağaç dokuları (VillageScene ile aynı) ve sabit y konumları (merkez).
const BUSH_TEXTURES: Array[String] = [
	"res://assets/forest assets/bush1.png", "res://assets/forest assets/bush2.png", "res://assets/forest assets/bush3.png",
	"res://assets/forest assets/bush4.png", "res://assets/forest assets/bush5.png",
]
const GRASS_TEXTURES: Array[String] = [
	"res://assets/forest assets/grass1.png", "res://assets/forest assets/grass2.png", "res://assets/forest assets/grass3.png",
	"res://assets/forest assets/grass4.png", "res://assets/forest assets/grass5.png",
]
## Tek çam (250x700); trees_front.png 3072 px genişliğinde bir orman şeridi, serpiştirmeye uygun değil.
const TREE_TEXTURES: Array[String] = ["res://village/assets/trees_front1.png"]
const DECOR_Y := {"bush": -141.0, "grass": -129.0, "tree": -371.0}

const EXIT_TRIGGER_HALF_WIDTH: float = 150.0
const PLAYER_SPAWN_INSET: float = 700.0

var info: Dictionary = {}
var layout: Dictionary = {}
var player: Node2D = null
var building_nodes: Array[Node2D] = []
var agents: Array[VisitVillager] = []
## Binaların içindeki köylü sayısı (pencere ışığı için), building_nodes ile aynı sırada.
var _occupants: Array[int] = []
var _residents: Array[int] = []   # binada yaşayan köylü sayısı (pencerelerin açık/kapalı durumunu belirler)
var _last_window_hour: int = -1
var _was_night: bool = false

var _in_exit: bool = false
var _hint_label: Label = null
var _banner_label: Label = null
var _leaving: bool = false

# C2: nöbetçiler, hedefler, alarm, ganimet
const GUARD_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.88, 0.92, 1.0), Color(1.0, 0.9, 0.88), Color(0.9, 1.0, 0.9), Color(1.0, 0.97, 0.82),
]
const GUARD_PATROL_HALF: float = 240.0
const TARGET_RANGE_X: float = 100.0
const ALARM_HOLD_SECONDS: float = 1.6
const TREASURE_Y_BELOW: float = 150.0
const TREASURE_Y_ABOVE: float = 60.0

var alarm_active: bool = false
var guards: Array[VisitGuard] = []
var loot: Dictionary = {"gold": 0, "food": 0, "prisoners": 0}
var max_loot: Dictionary = {}
## Hedefler: {kind: treasure/storage/prison, pos: Vector2, taken: bool, hint: Control}
var targets: Array[Dictionary] = []
var _hud_layer: CanvasLayer = null
var _loot_label: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	add_to_group("village_visit_scene")
	info = _resolve_info()
	if info.is_empty():
		push_warning("[VillageVisit] Köy bilgisi bulunamadı, haritaya dönülüyor")
		call_deferred("_leave_to_map")
		return
	layout = Layout.generate(info)
	# Pencere süsleri köyün zenginliğine göre zenginleşir (bkz. HouseFloorVisual.get_prosperity).
	HouseFloorVisual.prosperity_override = PROSPERITY_BY_WEALTH.get(String(info.get("wealth_tier", "medium")), 0.55)
	_build_ground()
	_build_sky()
	_build_parallax()
	_build_decor()
	_add_building_depth()
	_build_buildings()
	_add_ground_decor()
	_add_window_ropes()
	if bool(layout.get("coastal", false)):
		_build_water()
	_build_exits()
	_build_day_night()
	_spawn_player()
	_build_villagers()
	_add_show_director()
	_build_hud()
	_build_guards()
	_build_targets()
	_build_foreground()
	_was_night = Layout.is_night(_current_hour())


## Şu anki ziyaret kipi: free / night_stealth / hostile_day / hostile_night (saat TimeManager'dan).
func current_mode() -> String:
	return Layout.visit_mode(bool(info.get("hostile", false)), _current_hour())


func _current_hour() -> float:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if tm != null and tm.has_method("get_continuous_hour_float"):
		return float(tm.call("get_continuous_hour_float"))
	return 12.0


func _resolve_info() -> Dictionary:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("get_village_visit_info"):
		return {}
	var sid: String = ""
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("get_current_payload"):
		sid = String(sm.call("get_current_payload").get("settlement_id", ""))
	# Editörden doğrudan açılınca (payload yok): ilk keşfedilmiş köy, yoksa ilk köy.
	if sid.is_empty() and OS.has_feature("editor"):
		for key in wm.world_map_settlement_positions.keys():
			sid = String(key)
			if bool(wm.world_map_settlement_positions[key].get("discovered", false)):
				break
	if sid.is_empty():
		return {}
	return wm.call("get_village_visit_info", sid)


# ─── Zemin, gökyüzü, arka plan ────────────────────────────────────────────────

func _build_ground() -> void:
	var half: float = float(layout["half_width"])
	var ground := StaticBody2D.new()
	ground.name = "ground"
	add_child(ground)
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = WorldBoundaryShape2D.new()
	ground.add_child(floor_shape)
	for side in [-1.0, 1.0]:
		var wall := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(400.0, 12000.0)
		wall.shape = rect
		wall.position = Vector2(side * (half + 200.0), -6000.0)
		ground.add_child(wall)
	# Yer tutucu: zemin resminin altı siyah kalmasın (kıyı köyünde su, diğerlerinde kullanıcının çizeceği tam
	# çimen zemin gelecek).
	var under := Polygon2D.new()
	under.name = "UndergroundPlaceholder"
	under.color = Color(0.05, 0.1, 0.05, 1.0)
	under.z_index = GROUND_Z_BASE - 1
	under.polygon = PackedVector2Array([
		Vector2(-half - 1500.0, 110.0), Vector2(half + 1500.0, 110.0),
		Vector2(half + 1500.0, 2400.0), Vector2(-half - 1500.0, 2400.0)])
	add_child(under)
	# Zemin resmi (VillageScene'deki "green_ground"), köy genişliğince yan yana döşenir.
	var ground_path: String = String(GROUND_TEXTURES.get(String(layout.get("background_set", "green")), GROUND_TEXTURES["green"]))
	if not bool(layout.get("coastal", false)):
		ground_path = GROUND_TEXTURE_INLAND
	var tex: Texture2D = _load_texture(ground_path)
	# İç köyde zeminin altı da çimen rengi olsun (kamera zemin resminin altını görünce siyah kalmasın).
	if tex != null and ground_path == GROUND_TEXTURE_INLAND:
		var img: Image = tex.get_image()
		if img != null and not img.is_empty():
			under.color = img.get_pixel(100, img.get_height() - 1)
	if tex == null:
		return
	var tex_w: float = float(tex.get_width())
	var x: float = GROUND_ORIGIN.x
	while x > -half - 800.0:
		x -= tex_w
	while x < half + 800.0:
		var spr := Sprite2D.new()
		spr.name = "GroundImage"
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2(x, GROUND_ORIGIN.y)
		spr.z_index = GROUND_Z_BASE
		add_child(spr)
		x += tex_w


func _build_sky() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.name = "SkyCanvas"
	sky_layer.layer = -1000
	add_child(sky_layer)
	var rect := TextureRect.new()
	rect.name = "SkyRect"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = _make_sky_texture()
	sky_layer.add_child(rect)


var _sky_texture: GradientTexture2D = null

func _make_sky_texture() -> GradientTexture2D:
	if _sky_texture != null:
		return _sky_texture
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 1, 1, 1)])
	_sky_texture = GradientTexture2D.new()
	_sky_texture.gradient = grad
	_sky_texture.fill_from = Vector2(0.545872, 0.642202)
	_sky_texture.fill_to = Vector2(0.536697, 0.0)
	return _sky_texture


func _build_parallax() -> void:
	var half: float = float(layout["half_width"])
	var bg := ParallaxBackground.new()
	bg.name = "ParallaxBackground"
	bg.layer = -1
	add_child(bg)
	var set_name: String = String(layout.get("background_set", "green"))
	for def in BACKGROUND_LAYERS.get(set_name, BACKGROUND_LAYERS["green"]):
		var tex: Texture2D = _load_texture(String(def["tex"]))
		if tex == null:
			continue
		var pl := ParallaxLayer.new()
		pl.position = def["layer_pos"]
		pl.motion_scale = def["motion"]
		pl.z_index = int(def["z"])
		bg.add_child(pl)
		var tex_w: float = float(tex.get_width())
		# Köy kenarlara uzandığı için asıl konumdaki kopyaya ek olarak iki yana kopyalar eklenir.
		var motion_x: float = (def["motion"] as Vector2).x
		var reach: float = (half + 1400.0) * maxf(motion_x, 0.1) + tex_w
		for base_pos in def["sprites"]:
			var k: int = -int(ceil(reach / tex_w)) - 1
			while float(k) * tex_w <= reach:
				var spr := Sprite2D.new()
				spr.texture = tex
				# Komşu kopyalar yatay çevrilir: uçlardaki kesik ağaç ve tepeler ayna gibi tamamlanır.
				spr.flip_h = k % 2 != 0
				spr.position = Vector2(float(base_pos.x) + float(k) * tex_w, float(base_pos.y))
				spr.z_index = int(def["sprite_z"])
				pl.add_child(spr)
				k += 1
	var tint := CanvasModulate.new()
	tint.name = "BackgroundTint"
	tint.z_index = -1
	bg.add_child(tint)
	_build_birds(bg)


## Gündüz gökyüzünde zaman zaman geçen kuşlar (oyuncu köyündekiyle aynı BirdFlockManager). Ekrana sabit (x kayması 0)
## bir parallax katmanında uçarlar.
func _build_birds(bg: ParallaxBackground) -> void:
	var bird_layer := ParallaxLayer.new()
	bird_layer.name = "BirdLayer"
	bird_layer.motion_scale = Vector2(0.0, 0.1)
	bird_layer.z_index = -1
	bg.add_child(bird_layer)
	var mgr := Node.new()
	mgr.name = "BirdFlockManager"
	mgr.set_script(preload("res://village/scripts/BirdFlockManager.gd"))
	mgr.set("layer_path", NodePath("../ParallaxBackground/BirdLayer"))
	add_child(mgr)


func _exit_tree() -> void:
	HouseFloorVisual.prosperity_override = -1.0


## Ekranın en önündeki çalılar (bush_frontground): oyuncunun ve binaların önünden geçer, kamera
## hareketinin biraz tersine kayarak derinlik verir. Dünya tuvalinde olduğu için gece rengini de alır.
func _build_foreground() -> void:
	var tex: Texture2D = _load_texture(FOREGROUND_BUSH_TEXTURE)
	if tex == null:
		return
	_foreground = Node2D.new()
	_foreground.name = "ForegroundBushes"
	_foreground.z_index = 40
	add_child(_foreground)
	var tile_w: float = float(tex.get_width())
	for k in range(-2, 3):
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		# Çizimin uçlarında kesik kalan çalıyı yatay çevrilmiş komşu döşeme tamamlar (ayna dikişi).
		spr.flip_h = k % 2 != 0
		# Görselin alt kenarı düğümün y'sinde durur; düğüm her karede ekranın alt kenarına taşınır.
		spr.position = Vector2(-tile_w * 0.5 + float(k) * tile_w, -float(tex.get_height()))
		_foreground.add_child(spr)


func _update_foreground() -> void:
	if _foreground == null or player == null:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var cam_x: float = cam.get_screen_center_position().x if cam != null else player.global_position.x
	# Ekranda kamera hareketinin FOREGROUND_SPEED katı hızla kayar (5 döşeme köyün her yerini kapsar).
	_foreground.position.x = cam_x * (1.0 - FOREGROUND_SPEED)
	# Dikeyde kameraya değil zemine bağlı: dünyada sabit y, oyuncu zıplayıp çatıya çıksa da yerinde kalır.
	_foreground.position.y = FOREGROUND_BOTTOM_WORLD_Y


func _build_decor() -> void:
	var holder := Node2D.new()
	holder.name = "Decor"
	add_child(holder)
	for d in layout["decor"]:
		var kind: String = String(d["kind"])
		var pool: Array[String] = BUSH_TEXTURES
		if kind == "grass":
			pool = GRASS_TEXTURES
		elif kind == "tree":
			pool = TREE_TEXTURES
		var tex: Texture2D = _load_texture(pool[int(d["variant"]) % pool.size()])
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = Vector2(float(d["x"]), float(DECOR_Y[kind]))
		match kind:
			"tree":
				spr.z_index = GROUND_Z_BASE - 2
			_:
				# Çalı ve çimen zeminin üstünde ama bina kalınlık katmanının ve binaların (z 0) arkasında kalır.
				spr.z_index = GROUND_Z_BASE + 1
		holder.add_child(spr)


# ─── Binalar ─────────────────────────────────────────────────────────────────

## Ev ve dükkânların arkasına kalınlık (karton) katmanı ekleyen yönetici; binalar eklenirken yakalanır.
func _add_building_depth() -> void:
	var mgr := Node.new()
	mgr.name = "BuildingDepthManager"
	mgr.set_script(preload("res://village/scripts/BuildingDepthManager.gd"))
	add_child(mgr)


## Köylülerin küçük gösterme etkinlikleri: akşam meydanda toplanma, sohbet, yüzme, balık tutma... (VillageShowDirector).
func _add_show_director() -> void:
	var dir := Node2D.new()
	dir.set_script(preload("res://village/scripts/show/VillageShowDirector.gd"))
	dir.set("mode", "visit")
	dir.set("center_x", 0.0)
	dir.set("has_water", bool(layout.get("coastal", false)))
	dir.set("buildings_root_path", NodePath("../Buildings"))
	dir.set("visit_scene_path", NodePath(".."))
	add_child(dir)
	# Dolu pencerelerde ara sıra dışarı bakan köylüler.
	var watcher := Node2D.new()
	watcher.set_script(preload("res://village/scripts/show/WindowWatcherDirector.gd"))
	add_child(watcher)


## Yan yana evlerin aynı yükseklikteki pencereleri arasına çamaşır / sebze ipleri gerer (bkz. WindowRopeManager).
func _add_window_ropes() -> void:
	var mgr := Node2D.new()
	mgr.set_script(preload("res://village/scripts/WindowRopeManager.gd"))
	add_child(mgr)


## Binaların önüne/arkasına/aralarına zemin süsleri (fıçı, kova, odun yığını...) serpiştirir. Binalardan SONRA eklenir:
## ön süsler z 1'de (dükkân ön yüzleriyle aynı z, sonradan eklendiği için üstte) köylülerin (z 2) altında kalır.
func _add_ground_decor() -> void:
	var mgr := Node2D.new()
	mgr.name = "GroundDecorManager"
	mgr.set_script(preload("res://village/scripts/GroundDecorManager.gd"))
	mgr.set("buildings_root_path", NodePath("../Buildings"))
	mgr.set("front_z", 1)  # dükkân ön yüzü (FrontSprite) z 1'de; eşit z'de ağaç sırası belirler (süs sonra eklenir). Köylüler z 2.
	mgr.set("behind_z", DECOR_BEHIND_Z)
	mgr.set("seed_key", "visit_%s" % String(info.get("settlement_id", "")))
	mgr.set("population", int(info.get("population", 80)))
	add_child(mgr)


## Binalar oyuncu köyündeki gerçek bina sahneleridir (betiksiz görünüm kopyası, bkz. VillageVisitBuildings.gd)
## ve oyuncu köyündeki parsel konumlarına (400 px arayla, y=0) dizilir.
func _build_buildings() -> void:
	var holder := Node2D.new()
	holder.name = "Buildings"
	add_child(holder)
	for i in range(layout["buildings"].size()):
		var b: Dictionary = layout["buildings"][i]
		var node: Node2D = VillageVisitBuildings.build(b)
		if node == null:
			push_warning("[VillageVisit] Bina kurulamadı: %s" % String(b["scene"]))
			node = Node2D.new()  # indeksler hizalı kalsın
		node.name = "Building%d_%s" % [i, String(b["role"])]
		node.set_meta("role", String(b["role"]))
		holder.add_child(node)
		node.position = Vector2(float(b["x"]), 0.0)
		building_nodes.append(node)
		if OS.has_feature("editor") and String(b["role"]) != "house":
			_add_debug_role_label(node, String(b["role"]), b)
	_occupants.resize(building_nodes.size())
	_occupants.fill(0)


## Editörde rolü görmek için (hazine / depo / zindan); oyuncuya gösterilmez.
func _add_debug_role_label(node: Node2D, role: String, def: Dictionary) -> void:
	var label := Label.new()
	label.text = role.to_upper()
	var floors: int = int(def.get("floors", 0)) + int(def.get("ext_floors", 0))
	label.position = Vector2(-60.0, -520.0 - float(floors) * VillageVisitBuildings.FLOOR_HEIGHT)
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.z_index = 50
	node.add_child(label)


# ─── Köylüler ────────────────────────────────────────────────────────────────

func _build_villagers() -> void:
	var holder := Node2D.new()
	holder.name = "Villagers"
	add_child(holder)
	var hour: float = _current_hour()
	for v in layout["villagers"]:
		var agent := VisitVillager.new()
		holder.add_child(agent)
		agent.setup(self, int(v["home"]), int(v["work"]), float(v["shift_shift"]), hour)
		agents.append(agent)
	_count_residents()
	_refresh_all_windows()


## Binanın kapısının x konumu (parsel merkezi).
func door_x(building: int) -> float:
	if building < 0 or building >= building_nodes.size():
		return 0.0
	return building_nodes[building].position.x


## Taşıma işi hedefi: kaynak binaları ambara, dükkânlar ambara ya da başka bir dükkâna taşır (yoksa -1).
func haul_destination(from_building: int) -> int:
	var buildings: Array = layout.get("buildings", [])
	if from_building < 0 or from_building >= buildings.size():
		return -1
	var storage: int = int(layout.get("storage_index", -1))
	var gatherer: bool = not String(buildings[from_building].get("prefix", "")).is_empty()
	if gatherer and storage >= 0:
		return storage
	var options: Array[int] = []
	for i in range(buildings.size()):
		if i != from_building and String(buildings[i].get("kind", "")) == "work":
			options.append(i)
	if options.is_empty():
		return -1
	return options[randi() % options.size()]


## Taşınan malın rozet anahtarı: kaynak binasında kaynak türü, dükkânda binanın adı.
func haul_resource_key(from_building: int) -> String:
	var buildings: Array = layout.get("buildings", [])
	if from_building < 0 or from_building >= buildings.size():
		return ""
	var def: Dictionary = buildings[from_building]
	var prefix: String = String(def.get("prefix", ""))
	if not prefix.is_empty():
		return prefix
	return String(def.get("scene", "")).get_file().get_basename().to_lower()


func current_hour_value() -> float:
	return _current_hour()


func on_villager_entered(building: int) -> void:
	if building < 0 or building >= _occupants.size():
		return
	_occupants[building] += 1


func on_villager_left(building: int) -> void:
	if building < 0 or building >= _occupants.size():
		return
	_occupants[building] = maxi(0, _occupants[building] - 1)


## Her binada yaşayan sayısı: layout'un nüfusa göre dağıttığı "residents" alanı (sahnede görünen köylü sayısı
## gerçek nüfusun küçük bir kısmı olduğu için pencereler ona bağlanmaz).
func _count_residents() -> void:
	_residents.resize(building_nodes.size())
	_residents.fill(0)
	var buildings: Array = layout.get("buildings", [])
	for i in range(mini(buildings.size(), _residents.size())):
		_residents[i] = int(buildings[i].get("residents", 0))


func _refresh_windows(building: int) -> void:
	if building < 0 or building >= building_nodes.size() or building >= _residents.size():
		return
	VillageVisitBuildings.apply_windows(building_nodes[building], _residents[building], Layout.is_night(_current_hour()))


func _refresh_all_windows() -> void:
	for i in range(building_nodes.size()):
		_refresh_windows(i)


# ─── Su (kıyı köyü) ──────────────────────────────────────────────────────────

func _build_water() -> void:
	var shader: Shader = load(WATER_SHADER_PATH) as Shader
	var tex: Texture2D = _load_texture(WATER_TEXTURE_PATH)
	if shader == null or tex == null:
		return
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.1154
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 8
	noise.fractal_gain = 0.2
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	noise_tex.seamless_blend_skirt = 1.0
	noise_tex.bump_strength = 32.0
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("water_color", Color(5.05373e-07, 0.148499, 0.213102, 1.0))
	mat.set_shader_parameter("wave_noise", noise_tex)
	var water := Sprite2D.new()
	water.name = "Water"
	water.texture = tex
	water.material = mat
	water.z_index = 20
	var width: float = float(layout["half_width"]) * 2.0 + 4000.0
	water.scale = Vector2(width / float(tex.get_width()), 1.45469)
	water.position = Vector2(0.0, 214.625)
	add_child(water)


# ─── Çıkışlar ────────────────────────────────────────────────────────────────

func _build_exits() -> void:
	var exit_x: float = float(layout["exit_x"])
	for side in [-1.0, 1.0]:
		var area := Area2D.new()
		area.name = "Exit%s" % ("Left" if side < 0.0 else "Right")
		area.position = Vector2(side * exit_x, -150.0)
		area.collision_mask = 3
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(EXIT_TRIGGER_HALF_WIDTH * 2.0, 480.0)
		shape.shape = rect
		area.add_child(shape)
		add_child(area)
		var label := Label.new()
		label.text = tr("visit.exit_hint")
		label.position = Vector2(-120.0, -300.0)
		label.size = Vector2(240.0, 30.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
		label.add_theme_constant_override("outline_size", 5)
		area.add_child(label)


# ─── Gün / gece ──────────────────────────────────────────────────────────────

func _build_day_night() -> void:
	var script: Script = load(DAY_NIGHT_SCRIPT_PATH) as Script
	if script == null:
		return
	var dn := CanvasModulate.new()
	dn.name = "DayNightController"
	dn.set_script(script)
	dn.set("night_color", Color(0.337406, 0.445476, 0.853101, 1.0))
	dn.set("bg_day_color", Color(0.65, 0.8, 1.0, 1.0))
	dn.set("sky_gradient_resource", _make_sky_texture())
	dn.set("transition_speed", 0.3)
	add_child(dn)


# ─── Oyuncu, arayüz ──────────────────────────────────────────────────────────

func _spawn_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
		if packed == null:
			return
		player = packed.instantiate() as Node2D
		player.name = "Player"
		add_child(player)
	var half: float = float(layout["half_width"])
	# Soldaki çıkıştan girilir.
	player.global_position = Vector2(-(half - PLAYER_SPAWN_INSET - 300.0), -70.0)
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_left = int(-half)
		cam.limit_right = int(half)
		cam.enabled = true
		cam.make_current()


func _build_hud() -> void:
	var game_ui: PackedScene = load(GAME_UI_SCENE_PATH) as PackedScene
	if game_ui != null:
		add_child(game_ui.instantiate())
	var pause_layer := CanvasLayer.new()
	pause_layer.name = "PauseMenuLayer"
	pause_layer.layer = 210
	add_child(pause_layer)
	var pause: PackedScene = load(PAUSE_MENU_SCENE_PATH) as PackedScene
	if pause != null:
		var inst: Node = pause.instantiate()
		if inst is Control:
			(inst as Control).z_index = 200
		# Ziyaret yarım kalmış bir soygundur, elle kayıt da kapalı (son kayıt haritaya girişteki kalır).
		var save_btn: Button = inst.get_node_or_null("Panel/VBoxContainer/SaveButton") as Button
		if save_btn != null:
			save_btn.disabled = true
			save_btn.tooltip_text = tr("visit.save_blocked")
		pause_layer.add_child(inst)
	# Giriş başlığı: köy adı, lideri ve bu saatteki kip; birkaç saniye sonra söner.
	var banner_layer := CanvasLayer.new()
	banner_layer.name = "VisitBannerLayer"
	banner_layer.layer = 80
	add_child(banner_layer)
	_hud_layer = banner_layer
	_loot_label = Label.new()
	_loot_label.theme = _MEDIEVAL_THEME
	_loot_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_loot_label.offset_left = 40.0
	_loot_label.offset_top = -120.0
	_loot_label.offset_right = 700.0
	_loot_label.offset_bottom = -80.0
	_loot_label.add_theme_font_size_override("font_size", 24)
	_loot_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_loot_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	_loot_label.add_theme_constant_override("outline_size", 7)
	_loot_label.visible = false
	banner_layer.add_child(_loot_label)
	_banner_label = Label.new()
	_banner_label.theme = _MEDIEVAL_THEME
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner_label.offset_top = 90.0
	_banner_label.offset_left = -520.0
	_banner_label.offset_right = 520.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 30)
	_banner_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.6))
	_banner_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	_banner_label.add_theme_constant_override("outline_size", 8)
	_banner_label.text = banner_text()
	banner_layer.add_child(_banner_label)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(6.0)
	_toast_tween.tween_property(_banner_label, "modulate:a", 0.0, 1.5)


## Giriş başlığı metni (test edilebilsin diye ayrı).
func banner_text() -> String:
	var leader: String = String(info.get("leader", ""))
	var personality_key: String = "wm.personality.%s" % String(info.get("personality", "cautious"))
	return "%s\n%s\n%s" % [
		String(info.get("name", "")),
		tr("wm.tooltip.neighbor.leader") % [leader, tr(personality_key)],
		tr("visit.mode.%s" % current_mode()),
	]


# ─── Çıkış mantığı ───────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or layout.is_empty():
		return
	var exit_x: float = float(layout["exit_x"])
	_in_exit = absf(player.global_position.x) >= exit_x - EXIT_TRIGGER_HALF_WIDTH
	# Gece / gündüz geçişinde pencereler yeniden boyanır (gece dolu pencereler sıcak ışık verir).
	var night_now: bool = Layout.is_night(_current_hour())
	var hour_now: int = int(_current_hour())
	if hour_now != _last_window_hour:
		# Pencere ışıklarının yanma/sönme saatleri pencere başına farklı: saat değişince yeniden boyanır.
		_last_window_hour = hour_now
		_refresh_all_windows()
	if night_now != _was_night:
		_was_night = night_now
		_refresh_all_windows()
		_refresh_guard_vision()
	_update_talk_hint()
	_update_foreground()
	# Hedef okları yalnız menzildeyken görünür.
	var reach: int = _target_in_reach()
	for i in range(targets.size()):
		var hint: Control = targets[i]["hint"] as Control
		if hint != null:
			hint.visible = i == reach


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or alarm_active:
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("ui_up")):
		return
	var t: int = _target_in_reach()
	if t >= 0:
		get_viewport().set_input_as_handled()
		take_target(t)
		return
	var talker: VisitVillager = _talkable_villager()
	if talker != null and not _in_exit:
		get_viewport().set_input_as_handled()
		talk_with(talker)
		return
	if _in_exit:
		get_viewport().set_input_as_handled()
		exit_village()


## Köyden çıkış: ganimet varsa başarı, yoksa eli boş; sonuç dünya durumuna yazılır, harita açılır.
func exit_village() -> void:
	if _leaving:
		return
	var has_loot: bool = int(loot["gold"]) > 0 or int(loot["food"]) > 0 or int(loot["prisoners"]) > 0
	_resolve("success" if has_loot else "empty")
	_leave_to_map()


func _resolve(outcome: String) -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.has_method("resolve_village_heist"):
		wm.call("resolve_village_heist", String(info.get("settlement_id", "")), outcome, loot)


# ─── Köylüyle konuşma (yalnız dost köyde, gündüz) ──────────────────────────────

const TALK_RANGE_X: float = 130.0
const TALK_BUBBLE_SECONDS: float = 6.0
var _talk_hint: TextureRect = null
var _last_talk_key: String = ""


## Yanında durulabilen, dışarıdaki en yakın köylü. Yalnız serbest kipte (dost köy, gündüz).
func _talkable_villager() -> VisitVillager:
	if player == null or current_mode() != "free" or alarm_active:
		return null
	var best: VisitVillager = null
	var best_d: float = TALK_RANGE_X
	for a in agents:
		if not is_instance_valid(a) or not a.is_outside():
			continue
		var d: float = absf(a.global_position.x - player.global_position.x)
		if d <= best_d and absf(player.global_position.y - a.global_position.y) < 200.0:
			best_d = d
			best = a
	return best


## Köylü kısa bir söz söyler (köy ve kişilik durumuna göre).
func talk_with(villager: VisitVillager) -> void:
	villager.talk_to(player.global_position.x, TALK_BUBBLE_SECONDS)
	var line: String = tr(talk_line_key())
	if line.contains("%s"):
		line = line % String(info.get("leader", ""))
	NpcAmbientBubble.show_on_npc(villager, line, TALK_BUBBLE_SECONDS, 230.0, 15)


## Köyün durumuna uyan söz anahtarlarından rastgele biri (arka arkaya aynısı gelmez).
func talk_line_key() -> String:
	var pool: Array[String] = []
	var personality: String = String(info.get("personality", "cautious"))
	pool.append("visit.talk.personality.%s.a" % personality)
	pool.append("visit.talk.personality.%s.b" % personality)
	pool.append("visit.talk.leader")
	pool.append("visit.talk.generic.1")
	pool.append("visit.talk.generic.2")
	pool.append("visit.talk.generic.3")
	var wealth: String = String(info.get("wealth_tier", "medium"))
	if wealth != "medium":
		pool.append("visit.talk.wealth.%s" % wealth)
	var army: String = String(info.get("army_tier", "medium"))
	if army != "medium":
		pool.append("visit.talk.army.%s" % army)
	if int(info.get("prisoners", 0)) > 0:
		pool.append("visit.talk.prisoners")
	var rel: int = int(info.get("relation", 0))
	if rel >= 25:
		pool.append("visit.talk.relation.high")
	elif rel <= -5:
		pool.append("visit.talk.relation.low")
	if pool.size() > 1:
		pool.erase(_last_talk_key)
	var key: String = pool[randi() % pool.size()]
	_last_talk_key = key
	return key


## Konuşulabilen köylünün üstünde ok (mevcut ok simgesi).
func _update_talk_hint() -> void:
	var v: VisitVillager = _talkable_villager()
	if v == null:
		if _talk_hint != null:
			_talk_hint.visible = false
		return
	if _talk_hint == null:
		_talk_hint = NpcOverheadUi.build_up_arrow_hint_icon()
		_talk_hint.z_index = 60
		add_child(_talk_hint)
	_talk_hint.visible = not NpcAmbientBubble.has_active_bubble(v)
	_talk_hint.global_position = v.global_position + Vector2(-_talk_hint.size.x * 0.5, -_talk_hint.size.y - 150.0)


# ─── C2: nöbetçiler ──────────────────────────────────────────────────────────

## Nöbetçiler yalnız gizlilik gereken kiplerde uyanıktır (dost köyde gündüz barışçıl).
func guards_alert() -> bool:
	return Layout.stealth_required(current_mode())


func _build_guards() -> void:
	var holder := Node2D.new()
	holder.name = "Guards"
	add_child(holder)
	var count: int = int(layout.get("guard_count", 2))
	var half: float = float(layout["half_width"])
	var spawn_x: float = -(half - PLAYER_SPAWN_INSET - 300.0)
	var from_x: float = spawn_x + 900.0
	var to_x: float = float(layout["exit_x"]) - 200.0
	var treasure_x: float = door_x(int(layout.get("treasure_index", 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(info.get("settlement_id", "")))
	var clustered: int = int(round(float(count) * 0.4))
	for i in range(count):
		var center: float
		if i < clustered:
			# Hazine binası etrafında: ipucu (nöbetçi yoğunluğu)
			center = treasure_x + rng.randf_range(-450.0, 450.0)
		else:
			center = lerpf(from_x, to_x, (float(i - clustered) + 0.5) / maxf(float(count - clustered), 1.0))
		center = clampf(center, from_x, to_x)
		var guard := VisitGuard.new()
		guard.name = "Guard%d" % i
		holder.add_child(guard)
		guard.global_position = Vector2(center, 0.0)
		guard.setup(self, center - GUARD_PATROL_HALF, center + GUARD_PATROL_HALF, GUARD_TINTS[int(hash(String(info.get("settlement_id", "")))) % GUARD_TINTS.size()], "visit_guard_%d" % i)
		guards.append(guard)
	_refresh_guard_vision()


## Saat/kip değişince görüş menzili yenilenir.
func _refresh_guard_vision() -> void:
	var mult: float = Layout.vision_multiplier(current_mode())
	for g in guards:
		if is_instance_valid(g):
			g.set_vision_multiplier(mult)


func raise_alarm(reason: String = "spotted") -> void:
	if alarm_active or _leaving:
		return
	alarm_active = true
	loot = {"gold": 0, "food": 0, "prisoners": 0}
	_update_loot_label()
	_show_toast(tr("visit.alarm"), Color(1.0, 0.35, 0.3), ALARM_HOLD_SECONDS + 1.0)
	var timer := get_tree().create_timer(ALARM_HOLD_SECONDS)
	timer.timeout.connect(_on_alarm_timeout)


func _on_alarm_timeout() -> void:
	if _leaving:
		return
	_resolve("alarm")
	_leave_to_map()


# ─── C2: hedefler (hazine kapağı, depo, zindan) ──────────────────────────────

func _build_targets() -> void:
	max_loot = {"gold": 0, "food": 0, "prisoners": 0}
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.has_method("get_heist_loot_amounts"):
		max_loot = wm.call("get_heist_loot_amounts", String(info.get("settlement_id", "")))
	var ti: int = int(layout.get("treasure_index", -1))
	var si: int = int(layout.get("storage_index", -1))
	var pi: int = int(layout.get("prison_index", -1))
	if ti >= 0 and ti < building_nodes.size():
		var roof: Vector2 = VillageVisitBuildings.roof_point(building_nodes[ti])
		_add_target("treasure", building_nodes[ti].position + roof)
	if si >= 0 and si < building_nodes.size() and int(max_loot.get("food", 0)) > 0:
		_add_target("storage", Vector2(building_nodes[si].position.x, -120.0))
	if pi >= 0 and pi < building_nodes.size() and int(max_loot.get("prisoners", 0)) > 0:
		_add_target("prison", Vector2(building_nodes[pi].position.x, -120.0))


func _add_target(kind: String, pos: Vector2) -> void:
	var holder := Node2D.new()
	holder.name = "Target_%s" % kind
	holder.position = pos
	holder.z_index = 60
	add_child(holder)
	var icon: TextureRect = NpcOverheadUi.build_up_arrow_hint_icon()
	icon.position = Vector2(-icon.size.x * 0.5, -icon.size.y - 70.0)
	icon.visible = false
	holder.add_child(icon)
	targets.append({"kind": kind, "pos": pos, "taken": false, "hint": icon})


## Oyuncunun ulaşabildiği hedef (yoksa -1). Yalnız gizlilik gereken kiplerde ve alarm yokken.
func _target_in_reach() -> int:
	if player == null or not guards_alert() or alarm_active:
		return -1
	var pp: Vector2 = player.global_position
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		if bool(t["taken"]):
			continue
		var tp: Vector2 = t["pos"]
		var dy: float = pp.y - tp.y
		if String(t["kind"]) == "treasure":
			# Çatıdaki kapak: oyuncu çatıya çıkmış olmalı.
			if absf(pp.x - tp.x) <= TARGET_RANGE_X and dy >= -TREASURE_Y_ABOVE - 60.0 and dy <= TREASURE_Y_BELOW - 70.0:
				return i
		elif absf(pp.x - tp.x) <= TARGET_RANGE_X and pp.y > -260.0:
			return i
	return -1


func take_target(i: int) -> void:
	if i < 0 or i >= targets.size() or bool(targets[i]["taken"]):
		return
	var t: Dictionary = targets[i]
	t["taken"] = true
	targets[i] = t
	var kind: String = String(t["kind"])
	var amount: int = 0
	match kind:
		"treasure":
			amount = int(max_loot.get("gold", 0))
			loot["gold"] = amount
		"storage":
			amount = int(max_loot.get("food", 0))
			loot["food"] = amount
		"prison":
			amount = int(max_loot.get("prisoners", 0))
			loot["prisoners"] = amount
	_update_loot_label()
	if amount > 0:
		_show_toast(tr("visit.loot.%s" % kind) % amount, Color(1.0, 0.9, 0.5), 3.0)
	else:
		_show_toast(tr("visit.loot.empty"), Color(0.85, 0.85, 0.85), 3.0)


func _update_loot_label() -> void:
	if _loot_label == null:
		return
	var any: bool = int(loot["gold"]) > 0 or int(loot["food"]) > 0 or int(loot["prisoners"]) > 0
	_loot_label.visible = any
	if any:
		_loot_label.text = tr("visit.loot.hud") % [int(loot["gold"]), int(loot["food"]), int(loot["prisoners"])]


func _show_toast(text: String, color: Color, seconds: float) -> void:
	if _banner_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_banner_label, "modulate:a", 0.0, 1.0)


func _leave_to_map() -> void:
	if _leaving:
		return
	_leaving = true
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("change_to_world_map"):
		sm.call("change_to_world_map", {"source": "village_visit", "return_reason": "visit_exit"})


func _load_texture(path: String) -> Texture2D:
	var res: Resource = load(path)
	return res as Texture2D
