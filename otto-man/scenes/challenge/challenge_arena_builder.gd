class_name ChallengeArenaBuilder
extends RefCounted

## Challenge odasının tek chunk'lık arenasını kodla kurar: dungeon_master_tileset'in terrain'leriyle
## (zindan: kapalı oda, orman: zemin + açık gökyüzü) düz bir döşeme, yan sınırlar ve arka plan.
## Kamera sabit (1920x1080) olduğundan her şey bu alanın içinde kalır.
## GEÇİCİ SANAT: arka plan düz renk/degrade; kendi arena chunk'larını çizince build() yerine
## sahne yüklemek yeterli (layout sözlüğü aynı kalır).

const TILESET_PATH := "res://Tile set/dungeon_master_tileset.tres"
const TILE: int = 32
const COLS: int = 60
const ROWS: int = 34
## Zemin satırı (zemin yüzeyi y = FLOOR_ROW * 32)
const FLOOR_ROW: int = 29
## Asansör kuyusu: zemin çok aşağıda, asansör buradan yukarı çıkar (~4400 px yükseklik)
const SHAFT_FLOOR_ROW: int = 140
const WALL_COLS: int = 3
## Karoların ekran dışına taşma miktarı (sıra sayısı)
const OVERSCAN: int = 6
const CEILING_ROWS: int = 4

const WALL_BG_PATH := "res://Tile set/Dungeon wall bg2-sheet.png"
const DOOR_PATH := "res://assets/objects/dungeon/door_1.png"
const OBJECT_DIR := "res://assets/objects/dungeon/"

## Zindan renk paletleri (karo tonu, arka plan tuğla tonu, bayrak renk kaydırması; bayrak aslen mavi)
const PALETTES: Array[Dictionary] = [
	{"tile": Color(1.0, 1.0, 1.0), "bg": Color(1.5, 1.5, 1.65), "banner_hue": 0.0},
	{"tile": Color(1.15, 0.85, 0.8), "bg": Color(1.75, 1.25, 1.2), "banner_hue": 0.36},
	{"tile": Color(0.85, 1.05, 0.85), "bg": Color(1.2, 1.6, 1.3), "banner_hue": 0.85},
	{"tile": Color(1.0, 0.85, 1.15), "bg": Color(1.6, 1.3, 1.8), "banner_hue": 0.15},
	{"tile": Color(1.15, 1.0, 0.8), "bg": Color(1.8, 1.5, 1.1), "banner_hue": 0.45},
	{"tile": Color(0.85, 1.0, 1.1), "bg": Color(1.2, 1.6, 1.8), "banner_hue": 0.9},
]

static var _rng := RandomNumberGenerator.new()

const TERRAIN_SET_DUNGEON: int = 0   # "walls"
const TERRAIN_SET_FOREST: int = 1    # "forest_ground"


## Arenayı `root` altına kurar ve yerleşim bilgisini döndürür.
## `shaft` = true: Asansör Arenası için uzun dikey kuyu (yan duvarlar yukarı kadar sürer, en altta zemin).
static func build(root: Node2D, biome: String, shaft: bool = false) -> Dictionary:
	_rng.randomize()
	var forest: bool = biome == "orman"
	var floor_row: int = SHAFT_FLOOR_ROW if shaft else FLOOR_ROW
	var rows: int = floor_row + (ROWS - FLOOR_ROW)
	# Orman: gökyüzü, parallax ve dekor ForestArenaDecorator'dan gelir (düz renk arka plan YOK)
	if not forest:
		_add_background(root, forest)
	var layer := TileMapLayer.new()
	# "TileMapLayer" adı orman dekor kodunun karoları bulması için gerekli (chunk sahneleriyle aynı ad)
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET_PATH) as TileSet
	root.add_child(layer)

	var cells: Array[Vector2i] = []
	# Karolar ekranın (kamera 1920x1080) birkaç sıra dışına taşar: kenar/bitiş çizgisi görünmesin,
	# duvarlar ve zemin ekran dışına devam ediyormuş gibi dursun. Oynanabilir sınırlar değişmez.
	for x in range(-OVERSCAN, COLS + OVERSCAN):
		for y in range(floor_row, rows + OVERSCAN):
			cells.append(Vector2i(x, y))
	if not forest or shaft:
		for y in range(-OVERSCAN, floor_row):
			for x in range(-OVERSCAN, COLS + OVERSCAN):
				if x < WALL_COLS or x >= COLS - WALL_COLS or (y < CEILING_ROWS and not forest):
					cells.append(Vector2i(x, y))
	layer.set_cells_terrain_connect(cells, TERRAIN_SET_FOREST if forest else TERRAIN_SET_DUNGEON, 0)

	var floor_y: float = float(floor_row * TILE)
	var left_x: float = float(WALL_COLS * TILE)
	var right_x: float = float((COLS - WALL_COLS) * TILE)
	if not shaft:
		_add_boundary_walls(root, left_x, right_x, forest)
	if not forest:
		_add_dungeon_dressing(root, layer, left_x, right_x, floor_y, shaft)
	var cam_y: float = floor_y - 388.0 if shaft else 540.0
	return {
		"bounds": Rect2(left_x, floor_y - 1100.0 if shaft else float(CEILING_ROWS * TILE), right_x - left_x, 1100.0 if shaft else floor_y - float(CEILING_ROWS * TILE)),
		"floor_y": floor_y,
		"left_x": left_x,
		"right_x": right_x,
		"center_x": (left_x + right_x) * 0.5,
		"player_spawn": Vector2(left_x + 140.0, floor_y),
		"spawn_left": Vector2(left_x + 40.0, floor_y - 40.0),
		"spawn_right": Vector2(right_x - 40.0, floor_y - 40.0),
		"air_y": floor_y - 420.0,
		"camera_position": Vector2(960.0, cam_y),
	}


## Orman arenasında duvar yok; oyuncu/düşman kaçmasın diye görünmez sınırlar.
## Zindanda da tavan/yan duvarlar karo olduğu için yalnız orman için kurulur.
static func _add_boundary_walls(root: Node2D, left_x: float, right_x: float, forest: bool) -> void:
	if not forest:
		return
	var body := StaticBody2D.new()
	body.name = "BoundaryWalls"
	# WORLD katmanında (hurt/dash/dodge gibi durumlar bunu gerçek duvar sayar, içinden geçilemez).
	# "no_wall_slide" meta'sı: oyuncu çarpışır ama tutunamaz (bkz. wall_slide_state._ray_hits_slideable).
	# Kalın duvar: sert darbe/knockback ince bir duvarın içinden geçip haritanın dışına atmasın.
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.set_meta("no_wall_slide", true)
	var specs := [
		[Vector2(left_x - 200.0, 540.0), Vector2(400.0, 2400.0)],
		[Vector2(right_x + 200.0, 540.0), Vector2(400.0, 2400.0)],
		[Vector2(960.0, 96.0 - 200.0), Vector2(4000.0, 400.0)],
	]
	for spec in specs:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = spec[1]
		shape.shape = rect
		shape.position = spec[0]
		body.add_child(shape)
	root.add_child(body)


## Zindan arenasının iç görünümü: duvar arka planı (gerçek chunk'larla aynı 64 px "Dungeon wall bg2"
## karoları), giriş kapısı ve zemin/tavan dekoru. Hepsi görsel; çarpışma/etkileşim yok.
static func _add_dungeon_dressing(root: Node2D, floor_layer: TileMapLayer, left_x: float, right_x: float, floor_y: float, shaft: bool = false) -> void:
	var ceiling_y: float = float(CEILING_ROWS * TILE)
	# Her girişte rastgele renk paleti: zemin/duvar karoları, arka plan tuğlaları ve bayrak rengi birlikte döner
	var palette: Dictionary = PALETTES[_rng.randi() % PALETTES.size()]
	floor_layer.modulate = palette["tile"]
	# Arka plan duvarı: chunk'lardaki bg katmanıyla aynı karo seti (yalnız düz tuğla karoları)
	var bg_tex := load(WALL_BG_PATH) as Texture2D
	if bg_tex:
		var atlas := TileSetAtlasSource.new()
		atlas.texture = bg_tex
		atlas.texture_region_size = Vector2i(64, 64)
		var variants: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
		for v in variants:
			atlas.create_tile(v)
		var ts := TileSet.new()
		ts.tile_size = Vector2i(64, 64)
		ts.add_source(atlas, 0)
		var bg := TileMapLayer.new()
		bg.name = "WallBackdrop"
		bg.z_index = -10
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.tile_set = ts
		# Tuğlaların hemen hep aynı görünmemesi için sabit tohumlu rastgele varyant
		var rng := RandomNumberGenerator.new()
		rng.seed = 7731
		var x0: int = int(left_x) / 64
		var x1: int = int(ceil(right_x / 64.0))
		var y0: int = int(ceiling_y) / 64
		var y1: int = int(ceil(floor_y / 64.0))
		for cx in range(x0, x1):
			for cy in range(y0, y1):
				bg.set_cell(Vector2i(cx, cy), 0, variants[rng.randi() % variants.size()])
		bg.modulate = palette["bg"]
		root.add_child(bg)

	# Giriş kapısı: oyuncunun doğduğu uçta, kapı (açık) karesi; yalnızca görsel
	var door_tex := load(DOOR_PATH) as Texture2D
	if door_tex:
		var door := Sprite2D.new()
		door.name = "EntranceDoor"
		door.texture = door_tex
		door.hframes = 8
		door.frame = 6
		door.z_index = -4
		door.position = Vector2(left_x + 96.0, floor_y - 96.0)
		root.add_child(door)

	# Dekor her girişte rastgele: tavandan bayraklar, köşelerde ağ, yerde birkaç eşya
	var span: float = right_x - left_x
	# Tavan: 2-4 bayrak, birbirine en az 260 px uzak (bayrak rengi paletle birlikte döner)
	var banner_xs: Array[float] = []
	var banner_count: int = _rng.randi_range(2, 4)
	for i in range(banner_count * 6):
		if banner_xs.size() >= banner_count:
			break
		var bx: float = _rng.randf_range(120.0, span - 120.0)
		var clear := true
		for other in banner_xs:
			if absf(other - bx) < 260.0:
				clear = false
		if clear:
			banner_xs.append(bx)
	for bx in banner_xs:
		_place_decor(root, "banner1", left_x + bx, ceiling_y, floor_y, true, 1.0, false, palette["banner_hue"])
	# Kuyuda: yükseldikçe duvarda bayraklar akıp gitsin (yükseklik boyunca rastgele serpiştirilir)
	if shaft:
		var h: float = floor_y - ceiling_y
		for i in range(int(h / 380.0)):
			var by: float = ceiling_y + 200.0 + float(i) * 380.0 + _rng.randf_range(-60.0, 60.0)
			if by > floor_y - 700.0:
				continue
			_place_decor(root, "banner1", left_x + _rng.randf_range(120.0, span - 120.0), by, floor_y, true, 1.0, false, palette["banner_hue"])
	# Köşe ağları (rastgele açılır/kapanır, yatay çevrilir)
	if _rng.randf() < 0.8:
		_place_decor(root, "web1", left_x + 16.0, ceiling_y, floor_y, true, 2.0, false)
	if _rng.randf() < 0.8:
		_place_decor(root, "web2", right_x - 48.0, ceiling_y, floor_y, true, 2.0, true)
	# Zemin: büyük eşyalar kapıdan ve korunan köylülerin durduğu orta banttan uzak, küçükler her yerde
	var big_pool: Array[String] = ["sculpture1", "sculpture2", "box2", "box3", "box1", "stone1"]
	var small_pool: Array[String] = ["bone1", "bone2", "box1", "stone1"]
	var used: Array[Vector2] = []
	var center_x: float = span * 0.5
	var floor_count: int = _rng.randi_range(5, 8)
	for i in range(floor_count * 8):
		if used.size() >= floor_count:
			break
		var big: bool = _rng.randf() < 0.55
		var name: String = (big_pool if big else small_pool)[_rng.randi() % (big_pool.size() if big else small_pool.size())]
		var fx: float = _rng.randf_range(260.0, span - 60.0)
		if big and absf(fx - center_x) < 260.0:
			continue
		var clear := true
		for u in used:
			if absf(u.x - fx) < 110.0:
				clear = false
		if not clear:
			continue
		used.append(Vector2(fx, 0.0))
		_place_decor(root, name, left_x + fx, ceiling_y, floor_y, false, 1.0, _rng.randf() < 0.5)


## Tek bir dekor sprite'ı yerleştirir (zemine oturur veya tavandan sarkar).
static func _place_decor(root: Node2D, tex_name: String, x: float, ceiling_y: float, floor_y: float,
		hang: bool, scale_factor: float, flip: bool, hue: float = -1.0) -> void:
	var tex := load(OBJECT_DIR + tex_name + ".png") as Texture2D
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.name = "Decor_" + tex_name
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.flip_h = flip
	sprite.z_index = -3
	var h: float = tex.get_height() * scale_factor
	sprite.position = Vector2(x, ceiling_y + h * 0.5) if hang else Vector2(x, floor_y + 4.0 - h * 0.5)
	if hue >= 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = _hue_shader()
		mat.set_shader_parameter("hue_shift", hue)
		sprite.material = mat
	root.add_child(sprite)


static func _hue_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float hue_shift = 0.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(col.rgb);
	hsv.x = fract(hsv.x + hue_shift);
	COLOR = vec4(hsv2rgb(hsv), col.a);
}
"""
	return shader


static func _add_background(root: Node2D, forest: bool) -> void:
	var bg := Node2D.new()
	bg.name = "ArenaBackground"
	bg.z_index = -20
	root.add_child(bg)
	var top := ColorRect.new()
	var bottom := ColorRect.new()
	top.size = Vector2(COLS * TILE, ROWS * TILE * 0.5)
	bottom.size = Vector2(COLS * TILE, ROWS * TILE * 0.5)
	bottom.position = Vector2(0.0, ROWS * TILE * 0.5)
	if forest:
		top.color = Color(0.48, 0.70, 0.86)
		bottom.color = Color(0.58, 0.78, 0.62)
	else:
		top.color = Color(0.14, 0.11, 0.15)
		bottom.color = Color(0.21, 0.16, 0.17)
	bg.add_child(top)
	bg.add_child(bottom)
