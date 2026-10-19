extends Node2D

# Yan yana iki evin aynı yükseklikteki pencereleri arasına gerilen çamaşır / sebze iplerini kurar.
# Çizimler: window_decor3_clothes.png (çamaşır, 148x33) ve window_decor3_veggies.png (asılmış sebze, 148x12); sprite
# genişliği (148) komşu plotların dış pencere kenarları arasındaki mesafeyle (400 - 2*127 = 146) aynıdır.
#  - Ip sadece iki pencerede de yaşayan olan (pencere açık/yarı açık) komşu evler arasına gerilir.
#  - Hangi çiftlerde ip olacağı, ip türü, yüksekliği ve çamaşır renkleri günden güne değişir (günlük tohum).
#  - Çamaşırlar sadece gündüz ve yağmursuzken asılıdır; sebzeler geceye kadar kalır.
#  - Rüzgârda sallanır (pencere süsleriyle aynı sallanma shader'ı).

const CLOTHES_TEXTURE: Texture2D = preload("res://village/buildings/sprite/house/decor/window_decor3_clothes.png")
const VEGGIES_TEXTURE: Texture2D = preload("res://village/buildings/sprite/house/decor/window_decor3_veggies.png")
const SWAY_SHADER_PATH: String = "res://shaders/window_sway.gdshader"

const MIN_SPAN: float = 100.0              # iki pencerenin dış kenarı arası en az / en çok bu kadar olmalı
const MAX_SPAN: float = 200.0
const MAX_HEIGHT_DIFF: float = 3.0         # "aynı yükseklik" toleransı
const ROPE_CHANCE: float = 0.45            # uygun bir çiftte o gün ip olma olasılığı
const CLOTHES_SHARE: float = 0.65          # ip olan çiftlerde çamaşır olma oranı (kalanı sebze)
const DROP_MIN: float = 8.0                # ipin pencere üstünden aşağı kayma aralığı (piksel), günlük değişir
const DROP_MAX: float = 30.0
const ROPE_PIXEL_MAX: int = 12             # bu değerden koyu (0x050403) pikseller ip sayılır, çamaşıra katılmaz
const CLOTHES_DAY_START: int = 6           # çamaşırlar bu saatten başlayıp ...
const CLOTHES_DAY_END: int = 19            # ... bu saatte toplanır
const VEGGIES_DAY_END: int = 21
const MAX_RAIN_FOR_CLOTHES: float = 0.2
const ROPE_DAY_ROLLOVER_HOUR: int = 4      # günlük değişim gece 04:00'te olur, gün içinde ip atlamaz
const SWAY_AMPLITUDE_SCALE: float = 0.8
const REFRESH_INTERVAL: float = 4.0
const OFFSCREEN_MARGIN: float = 150.0      # kamera görüş alanının bu kadar dışı "görünmüyor" sayılır
const INITIAL_GRACE_MSEC: int = 6000       # sahne açılırken ilk kurulum bu sürede anında yapılır

static var _base_images: Dictionary = {}
var _born_msec: int = 0

var _ropes: Dictionary = {}                # çift anahtarı -> {sprite, kind}
var _timer: float = 0.0
var _clothes_material: ShaderMaterial = null
var _veggies_material: ShaderMaterial = null
var _tex_cache: Dictionary = {}            # çift+gün anahtarı -> Texture2D (günlük çamaşır renkleri)
var _last_rope_day: int = -999

func _ready() -> void:
	name = "WindowRopes"
	_born_msec = Time.get_ticks_msec()
	z_index = 1
	var shader := load(SWAY_SHADER_PATH) as Shader
	if shader != null:
		_clothes_material = _make_material(shader, CLOTHES_TEXTURE)
		_veggies_material = _make_material(shader, VEGGIES_TEXTURE)
	_timer = 1.0

func _make_material(shader: Shader, tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("top_v", 0.0)
	mat.set_shader_parameter("bottom_v", 1.0)
	mat.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	return mat

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_INTERVAL
		_refresh()
	_update_sway()

# ─── Zaman / hava ────────────────────────────────────────────────────────────

func _hour() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	return int(tm.get_hour()) if tm != null and tm.has_method("get_hour") else 12

func _rope_day() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	var day: int = int(tm.get_day()) if tm != null and tm.has_method("get_day") else 1
	return day if _hour() >= ROPE_DAY_ROLLOVER_HOUR else day - 1

func _rain() -> float:
	var weather := get_node_or_null("/root/WeatherManager")
	return float(weather.rain_intensity) if weather != null and "rain_intensity" in weather else 0.0

func _update_sway() -> void:
	if _ropes.is_empty() or _clothes_material == null:
		return
	var wind: float = 0.0
	var weather := get_node_or_null("/root/WeatherManager")
	if weather != null and "wind_strength" in weather:
		wind = clampf(float(weather.wind_strength), 0.0, 1.0)
	var amp: float = (HouseFloorVisual.SWAY_BASE_AMPLITUDE + wind * HouseFloorVisual.SWAY_WIND_AMPLITUDE) * SWAY_AMPLITUDE_SCALE
	var spd: float = HouseFloorVisual.SWAY_BASE_SPEED + wind * HouseFloorVisual.SWAY_WIND_SPEED
	for mat in [_clothes_material, _veggies_material]:
		(mat as ShaderMaterial).set_shader_parameter("amplitude_px", amp)
		(mat as ShaderMaterial).set_shader_parameter("speed", spd)

# ─── Çiftleri bul ve iplerı kur ─────────────────────────────────────────────

# Oyuncu bakarken hiçbir şey değişmez: ip ekleme/kaldırma, günlük yenilenme ve çamaşırların toplanması yalnızca ipin
# bulunduğu yer kamera dışındayken yapılır (sahne ilk açıldığı kısa süre hariç: ilk kurulum anında yapılır).
func _can_change(x: float) -> bool:
	if Time.get_ticks_msec() - _born_msec < INITIAL_GRACE_MSEC:
		return true
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var half_view: float = get_viewport().get_visible_rect().size.x / maxf(cam.zoom.x, 0.01) * 0.5
	return absf(x - cam.get_screen_center_position().x) > half_view + OFFSCREEN_MARGIN

func _refresh() -> void:
	var rope_day: int = _rope_day()
	if rope_day != _last_rope_day:
		_last_rope_day = rope_day
		_tex_cache.clear()  # eski ipler kendi dokusunu tutar; yenileri kamera dışında yeni güne geçer
	var hour: int = _hour()
	var rain: float = _rain()
	var floors: Array = get_tree().get_nodes_in_group(&"house_floor_visual")
	var wanted: Dictionary = {}
	for f in floors:
		if not is_instance_valid(f) or not (f as Node2D).is_visible_in_tree():
			continue
		var right: Dictionary = f.get_outer_window(1)
		if int(right["state"]) <= 0 or (right["pos"] as Vector2) == Vector2.INF:
			continue
		var partner: Dictionary = _find_partner(f, right["pos"] as Vector2, floors)
		if partner.is_empty():
			continue
		var rpos: Vector2 = right["pos"]
		var key: String = "%d_%d" % [int(round(rpos.x)), int(round(rpos.y))]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("rope_%s_%d" % [key, rope_day])
		for _warm in 4:
			rng.randi()  # benzer tohumların ilk çıktıları ilişkili olabilir; ilkleri at
		if rng.randf() >= ROPE_CHANCE:
			continue
		var kind: String = "clothes" if rng.randf() < CLOTHES_SHARE else "veggies"
		var lpos: Vector2 = partner["pos"]
		wanted[key] = {"kind": kind, "rpos": rpos, "lpos": lpos, "rng": rng, "x": (rpos.x + lpos.x) * 0.5}
	# Artık uygun olmayan ya da başka güne ait iplerin sprite'larını kaldır (sadece kamera dışındayken), yenileri ekle.
	for key in _ropes.keys():
		var entry: Dictionary = _ropes[key]
		var stale: bool = not wanted.has(key) or int(entry["day"]) != rope_day
		if stale and _can_change(float(entry["x"])):
			_remove_rope(key)
	for key in wanted.keys():
		var w: Dictionary = wanted[key]
		if not _ropes.has(key) and _can_change(float(w["x"])):
			_add_rope(key, String(w["kind"]), w["rpos"], w["lpos"], w["rng"], rope_day, float(w["x"]))
			_apply_visibility(key, hour, rain, true)
	for key in _ropes.keys():
		_apply_visibility(key, hour, rain, false)

func _find_partner(floor_node: Node, right_pos: Vector2, floors: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_dx: float = INF
	for g in floors:
		if g == floor_node or not is_instance_valid(g) or not (g as Node2D).is_visible_in_tree():
			continue
		var left: Dictionary = g.get_outer_window(-1)
		if int(left["state"]) <= 0 or (left["pos"] as Vector2) == Vector2.INF:
			continue
		var lpos: Vector2 = left["pos"]
		var dx: float = lpos.x - right_pos.x
		if dx >= MIN_SPAN and dx <= MAX_SPAN and absf(lpos.y - right_pos.y) <= MAX_HEIGHT_DIFF and dx < best_dx:
			best_dx = dx
			best = left
	return best

func _add_rope(key: String, kind: String, rpos: Vector2, lpos: Vector2, rng: RandomNumberGenerator, rope_day: int, center_x: float) -> void:
	var spr := Sprite2D.new()
	spr.name = "Rope_%s" % key
	spr.centered = false
	var base_tex: Texture2D = CLOTHES_TEXTURE if kind == "clothes" else VEGGIES_TEXTURE
	spr.texture = _tinted_clothes(key, rng) if kind == "clothes" else base_tex
	spr.flip_h = rng.randf() < 0.5
	var drop: float = rng.randf_range(DROP_MIN, DROP_MAX)
	spr.position = Vector2((rpos.x + lpos.x) * 0.5 - float(base_tex.get_width()) * 0.5, rpos.y + roundf(drop))
	spr.material = _clothes_material if kind == "clothes" else _veggies_material
	add_child(spr)
	_ropes[key] = {"sprite": spr, "kind": kind, "day": rope_day, "x": center_x}

func _remove_rope(key) -> void:
	var entry: Dictionary = _ropes.get(key, {})
	var spr = entry.get("sprite")
	if spr != null and is_instance_valid(spr):
		spr.queue_free()
	_ropes.erase(key)

func _apply_visibility(key: String, hour: int, rain: float, force: bool) -> void:
	var entry: Dictionary = _ropes.get(key, {})
	var spr = entry.get("sprite")
	if spr == null or not is_instance_valid(spr):
		return
	var show_rope: bool
	if String(entry["kind"]) == "clothes":
		show_rope = hour >= CLOTHES_DAY_START and hour < CLOTHES_DAY_END and rain < MAX_RAIN_FOR_CLOTHES
	else:
		show_rope = hour >= CLOTHES_DAY_START and hour < VEGGIES_DAY_END
	if (spr as Sprite2D).visible != show_rope and (force or _can_change(float(entry["x"]))):
		(spr as Sprite2D).visible = show_rope

# ─── Çamaşır renkleri ────────────────────────────────────────────────────────

# Her çamaşır parçası (ipten ayrı bağlantılı piksel öbeği) günlük rastgele bir kumaş rengiyle boyanır.
# Parçaların gölgesi (807B7A) ana rengin (A69E9A) göreli parlaklığıyla korunur. İp (0x050403) boyanmaz.
func _tinted_clothes(key: String, rng: RandomNumberGenerator) -> Texture2D:
	var cache_key: String = "%s_%d" % [key, _last_rope_day]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	if not _base_images.has("clothes"):
		var src: Image = CLOTHES_TEXTURE.get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		_base_images["clothes"] = src
	var base: Image = _base_images["clothes"]
	var img: Image = base.duplicate()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var ref_lum: float = Color8(0xA6, 0x9E, 0x9A).get_luminance()
	var labeled: PackedByteArray = PackedByteArray()
	labeled.resize(w * h)
	for y in h:
		for x in w:
			if labeled[y * w + x] == 1:
				continue
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.0 or _is_rope_pixel(c):
				continue
			var tint: Color = HouseFloorVisual.FABRIC_TINTS[rng.randi() % HouseFloorVisual.FABRIC_TINTS.size()]
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or labeled[p.y * w + p.x] == 1:
					continue
				var pc: Color = base.get_pixel(p.x, p.y)
				if pc.a <= 0.0 or _is_rope_pixel(pc):
					continue
				labeled[p.y * w + p.x] = 1
				var factor: float = pc.get_luminance() / ref_lum
				img.set_pixelv(p, Color(clampf(tint.r * factor, 0.0, 1.0), clampf(tint.g * factor, 0.0, 1.0), clampf(tint.b * factor, 0.0, 1.0), pc.a))
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx != 0 or dy != 0:
							stack.append(Vector2i(p.x + dx, p.y + dy))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[cache_key] = tex
	return tex

static func _is_rope_pixel(c: Color) -> bool:
	return c.r8 <= ROPE_PIXEL_MAX and c.g8 <= ROPE_PIXEL_MAX and c.b8 <= ROPE_PIXEL_MAX
