class_name TrapCorridorTraps
extends RefCounted

## Tuzak Geçidi: koridora tema tuzaklarını dizer. Gerçek zindan tuzak sistemini (traps_v2: TileTrapSpawner,
## TrapConfigV2, DungeonThemeStyle) kullanır; level_generator'ın yaptığı gibi her tuzak bir karo yüzeyinin
## ortasına konur. Konumlar çözülmüş karo kümesinden (layout["solid"]) hesaplanır.
##   - Zemin: engeller arasındaki düz boşluklarda 1-5'li gruplar (tür ve grup boyu tema + zorluğa göre)
##   - Tavan: tavana zehir damlası gibi sarkan tuzaklar
##   - Duvar: engel duvarlarının oyuncuya bakan yüzünde ok/top (oyuncu onlara doğru koşar)

const TILE: int = 32
## Başlangıç ve bitiş bölgesinde tuzak yok
const SAFE_START_COLS: int = 30
const SAFE_END_COLS: int = 34
## Engel parçalarının kenarından bu kadar kolon uzak durulur (zıplama/iniş payı)
const SPAN_MARGIN: int = 4


## Tuzakları `parent` altına kurar; yerleştirilen tuzak sayısını döndürür.
static func populate(parent: Node2D, layout: Dictionary, theme: String, level: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var solid: Dictionary = layout["solid"]
	var ground: Array = layout["ground"]
	var spans: Array = layout["spans"]
	var total: int = ground.size()
	var count: int = 0
	# Zorlukla artan sıklık: aralık (kolon) = 20 - zorluk
	var gap_lo: int = maxi(8, 20 - level)
	var gap_hi: int = gap_lo + 8

	# --- Zemin tuzakları: düz boşluklara ---
	var x: int = SAFE_START_COLS
	while x < total - SAFE_END_COLS:
		var trap_type: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.FLOOR, level, theme)
		var group: int = _group_size(trap_type, level, theme, rng)
		if _is_flat_clear(ground, spans, x - 1, x + group + 1):
			var g: int = int(ground[x])
			for i in range(group):
				var pos := Vector2(float((x + i) * TILE + TILE / 2), float(g * TILE))
				count += _spawn(parent, trap_type, TrapConfigV2.SurfaceType.FLOOR, pos, level, theme)
			x += group + rng.randi_range(gap_lo, gap_hi)
		else:
			x += 3

	# --- Tavan tuzakları: tavan satırının alt yüzeyine (dungeon tavanı) ---
	var ceil_row: int = ChaseCorridorBuilder.CEILING_ROWS
	x = SAFE_START_COLS + 10
	while x < total - SAFE_END_COLS:
		if _near_span(spans, x, 3) or not solid.has(Vector2i(x, ceil_row - 1)) or solid.has(Vector2i(x, ceil_row)):
			x += 2
			continue
		var ct: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.CEILING, level, theme)
		var cpos := Vector2(float(x * TILE + TILE / 2), float(ceil_row * TILE))
		count += _spawn(parent, ct, TrapConfigV2.SurfaceType.CEILING, cpos, level, theme)
		x += rng.randi_range(gap_lo + 6, gap_hi + 12)

	# --- Duvar tuzakları: engel duvarlarının oyuncuya (sola) bakan yüzüne ---
	for s in spans:
		var span: Vector2i = s
		if span.x < SAFE_START_COLS or span.y > total - SAFE_END_COLS:
			continue
		if rng.randf() > 0.55 + 0.04 * float(level):
			continue
		var cell: Vector2i = _find_wall_cell(solid, ground, span, rng)
		if cell.x < 0:
			continue
		var wt: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.RIGHT_WALL, level, theme)
		# Duvar tuzağı: karonun sol kenarının ortası (level_generator'daki RIGHT_WALL konumu)
		var wpos := Vector2(float(cell.x * TILE), float(cell.y * TILE + TILE / 2))
		count += _spawn(parent, wt, TrapConfigV2.SurfaceType.RIGHT_WALL, wpos, level, theme)
	return count


static func _group_size(t: TrapConfigV2.TrapType, level: int, theme: String, rng: RandomNumberGenerator) -> int:
	var ov: Vector2i = DungeonThemeStyle.get_trap_group_override(theme, TrapConfigV2.trap_name(t))
	var r: Vector2i = ov if ov != Vector2i.ZERO else TrapConfigV2.get_group_size_range(level)
	return rng.randi_range(maxi(r.x, 1), maxi(r.y, 1))


## [from_col, to_col] aralığında zemin sabit mi ve hiçbir engel parçasına (+ marj) değmiyor mu?
static func _is_flat_clear(ground: Array, spans: Array, from_col: int, to_col: int) -> bool:
	if from_col < 0 or to_col >= ground.size():
		return false
	var g: int = int(ground[from_col])
	for c in range(from_col, to_col + 1):
		if int(ground[c]) != g:
			return false
		if _near_span(spans, c, SPAN_MARGIN):
			return false
	return true


static func _near_span(spans: Array, col: int, margin: int) -> bool:
	for s in spans:
		var sp: Vector2i = s
		if col >= sp.x - margin and col < sp.y + margin:
			return true
	return false


## Parça içinde, solu açık (hava), oyuncunun boyuna yakın yükseklikte bir duvar karosu bulur; yoksa (-1, -1).
static func _find_wall_cell(solid: Dictionary, ground: Array, span: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cx in range(span.x, span.y):
		if cx <= 0 or cx >= ground.size():
			continue
		var g: int = int(ground[cx])
		# Zeminden 1-3 satır yukarıdaki karolar (ok/top oyuncunun göğüs hizasında gelir)
		for dy in range(1, 4):
			var cell := Vector2i(cx, g - dy)
			if solid.has(cell) and not solid.has(Vector2i(cx - 1, cell.y)) and not solid.has(Vector2i(cx - 2, cell.y)):
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi() % candidates.size()]


## level_generator ile aynı yol: TileTrapSpawner düğümü kurulur ve etkinleştirilir.
static func _spawn(parent: Node2D, t: TrapConfigV2.TrapType, surface: TrapConfigV2.SurfaceType, pos: Vector2, level: int, theme: String) -> int:
	var spawner := Node2D.new()
	spawner.set_script(load("res://traps_v2/tile_trap_spawner.gd"))
	spawner.set("trap_type", t)
	spawner.set("surface_type", surface)
	spawner.set("current_level", level)
	spawner.set("dungeon_theme", theme)
	parent.add_child(spawner)
	spawner.global_position = pos
	spawner.call_deferred("activate")
	return 1
