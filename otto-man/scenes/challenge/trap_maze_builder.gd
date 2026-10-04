class_name TrapMazeBuilder
extends RefCounted

## Tuzak Geçidi: gerçek bir labirent. Oda, W x 5 hücrelik bir ızgaraya bölünür (hücre = 7 kolon x 3 satır iç boşluk,
## 2 satır zemin); rastgele DFS ile "mükemmel labirent" üretilir (her hücreye tek yol), üstüne birkaç duvar daha
## açılarak alternatif/döngü yollar eklenir. Çoğu yol çıkmaz sokaktır; hangisinin sağdaki çıkışa gittiğini oyuncu
## gözüyle bulur. Yan geçitler duvar sütunundaki açıklıklardır; dikey geçitler zemindeki 4 kolonluk deliklerdir
## (aşağı düşersin, yukarı çift zıplamayla çıkarsın). Hücrelerin içi tuzak doludur (bkz. populate).

const TILE: int = 32
const FLOOR_ROW: int = 29
const CEILING_ROWS: int = 4
const OVERSCAN: int = 6
const START_COLS: int = 12       # soldaki başlangıç alanı
const END_COLS: int = 26         # sağdaki bitiş alanı (kapı)
const WALL_COLS: int = 3
## Hücre ölçüleri: iç genişlik 7 + sağda 1 kolon duvar sütunu; iç yükseklik 3 + 2 satır zemin
const CELL_W: int = 6
const PITCH_X: int = 8
const CELL_AIR: int = 3
const PITCH_Y: int = 5
const GRID_H: int = 5
## Başlangıç/bitiş alanlarının zemin yüksekliği: alt hücre sırasının zemini ile aynı (ayak satırı 26)
const RAISED_ROWS: Array[int] = [27, 28]


## Labirenti kurar. Dönen sözlük ChallengeRoom'un beklediği alanları taşır.
static func build(root: Node2D, difficulty: int, theme: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gw: int = 4 * clampi(difficulty, 1, 9)   # uzunluk zorlukla orantılı: 1x, 2x ... 9x
	var cols: int = START_COLS + gw * PITCH_X + END_COLS
	var maze: Dictionary = _make_maze(rng, gw, GRID_H)
	var blocks: Dictionary = _build_blocks(rng, maze, gw, cols)
	var route: Array[Vector2i] = _solution_cells(maze, gw)

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

	var raised_y: float = float(RAISED_ROWS[0] * TILE)
	var length: float = float(cols * TILE)
	# Arka plan, kapılar ve bayraklar: koridorun dekor koduyla (zemin = yükseltilmiş başlangıç/bitiş zemini)
	var ground: Array[int] = []
	ground.resize(cols)
	ground.fill(RAISED_ROWS[0])
	var no_spans: Array[Vector2i] = []
	ChaseCorridorBuilder._add_dungeon_dressing(root, layer, rng, length, ground, no_spans, theme, true)
	return {
		"bounds": Rect2(0.0, float(CEILING_ROWS * TILE), length, FLOOR_ROW * TILE - float(CEILING_ROWS * TILE)),
		"floor_y": raised_y,
		"length": length,
		"end_x": length - float(END_COLS - 8) * float(TILE),
		"player_spawn": Vector2(150.0, raised_y),
		"camera_position": Vector2(960.0, 540.0),
		"fixed_cam_y": 540.0,
		"center_x": length * 0.5,
		"cols": cols,
		"blocks": blocks,
		"route": route,
		"route_cells": route.size(),
	}


# --- Labirent grafı -------------------------------------------------------------------------------

## Mükemmel labirent (DFS) + birkaç ek açıklık. Dönen sözlük:
##   "h": Dictionary (i, j) -> true   (i,j) ile (i+1,j) arası yan geçit açık
##   "v": Dictionary (i, j) -> true   (i,j) ile (i,j+1) arası dikey geçit (zemindeki delik) açık
##   "hole": Dictionary (i, j) -> delik sol kolonu (hücre içi 0 ya da 3)
static func _make_maze(rng: RandomNumberGenerator, gw: int, gh: int) -> Dictionary:
	var h: Dictionary = {}
	var v: Dictionary = {}
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = []
	var start := Vector2i(0, gh - 1)
	visited[start] = true
	stack.append(start)
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < gw and n.y >= 0 and n.y < gh and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		# Dikey hamleler 3 kat ağırlıklı: satırlar kısa parçalara bölünür, düz bir şeritle sona ulaşılamaz
		var weighted: Array[Vector2i] = []
		for o in options:
			for _w in range(3 if o.x == cur.x else 1):
				weighted.append(o)
		var nxt: Vector2i = weighted[rng.randi() % weighted.size()]
		_open_between(h, v, cur, nxt)
		visited[nxt] = true
		stack.append(nxt)
	# Döngüler: duvarların ~%12'si daha açılır (birden fazla yol, kafa karıştırıcı kısa yollar)
	for i in range(gw):
		for j in range(gh):
			if i + 1 < gw and not h.has(Vector2i(i, j)) and rng.randf() < 0.03:
				h[Vector2i(i, j)] = true
			if j + 1 < gh and not v.has(Vector2i(i, j)) and rng.randf() < 0.12:
				v[Vector2i(i, j)] = true
	var hole: Dictionary = {}
	for k in v.keys():
		hole[k] = 0 if rng.randf() < 0.5 else CELL_W - 4
	return {"h": h, "v": v, "hole": hole}


static func _open_between(h: Dictionary, v: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if a.y == b.y:
		h[Vector2i(mini(a.x, b.x), a.y)] = true
	else:
		v[Vector2i(a.x, mini(a.y, b.y))] = true


## Başlangıç hücresinden (0, son sıra) bitiş hücresine (gw-1, son sıra) giden hücre yolu (BFS), ayak karolarına çevrilmiş.
static func _solution_cells(maze: Dictionary, gw: int) -> Array[Vector2i]:
	var gh: int = GRID_H
	var h: Dictionary = maze["h"]
	var v: Dictionary = maze["v"]
	var start := Vector2i(0, gh - 1)
	var goal := Vector2i(gw - 1, gh - 1)
	var parent: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			break
		var nbs: Array[Vector2i] = []
		if h.has(cur):
			nbs.append(cur + Vector2i(1, 0))
		if h.has(cur + Vector2i(-1, 0)):
			nbs.append(cur + Vector2i(-1, 0))
		if v.has(cur):
			nbs.append(cur + Vector2i(0, 1))
		if v.has(cur + Vector2i(0, -1)):
			nbs.append(cur + Vector2i(0, -1))
		for n in nbs:
			if not parent.has(n):
				parent[n] = cur
				queue.append(n)
	var out: Array[Vector2i] = []
	if not parent.has(goal):
		return out
	var path: Array[Vector2i] = []
	var n: Vector2i = goal
	while n != start:
		path.append(n)
		n = parent[n]
	path.append(start)
	path.reverse()
	for cell in path:
		var y: int = CEILING_ROWS + cell.y * PITCH_Y + CELL_AIR - 1   # hücrenin ayak satırı
		for dx in range(CELL_W):
			out.append(Vector2i(START_COLS + cell.x * PITCH_X + dx, y))
	return out


# --- Bloklar ---------------------------------------------------------------------------------------

## Labirentin katı hücrelerini üretir: zeminler, duvar sütunları, delikler, yan açıklıklar, giriş/çıkış alanları,
## ve bazı hücrelerin içine zıplanacak 2x2 bloklar.
static func _build_blocks(rng: RandomNumberGenerator, maze: Dictionary, gw: int, cols: int) -> Dictionary:
	var blocks: Dictionary = {}
	var h: Dictionary = maze["h"]
	var v: Dictionary = maze["v"]
	var hole: Dictionary = maze["hole"]
	for j in range(GRID_H):
		var y0: int = CEILING_ROWS + j * PITCH_Y
		for i in range(gw):
			var x0: int = START_COLS + i * PITCH_X
			# Zemin (2 satır): dikey geçit varsa 4 kolonluk delik
			var hx: int = int(hole.get(Vector2i(i, j), -1))
			var has_hole: bool = v.has(Vector2i(i, j))
			for dx in range(CELL_W):
				if has_hole and dx >= hx and dx < hx + 4:
					continue
				for r in range(CELL_AIR, PITCH_Y):
					blocks[Vector2i(x0 + dx, y0 + r)] = true
			# Hücre içi blok (zıplanacak 2x2): delik ve yan açıklık hizasından uzakta, orta kolonlarda
			if rng.randf() < 0.4:
				var bx: int = x0 + 2 + rng.randi_range(0, 1)
				if has_hole and bx + 1 >= x0 + hx and bx <= x0 + hx + 3:
					bx = x0 + (4 if hx == 0 else 0)   # delikten kaçınmak için karşı yana kaydır
				for dx in range(2):
					for r in range(CELL_AIR - 2, CELL_AIR):
						blocks[Vector2i(bx + dx, y0 + r)] = true
		# Duvar sütunları: i = 0 .. gw; açık geçit varsa 3 hava satırı oyulur (zemin kalır)
		for k in range(gw + 1):
			var px: int = START_COLS - 2 + k * PITCH_X
			var open_gap: bool = false
			if k == 0 or k == gw:
				open_gap = (j == GRID_H - 1)          # sol: başlangıç, sağ: çıkış (alt sıra)
			else:
				open_gap = h.has(Vector2i(k - 1, j))
			for r in range(PITCH_Y):
				if open_gap and r < CELL_AIR:
					continue
				blocks[Vector2i(px, y0 + r)] = true
				blocks[Vector2i(px + 1, y0 + r)] = true
	# Başlangıç ve bitiş alanı zeminleri (alt hücre sırasının zemin yüksekliği)
	for x in range(0, START_COLS - 2):
		for r in RAISED_ROWS:
			blocks[Vector2i(x, r)] = true
	for x in range(START_COLS + gw * PITCH_X, cols):
		for r in RAISED_ROWS:
			blocks[Vector2i(x, r)] = true
	return blocks


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

## Labirentin her açık yüzüne tema tuzakları koyar: hücre zeminleri, tavanlar, duvar sütunları. Çözüm yolundaki
## hücrelerin bazı noktaları (ve komşuları) zemin tuzağından muaf: oyuncu orada nefes alır. Çıkmaz sokaklar da dolu.
static func populate(parent: Node2D, layout: Dictionary, theme: String, level: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var blocks: Dictionary = layout["blocks"]
	var cols: int = int(layout["cols"])
	var route: Array = layout["route"]
	var safe: Dictionary = {}
	for i in range(route.size()):
		if i % 14 == 3:
			var r: Vector2i = route[i]
			for dx in range(-1, 2):
				safe[Vector2i(r.x + dx, r.y)] = true
	var route_set: Dictionary = {}
	for rc in route:
		route_set[rc] = true
	var p_floor: float = 0.17 + 0.015 * float(level)
	var p_route: float = p_floor + 0.07
	var p_ceiling: float = 0.04 + 0.006 * float(level)
	var p_wall: float = 0.04 + 0.005 * float(level)
	var count: int = 0
	var x_min: int = START_COLS
	var x_max: int = cols - END_COLS

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
				if rng.randf() < p_ceiling:
					var ct: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.CEILING, level, theme)
					count += TrapCorridorTraps._spawn(parent, ct, TrapConfigV2.SurfaceType.CEILING, Vector2(float(x * TILE + TILE / 2), float(y * TILE)), level, theme)
			# Duvar: solu dolu (sağa bakan yüz) ya da sağı dolu (sola bakan yüz); önünde iki karo hava
			if _is_solid(blocks, Vector2i(x - 1, y), cols) and not _is_solid(blocks, Vector2i(x + 1, y), cols) and not _is_solid(blocks, Vector2i(x + 2, y), cols):
				if rng.randf() < p_wall and y < FLOOR_ROW - 1:
					var lt: TrapConfigV2.TrapType = TrapConfigV2.select_random_trap(TrapConfigV2.SurfaceType.LEFT_WALL, level, theme)
					count += TrapCorridorTraps._spawn(parent, lt, TrapConfigV2.SurfaceType.LEFT_WALL, Vector2(float(x * TILE), float(y * TILE + TILE / 2)), level, theme)
			elif _is_solid(blocks, Vector2i(x + 1, y), cols) and not _is_solid(blocks, Vector2i(x - 1, y), cols) and not _is_solid(blocks, Vector2i(x - 2, y), cols):
				if rng.randf() < p_wall and y < FLOOR_ROW - 1:
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
