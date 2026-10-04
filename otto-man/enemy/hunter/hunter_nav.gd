class_name HunterNav
extends RefCounted

## Avcının çalışma zamanı gezinme grafiği. Tile'lar önceden işaretlenmez; çevre fizik sorgularıyla taranır:
##  1. Sütun taraması: her STEP pikselde aşağı ışın atılır, basılabilir her yüzey (zemin ve one-way dahil) bir düğüm olur.
##  2. Yan yana düğümler "yürü" kenarıyla bağlanır; bağlı düğümler aynı koşu (run) olur.
##  3. Zıplama / kenardan düşme / platformdan inme kenarları tembel üretilir (A* bir düğümü açarken):
##     analitik yay hesaplanır, sonra gerçek gövdeyle (test_move) simüle edilip nereye indiği doğrulanır.
##     Yani kenar listesindeki her hamle bu gövdeyle gerçekten yapılabilir.
##  4. A* zaman bütçeli, kareye yayılarak çalışır.

const STEP := 16.0
const SIM_DT := 1.0 / 30.0
const LAUNCH_EVERY := 3
const MAX_REACH_COLS := 28
const MAX_RISE_MARGIN := 12.0
const MAX_DROP := 520.0
const MAX_POPS := 520
const MAX_SIMS_PER_NODE := 12
const FLAT_NORMAL_Y := -0.7
const COL_Y_QUANT := 256.0

enum Kind { WALK, JUMP, DROP, DROPTHRU, DJUMP }
enum Search { IDLE, SEARCHING, FOUND, FAILED }

class NavNode:
	var id: int = 0
	var cx: int = 0
	var surf: Vector2 = Vector2.ZERO   # basılan yüzey noktası
	var pos: Vector2 = Vector2.ZERO    # gövde orijini (ayakta dururken)
	var one_way: bool = false
	var walk: Array = []
	var has_left: bool = false
	var has_right: bool = false
	var edges: Array = []
	var expanded: bool = false
	var seen: int = -1
	var closed: bool = false
	var g: float = 0.0
	var f: float = 0.0
	var parent = null
	var parent_edge: Dictionary = {}

var body: CharacterBody2D
var gravity: float
var jump_speed: float
var air_max: float
var run_speed: float
var feet_off: float
var dj_speed: float = 780.0   # çift zıplamanın ikinci itkisi (ilk zıplamanın zirvesinde uygulanır)

var nodes: Array = []
var cols: Dictionary = {}
var search_state: int = Search.IDLE
var result_path: Array = []
var result_partial: bool = false

var _scanned: Dictionary = {}
var _uf: PackedInt32Array = PackedInt32Array()
var _kc: KinematicCollision2D = KinematicCollision2D.new()
var _head_shape: CapsuleShape2D = CapsuleShape2D.new()
var _open: Array = []
var _search_id: int = 0
var _goal = null
var _best = null
var _pops: int = 0


func _init(p_body: CharacterBody2D, p_gravity: float, p_jump: float, p_air_max: float, p_run: float,
		p_feet_off: float, shape_radius: float, shape_height: float) -> void:
	body = p_body
	gravity = p_gravity
	jump_speed = p_jump
	air_max = p_air_max
	run_speed = p_run
	feet_off = p_feet_off
	_head_shape.radius = maxf(shape_radius - 3.0, 4.0)
	_head_shape.height = maxf(shape_height - 8.0, _head_shape.radius * 2.0 + 2.0)


func _space() -> PhysicsDirectSpaceState2D:
	return body.get_world_2d().direct_space_state


# --- Tarama ---------------------------------------------------------------------------------

## İstenen x aralığındaki sütunları (y aralığı 256'ya yuvarlanır) tarar. Tüm sütunlar hazırsa true döner.
func ensure_columns(x0: float, x1: float, y0: float, y1: float, max_cols: int = 40) -> bool:
	var qy0: float = floorf(y0 / COL_Y_QUANT) * COL_Y_QUANT
	var qy1: float = ceilf(y1 / COL_Y_QUANT) * COL_Y_QUANT
	var c0: int = int(floorf(x0 / STEP))
	var c1: int = int(floorf(x1 / STEP))
	var done: int = 0
	for cx in range(c0, c1 + 1):
		var rng: Variant = _scanned.get(cx)
		if rng != null and (rng as Vector2).x <= qy0 and (rng as Vector2).y >= qy1:
			continue
		if done >= max_cols:
			return false
		_scan_column(cx, qy0, qy1)
		var nr := Vector2(qy0, qy1)
		if rng != null:
			nr = Vector2(minf((rng as Vector2).x, qy0), maxf((rng as Vector2).y, qy1))
		_scanned[cx] = nr
		_link_column(cx)
		done += 1
	return true


func _scan_column(cx: int, y0: float, y1: float) -> void:
	var space := _space()
	var x: float = cx * STEP + STEP * 0.5
	var y: float = y0
	var guard: int = 0
	while y < y1 and guard < 8:
		guard += 1
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, y1))
		q.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		var p: Vector2 = hit["position"]
		var n: Vector2 = hit["normal"]
		y = p.y + 10.0
		if n.y > FLAT_NORMAL_Y:
			continue
		if _node_at(cx, p.y) != null:
			continue
		if not _has_headroom(p):
			continue
		var nn := NavNode.new()
		nn.id = nodes.size()
		nn.cx = cx
		nn.surf = p
		nn.pos = p - Vector2(0.0, feet_off)
		nn.one_way = _probe_one_way(p)
		nodes.append(nn)
		_uf.append(nn.id)
		if not cols.has(cx):
			cols[cx] = []
		(cols[cx] as Array).append(nn)


func _node_at(cx: int, y: float):
	if not cols.has(cx):
		return null
	for n in cols[cx]:
		if absf(n.surf.y - y) < 6.0:
			return n
	return null


func _has_headroom(surf: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _head_shape
	q.transform = Transform2D(0.0, surf + Vector2(0.0, -feet_off - 6.0))
	q.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	return _space().intersect_shape(q, 1).is_empty()


## Yüzeyin altına geçip yukarı doğru hareket ederek one-way olup olmadığını (altından geçilebiliyor mu) anlar.
func _probe_one_way(surf: Vector2) -> bool:
	var depth: float = 90.0
	var o: Vector2 = surf + Vector2(0.0, depth - feet_off)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _head_shape
	q.transform = Transform2D(0.0, o + Vector2(0.0, -6.0))
	q.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	if not _space().intersect_shape(q, 1).is_empty():
		return false
	return not body.test_move(Transform2D(0.0, o), Vector2(0.0, -(depth + 14.0)), null, 0.04)


func _link_column(cx: int) -> void:
	if not cols.has(cx):
		return
	for dcx in [-1, 1]:
		if not cols.has(cx + dcx):
			continue
		for a in cols[cx]:
			for b in cols[cx + dcx]:
				if absf(a.surf.y - b.surf.y) <= 12.0 and not (b in a.walk):
					a.walk.append(b)
					b.walk.append(a)
					_union(a.id, b.id)
					if dcx == 1:
						a.has_right = true
						b.has_left = true
					else:
						a.has_left = true
						b.has_right = true


func _find(i: int) -> int:
	var r: int = i
	while _uf[r] != r:
		_uf[r] = _uf[_uf[r]]
		r = _uf[r]
	return r


func _union(a: int, b: int) -> void:
	var ra: int = _find(a)
	var rb: int = _find(b)
	if ra != rb:
		_uf[ra] = rb


func same_run(a, b) -> bool:
	return a != null and b != null and _find(a.id) == _find(b.id)


## Noktaya en yakın düğüm (max_d içinde); noktanın belirgin üstündeki düğümler cezalıdır.
func nearest_node(p: Vector2, max_d: float = 64.0):
	var cx0: int = int(floorf(p.x / STEP))
	var span: int = int(ceilf(max_d / STEP)) + 1
	var best = null
	var best_s: float = INF
	for cx in range(cx0 - span, cx0 + span + 1):
		if not cols.has(cx):
			continue
		for n in cols[cx]:
			var dx: float = absf(n.surf.x - p.x)
			var dy: float = n.surf.y - p.y
			if Vector2(dx, dy).length() > max_d:
				continue
			var s: float = dx + absf(dy) * 1.5
			if dy < -24.0:
				s += 200.0
			if s < best_s:
				best_s = s
				best = n
	return best


# --- Kenar üretimi (tembel) -----------------------------------------------------------------

func _expand(n) -> void:
	n.expanded = true
	for w in n.walk:
		n.edges.append({"kind": Kind.WALK, "from": n, "to": w, "vx": 0.0, "t": 0.0,
				"cost": n.pos.distance_to(w.pos) / run_speed})
	var is_end: bool = not n.has_left or not n.has_right
	var launch: bool = is_end or (n.cx % LAUNCH_EVERY == 0)
	var thru: bool = n.one_way and (n.cx % 2 == 0)
	if not launch and not thru:
		return
	var apex1: float = jump_speed * jump_speed / (2.0 * gravity)
	var apex: float = apex1 + dj_speed * dj_speed / (2.0 * gravity)   # çift zıplamayla toplam yükseklik
	var ts: float = jump_speed / gravity                              # ilk zıplamanın zirve zamanı
	var my_root: int = _find(n.id)
	var cands: Dictionary = {}
	for cx in range(n.cx - MAX_REACH_COLS, n.cx + MAX_REACH_COLS + 1):
		if not cols.has(cx):
			continue
		for c in cols[cx]:
			if c == n:
				continue
			var root: int = _find(c.id)
			if root == my_root:
				continue
			var dx: float = c.pos.x - n.pos.x
			var dy: float = c.pos.y - n.pos.y
			if dy < -(apex - MAX_RISE_MARGIN) or dy > MAX_DROP:
				continue
			var c_end: float = 60.0 if (not c.has_left or not c.has_right) else 0.0
			var score: float = absf(dx) + c_end
			if launch:
				var single_ok: bool = false
				var disc: float = jump_speed * jump_speed + 2.0 * gravity * dy
				if disc >= 0.0:
					var t: float = (jump_speed + sqrt(disc)) / gravity
					var vx: float = dx / t
					if absf(vx) <= air_max:
						single_ok = true
						_add_cand(cands, root, Kind.JUMP, score, c, vx, t)
				if not single_ok:
					# Tek zıplama yetmiyor (çok yüksek / çok uzak): zirvede ikinci zıplama
					var disc2: float = dj_speed * dj_speed + 2.0 * gravity * (dy + apex1)
					if disc2 >= 0.0:
						var t2d: float = ts + (dj_speed + sqrt(disc2)) / gravity
						var vx2d: float = dx / t2d
						if absf(vx2d) <= air_max:
							_add_cand(cands, root, Kind.DJUMP, score + 40.0, c, vx2d, t2d)
			if is_end and dy >= 24.0 and ((dx > 0.0 and not n.has_right) or (dx < 0.0 and not n.has_left)):
				var t2: float = sqrt(2.0 * dy / gravity)
				var vx2: float = dx / t2
				if absf(vx2) <= minf(air_max, run_speed):
					_add_cand(cands, root, Kind.DROP, score, c, vx2, t2)
			if thru and dy >= 48.0 and absf(dx) <= 56.0:
				var t3: float = sqrt(2.0 * dy / gravity)
				_add_cand(cands, root, Kind.DROPTHRU, score, c, clampf(dx / t3, -120.0, 120.0), t3)
	var sims: int = 0
	for key in cands:
		var list: Array = cands[key]
		list.sort_custom(func(a, b): return a["score"] < b["score"])
		var tries: int = 0
		for cd in list:
			if tries >= 2 or sims >= MAX_SIMS_PER_NODE:
				break
			tries += 1
			sims += 1
			var land = _verify(n, cd)
			if land != null:
				var kind: int = cd["kind"]
				var pen: float = 0.35
				if kind == Kind.DJUMP:
					pen = 0.6
				elif kind == Kind.DROP:
					pen = 0.1
				elif kind == Kind.DROPTHRU:
					pen = 0.3
				n.edges.append({"kind": kind, "from": n, "to": land, "vx": cd["vx"], "t": cd["t"],
						"cost": float(cd["t"]) + pen})
				break


func _add_cand(cands: Dictionary, root: int, kind: int, score: float, c, vx: float, t: float) -> void:
	var key: int = root * 4 + kind
	if not cands.has(key):
		cands[key] = []
	(cands[key] as Array).append({"kind": kind, "score": score, "node": c, "vx": vx, "t": t})


## Adayı gerçek gövdeyle simüle eder; hedef koşuya iniyorsa inilen düğümü döndürür.
func _verify(n, cd: Dictionary):
	var kind: int = cd["kind"]
	var target_root: int = _find(cd["node"].id)
	var land = null
	if kind == Kind.JUMP:
		land = _simulate(n.pos, cd["vx"], -jump_speed, cd["t"])
	elif kind == Kind.DJUMP:
		land = _simulate(n.pos, cd["vx"], -jump_speed, cd["t"], jump_speed / gravity, dj_speed)
	elif kind == Kind.DROP:
		var dir: float = signf(cd["vx"])
		var start: Vector2 = _walk_off_point(n.pos, dir)
		land = _simulate(start, cd["vx"], 0.0, cd["t"])
	else:
		land = _simulate(n.pos + Vector2(0.0, 20.0), cd["vx"], 250.0, cd["t"])
	if land != null and _find(land.id) == target_root:
		return land
	return null


## Kenar düğümünden dir yönünde yürüyüp desteğin bittiği (gövde merkezi kenarı geçtiği) noktayı bulur.
func _walk_off_point(start: Vector2, dir: float) -> Vector2:
	var space := _space()
	var p: Vector2 = start
	for i in 10:
		var q := PhysicsRayQueryParameters2D.create(
				Vector2(p.x + dir * 4.0, p.y + feet_off - 6.0), Vector2(p.x + dir * 4.0, p.y + feet_off + 6.0))
		q.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
		if space.intersect_ray(q).is_empty():
			break
		p.x += dir * 4.0
	p.x += dir * 6.0
	return p


func _simulate(start: Vector2, vx: float, vy0: float, t_hint: float, dj_time: float = -1.0, dj_v: float = 0.0):
	sims_run += 1
	var pos: Vector2 = start
	var vy: float = vy0
	var steps: int = int(ceilf((t_hint + 0.6) / SIM_DT))
	var xf := Transform2D(0.0, pos)
	var dj_done: bool = dj_time < 0.0
	for i in steps:
		if not dj_done and i * SIM_DT >= dj_time:
			vy = -dj_v
			dj_done = true
		vy += gravity * SIM_DT
		var motion := Vector2(vx * SIM_DT, vy * SIM_DT)
		xf.origin = pos
		if body.test_move(xf, motion, _kc, 0.04):
			var nrm: Vector2 = _kc.get_normal()
			if nrm.y < -0.6 and vy > 0.0:
				var land_o: Vector2 = pos + _kc.get_travel()
				return nearest_node(land_o + Vector2(0.0, feet_off), 20.0)
			return null
		pos += motion
	return null

var sims_run: int = 0


# --- A* -------------------------------------------------------------------------------------

func _h(n) -> float:
	return n.pos.distance_to(_goal.pos) / 450.0


func begin_search(start, goal) -> void:
	_search_id += 1
	_open.clear()
	_goal = goal
	_best = start
	_pops = 0
	result_path = []
	result_partial = false
	start.seen = _search_id
	start.g = 0.0
	start.f = _h(start)
	start.closed = false
	start.parent = null
	start.parent_edge = {}
	_open.append(start)
	search_state = Search.SEARCHING
	if start == goal:
		search_state = Search.FOUND


func step(budget_us: int) -> void:
	if search_state != Search.SEARCHING:
		return
	var t0: int = Time.get_ticks_usec()
	while not _open.is_empty():
		var bi: int = 0
		for i in range(1, _open.size()):
			if _open[i].f < _open[bi].f:
				bi = i
		var cur = _open[bi]
		_open[bi] = _open.back()
		_open.pop_back()
		cur.closed = true
		_pops += 1
		if cur == _goal:
			_finish(cur)
			return
		if _h(cur) < _h(_best):
			_best = cur
		if not cur.expanded:
			_expand(cur)
		for e in cur.edges:
			var nb = e["to"]
			if nb.seen != _search_id:
				nb.seen = _search_id
				nb.g = INF
				nb.closed = false
				nb.parent = null
			if nb.closed:
				continue
			var ng: float = cur.g + float(e["cost"])
			if ng < nb.g:
				nb.g = ng
				nb.f = ng + _h(nb)
				nb.parent = cur
				nb.parent_edge = e
				if not (nb in _open):
					_open.append(nb)
		if _pops >= MAX_POPS:
			_finish(_best)
			return
		if Time.get_ticks_usec() - t0 > budget_us:
			return
	_finish(_best)


func _finish(end_node) -> void:
	var path: Array = []
	var n = end_node
	while n != null and not n.parent_edge.is_empty() and n.parent != null:
		path.push_front(n.parent_edge)
		n = n.parent
	result_path = path
	result_partial = end_node != _goal
	if path.is_empty() and end_node != _goal:
		search_state = Search.FAILED
	else:
		search_state = Search.FOUND
