class_name ChaseCorridorBuilder
extends RefCounted

## Kovalamaca odasının uzun koşu koridoru. Engeller "şablonlardan" rastgele dizilir; her şablonun bir
## zorluk puanı ve bir yükseklik farkı (delta) vardır: zemin yukarı çıkıp aşağı inebilir (merdiven, uçurum,
## vadi...). İzin verilen puan koridor boyunca yükselir (bkz. docs/CHALLENGE_ROOMS.md).
## Karolar ChallengeArenaBuilder ile aynı tileset/terrain'i kullanır (orman: toprak, zindan: taş).
## Oyuncu en solda başlar, kuşlar soldan gelir; sağdaki kapıya ulaşan kazanır.

const TILE: int = 32
const FLOOR_ROW: int = 29
const CEILING_ROWS: int = 4
const OVERSCAN: int = 6
const START_COLS: int = 22          # başlangıçtaki düz alan
const END_COLS: int = 26            # bitişteki düz alan + kapı
const WALL_COLS: int = 3
## Zemin satırının gidebileceği aralık (tavanla arasında hep geniş boşluk kalsın)
const GROUND_MIN: int = FLOOR_ROW - 9
const GROUND_MAX: int = FLOOR_ROW + 3
const DEEP_ROWS: int = 16           # zeminin altındaki dolgu derinliği

## Şablon: [ad, maliyet, genişlik (kolon), yükseklik farkı (satır; negatif = yukarı)].
## Biçimler `_piece_ops` içinde dikdörtgenlerle tanımlı. Oyuncu ~44 px boyunda, çömelince ~22 px:
## 1 karo (32 px) aralık = kayarak geçilir, 2 karo ayakta geçilir.
const TEMPLATES: Array = [
	# Yatay
	["hurdle1", 1, 2, 0],
	["hurdle2", 1, 2, 0],
	["trench_s", 1, 4, 0],
	["low_ceiling", 1, 10, 0],       # alçak tavan: zıplamadan koş
	["trench_m", 2, 6, 0],
	["wall3", 2, 2, 0],
	["slide_gap", 2, 8, 0],          # tavandan inen blok: kayarak geç
	["stalactites", 2, 16, 0],       # sarkıtlar + aralarında engeller
	["hill", 2, 14, 0],              # merdiven, tavanlı plato, iniş
	["valley", 2, 16, 0],            # basamaklı vadi, dipte engel
	["mound", 2, 18, 0],             # merdivenle tümseğe çık, in
	["sawtooth", 2, 22, 0],          # üç testere dişi tümsek
	["double_hurdle", 3, 8, 0],
	["trench_l", 3, 9, 0],
	["bridge_pit", 3, 14, 0],        # çukurda taş basamaklar
	["pillar_stairs", 3, 16, 0],     # giderek yükselen üç sütun
	["fork_block", 3, 19, 0],        # iki yol: blokun üstü (zıpla) veya altı (kay)
	["chicane", 4, 22, 0],           # zıpla, kay, zıpla ardışık
	["fork_trench", 4, 30, 0],       # iki yol: üstte platformlar, altta derin hendek
	["wall5", 4, 2, 0],
	# Dikey (zemin seviyesi değişir)
	["stairs_up_s", 1, 6, -3],       # kısa merdiven yukarı
	["cliff_drop", 1, 3, 4],         # uçurumdan aşağı atla
	["stairs_down_s", 1, 6, 3],      # kısa merdiven aşağı
	["stairs_up_l", 2, 12, -6],      # uzun merdiven yukarı
	["stairs_down_l", 2, 12, 6],     # uzun merdiven aşağı
	["cliff_up", 2, 3, -4],          # yüksek basamak: zıpla/duvardan çık
	["tunnel_drop", 2, 12, 3],       # tavanlı iniş
	["trench_climb", 3, 12, -3],     # çukurdan sonra merdiven
	["squeeze_ramp", 3, 14, -2],     # basamak, ardından kayarak geçilen tavanlı plato
	["zigzag_climb", 4, 18, -6],     # yüzen platformlarla yukarı tırman
]


## Şablonun karo işlemleri: {"carve": [Rect2i], "solid": [Rect2i]}; x piece başından kolon, y mutlak satır.
## G = piece başındaki zemin satırı. Önce oyma, sonra dolgu uygulanır. T = ekranın üstüne taşan en üst
## satır (tavandan sarkanlar için).
static func _piece_ops(name: String, G: int) -> Dictionary:
	var T: int = -OVERSCAN
	var carve: Array[Rect2i] = []
	var solid: Array[Rect2i] = []
	match name:
		"hurdle1":
			solid.append(Rect2i(0, G - 1, 2, 1))
		"hurdle2":
			solid.append(Rect2i(0, G - 2, 2, 2))
		"wall3":
			solid.append(Rect2i(0, G - 3, 2, 3))
		"wall5":
			solid.append(Rect2i(0, G - 5, 2, 5))
		"trench_s":
			carve.append(Rect2i(0, G, 4, 2))
		"trench_m":
			carve.append(Rect2i(0, G, 6, 2))
		"trench_l":
			carve.append(Rect2i(0, G, 9, 2))
		"double_hurdle":
			solid.append(Rect2i(0, G - 2, 2, 2))
			solid.append(Rect2i(6, G - 2, 2, 2))
		"low_ceiling":
			# Alt kenarı zeminden 2 karo yukarıda (64 px): ayakta geçilir, zıplanamaz
			solid.append(Rect2i(0, T, 10, (G - 2) - T))
		"slide_gap":
			# Alt kenarı zeminden 1 karo yukarıda (32 px): yalnız çömelip kayarak geçilir
			solid.append(Rect2i(0, T, 8, (G - 1) - T))
		"stalactites":
			# 4 sarkıt (alt kenar zeminden 3 karo yukarıda) ve aralarında alçak engeller
			for k in range(4):
				solid.append(Rect2i(k * 4 + 1, T, 1 + (k % 2), (G - 3) - T))
			solid.append(Rect2i(3, G - 1, 2, 1))
			solid.append(Rect2i(11, G - 1, 2, 1))
		"chicane":
			solid.append(Rect2i(0, G - 3, 2, 3))
			solid.append(Rect2i(8, T, 6, (G - 1) - T))
			solid.append(Rect2i(19, G - 2, 2, 2))
		"hill":
			solid.append(Rect2i(0, G - 1, 2, 1))
			solid.append(Rect2i(2, G - 2, 2, 2))
			solid.append(Rect2i(4, G - 3, 6, 3))
			solid.append(Rect2i(4, T, 6, (G - 6) - T))   # platonun üstünde tavan: 2 karo boşluk
			solid.append(Rect2i(10, G - 2, 2, 2))
			solid.append(Rect2i(12, G - 1, 2, 1))
		"valley":
			# Basamaklarla inen vadi; dipte alçak engel, sonra basamaklarla çıkış
			carve.append(Rect2i(0, G, 2, 1))
			carve.append(Rect2i(2, G, 2, 2))
			carve.append(Rect2i(4, G, 8, 3))
			carve.append(Rect2i(12, G, 2, 2))
			carve.append(Rect2i(14, G, 2, 1))
			solid.append(Rect2i(7, G + 1, 2, 2))
		"mound":
			for k in range(4):
				solid.append(Rect2i(2 * k, G - (k + 1), 2, k + 1))
			solid.append(Rect2i(8, G - 4, 4, 4))
			for k in range(3):
				solid.append(Rect2i(12 + 2 * k, G - (3 - k), 2, 3 - k))
		"sawtooth":
			for b in range(3):
				var bx: int = b * 8
				solid.append(Rect2i(bx, G - 1, 2, 1))
				solid.append(Rect2i(bx + 2, G - 2, 2, 2))
				solid.append(Rect2i(bx + 4, G - 1, 2, 1))
		"bridge_pit":
			carve.append(Rect2i(0, G, 14, 2))
			solid.append(Rect2i(2, G, 2, 2))
			solid.append(Rect2i(6, G, 2, 2))
			solid.append(Rect2i(10, G, 2, 2))
		"pillar_stairs":
			solid.append(Rect2i(0, G - 2, 2, 2))
			solid.append(Rect2i(5, G - 3, 2, 3))
			solid.append(Rect2i(10, G - 4, 2, 4))
		"fork_block":
			# Blok: üstü 128 px yüksekte (zıplayıp çık), altında 1 karo aralık (kayarak geç)
			# (12 karo = 384 px: bir kayma (~400 px) tüneli geçmeye yeter, sürünmeye kalmazsın)
			solid.append(Rect2i(3, G - 4, 12, 3))
		"fork_trench":
			# Üst yol: boşluklu platformlar. Alt yol: 6 karo derin hendeğin dibi (engelli), sağda merdivenle çıkış
			carve.append(Rect2i(0, G, 30, 6))
			solid.append(Rect2i(1, G, 4, 2))
			solid.append(Rect2i(8, G, 4, 2))
			solid.append(Rect2i(15, G, 4, 2))
			solid.append(Rect2i(22, G, 3, 2))
			for k in range(5):
				solid.append(Rect2i(25 + k, G + 5 - k, 1, 1 + k))
			solid.append(Rect2i(11, G + 4, 2, 2))
			solid.append(Rect2i(19, G + 4, 2, 2))
		"stairs_up_s":
			for k in range(3):
				solid.append(Rect2i(2 * k, G - (k + 1), 2, k + 1))
		"stairs_up_l":
			for k in range(6):
				solid.append(Rect2i(2 * k, G - (k + 1), 2, k + 1))
		"stairs_down_s":
			for k in range(3):
				carve.append(Rect2i(2 * k, G, 2, k + 1))
		"stairs_down_l":
			for k in range(6):
				carve.append(Rect2i(2 * k, G, 2, k + 1))
		"cliff_up":
			solid.append(Rect2i(0, G - 4, 3, 4))
		"cliff_drop":
			carve.append(Rect2i(0, G, 3, 4))
		"tunnel_drop":
			for k in range(3):
				carve.append(Rect2i(2 * k, G, 2, k + 1))
			solid.append(Rect2i(0, T, 12, (G - 2) - T))
		"trench_climb":
			carve.append(Rect2i(0, G, 4, 2))
			for k in range(3):
				solid.append(Rect2i(6 + 2 * k, G - (k + 1), 2, k + 1))
		"squeeze_ramp":
			# 2 basamak, ardından tavanı 1 karo boşluk bırakan plato: basamakları atla, platoda kay
			for k in range(2):
				solid.append(Rect2i(2 * k, G - (k + 1), 2, k + 1))
			solid.append(Rect2i(4, G - 2, 10, 2))
			solid.append(Rect2i(4, T, 10, (G - 3) - T))
		"zigzag_climb":
			for k in range(3):
				solid.append(Rect2i(7 * k, G - 2 * (k + 1), 4, 2))
	return {"carve": carve, "solid": solid}


static func _apply_rect(cells: Dictionary, r: Rect2i, px: int, add: bool) -> void:
	for x in range(px + r.position.x, px + r.position.x + r.size.x):
		for y in range(r.position.y, r.position.y + r.size.y):
			if add:
				cells[Vector2i(x, y)] = true
			else:
				cells.erase(Vector2i(x, y))


## Boş değilse yalnız bu şablon kullanılır (yalnızca geliştirme/test).
static var dev_force_template: String = ""


## Koridoru `root` altında kurar. Dönen sözlük ChallengeRoom'un beklediği alanları taşır.
static func build(root: Node2D, biome: String, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var forest: bool = biome == "orman"
	var total_cols: int = 260 + difficulty * 16
	var plan: Array = _plan(rng, difficulty, total_cols)

	# Her kolonun zemin satırı (parça içinde başlangıç seviyesi, parçadan sonra bitiş seviyesi)
	var ground: Array[int] = []
	ground.resize(total_cols)
	var cursor: int = 0
	var cur_g: int = FLOOR_ROW
	for piece in plan:
		for c in range(cursor, int(piece["x"])):
			ground[c] = cur_g
		for c in range(int(piece["x"]), int(piece["x"]) + int(piece["w"])):
			ground[c] = int(piece["g"])
		cursor = int(piece["x"]) + int(piece["w"])
		cur_g = int(piece["g2"])
	for c in range(cursor, total_cols):
		ground[c] = cur_g

	if not forest:
		ChallengeArenaBuilder._add_background(root, false)
	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(ChallengeArenaBuilder.TILESET_PATH) as TileSet
	root.add_child(layer)

	var solid: Dictionary = {}
	# Zemin (taşma ile ekran dışına devam eder)
	for x in range(-OVERSCAN - WALL_COLS, total_cols + OVERSCAN + WALL_COLS):
		var g: int = ground[clampi(x, 0, total_cols - 1)]
		for y in range(g, FLOOR_ROW + DEEP_ROWS + OVERSCAN):
			solid[Vector2i(x, y)] = true
	if not forest:
		for x in range(-OVERSCAN - WALL_COLS, total_cols + OVERSCAN + WALL_COLS):
			for y in range(-OVERSCAN, CEILING_ROWS):
				solid[Vector2i(x, y)] = true
		# Başlangıç ve bitiş duvarı
		for y in range(-OVERSCAN, FLOOR_ROW):
			for x in range(-OVERSCAN - WALL_COLS, 0):
				solid[Vector2i(x, y)] = true
			for x in range(total_cols, total_cols + OVERSCAN + WALL_COLS):
				solid[Vector2i(x, y)] = true
	var obstacle_spans: Array[Vector2i] = []
	for piece in plan:
		var px: int = int(piece["x"])
		var w: int = int(piece["w"])
		obstacle_spans.append(Vector2i(px, px + w))
		var ops: Dictionary = _piece_ops(String(piece["name"]), int(piece["g"]))
		for r in ops["carve"]:
			_apply_rect(solid, r, px, false)
		for r in ops["solid"]:
			_apply_rect(solid, r, px, true)
	var cells: Array[Vector2i] = []
	for c in solid.keys():
		cells.append(c)
	layer.set_cells_terrain_connect(cells, ChallengeArenaBuilder.TERRAIN_SET_FOREST if forest else ChallengeArenaBuilder.TERRAIN_SET_DUNGEON, 0)

	var floor_y: float = float(FLOOR_ROW * TILE)
	var length: float = float(total_cols * TILE)
	var end_x: float = length - float(END_COLS - 8) * float(TILE)
	if forest:
		_add_forest_bounds(root, length)
	else:
		_add_dungeon_dressing(root, layer, rng, length, ground, obstacle_spans)
	return {
		"bounds": Rect2(0.0, float(CEILING_ROWS * TILE), length, floor_y - float(CEILING_ROWS * TILE)),
		"floor_y": floor_y,
		"length": length,
		"end_x": end_x,
		"player_spawn": Vector2(300.0, floor_y),
		"camera_position": Vector2(960.0, 540.0),
		"center_x": length * 0.5,
		"plan": plan,
		"ground": ground,
	}


## Engel planı: [{name, x, w, cost, g, g2}] (x/w kolon, g/g2 parça öncesi/sonrası zemin satırı).
## İzin verilen maliyet koridor boyunca artar; zemin sınırlarda kalır ve ortaya doğru geri çekilir.
static func _plan(rng: RandomNumberGenerator, difficulty: int, total_cols: int) -> Array:
	var out: Array = []
	var limit: int = total_cols - END_COLS
	var G: int = FLOOR_ROW
	# Geliştirme kancası: tek bir şablonu art arda diz (görsel/oynanış denemesi için)
	if not dev_force_template.is_empty():
		for t in TEMPLATES:
			if String(t[0]) == dev_force_template:
				var fx: int = START_COLS
				while fx + int(t[2]) < limit and G + int(t[3]) >= GROUND_MIN and G + int(t[3]) <= GROUND_MAX:
					out.append({"name": t[0], "x": fx, "w": int(t[2]), "cost": int(t[1]), "g": G, "g2": G + int(t[3])})
					G += int(t[3])
					fx += int(t[2]) + 14
				return out
	var cap_max: int = 2 + difficulty / 2
	var x: int = START_COLS
	var recent: Array[String] = []
	while x < limit:
		var progress: float = float(x) / float(maxi(limit, 1))
		var cap: int = clampi(1 + int(progress * float(cap_max + 1)), 1, 4)
		var pool: Array = []
		for t in TEMPLATES:
			var d: int = int(t[3])
			if int(t[1]) > cap or String(t[0]) in recent:
				continue
			if G + d < GROUND_MIN or G + d > GROUND_MAX:
				continue
			pool.append(t)
			# Sonlara doğru pahalılar daha sık; zemin uçlara kaydıysa ortaya döndüren şablonlar öncelikli
			if int(t[1]) >= cap - 1 and progress > 0.35:
				pool.append(t)
			if (G < FLOOR_ROW - 3 and d > 0) or (G > FLOOR_ROW + 1 and d < 0):
				pool.append(t)
				pool.append(t)
			# Dikey çeşit: yükselti/alçalma şablonları biraz öne çıkar
			if d != 0:
				pool.append(t)
		var t: Array = pool[rng.randi() % pool.size()]
		if x + int(t[2]) >= limit:
			break
		recent.append(String(t[0]))
		if recent.size() > 3:
			recent.pop_front()
		var g2: int = G + int(t[3])
		out.append({"name": t[0], "x": x, "w": int(t[2]), "cost": int(t[1]), "g": G, "g2": g2})
		G = g2
		x += int(t[2]) + rng.randi_range(maxi(8, 15 - difficulty), 19)
	return out


static func _add_forest_bounds(root: Node2D, length: float) -> void:
	var body := StaticBody2D.new()
	body.name = "BoundaryWalls"
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.set_meta("no_wall_slide", true)
	for spec in [
		[Vector2(-200.0, 540.0), Vector2(400.0, 4800.0)],
		[Vector2(length + 200.0, 540.0), Vector2(400.0, 4800.0)],
		[Vector2(length * 0.5, -304.0), Vector2(length + 1000.0, 400.0)],
	]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = spec[1]
		shape.shape = rect
		shape.position = spec[0]
		body.add_child(shape)
	root.add_child(body)


## Zindan koridoru: arka plan duvarı + paletli karolar, giriş/çıkış kapıları, bayrak ve eşya dekoru.
static func _add_dungeon_dressing(root: Node2D, layer: TileMapLayer, rng: RandomNumberGenerator,
		length: float, ground: Array[int], spans: Array[Vector2i]) -> void:
	var palette: Dictionary = ChallengeArenaBuilder.PALETTES[rng.randi() % ChallengeArenaBuilder.PALETTES.size()]
	layer.modulate = palette["tile"]
	var bg_tex := load(ChallengeArenaBuilder.WALL_BG_PATH) as Texture2D
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
		bg.modulate = palette["bg"]
		for cx in range(0, int(length) / 64 + 1):
			for cy in range(CEILING_ROWS / 2, (FLOOR_ROW + DEEP_ROWS) / 2):
				bg.set_cell(Vector2i(cx, cy), 0, variants[rng.randi() % variants.size()])
		root.add_child(bg)
	var door_tex := load(ChallengeArenaBuilder.DOOR_PATH) as Texture2D
	if door_tex:
		var exit_x: float = length - float(END_COLS - 8) * float(TILE) + 220.0
		for entry in [[140.0, 6], [exit_x, 0]]:
			var door := Sprite2D.new()
			door.name = "Door"
			door.texture = door_tex
			door.hframes = 8
			door.frame = int(entry[1])
			door.z_index = -4
			var dcol: int = clampi(int(float(entry[0]) / float(TILE)), 0, ground.size() - 1)
			door.position = Vector2(float(entry[0]), float(ground[dcol] * TILE) - 96.0)
			root.add_child(door)
	var ceiling_y: float = float(CEILING_ROWS * TILE)
	var bx: float = 500.0
	while bx < length - 400.0:
		ChallengeArenaBuilder._place_decor(root, "banner1", bx, ceiling_y, 0.0, true, 1.0, false, palette["banner_hue"])
		bx += rng.randf_range(520.0, 1100.0)
	# Zemin dekoru yalnızca engellerden uzak düz yerlere; yükseklik o kolonun zemin seviyesinden
	var fx: float = 700.0
	while fx < length - 700.0:
		var col: int = int(fx) / TILE
		var blocked: bool = false
		for s in spans:
			if col >= s.x - 3 and col <= s.y + 3:
				blocked = true
		if not blocked:
			var names: Array[String] = ["bone1", "bone2", "box1", "stone1", "sculpture1", "sculpture2", "box2"]
			ChallengeArenaBuilder._place_decor(root, names[rng.randi() % names.size()], fx, ceiling_y, float(ground[col] * TILE), false, 1.0, rng.randf() < 0.5)
		fx += rng.randf_range(260.0, 620.0)
