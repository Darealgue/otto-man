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
const WALL_COLS: int = 3
const CEILING_ROWS: int = 4

const WALL_BG_PATH := "res://Tile set/Dungeon wall bg2-sheet.png"
const DOOR_PATH := "res://assets/objects/dungeon/door_1.png"
const OBJECT_DIR := "res://assets/objects/dungeon/"

const TERRAIN_SET_DUNGEON: int = 0   # "walls"
const TERRAIN_SET_FOREST: int = 1    # "forest_ground"


## Arenayı `root` altına kurar ve yerleşim bilgisini döndürür.
static func build(root: Node2D, biome: String) -> Dictionary:
	var forest: bool = biome == "orman"
	# Orman: gökyüzü, parallax ve dekor ForestArenaDecorator'dan gelir (düz renk arka plan YOK)
	if not forest:
		_add_background(root, forest)
	var layer := TileMapLayer.new()
	# "TileMapLayer" adı orman dekor kodunun karoları bulması için gerekli (chunk sahneleriyle aynı ad)
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET_PATH) as TileSet
	root.add_child(layer)

	var cells: Array[Vector2i] = []
	for x in range(COLS):
		for y in range(FLOOR_ROW, ROWS):
			cells.append(Vector2i(x, y))
	if not forest:
		for y in range(0, FLOOR_ROW):
			for x in range(COLS):
				if x < WALL_COLS or x >= COLS - WALL_COLS or y < CEILING_ROWS:
					cells.append(Vector2i(x, y))
	layer.set_cells_terrain_connect(cells, TERRAIN_SET_FOREST if forest else TERRAIN_SET_DUNGEON, 0)

	var floor_y: float = float(FLOOR_ROW * TILE)
	var left_x: float = float(WALL_COLS * TILE)
	var right_x: float = float((COLS - WALL_COLS) * TILE)
	_add_boundary_walls(root, left_x, right_x, forest)
	if not forest:
		_add_dungeon_dressing(root, left_x, right_x, floor_y)
	return {
		"bounds": Rect2(left_x, float(CEILING_ROWS * TILE), right_x - left_x, floor_y - float(CEILING_ROWS * TILE)),
		"floor_y": floor_y,
		"center_x": (left_x + right_x) * 0.5,
		"player_spawn": Vector2(left_x + 140.0, floor_y),
		"spawn_left": Vector2(left_x + 40.0, floor_y - 40.0),
		"spawn_right": Vector2(right_x - 40.0, floor_y - 40.0),
		"air_y": floor_y - 420.0,
		"camera_position": Vector2(960.0, 540.0),
	}


## Orman arenasında duvar yok; oyuncu/düşman kaçmasın diye görünmez sınırlar.
## Zindanda da tavan/yan duvarlar karo olduğu için yalnız orman için kurulur.
static func _add_boundary_walls(root: Node2D, left_x: float, right_x: float, forest: bool) -> void:
	if not forest:
		return
	var body := StaticBody2D.new()
	body.name = "BoundaryWalls"
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var specs := [
		[Vector2(left_x - 16.0, 540.0), Vector2(32.0, 1400.0)],
		[Vector2(right_x + 16.0, 540.0), Vector2(32.0, 1400.0)],
		[Vector2(960.0, 96.0 - 16.0), Vector2(2000.0, 32.0)],
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
static func _add_dungeon_dressing(root: Node2D, left_x: float, right_x: float, floor_y: float) -> void:
	var ceiling_y: float = float(CEILING_ROWS * TILE)
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
		bg.modulate = Color(1.5, 1.5, 1.65)
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

	# Dekor: [yol, x ofseti (sol duvardan), yer (0 = zemin, 1 = tavandan asılı), ölçek]
	var items: Array = [
		["banner1", 330.0, 1, 1.0],
		["banner1", 760.0, 1, 1.0],
		["banner1", 1180.0, 1, 1.0],
		["banner1", 1560.0, 1, 1.0],
		["web1", 4.0, 1, 2.0],
		["web2", 1636.0, 1, 2.0],
		["sculpture1", 560.0, 0, 1.0],
		["sculpture2", 1400.0, 0, 1.0],
		["box2", 250.0, 0, 1.0],
		["box1", 1520.0, 0, 1.0],
		["box3", 1630.0, 0, 1.0],
		["stone1", 690.0, 0, 1.0],
		["bone1", 940.0, 0, 1.2],
		["bone2", 1100.0, 0, 1.2],
		["bone1", 1300.0, 0, 1.0],
	]
	for item in items:
		var tex := load(OBJECT_DIR + String(item[0]) + ".png") as Texture2D
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.name = "Decor_" + String(item[0])
		var s: float = float(item[3])
		sprite.scale = Vector2(s, s)
		sprite.z_index = -3
		var h: float = tex.get_height() * s
		var px: float = left_x + float(item[1])
		if int(item[2]) == 1:
			sprite.position = Vector2(px, ceiling_y + h * 0.5)
		else:
			sprite.position = Vector2(px, floor_y + 4.0 - h * 0.5)
		root.add_child(sprite)


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
