extends Node2D

# Köy zemin süsleri: binaların önüne, arkasına ve aralarına fıçı, kova, odun yığını, merdiven gibi süsler serpiştirir.
# Oyuncudan bağımsız: süs sayısı köy nüfusuna ve bina sayısına bağlı; oyuncu görmüyorken (kamera dışında) süsler
# yer ve tür değiştirir, köy "yaşıyor" gibi görünür.
# Çizimler `decor_<tür><no>.png` (150x150 tuval, alt orta nokta zemine basar); yeni tür eklemek için dosyayı klasöre koymak yeter.

const DECOR_DIR: String = "res://village/buildings/sprite/decor/"
const CANVAS_SIZE: Vector2 = Vector2(150, 150)

# Türlerin seçilme ağırlığı (listede olmayan tür 1.0). Sadece duvar kenarına konabilen türler WALL_ONLY_KINDS'ta.
const KIND_WEIGHTS: Dictionary = {"barrel": 1.0, "bucket": 0.5, "chair": 0.6, "ladder": 0.5, "wood_pile": 1.0}
const WALL_ONLY_KINDS: Array[String] = ["ladder"]

# Bina genişliğine göre ön yuva konumları (0 = sol kenar, 1 = sağ kenar). Orta kısım kapı için boş bırakılır.
const FRONT_FRACTIONS: Array[float] = [0.07, 0.22, 0.78, 0.93]
const WALL_FRACTIONS: Array[float] = [0.07, 0.93]
const BEHIND_EDGE_MARGIN: float = 48.0     # binanın yan kenarından dışarı: binaya gömülmesin diye tamamen dışında kalır
const BEHIND_Y_OFFSET: float = -30.0       # arka süs zeminde belirgin şekilde geride (yukarıda) durur, binanın arkasındaymış gibi görünür
const MIN_GAP_FOR_SLOT: float = 40.0       # iki bina arası bundan genişse boşluğa yuva açılır
const END_MARGIN: float = 90.0             # en uçtaki binanın dışına
const MIN_SPACING: float = 60.0            # iki süs arasında en az bu kadar x mesafesi
const MIN_BUILDING_WIDTH: float = 100.0
const SPRITE_MIN_WIDTH: float = 150.0      # bina gövdesi sayılan en dar sprite (pencere, kapı, süs sayılmaz)

const FRONT_Y_JITTER: float = 6.0          # ön süsler zeminde 0..6 piksel öne kayar
# Karakterlerin derinlik sıralaması (Player/Worker: ayak y'si 0..25 arası z 6..19). Ön süsler aynı formülle sıralanır.
const DEPTH_Z_MIN: int = 6
const DEPTH_Z_MAX: int = 19
const DEPTH_Y_RANGE: float = 25.0
## Derinlik eşlemesi sahneye göre değişir: oyuncu köyünde yürünebilir bant y=5..30 (Worker.VERTICAL_RANGE_MIN), ziyaret köyünde
## y=0..25 (VisitVillager.depth_z) ve süs karakterlerin önüne +1 ile geçer. Ziyaret sahnesi bu ikisini eski değerlerine ayarlar.
@export var depth_band_top_y: float = 5.0
@export var depth_front_bias: int = 0   # NOT: -1 denendi, ayak çizgisinde duran oyuncuyu fıçıların önüne alıp bozdu; 0 doğru

const BUILDING_CHECK_INTERVAL: float = 3.0
const OFFSCREEN_MARGIN: float = 250.0

@export var buildings_root_path: NodePath
@export var depth_sort_front: bool = true  # ön süsler karakterlerle aynı derinlik formülüyle sıralanır (front_z yedek)
@export var front_z: int = 2
@export var behind_z: int = -3   # bina kalınlık katmanının (z -2) arkasında
@export var ground_y: float = 0.0
@export var seed_key: String = "village"
@export var population: int = -1           # -1: VillageManager.total_workers kullanılır
@export var shuffle_interval: float = 8.0  # kamera dışındaki bir yuvanın yenilenme aralığı (saniye)

var _library: Dictionary = {}              # tür -> Array[Texture2D]
var _slots: Dictionary = {}                # anahtar -> {x, layer, wall, node}
var _buildings_root: Node = null
var _signature: String = ""
var _built_once: bool = false
var _check_timer: float = 0.0
var _shuffle_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

## Sahnedeki ön katmandaki sandalye süsleri (köylüler üstüne oturur, bkz. VillageShowDirector). Süs yenilenirken kalkabilir.
func get_chair_sprites() -> Array:
	var out: Array = []
	for s in _slots.values():
		var n = s.get("node")
		if n != null and is_instance_valid(n) and String(s["layer"]) == "front" and (n as Sprite2D).texture != null \
				and (n as Sprite2D).texture.resource_path.get_file().begins_with("decor_chair"):
			out.append(n)
	return out

func _ready() -> void:
	add_to_group(&"ground_decor_manager")
	name = "GroundDecor"
	_load_library()
	_buildings_root = get_node_or_null(buildings_root_path)
	_rng.seed = hash(seed_key)
	_shuffle_timer = shuffle_interval
	if _library.is_empty() or _buildings_root == null:
		set_process(false)
		return
	_rebuild_slots()

func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = BUILDING_CHECK_INTERVAL
		var sig: String = _compute_signature(_collect_spans())
		if sig != _signature:
			_rebuild_slots()
	_shuffle_timer -= delta
	if _shuffle_timer <= 0.0:
		_shuffle_timer = shuffle_interval * _rng.randf_range(0.6, 1.4)
		_shuffle_once()

# ─── Kütüphane ───────────────────────────────────────────────────────────────

func _load_library() -> void:
	_library.clear()
	var seen: Array[String] = []
	for file in DirAccess.get_files_at(DECOR_DIR):
		var base: String = file.trim_suffix(".import").trim_suffix(".remap")
		if base.ends_with(".png") and base.begins_with("decor_") and not seen.has(base):
			seen.append(base)
	seen.sort()
	for base in seen:
		var kind: String = base.get_basename().trim_prefix("decor_").rstrip("0123456789").trim_suffix("_")
		var tex := load(DECOR_DIR + base) as Texture2D
		if tex == null or kind.is_empty():
			continue
		if not _library.has(kind):
			_library[kind] = []
		_library[kind].append(tex)

# ─── Yuvalar ─────────────────────────────────────────────────────────────────

func _collect_spans() -> Array[Vector2]:
	var spans: Array[Vector2] = []
	if _buildings_root == null:
		return spans
	for child in _buildings_root.get_children():
		if not (child is Node2D) or not (child as Node2D).visible:
			continue
		_last_span = Vector2(INF, -INF)
		_extend_span_recursive(child)
		if _last_span.y - _last_span.x >= MIN_BUILDING_WIDTH:
			spans.append(_last_span)
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return spans

var _last_span: Vector2 = Vector2(INF, -INF)

# Binanın gövde sprite'larının kapladığı x aralığı (dünya koordinatı) _last_span'a yazılır.
func _extend_span_recursive(node: Node) -> void:
	for child in node.get_children():
		if String(child.name) == "DepthSlab":
			continue
		if child is Sprite2D:
			var s: Sprite2D = child
			if s.texture != null and s.hframes == 1 and s.vframes == 1 and s.is_visible_in_tree() \
					and not String(s.name).begins_with("Window") \
					and s.texture.get_width() * absf(s.global_scale.x) >= SPRITE_MIN_WIDTH:
				var r: Rect2 = s.get_rect()
				for corner in [r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y)]:
					var gx: float = s.to_global(corner).x
					_last_span.x = minf(_last_span.x, gx)
					_last_span.y = maxf(_last_span.y, gx)
		_extend_span_recursive(child)

func _compute_signature(spans: Array[Vector2]) -> String:
	var parts: PackedStringArray = []
	for sp in spans:
		parts.append("%d:%d" % [int(round(sp.x)), int(round(sp.y))])
	return ";".join(parts)

func _desired_slots(spans: Array[Vector2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sp in spans:
		var w: float = sp.y - sp.x
		for f in FRONT_FRACTIONS:
			out.append({"x": sp.x + w * f, "layer": "front", "wall": WALL_FRACTIONS.has(f)})
		out.append({"x": sp.x - BEHIND_EDGE_MARGIN, "layer": "behind", "wall": false})
		out.append({"x": sp.y + BEHIND_EDGE_MARGIN, "layer": "behind", "wall": false})
	for i in range(spans.size() - 1):
		var gap: float = spans[i + 1].x - spans[i].y
		if gap >= MIN_GAP_FOR_SLOT:
			var mid: float = (spans[i].y + spans[i + 1].x) * 0.5
			out.append({"x": mid, "layer": "front", "wall": false})
			out.append({"x": mid, "layer": "behind", "wall": false})
	if not spans.is_empty():
		out.append({"x": spans[0].x - END_MARGIN, "layer": "front", "wall": false})
		out.append({"x": spans[spans.size() - 1].y + END_MARGIN, "layer": "front", "wall": false})
	for s in out:
		s["key"] = "%d_%s" % [int(round(float(s["x"]))), String(s["layer"])]
	return out

func _rebuild_slots() -> void:
	var spans: Array[Vector2] = _collect_spans()
	_signature = _compute_signature(spans)
	var desired: Array[Dictionary] = _desired_slots(spans)
	var desired_keys: Dictionary = {}
	for d in desired:
		desired_keys[d["key"]] = true
	for key in _slots.keys():
		if not desired_keys.has(key):
			_vacate(_slots[key])
			_slots.erase(key)
	var fresh: Array[Dictionary] = []
	for d in desired:
		if not _slots.has(d["key"]):
			d["node"] = null
			_slots[d["key"]] = d
			fresh.append(d)
	# Yeni yuvaları hedef doluluğa ulaşana kadar rastgele sırayla doldur (aynı tohum aynı köyde aynı başlangıcı verir).
	fresh.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return hash("%s%s" % [seed_key, a["key"]]) < hash("%s%s" % [seed_key, b["key"]]))
	# Oyuncu bakarken hiçbir şey değişmez: ilk kurulumda (sahne açılırken) yuvalar hemen dolar; sonradan eklenen
	# binaların yuvaları yalnızca kamera dışındayken dolar, kalan boşluğu _shuffle_once yavaş yavaş tamamlar.
	var first_build: bool = not _built_once
	_built_once = true
	var target: int = _target_count()
	for s in fresh:
		if _occupied_count() >= target:
			break
		if (first_build or _is_offscreen(float(s["x"]))) and _spacing_ok(s):
			_occupy(s)
	# İlk kurulumda fazla süs varsa fazlayı kaldır; sonradan fazlalığı kamera dışındaki yenilenme eritir.
	var guard: int = 0
	while first_build and _occupied_count() > target and guard < 500:
		guard += 1
		var occupied: Array = _occupied_slots()
		_vacate(occupied[_rng.randi() % occupied.size()])

# ─── Doluluk ve yenilenme ────────────────────────────────────────────────────

func _density() -> float:
	var pop: int = population
	if pop < 0:
		var vm := get_node_or_null("/root/VillageManager")
		pop = int(vm.total_workers) if vm != null and "total_workers" in vm else 30
	return clampf(0.12 + float(pop) / 150.0 * 0.6, 0.12, 0.85)

func _target_count() -> int:
	return int(round(float(_slots.size()) * _density()))

func _occupied_slots() -> Array:
	var out: Array = []
	for s in _slots.values():
		if s["node"] != null:
			out.append(s)
	return out

func _occupied_count() -> int:
	var n: int = 0
	for s in _slots.values():
		if s["node"] != null:
			n += 1
	return n

func _spacing_ok(slot: Dictionary) -> bool:
	for s in _slots.values():
		if s["node"] != null and s != slot and absf(float(s["x"]) - float(slot["x"])) < MIN_SPACING:
			return false
	return true

func _is_offscreen(x: float) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var half_view: float = get_viewport().get_visible_rect().size.x / maxf(cam.zoom.x, 0.01) * 0.5
	return absf(x - cam.get_screen_center_position().x) > half_view + OFFSCREEN_MARGIN

# Kamera dışındaki rastgele bir yuvayı yeniler: hedefin altındaysa doldurur, üstündeyse boşaltır, eşitse süsü yenisiyle
# değiştirir ya da başka bir (kamera dışı) boş yuvaya taşır. Oyuncu hiçbir değişikliği görmez.
func _shuffle_once() -> void:
	var offscreen: Array = []
	for s in _slots.values():
		if _is_offscreen(float(s["x"])):
			offscreen.append(s)
	if offscreen.is_empty():
		return
	var slot: Dictionary = offscreen[_rng.randi() % offscreen.size()]
	var occupied: int = _occupied_count()
	var target: int = _target_count()
	if slot["node"] == null:
		if occupied < target and _spacing_ok(slot):
			_occupy(slot)
		return
	if occupied > target:
		_vacate(slot)
	elif _rng.randf() < 0.5:
		_vacate(slot)
		_occupy(slot)  # aynı yerde farklı süs
	else:
		var empties: Array = []
		for s in offscreen:
			if s["node"] == null and s != slot:
				empties.append(s)
		if not empties.is_empty():
			var dest: Dictionary = empties[_rng.randi() % empties.size()]
			_vacate(slot)
			if _spacing_ok(dest):
				_occupy(dest)
			else:
				_occupy(slot)

func _pick_texture(slot: Dictionary) -> Texture2D:
	var kinds: Array[String] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for k in _library.keys():
		if WALL_ONLY_KINDS.has(k) and not bool(slot["wall"]):
			continue
		var w: float = float(KIND_WEIGHTS.get(k, 1.0))
		kinds.append(k)
		weights.append(w)
		total += w
	if kinds.is_empty():
		return null
	var roll: float = _rng.randf() * total
	for i in kinds.size():
		roll -= weights[i]
		if roll <= 0.0 or i == kinds.size() - 1:
			var variants: Array = _library[kinds[i]]
			return variants[_rng.randi() % variants.size()]
	return null

func _occupy(slot: Dictionary) -> void:
	var tex: Texture2D = _pick_texture(slot)
	if tex == null:
		return
	if slot["node"] != null:
		_vacate(slot)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-CANVAS_SIZE.x * 0.5, -CANVAS_SIZE.y)  # alt orta nokta zemine basar
	spr.flip_h = _rng.randf() < 0.5
	var front: bool = String(slot["layer"]) == "front"
	spr.position = Vector2(float(slot["x"]), ground_y + (_rng.randf_range(0.0, FRONT_Y_JITTER) if front else BEHIND_Y_OFFSET))
	if not front:
		spr.z_index = behind_z
	elif depth_sort_front:
		spr.z_index = _depth_z(spr.position.y - ground_y)
	else:
		spr.z_index = front_z
	add_child(spr)
	slot["node"] = spr

# Oyuncu, köylüler ve işçilerle aynı derinlik formülü (ayak y'si 0..25 -> z 6..19): tabanı karakterin ayağından aşağıdaysa
# süs önde, yukarıdaysa arkada çizilir. Süsler zeminin en önünde (y >= 0) durduğu için +1 ile ayak çizgisindeki karakterin
# de önüne geçer.
func _depth_z(depth_y: float) -> int:
	# Karakterler yürünebilir bandı VERTICAL_RANGE_MIN (y=5)..MAX (y=30) arasında z 6..19'a eşler (Worker.gd). Süs de aynı eşlemeyi
	# kullanır (eskiden y=0'dan başlıyordu: ayak çizgisi 5 px aşağıdaki köylü süsün ARKASINDA kalıyordu, ateşin önünde oturanlar gibi).
	var t: float = clampf((depth_y + ground_y - depth_band_top_y) / DEPTH_Y_RANGE, 0.0, 1.0)
	return int(round(lerpf(float(DEPTH_Z_MIN), float(DEPTH_Z_MAX), t))) + depth_front_bias

func _vacate(slot: Dictionary) -> void:
	var node = slot.get("node")
	if node != null and is_instance_valid(node):
		node.queue_free()
	slot["node"] = null
