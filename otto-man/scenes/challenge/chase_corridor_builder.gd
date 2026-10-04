class_name ChaseCorridorBuilder
extends RefCounted

## Kovalamaca odasının uzun yatay koşu koridoru. Engeller "şablonlardan" rastgele dizilir; her şablonun
## bir zorluk puanı vardır, koridor boyunca izin verilen puan yükselir (bkz. docs/CHALLENGE_ROOMS.md).
## Karolar ChallengeArenaBuilder ile aynı tileset/terrain'i kullanır (orman: toprak, zindan: taş).
## Oyuncu en solda başlar, kuşlar soldan gelir; sağdaki kapıya ulaşan kazanır.

const TILE: int = 32
const FLOOR_ROW: int = 29
const CEILING_ROWS: int = 4
const OVERSCAN: int = 6
const START_COLS: int = 22          # başlangıçtaki düz alan
const END_COLS: int = 26            # bitişteki düz alan + kapı
const WALL_COLS: int = 3

## Şablon: [ad, maliyet, genişlik (kolon), yükseklik/derinlik]
const TEMPLATES: Array = [
	["hurdle1", 1, 2, 1],
	["hurdle2", 1, 2, 2],
	["trench_s", 1, 4, 2],
	["trench_m", 2, 6, 2],
	["wall3", 2, 2, 3],
	["double_hurdle", 3, 8, 2],
	["trench_l", 3, 9, 2],
	["wall5", 4, 2, 5],
]


## Koridoru `root` altında kurar. Dönen sözlük ChallengeRoom'un beklediği alanları taşır.
static func build(root: Node2D, biome: String, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var forest: bool = biome == "orman"
	var total_cols: int = 260 + difficulty * 16
	var plan: Array = _plan(rng, difficulty, total_cols)

	if not forest:
		ChallengeArenaBuilder._add_background(root, false)
	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(ChallengeArenaBuilder.TILESET_PATH) as TileSet
	root.add_child(layer)

	var solid: Dictionary = {}
	# Zemin (taşma ile ekran dışına devam eder)
	for x in range(-OVERSCAN - WALL_COLS, total_cols + OVERSCAN + WALL_COLS):
		for y in range(FLOOR_ROW, FLOOR_ROW + 8 + OVERSCAN):
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
		var h: int = int(piece["h"])
		obstacle_spans.append(Vector2i(px, px + w))
		match String(piece["name"]):
			"hurdle1", "hurdle2", "wall3", "wall5":
				for x in range(px, px + w):
					for y in range(FLOOR_ROW - h, FLOOR_ROW):
						solid[Vector2i(x, y)] = true
			"trench_s", "trench_m", "trench_l":
				for x in range(px, px + w):
					for y in range(FLOOR_ROW, FLOOR_ROW + h):
						solid.erase(Vector2i(x, y))
			"double_hurdle":
				for x in range(px, px + 2):
					for y in range(FLOOR_ROW - h, FLOOR_ROW):
						solid[Vector2i(x, y)] = true
				for x in range(px + w - 2, px + w):
					for y in range(FLOOR_ROW - h, FLOOR_ROW):
						solid[Vector2i(x, y)] = true
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
		_add_dungeon_dressing(root, layer, rng, length, floor_y, obstacle_spans)
	return {
		"bounds": Rect2(0.0, float(CEILING_ROWS * TILE), length, floor_y - float(CEILING_ROWS * TILE)),
		"floor_y": floor_y,
		"length": length,
		"end_x": end_x,
		"player_spawn": Vector2(300.0, floor_y),
		"camera_position": Vector2(960.0, 540.0),
		"center_x": length * 0.5,
		"plan": plan,
	}


## Engel planı: [{name, x, w, h}] (x/w kolon). İzin verilen maliyet koridor boyunca artar.
static func _plan(rng: RandomNumberGenerator, difficulty: int, total_cols: int) -> Array:
	var out: Array = []
	var cap_max: int = 1 + difficulty / 2
	var x: int = START_COLS
	var limit: int = total_cols - END_COLS
	while x < limit:
		var progress: float = float(x) / float(maxi(limit, 1))
		var cap: int = clampi(1 + int(progress * float(cap_max)), 1, 4)
		var pool: Array = []
		for t in TEMPLATES:
			if int(t[1]) <= cap:
				pool.append(t)
		var t: Array = pool[rng.randi() % pool.size()]
		if x + int(t[2]) >= limit:
			break
		out.append({"name": t[0], "x": x, "w": int(t[2]), "h": int(t[3]), "cost": int(t[1])})
		x += int(t[2]) + rng.randi_range(maxi(9, 17 - difficulty), 21)
	return out


static func _add_forest_bounds(root: Node2D, length: float) -> void:
	var body := StaticBody2D.new()
	body.name = "BoundaryWalls"
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.set_meta("no_wall_slide", true)
	for spec in [
		[Vector2(-200.0, 540.0), Vector2(400.0, 2400.0)],
		[Vector2(length + 200.0, 540.0), Vector2(400.0, 2400.0)],
		[Vector2(length * 0.5, -104.0), Vector2(length + 1000.0, 400.0)],
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
		length: float, floor_y: float, spans: Array[Vector2i]) -> void:
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
			for cy in range(CEILING_ROWS / 2, int(ceil(floor_y / 64.0))):
				bg.set_cell(Vector2i(cx, cy), 0, variants[rng.randi() % variants.size()])
		root.add_child(bg)
	var door_tex := load(ChallengeArenaBuilder.DOOR_PATH) as Texture2D
	if door_tex:
		for entry in [[140.0, 6], [length - float(END_COLS - 8) * float(TILE) + 220.0, 0]]:
			var door := Sprite2D.new()
			door.name = "Door"
			door.texture = door_tex
			door.hframes = 8
			door.frame = int(entry[1])
			door.z_index = -4
			door.position = Vector2(float(entry[0]), floor_y - 96.0)
			root.add_child(door)
	var ceiling_y: float = float(CEILING_ROWS * TILE)
	var bx: float = 500.0
	while bx < length - 400.0:
		ChallengeArenaBuilder._place_decor(root, "banner1", bx, ceiling_y, floor_y, true, 1.0, false, palette["banner_hue"])
		bx += rng.randf_range(520.0, 1100.0)
	# Zemin dekoru yalnızca engellerden uzak düz yerlere
	var fx: float = 700.0
	while fx < length - 700.0:
		var col: int = int(fx) / TILE
		var blocked: bool = false
		for s in spans:
			if col >= s.x - 3 and col <= s.y + 3:
				blocked = true
		if not blocked:
			var names: Array[String] = ["bone1", "bone2", "box1", "stone1", "sculpture1", "sculpture2", "box2"]
			ChallengeArenaBuilder._place_decor(root, names[rng.randi() % names.size()], fx, ceiling_y, floor_y, false, 1.0, rng.randf() < 0.5)
		fx += rng.randf_range(260.0, 620.0)
