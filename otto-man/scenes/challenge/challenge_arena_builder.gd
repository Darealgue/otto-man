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

const TERRAIN_SET_DUNGEON: int = 0   # "walls"
const TERRAIN_SET_FOREST: int = 1    # "forest_ground"


## Arenayı `root` altına kurar ve yerleşim bilgisini döndürür.
static func build(root: Node2D, biome: String) -> Dictionary:
	var forest: bool = biome == "orman"
	_add_background(root, forest)
	var layer := TileMapLayer.new()
	layer.name = "ArenaTiles"
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
