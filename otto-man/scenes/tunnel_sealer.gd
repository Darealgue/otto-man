extends RefCounted
## Crawl tunnels between chunks.
##
## Chunks are authored with 1-2 tile high crawl tunnels that leave through the left or right edge. Whether such a
## tunnel leads anywhere depends on the neighbour that gets placed next to it. After the layout is built (and before
## decor spawns and the chunks are merged) every tunnel mouth is resolved:
##   1. the neighbour is already open at the same row(s)          -> keep it (a passage exists)
##   2. the neighbour is solid there but has enough rock around   -> dig a matching tunnel through the neighbour's
##                                                                  rock until it meets one of its rooms
##   3. otherwise (wall chunk, no chunk, start/finish, thin rock) -> fill the whole corridor behind the mouth
## so a tunnel that stays visible always has a way through.
##
## Usage: TunnelSealer.seal(grid) where grid[x][y] has a `.chunk` (Node2D or null). Returns the number of cells filled.

const W := 60
const H := 34
const DEBUG := false
const MAX_FILL := 600
const MAX_DIG := 45          # longest tunnel dug into a neighbour
const MARGIN := 3            # rock rows kept above and below a dug tunnel
const NO_DIG_SCENES := ["start_chunk", "finish_chunk", "boss_arena", "villager", "vip_dead_end", "full.tscn", "challenge_room"]

static var stat_kept := 0
static var stat_dug := 0
static var stat_sealed := 0
static var stat_spur := 0
static var dbg := {}
static var _cur_name := ""
static var _pass_no := 0
static var _log: Array = []
static var _valid := {}
static var _gt := {}          # TileMapLayer -> global tile offset of that chunk
static var _gtm: Array = []   # [gx][gy] -> TileMapLayer or null
static var _gw := 0
static var _gh := 0
const MAX_REACH := 400000
static var guard_enabled := true   # tests only

# ---------------------------------------------------------------- connectivity guard
# Filling must never cut the level in two: a fill that separates cells which were connected before is refused.
static func _g_open(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	var cx := x / W
	var cy := y / H
	if cx >= _gw or cy >= _gh:
		return false
	var tm = _gtm[cx][cy]
	if tm == null:
		return false
	var c := Vector2i(x % W, y % H)
	if tm.get_cell_source_id(c) == -1:
		return true
	var td: TileData = tm.get_cell_tile_data(c)
	return td != null and td.terrain == 1

static func _reach(start: Vector2i, blocked: Dictionary, targets: Dictionary) -> Dictionary:
	var found := {start: true}
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size() and found.size() < targets.size() and queue.size() < MAX_REACH:
		var c: Vector2i = queue[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or blocked.has(n) or not _g_open(n.x, n.y):
				continue
			seen[n] = true
			queue.append(n)
			if targets.has(n):
				found[n] = true
	return found

# true when closing `cells` (chunk local coords of `tm`) would disconnect open cells that are connected right now
static func _would_split(tm: TileMapLayer, cells: Array) -> bool:
	if not guard_enabled or not _gt.has(tm):
		return false
	var off: Vector2i = _gt[tm]
	var s := {}
	for c in cells:
		s[Vector2i(c) + off] = true
	var nb := {}
	for k in s.keys():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if not s.has(n) and _g_open(n.x, n.y):
				nb[n] = true
	if nb.size() < 2:
		return false
	var remaining := nb.duplicate()
	var none := {}
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var after := _reach(start, s, nb)
		if after.size() < nb.size():
			var before := _reach(start, none, nb)
			if before.size() > after.size():
				return true
		for k2 in after.keys():
			remaining.erase(k2)
	return false

static func _tm(chunk) -> TileMapLayer:
	if chunk == null or not is_instance_valid(chunk):
		return null
	return chunk.find_child("TileMapLayer", true, false) as TileMapLayer

static func _open(tm: TileMapLayer, x: int, y: int) -> bool:
	return tm.get_cell_source_id(Vector2i(x, y)) == -1

static func _can_dig_into(chunk) -> bool:
	if chunk == null or not is_instance_valid(chunk):
		return false
	var path := String(chunk.scene_file_path)
	for key in NO_DIG_SCENES:
		if path.find(key) >= 0:
			return false
	return true

## Returns the number of tunnel cells that were filled.
static var disabled := false   # tests only

static func seal(grid: Array) -> int:
	if disabled:
		return 0
	stat_kept = 0
	stat_dug = 0
	stat_sealed = 0
	stat_spur = 0
	dbg = {}
	_log = []
	var total := 0
	var tms: Array = []
	var before := {}
	var plain: Array = []
	_gt = {}
	_gtm = []
	_gw = grid.size()
	_gh = 0
	for col in grid:
		_gh = maxi(_gh, col.size())
	for gx0 in range(grid.size()):
		var tcol: Array = []
		tcol.resize(_gh)
		_gtm.append(tcol)
		for gy0 in range(grid[gx0].size()):
			var c0 = grid[gx0][gy0]
			if c0 != null and c0.chunk != null:
				var tm0 := _tm(c0.chunk)
				if tm0 != null:
					_gtm[gx0][gy0] = tm0
					_gt[tm0] = Vector2i(gx0 * W, gy0 * H)
					tms.append(tm0)
					if _can_dig_into(c0.chunk):
						plain.append(tm0)
					before[tm0] = _bad_cells(tm0)
	var m_before := _measure_reach() if measure else {}
	for _pass in range(10):
		_pass_no = _pass
		var changed := 0
		for gx in range(grid.size()):
			for gy in range(grid[gx].size()):
				var cell = grid[gx][gy]
				if cell == null or cell.chunk == null:
					continue
				var tm := _tm(cell.chunk)
				if tm == null:
					continue
				_cur_name = String(cell.chunk.scene_file_path).get_file()
				for right in [false, true]:
					var nx: int = gx + (1 if right else -1)
					var ntm: TileMapLayer = null
					var nchunk = null
					if nx >= 0 and nx < grid.size():
						var ncell = grid[nx][gy]
						if ncell != null and ncell.chunk != null:
							nchunk = ncell.chunk
							ntm = _tm(nchunk)
					changed += _resolve_side(tm, right, ntm, nchunk)
		total += changed
		if changed == 0:
			break
	for tm2 in plain:
		stat_spur += _seal_spurs(tm2)
	for tm1 in tms:
		_repair(tm1, before[tm1])
	if measure:
		var m_after := _measure_reach()
		m_lost = 0
		for k in m_before.keys():
			if _g_open(k.x, k.y) and not m_after.has(k):
				m_lost += 1
	return total

static var measure := false
static var m_lost := 0

static func _measure_reach() -> Dictionary:
	var seen := {}
	var q: Array[Vector2i] = []
	var sy: int = _gh / 2
	for y in range(H):
		for x in range(W):
			if _g_open(x, sy * H + y):
				var c := Vector2i(x, sy * H + y)
				seen[c] = true
				q.append(c)
	var i := 0
	while i < q.size():
		var c2: Vector2i = q[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c2 + d
			if not seen.has(n) and _g_open(n.x, n.y):
				seen[n] = true
				q.append(n)
	return seen

# returns the number of cells that changed (dug or filled), 0 when nothing had to be done
static func _resolve_side(tm: TileMapLayer, right: bool, ntm: TileMapLayer, nchunk) -> int:
	var ex := W - 1 if right else 0
	var nx := 0 if right else W - 1
	var changed := 0
	var y := 1
	while y < H - 1:
		if not _open(tm, ex, y):
			y += 1
			continue
		var y0 := y
		while y < H and _open(tm, ex, y):
			y += 1
		var y1 := y - 1
		# a tunnel mouth is a 1-2 high opening with rock above and below; taller openings are real passages
		if y1 - y0 + 1 > 2 or y0 < 1 or y1 > H - 2:
			continue
		if _open(tm, ex, y0 - 1) or _open(tm, ex, y1 + 1):
			continue
		var matched := false
		if ntm != null:
			for yy in range(y0, y1 + 1):
				if _open(ntm, nx, yy):
					matched = true
		if matched:
			if _pass_no == 0:
				stat_kept += 1
			continue
		if ntm == null:
			dbg['noneighbour'] = int(dbg.get('noneighbour', 0)) + 1
		elif not _can_dig_into(nchunk):
			dbg['nodigscene'] = int(dbg.get('nodigscene', 0)) + 1
		if ntm != null and _can_dig_into(nchunk):
			var dug := _dig_into(ntm, right, y0, y1)
			if dug > 0:
				stat_dug += 1
				changed += dug
				continue
		_log.append('%s %s row %d-%d sealed: %s' % [_cur_name, 'R' if right else 'L', y0, y1, 'no chunk' if ntm == null else ('special chunk' if not _can_dig_into(nchunk) else 'cannot dig')])
		var starts: Array = []
		for yy in range(y0, y1 + 1):
			starts.append(Vector2i(ex, yy))
		var f := _fill_corridor(tm, starts)
		if f > 0:
			stat_sealed += 1
		changed += f
	return changed

# is the cell block (x, yt .. yt+h-1) fit to be dug: rock (no platform tiles) with MARGIN rock cells above and below,
# and no open cell beside it other than straight ahead
static func _diggable(ntm: TileMapLayer, x: int, yt: int, h: int, dir: int) -> bool:
	if x < 0 or x >= W or yt < MARGIN or yt + h - 1 > H - 2:
		return false
	for yy in range(maxi(0, yt - MARGIN), mini(H - 1, yt + h - 1 + MARGIN) + 1):
		if _open(ntm, x, yy):
			return false
		var td := ntm.get_cell_tile_data(Vector2i(x, yy))
		if td != null and td.terrain == 1:
			return false
	return true

# dig a tunnel through the neighbour's rock, from its edge inward, until it reaches open space of that chunk.
# Breadth-first over (x, top row) so the tunnel may bend up and down to get around the rooms' ceilings and floors.
static func _dig_into(ntm: TileMapLayer, from_left_edge_of_neighbour: bool, y0: int, y1: int) -> int:
	var h := y1 - y0 + 1
	var start_x := 0 if from_left_edge_of_neighbour else W - 1
	var dir := 1 if from_left_edge_of_neighbour else -1
	var start := Vector3i(start_x, y0, 2)    # z: 0 = last step horizontal (run 1), 1 = vertical run 1, 2 = settled (run >= 2)
	if not _diggable(ntm, start.x, start.y, h, dir):
		dbg['start_fail'] = int(dbg.get('start_fail', 0)) + 1
		return 0
	var prev := {start: start}
	var depth := {start: 0}
	var queue: Array[Vector3i] = [start]
	var goal := Vector3i(-1, -1, 0)
	var i := 0
	while i < queue.size():
		var c: Vector3i = queue[i]
		i += 1
		var ax := c.x + dir
		if c.z == 2 and ax >= 0 and ax < W:
			for yy in range(c.y, c.y + h):
				if _open(ntm, ax, yy):
					goal = c
					break
		if goal.x >= 0:
			break
		if int(depth[c]) >= MAX_DIG:
			continue
		for mv in [Vector2i(dir, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var vertical: bool = mv.x == 0
			var nz := -1
			# z: 2 = straight run settled, 3/4 = first step up/down, 5/6 = settled shaft up/down, 0 = first step after a shaft
			if not vertical:
				if c.z == 2 or c.z == 0:
					nz = 2
				elif c.z == 5 or c.z == 6:
					nz = 0
			elif mv.y < 0:
				if c.z == 2 and absi(c.x - start_x) >= 2:
					nz = 3
				elif c.z == 3 or c.z == 5:
					nz = 5
			else:
				if c.z == 2 and absi(c.x - start_x) >= 2:
					nz = 4
				elif c.z == 4 or c.z == 6:
					nz = 6
			if nz < 0:
				continue
			var n := Vector3i(c.x + mv.x, c.y + mv.y, nz)
			if prev.has(n):
				continue
			if not _diggable(ntm, n.x, n.y, h, dir):
				continue
			if vertical:
				var side_open := false
				for sx in [n.x - 1, n.x + 1]:
					if sx < 0 or sx >= W:
						continue
					for yy2 in range(n.y, n.y + h):
						if _open(ntm, sx, yy2):
							side_open = true
				if side_open:
					continue
			prev[n] = c
			depth[n] = int(depth[c]) + 1
			queue.append(n)
	if goal.x < 0:
		dbg['noreach'] = int(dbg.get('noreach', 0)) + 1
		return 0
	var cellset := {}
	var cur: Vector3i = goal
	while true:
		for yy3 in range(cur.y, cur.y + h):
			cellset[Vector2i(cur.x, yy3)] = true
		if cur == start:
			break
		cur = prev[cur]
	var cells: Array[Vector2i] = []
	for k in cellset.keys():
		cells.append(k)
	if cells.size() < 2:
		return 0
	for c3 in cells:
		ntm.erase_cell(c3)
	# repaint the rock around the new hole so its edges get proper tiles
	var around := {}
	for c2 in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q: Vector2i = c2 + Vector2i(dx, dy)
				if q.x < 0 or q.x >= W or q.y < 0 or q.y >= H:
					continue
				if ntm.get_cell_source_id(q) == -1:
					continue
				var td2 := ntm.get_cell_tile_data(q)
				if td2 != null and td2.terrain == 1:
					continue
				around[q] = true
	var repaint: Array[Vector2i] = []
	for q2 in around.keys():
		repaint.append(q2)
	ntm.set_cells_terrain_connect(repaint, 0, 0, false)
	return cells.size()
static func _vrun(tm: TileMapLayer, x: int, y: int) -> int:
	var n := 1
	var yy := y - 1
	while yy >= 0 and _open(tm, x, yy):
		n += 1
		yy -= 1
	yy = y + 1
	while yy < H and _open(tm, x, yy):
		n += 1
		yy += 1
	return n

static func _hrun(tm: TileMapLayer, x: int, y: int) -> int:
	var n := 1
	var xx := x - 1
	while xx >= 0 and _open(tm, xx, y):
		n += 1
		xx -= 1
	xx = x + 1
	while xx < W and _open(tm, xx, y):
		n += 1
		xx += 1
	return n

# part of a crawl corridor: at most 2 open cells high, or a drop that is 1 wide; room cells never qualify
static func _corridor_cell(tm: TileMapLayer, x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 1 or y >= H - 1:
		return false
	if not _open(tm, x, y):
		return false
	return _vrun(tm, x, y) <= 2 or _hrun(tm, x, y) <= 1

static func _fill_corridor(tm: TileMapLayer, starts: Array) -> int:
	var seen := {}
	var queue: Array = []
	for s in starts:
		seen[s] = true
		queue.append(s)
	var i := 0
	while i < queue.size() and queue.size() <= MAX_FILL:
		var c: Vector2i = queue[i]
		i += 1
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if seen.has(n):
				continue
			if _corridor_cell(tm, n.x, n.y):
				seen[n] = true
				queue.append(n)
	if queue.size() > MAX_FILL:
		# something that is not a corridor was reached; refuse to fill rather than eat a room
		return 0
	var cells: Array[Vector2i] = []
	for c2 in queue:
		cells.append(c2)
	if _would_split(tm, cells):
		# this corridor is part of a real route: leave it open
		return 0
	tm.set_cells_terrain_connect(cells, 0, 0, false)
	return cells.size()

# ---------------------------------------------------------------- tile repair
# The tile set only draws 15 wall neighbourhoods. Digging and filling can leave a wall cell with another one (it would be
# drawn as a frameless dark square), so after sealing those cells are fixed by removing the cell or filling a neighbour.
const _DX := [1, 1, 0, -1, -1, -1, 0, 1]
const _DY := [0, 1, 1, 1, 0, -1, -1, -1]

static func _canon(m: int) -> int:
	var r := m & 0b01010101
	for pr in [[1, 0, 2], [3, 2, 4], [5, 4, 6], [7, 6, 0]]:
		if (m & (1 << pr[0])) != 0 and (m & (1 << pr[1])) != 0 and (m & (1 << pr[2])) != 0:
			r |= (1 << pr[0])
	return r

static func _ensure_valid(ts: TileSet) -> void:
	if not _valid.is_empty() or ts == null:
		return
	var src := ts.get_source(0) as TileSetAtlasSource
	var order := [TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER]
	for i in range(src.get_tiles_count()):
		var c := src.get_tile_id(i)
		var td := src.get_tile_data(c, 0)
		if td.terrain_set != 0 or td.terrain != 0:
			continue
		var m := 0
		for k in range(8):
			if td.get_terrain_peering_bit(order[k]) == 0:
				m |= (1 << k)
		_valid[_canon(m)] = true

static func _wall_grid(tm: TileMapLayer) -> Array:
	var wall: Array = []
	for y in range(H):
		var row: Array = []
		for x in range(W):
			var c := Vector2i(x, y)
			var is_wall := false
			if tm.get_cell_source_id(c) != -1:
				var td := tm.get_cell_tile_data(c)
				is_wall = not (td != null and td.terrain == 1)
			row.append(is_wall)
		wall.append(row)
	return wall

static func _cell_ok(wall: Array, x: int, y: int) -> bool:
	if not wall[y][x]:
		return true
	var m := 0
	for k in range(8):
		var nx: int = x + _DX[k]
		var ny: int = y + _DY[k]
		if nx >= 0 and nx < W and ny >= 0 and ny < H and wall[ny][nx]:
			m |= (1 << k)
	return _valid.has(_canon(m))

static func _bad_in(wall: Array, x0: int, y0: int, x1: int, y1: int) -> int:
	var n := 0
	for y in range(maxi(0, y0), mini(H - 1, y1) + 1):
		for x in range(maxi(0, x0), mini(W - 1, x1) + 1):
			if not _cell_ok(wall, x, y):
				n += 1
	return n

static func _bad_cells(tm: TileMapLayer) -> Dictionary:
	_ensure_valid(tm.tile_set)
	var res := {}
	var wall := _wall_grid(tm)
	for y in range(H):
		for x in range(W):
			if not _cell_ok(wall, x, y):
				res[Vector2i(x, y)] = true
	return res

static func _retile(tm: TileMapLayer, x: int, y: int) -> void:
	var cells: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := Vector2i(x + dx, y + dy)
			if q.x < 0 or q.x >= W or q.y < 0 or q.y >= H:
				continue
			if tm.get_cell_source_id(q) == -1 or q == Vector2i(x, y):
				continue
			var td := tm.get_cell_tile_data(q)
			if td != null and td.terrain == 1:
				continue
			cells.append(q)
	if not cells.is_empty():
		tm.set_cells_terrain_connect(cells, 0, 0, false)

static func _repair(tm: TileMapLayer, before: Dictionary) -> void:
	var wall := _wall_grid(tm)
	for _round in range(6):
		var fixed_any := false
		for y in range(H):
			for x in range(W):
				if before.has(Vector2i(x, y)) or _cell_ok(wall, x, y):
					continue
				var base := _bad_in(wall, x - 2, y - 2, x + 2, y + 2)
				var best_gain := 0
				var best_cell := Vector2i(-1, -1)
				var best_fill := false
				# candidate 1: remove the cell, candidates 2..: fill an open neighbour (inner cells only)
				for k in range(9):
					var cx := x
					var cy := y
					var fill := k > 0
					if fill:
						cx = x + _DX[k - 1]
						cy = y + _DY[k - 1]
						if wall[cy if cy >= 0 and cy < H else 0][cx if cx >= 0 and cx < W else 0] or cx < 1 or cx > W - 2 or cy < 1 or cy > H - 2:
							continue
						if tm.get_cell_source_id(Vector2i(cx, cy)) != -1:
							continue
					else:
						if x < 1 or x > W - 2 or y < 1 or y > H - 2:
							continue
					if fill and _would_split(tm, [Vector2i(cx, cy)]):
						continue
					wall[cy][cx] = fill
					var after := _bad_in(wall, x - 2, y - 2, x + 2, y + 2)
					wall[cy][cx] = not fill
					var gain := base - after
					if gain > best_gain:
						best_gain = gain
						best_cell = Vector2i(cx, cy)
						best_fill = fill
				if best_cell.x < 0:
					continue
				wall[best_cell.y][best_cell.x] = best_fill
				if best_fill:
					var one: Array[Vector2i] = [best_cell]
					tm.set_cells_terrain_connect(one, 0, 0, false)
				else:
					tm.erase_cell(best_cell)
					_retile(tm, best_cell.x, best_cell.y)
				fixed_any = true
		if not fixed_any:
			break
# ---------------------------------------------------------------- dead-end spurs inside a chunk
# A crawl corridor that touches the chunk edge is handled above. One that never leaves the chunk and opens into at most
# one room is a dead end, so it is filled as well: a visible tunnel always leads somewhere.
const MIN_SPUR := 6

static func _seal_spurs(tm: TileMapLayer) -> int:
	var cor := {}
	for y in range(H):
		for x in range(W):
			if _open(tm, x, y) and _corridor_cell(tm, x, y):
				cor[Vector2i(x, y)] = true
	var seen := {}
	var filled := 0
	for c0 in cor.keys():
		if seen.has(c0):
			continue
		var comp: Array = [c0]
		seen[c0] = true
		var i := 0
		var touches_edge := false
		var rooms: Array = []
		while i < comp.size():
			var c: Vector2i = comp[i]
			i += 1
			if c.x == 0 or c.x == W - 1 or c.y <= 1 or c.y >= H - 2:
				touches_edge = true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if cor.has(n):
					if not seen.has(n):
						seen[n] = true
						comp.append(n)
				elif n.x >= 0 and n.x < W and n.y >= 0 and n.y < H and _open(tm, n.x, n.y):
					var near := false
					for r in rooms:
						if absi(r.x - n.x) + absi(r.y - n.y) <= 6:
							near = true
							break
					if not near:
						rooms.append(n)
		if touches_edge or comp.size() < MIN_SPUR or comp.size() > MAX_FILL or rooms.size() >= 2:
			continue
		var cells: Array[Vector2i] = []
		for c2 in comp:
			cells.append(c2)
		if _would_split(tm, cells):
			continue
		tm.set_cells_terrain_connect(cells, 0, 0, false)
		filled += 1
	return filled