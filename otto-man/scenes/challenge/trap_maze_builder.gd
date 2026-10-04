class_name TrapMazeBuilder
extends RefCounted

## Tuzak Geçidi labirenti: odanın iç hacmi rastgele bloklarla (2x2, 2x6, L, T, birleşik kümeler) dolar;
## oyuncu bu bloklar arasından sağa doğru yolunu bulur. Blokların her yüzü tuzakla donatılır (bkz. populate).
## Yol garantisi: oyuncu hareketi (yürü/zıpla/düş) basitleştirilmiş bir grafikte aranır; yol yoksa yeniden üretilir.
## Rota üzerindeki duruş noktalarının bir kısmı tuzaksız bırakılır (güvenli nefes alma noktaları).

const TILE: int = 32
const FLOOR_ROW: int = 29
const CEILING_ROWS: int = 4
const OVERSCAN: int = 6
const START_COLS: int = 12      # soldaki boş başlangıç alanı
const END_COLS: int = 26        # sağdaki boş bitiş alanı (kapı)
const WALL_COLS: int = 3
## Zıplama sınırları (karo): zıplama + çift zıplamayla çıkılabilen yükseklik ve yatay erişim
## Yol boyunca ayak karosunun üstünde açık kalan satır sayısı (baş boşluğu)
const HEAD_ROWS: int = 3
const MAX_RISE: int = 6
const MAX_REACH: int = 7

## Blok şekilleri için dikdörtgen boyları (genişlik, yükseklik)
const RECTS: Array = [[2, 2], [2, 6], [6, 2], [3, 3], [2, 4], [4, 2], [4, 4], [2, 3], [5, 2]]


## Labirenti kurar. Dönen sözlük ChallengeRoom'un beklediği alanları taşır.
static func build(root: Node2D, difficulty: int, theme: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cols: int = 60 + 32 * clampi(difficulty, 1, 9)
	# Önce garantili yol oyulur (iniş çıkışlı, zıplamayla geçilebilen basamaklı şerit), sonra kalan boşluk
	# rastgele bloklarla doldurulur: yol labirentin içinde kıvrılır, çevresi çıkmaz sokaklarla doludur.
	var carved: Dictionary = _carve_route(rng, cols)
	var air: Dictionary = carved["air"]
	var blocks: Dictionary = _generate(rng, cols, 0.24, air, CEILING_ROWS, 0.22)
	# Zemin katı: alt satırlar da yoğun bloklarla dolar; düz yürüyerek geçilecek zemin yolu kalmaz, yalnız oyulan yol açık
	var floor_mass: Dictionary = _generate(rng, cols, 0.7, air, FLOOR_ROW - 8, 0.6)
	for c in floor_mass.keys():
		blocks[c] = true
	for c in carved["platform"].keys():
		blocks[c] = true
	var route: Array[Vector2i] = carved["route"]
	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(ChallengeArenaBuilder.TILESET_PATH) as TileSet
	root.add_child(layer)
	ChallengeArenaBuilder._add_background(root, false)

	var solid: Dictionary = {}
	for x in range(-OVERSCAN - WALL_COLS, cols + OVERSCAN + WALL_COLS):
		for y in range(FLOOR_ROW, FLOOR_ROW + 8 + OVERSCAN):
			solid[Vector2i(x, y)] = true          # zemin
		for y in range(-OVERSCAN, CEILING_ROWS):
			solid[Vector2i(x, y)] = true          # tavan
	for y in range(-OVERSCAN, FLOOR_ROW):
		for x in range(-OVERSCAN - WALL_COLS, 0):
			solid[Vector2i(x, y)] = true          # sol duvar
		for x in range(cols, cols + OVERSCAN + WALL_COLS):
			solid[Vector2i(x, y)] = true          # sağ duvar
	for c in blocks.keys():
		solid[c] = true
	var cells: Array[Vector2i] = []
	for c in solid.keys():
		cells.append(c)
	layer.set_cells_terrain_connect(cells, ChallengeArenaBuilder.TERRAIN_SET_DUNGEON, 0)

	var floor_y: float = float(FLOOR_ROW * TILE)
	var length: float = float(cols * TILE)
	# Arka plan, kapılar ve bayraklar: koridorun dekor koduyla (zemin sabit, engel parçası yok)
	var ground: Array[int] = []
	ground.resize(cols)
	ground.fill(FLOOR_ROW)
	var no_spans: Array[Vector2i] = []
	ChaseCorridorBuilder._add_dungeon_dressing(root, layer, rng, length, ground, no_spans, theme, true)
	return {
		"bounds": Rect2(0.0, float(CEILING_ROWS * TILE), length, floor_y - float(CEILING_ROWS * TILE)),
		"floor_y": floor_y,
		"length": length,
		"end_x": length - float(END_COLS - 8) * float(TILE),
		"player_spawn": Vector2(150.0, floor_y),
		"camera_position": Vector2(960.0, 540.0),
		"fixed_cam_y": 540.0,
		"center_x": length * 0.5,
		"cols": cols,
		"blocks": blocks,
		"route": route,
	}


# --- Blok üretimi -------------------------------------------------------------------------------

## İç hacmi (START_COLS .. cols-END_COLS, tavan ile zemin arası) hedef doluluğa kadar rastgele şekillerle doldurur.
static func _generate(rng: RandomNumberGenerator, cols: int, density: float, air: Dictionary, y_min: int, merge_chance: float) -> Dictionary:
	var blocks: Dictionary = {}
	var x0: int = START_COLS
	var x1: int = cols - END_COLS
	var y0: int = y_min
	var y1: int = FLOOR_ROW - 1
	var area: int = (x1 - x0) * (y1 - y0 + 1)
	var target: int = int(float(area) * density)
	var guard: int = 0
	while blocks.size() < target and guard < 4000:
		guard += 1
		var cells: Array[Vector2i] = _random_shape(rng)
		var bounds := _bounds(cells)
		var ox: int = rng.randi_range(x0, maxi(x0, x1 - bounds.size.x))
		var oy: int = rng.randi_range(y0, maxi(y0, y1 - bounds.size.y + 1))
		var placed: Array[Vector2i] = []
		var blocked: bool = false
		for c in cells:
			var p := Vector2i(c.x + ox - bounds.position.x, c.y + oy - bounds.position.y)
			if p.x < x0 or p.x >= x1 or p.y < y0 or p.y > y1:
				continue
			if air.has(p):
				blocked = true   # yolun içine giren şekil tümden atılır (şekil bütünlüğü bozulmasın)
				break
			placed.append(p)
		if not blocked:
			# Çoğu şekil diğerlerine 2 karodan fazla uzak durur (ayrı bloklar); %22'si birleşik kümelere katılır
			var touching: bool = false
			for p in placed:
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if blocks.has(Vector2i(p.x + dx, p.y + dy)):
							touching = true
			if touching and rng.randf() > merge_chance:
				continue
			for p in placed:
				blocks[p] = true
	# 1 karolu aralıkları (oyuncunun sığamayacağı yarıklar) doldur
	for pass_i in range(2):
		for x in range(x0, x1):
			for y in range(y0, y1 + 1):
				var c := Vector2i(x, y)
				if blocks.has(c) or air.has(c):
					continue
				var left: bool = blocks.has(Vector2i(x - 1, y)) or x - 1 < x0
				var right: bool = blocks.has(Vector2i(x + 1, y)) or x + 1 >= x1
				var up: bool = blocks.has(Vector2i(x, y - 1)) or y - 1 < y0
				var down: bool = blocks.has(Vector2i(x, y + 1)) or y + 1 > y1
				if (left and right and x - 1 >= x0 and x + 1 < x1) or (up and down):
					blocks[c] = true
	return blocks


## Rastgele bir şekil: dikdörtgen, L ya da T (hepsi en az 2 karo kalınlığında).
static func _random_shape(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var kind: int = rng.randi() % 10
	if kind < 6:
		var r: Array = RECTS[rng.randi() % RECTS.size()]
		_add_rect(out, 0, 0, int(r[0]), int(r[1]))
	elif kind < 8:
		# L: yatay kol + dikey kol köşede birleşir
		var a: int = rng.randi_range(4, 7)
		var b: int = rng.randi_range(4, 7)
		_add_rect(out, 0, 0, a, 2)
		_add_rect(out, 0, 0, 2, b)
		if rng.randf() < 0.5:
			_mirror_x(out, a)
		if rng.randf() < 0.5:
			_mirror_y(out, b)
	else:
		# T: yatay çubuk + ortadan aşağı ya da yukarı sap
		var w: int = rng.randi_range(5, 8)
		var h: int = rng.randi_range(3, 6)
		_add_rect(out, 0, 0, w, 2)
		_add_rect(out, w / 2 - 1, 2, 2, h)
		if rng.randf() < 0.5:
			_mirror_y(out, h + 2)
	return out


static func _add_rect(out: Array[Vector2i], x: int, y: int, w: int, h: int) -> void:
	for i in range(w):
		for j in range(h):
			var c := Vector2i(x + i, y + j)
			if c not in out:
				out.append(c)


static func _mirror_x(cells: Array[Vector2i], width: int) -> void:
	for i in range(cells.size()):
		cells[i] = Vector2i(width - 1 - cells[i].x, cells[i].y)


static func _mirror_y(cells: Array[Vector2i], height: int) -> void:
	for i in range(cells.size()):
		cells[i] = Vector2i(cells[i].x, height - 1 - cells[i].y)


static func _bounds(cells: Array[Vector2i]) -> Rect2i:
	var mn := Vector2i(1000000, 1000000)
	var mx := Vector2i(-1000000, -1000000)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)


# --- Garantili yol -------------------------------------------------------------------------------

## Soldan sağa iniş çıkışlı bir "ayak yolu" oyar. Her sütunun ayak satırı (ys) segmentler halinde 1-3 satır
## yükselip alçalır (yukarı basamak = zıplama, aşağı = düşüş; ikisi de oyuncu için kolay). Dönen sözlük:
##   air:      yol boyunca boş kalacak hücreler (5 satır baş boşluğu + basamak geçişleri) -> bloklar buraya giremez
##   platform: yolun altındaki 2 karo kalınlığında zemin (zemin satırında yoksa) -> bloklara eklenir
##   route:    ayak karoları (soldan sağa)
static func _carve_route(rng: RandomNumberGenerator, cols: int) -> Dictionary:
	var air: Dictionary = {}
	var platform: Dictionary = {}
	var route: Array[Vector2i] = []
	var x_end: int = cols - END_COLS + 2
	var ys: Array[int] = []
	ys.resize(cols)
	ys.fill(FLOOR_ROW - 1)
	var y: int = FLOOR_ROW - 1
	var x: int = START_COLS
	# Yol, tavan ve zemin bandı arasında zikzak yapar: hedef bandı (yüksek ya da alçak) seçer, oraya basamaklarla
	# ilerler, varınca diğer banda döner. Düz zemin boyunca yürüyerek geçilemez.
	var low_band := Vector2i(FLOOR_ROW - 6, FLOOR_ROW - 1)
	var high_band := Vector2i(CEILING_ROWS + 7, CEILING_ROWS + 12)
	var target: int = rng.randi_range(high_band.x, high_band.y)
	while x < x_end:
		var seg: int = rng.randi_range(3, 6)
		var delta: int
		if x >= x_end - 18:
			delta = mini(3, FLOOR_ROW - 1 - y)   # son 18 sütunda zemine inilir (çıkış kapısı zeminde)
		else:
			if absi(target - y) <= 1:
				# Varıldı: karşı banda yönel
				var go_high: bool = target > (CEILING_ROWS + FLOOR_ROW) / 2
				target = rng.randi_range(high_band.x, high_band.y) if go_high else rng.randi_range(low_band.x, low_band.y)
			var dir: int = signi(target - y)
			delta = dir * rng.randi_range(1, 3)
		y = clampi(y + delta, CEILING_ROWS + 6, FLOOR_ROW - 1)
		for i in range(seg):
			if x + i < cols:
				ys[x + i] = y
		x += seg
	for cx in range(START_COLS / 2, cols):
		var cy: int = ys[cx]
		route.append(Vector2i(cx, cy))
		for r in range(cy - HEAD_ROWS, cy + 1):
			air[Vector2i(cx, r)] = true
		# Basamak geçişleri: yukarı çıkarken önceki sütunun üstü, aşağı inerken bu sütunun üstü açık kalır
		if cx > START_COLS / 2:
			var py: int = ys[cx - 1]
			if cy < py:
				for r in range(cy - HEAD_ROWS, py + 1):
					air[Vector2i(cx - 1, r)] = true
			elif cy > py:
				for r in range(py - HEAD_ROWS, cy + 1):
					air[Vector2i(cx, r)] = true
		for r in [cy + 1, cy + 2]:
			if r < FLOOR_ROW and cx >= START_COLS:
				platform[Vector2i(cx, r)] = true
	return {"air": air, "platform": platform, "route": route}


## Ayak karosu (x, y): kendisi ve üstü boş, altı dolu (oyuncu ~44 px: 2 satır baş boşluğu).
static func _is_solid(blocks: Dictionary, c: Vector2i, cols: int) -> bool:
	if c.y < CEILING_ROWS or c.y >= FLOOR_ROW or c.x < 0 or c.x >= cols:
		return true
	return blocks.has(c)


static func _standing(blocks: Dictionary, x: int, y: int, cols: int) -> bool:
	if y < CEILING_ROWS + 1 or y >= FLOOR_ROW:
		return false
	return not _is_solid(blocks, Vector2i(x, y), cols) and not _is_solid(blocks, Vector2i(x, y - 1), cols) \
			and _is_solid(blocks, Vector2i(x, y + 1), cols)

# --- Tuzak yerleşimi -----------------------------------------------------------------------------

## Blokların ve zemin/tavanın her açık yüzüne tema tuzakları koyar. Rota üzerindeki duruş noktalarının bir kısmı
## (ve komşuları) zemin tuzağından muaf tutulur: oyuncu orada nefes alır.
static func populate(parent: Node2D, layout: Dictionary, theme: String, level: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var blocks: Dictionary = layout["blocks"]
	var cols: int = int(layout["cols"])
	var route: Array = layout["route"]
	var safe: Dictionary = {}
	for i in range(route.size()):
		if i % 4 == 0:
			var r: Vector2i = route[i]
			for dx in range(-1, 2):
				safe[Vector2i(r.x + dx, r.y)] = true
	# Rota hücreleri ve çevresi daha yoğun tuzaklanır: yol artık tuzaksız bir nefes koridoru değil
	var route_set: Dictionary = {}
	var near_route: Dictionary = {}
	for rc in route:
		var rv: Vector2i = rc
		route_set[rv] = true
		for dx in range(-3, 4):
			for dy in range(-4, 1):
				near_route[Vector2i(rv.x + dx, rv.y + dy)] = true
	var p_floor: float = 0.28 + 0.03 * float(level)
	var p_route: float = 0.55 + 0.03 * float(level)
	var p_ceiling: float = 0.05 + 0.012 * float(level)
	var p_wall: float = 0.05 + 0.008 * float(level)
	var count: int = 0
	var x_min: int = START_COLS + 1
	var x_max: int = cols - END_COLS - 1

	# Zemin yüzeyleri: satır satır ardışık hava hücreleri (altı dolu)
	for y in range(CEILING_ROWS + 1, FLOOR_ROW):
		var run: Array[int] = []
		for x in range(x_min, x_max + 1):
			if _standing(blocks, x, y, cols):
				run.append(x)
			else:
				if not run.is_empty():
					count += _place_floor_run(parent, run, y, safe, route_set, rng, p_floor, p_route, level, theme)
				run = []
		if not run.is_empty():
			count += _place_floor_run(parent, run, y, safe, route_set, rng, p_floor, p_route, level, theme)

	# Tavan ve duvar yüzeyleri
	for x in range(x_min, x_max + 1):
		for y in range(CEILING_ROWS, FLOOR_ROW):
			var c := Vector2i(x, y)
			if _is_solid(blocks, c, cols):
				continue
			# Tavan: üstü dolu, altı iki karo hava
			if _is_solid(blocks, Vector2i(x, y - 1), cols) and not _is_solid(blocks, Vector2i(x, y + 1), cols) and not _is_solid(blocks, Vector2i(x, y + 2), cols):
				if rng.randf() < (p_ceiling * 3.0 if near_route.has(c) else p_ceiling):
					var ct: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.CEILING, level, theme)
					count += TrapCorridorTraps._spawn(parent, ct, TrapConfigV2.SurfaceType.CEILING, Vector2(float(x * TILE + TILE / 2), float(y * TILE)), level, theme)
			# Duvar: solu dolu (sağa bakan yüz) ya da sağı dolu (sola bakan yüz); önünde iki karo hava
			if _is_solid(blocks, Vector2i(x - 1, y), cols) and not _is_solid(blocks, Vector2i(x + 1, y), cols) and not _is_solid(blocks, Vector2i(x + 2, y), cols):
				if rng.randf() < (p_wall * 4.0 if near_route.has(c) else p_wall) and y < FLOOR_ROW - 1:
					var lt: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.LEFT_WALL, level, theme)
					count += TrapCorridorTraps._spawn(parent, lt, TrapConfigV2.SurfaceType.LEFT_WALL, Vector2(float(x * TILE), float(y * TILE + TILE / 2)), level, theme)
			elif _is_solid(blocks, Vector2i(x + 1, y), cols) and not _is_solid(blocks, Vector2i(x - 1, y), cols) and not _is_solid(blocks, Vector2i(x - 2, y), cols):
				if rng.randf() < (p_wall * 4.0 if near_route.has(c) else p_wall) and y < FLOOR_ROW - 1:
					var rt: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.RIGHT_WALL, level, theme)
					count += TrapCorridorTraps._spawn(parent, rt, TrapConfigV2.SurfaceType.RIGHT_WALL, Vector2(float((x + 1) * TILE), float(y * TILE + TILE / 2)), level, theme)
	return count


static func _place_floor_run(parent: Node2D, run: Array[int], y: int, safe: Dictionary, route_set: Dictionary, rng: RandomNumberGenerator,
		p_floor: float, p_route: float, level: int, theme: String) -> int:
	var placed: int = 0
	var i: int = 0
	while i < run.size():
		var p: float = p_route if route_set.has(Vector2i(run[i], y)) else p_floor
		if rng.randf() >= p:
			i += 1
			continue
		var t: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.FLOOR, level, theme)
		var g: int = TrapCorridorTraps._group_size(t, level, theme, rng)
		g = mini(g, run.size() - i)
		var ok: bool = true
		for k in range(g):
			if safe.has(Vector2i(run[i + k], y)):
				ok = false
		if not ok:
			i += 1
			continue
		for k in range(g):
			var cx: int = run[i + k]
			placed += TrapCorridorTraps._spawn(parent, t, TrapConfigV2.SurfaceType.FLOOR, Vector2(float(cx * TILE + TILE / 2), float((y + 1) * TILE)), level, theme)
		i += g + rng.randi_range(2, 4)
	return placed
