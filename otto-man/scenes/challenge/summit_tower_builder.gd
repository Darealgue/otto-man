class_name SummitTowerBuilder
extends RefCounted

## Zirve Tırmanışı: gökyüzünde yukarı doğru dizilen platformlar. Oyuncu zıplayarak zirveye çıkar,
## yolda altın toplar. Yükseldikçe platformlar küçülür, aralar ve basamak yüksekliği artar.
## Başlangıçta alçak platform yok: engebeli zeminde bir ağaç öbeği (tree1 + tree3) dallarından yukarı çıkılır.
## Platform türleri:
##   "wall"   : orman zemin karosu, altı pürüzlü ada gibi (2-5 satır; her yandan katı, altından zıplanamaz)
##   "oneway" : tek satırlık tek yönlü platform (dungeon tileset'in "walls2" terrain'i, kahverengiye boyanır)
##   "branch" : sahnedeki hazır ağaçların tek yönlü dalları (çizilmez, sadece düzen/test verisi)
##   "summit" : zirve; ekranın bir yanındaki dağdan çıkıntı yapan kaya sırtı
## Ana yoldaki her platform bir öncekinden ulaşılabilir (basamak <= MAX_STEP_ROWS, yatay açıklık sınırlı);
## yol dışı yan çıkıntılar daha değerli altın (kese) taşır ve risk ister.

const TILESET_PATH := "res://Tile set/dungeon_master_tileset.tres"
const COIN_TEX_PATH := "res://assets/objects/dungeon/coin_small.png"
const POUCH_TEX_PATH := "res://assets/objects/dungeon/pouch.png"
const TREE1_PATH := "res://decoration/forest/tree1.tscn"
const TREE3_PATH := "res://decoration/forest/tree3.tscn"
const TILE: int = 32
const COLS: int = 60
const WALL_COLS: int = 0   # görünmez duvarlar ekranın kenarında: oyuncu ekranın en ucuna kadar yürüyebilir
const FLOOR_ROW: int = 29
const GROUND_DEPTH: int = 8
const OVERSCAN: int = 6
const LEFT_COL: int = WALL_COLS
const RIGHT_COL: int = COLS - WALL_COLS            # dışlayıcı
const TERRAIN_SET_DUNGEON: int = 0
const TERRAIN_SET_FOREST: int = 1
const TERRAIN_ONEWAY: int = 1                      # dungeon set içindeki "walls2"
## Tek yönlü platformlar gri taş; kahverengi toprak karolarına yaklaştırmak için çarpan renk
const ONEWAY_TINT := Color(0.8, 0.52, 0.38)
## Bir basamakta en çok çıkılan satır. Ölçüm (headless): tek zıplama 5.0 satır, çift zıplama 7.7 satır; 1.7 satır pay bırakıldı.
const MAX_STEP_ROWS: int = 6
## Katı platformun altına bu kadar satır mesafe içinde başka bir platform varsa zıplama alanı kapanır sayılır.
const JUMP_ZONE_ROWS: int = 11
## Yüzeydeki durma noktasının üstündeki en az boşluk (satır)
const MIN_HEADROOM_ROWS: int = 4
## Karo üst kenarından çarpışma yüzeyine fark (px)
const WALL_SURFACE_OFFSET: float = 8.0
const ONEWAY_SURFACE_OFFSET: float = 4.0
## Ağaç sprite'ları (merkez orijinli): yükseklik ve dal [x0, x1, y] değerleri sahne dosyalarından (tree1/tree3.tscn)
const TREE1_H: float = 900.0
const TREE3_H: float = 1500.0
const SPAWN_FLAT_COLS := Vector2i(24, 36)


## Platform sayısı zorlukla artar: zorluk 1 ~19, zorluk 9 ~59 (yaklaşık 2 ekran -> 8 ekran yükseklik).
static func platform_count(difficulty: int) -> int:
	return 14 + 5 * clampi(difficulty, 1, 9)


static func _is_solid(kind: String) -> bool:
	return kind == "wall" or kind == "summit"


static func _depth(p: Dictionary) -> int:
	if p.has("dmax"):
		return int(p["dmax"])
	return 2 if _is_solid(String(p["kind"])) else 1


## Platformun yürünebilir yüzeyinin dünya y'si.
static func surface_y(p: Dictionary) -> float:
	if p.has("surf_y"):
		return float(p["surf_y"])
	var off: float = ONEWAY_SURFACE_OFFSET if String(p["kind"]) == "oneway" else WALL_SURFACE_OFFSET
	return float(int(p["r"]) * TILE) + off


## Platformun yürünebilir x aralığı (px)
static func span_px(p: Dictionary) -> Vector2:
	if p.has("x0"):
		return Vector2(float(p["x0"]), float(p["x1"]))
	return Vector2(float(int(p["c0"]) * TILE), float(int(p["c1"]) * TILE))


# --- Ağaç öbeği (başlangıç) -----------------------------------------------------------------------

## Zeminde tree1 + tree3 öbeği; dalları ilk platforma giden basamaklardır. Yarısında ayna çevrilir.
static func _make_cluster(rng: RandomNumberGenerator) -> Dictionary:
	var mirror: bool = rng.randf() < 0.5
	var x1: float = 300.0 + rng.randf_range(-30.0, 30.0)
	var x3: float = x1 + 330.0
	var ground_y: float = float(FLOOR_ROW * TILE) + WALL_SURFACE_OFFSET
	var cy1: float = ground_y - TREE1_H * 0.5 + 6.0
	var cy3: float = ground_y - TREE3_H * 0.5 + 6.0
	var raw: Array = [
		{"x0": x1 + 55.0, "x1": x1 + 145.0, "y": cy1 + 277.0, "route": true},    # tree1 sağ dalı (zeminden çift zıplama)
		{"x0": x3 - 185.0, "x1": x3 - 73.0, "y": cy3 + 518.0, "route": true},    # tree3 alt sol
		{"x0": x3 + 58.0, "x1": x3 + 165.0, "y": cy3 + 402.0, "route": true},    # tree3 sağ
		{"x0": x3 - 169.0, "x1": x3 - 73.0, "y": cy3 + 269.0, "route": true},    # tree3 orta sol (öbeğin tepesi)
		{"x0": x1 - 148.0, "x1": x1 - 53.0, "y": cy1 + 232.0, "route": false},   # tree1 sol dalı (yan)
	]
	var branches: Array[Dictionary] = []
	for rb in raw:
		var bx0: float = float(rb["x0"])
		var bx1: float = float(rb["x1"])
		if mirror:
			bx0 = float(COLS * TILE) - float(rb["x1"])
			bx1 = float(COLS * TILE) - float(rb["x0"])
		branches.append({
			"kind": "branch", "x0": bx0, "x1": bx1, "c0": floori(bx0 / float(TILE)), "c1": ceili(bx1 / float(TILE)),
			"r": floori(float(rb["y"]) / float(TILE)), "surf_y": float(rb["y"]), "route": bool(rb["route"]),
		})
	var span_a: float = x1 - 230.0
	var span_b: float = x3 + 230.0
	if mirror:
		var tmp: float = float(COLS * TILE) - span_b
		span_b = float(COLS * TILE) - span_a
		span_a = tmp
	return {
		"mirror": mirror, "x1": x1, "x3": x3, "cy1": cy1, "cy3": cy3,
		"branches": branches, "span": Vector2(span_a, span_b),
	}


# --- Düzen ---------------------------------------------------------------------------------------

## Düzeni üretir (çizmeden): {"plats", "coins", "summit", "top_row", "cluster"}
static func plan(difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var d: int = clampi(difficulty, 1, 9)
	var n: int = platform_count(d)
	var plats: Array[Dictionary] = []
	var coins: Array[Dictionary] = []
	var cluster: Dictionary = _make_cluster(rng)
	for b in cluster["branches"]:
		plats.append(b)
	# Rota ağaç öbeğinin tepesinden (tree3 orta sol dalı) başlar
	var cur: Dictionary = (cluster["branches"] as Array)[3]
	var side: int = -1 if bool(cluster["mirror"]) else 1
	# Zirvenin bağlı olduğu dağ yönü: bağlı çıkıntı platformlar da hep bu yana bağlanır
	var mount: int = 1 if rng.randf() < 0.5 else -1
	var prev: Dictionary = cur
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		# Zorluk düşükse kulenin en sert kısmına hiç ulaşılmaz (zorluk 1: %55, zorluk 9: %100)
		var te: float = t * lerpf(0.55, 1.0, float(d - 1) / 8.0)
		var placed: Dictionary = {}
		for attempt in range(40):
			var cand: Dictionary = _route_candidate(rng, cur, side, te, d, i, attempt, mount, n)
			if not _conflicts(plats, cand) and not (bool(cand.get("attached", false)) and _mass_conflicts(plats, cand)):
				placed = cand
				break
		if placed.is_empty():
			# Çözülemeyen düzende yol kopmasın: aynı sütunların üstüne tek yönlü platform
			placed = _fallback_oneway(rng, cur, te)
		placed["route"] = true
		plats.append(placed)
		_add_route_coins(rng, coins, placed, cur, t, d)
		# Yan çıkıntı: yeni platformun gittiği yönün tersinde
		var went: int = 1 if int(placed["c0"]) >= int(cur["c1"]) else -1
		if i >= 2 and i < n - 5 and rng.randf() < lerpf(0.55, 0.35, t):
			_try_branch(rng, plats, coins, cur, -went, te, d, mount)
		# Sonraki yön: kenara yakınsa içeri, değilse çoğunlukla zikzak
		var next_side: int = -went if rng.randf() < 0.72 else went
		var center: float = (float(placed["c0"]) + float(placed["c1"])) * 0.5
		if center < 18.0:
			next_side = 1
		elif center > float(COLS - 18):
			next_side = -1
		if bool(placed.get("attached", false)):
			next_side = -mount
		# Son platformlarda zirvenin serbest ucuna yaklaş (dağ yönünde kolon 40/20 civarı)
		if i >= n - 5:
			var target_col: float = 34.0 if mount > 0 else 26.0
			next_side = 1 if center < target_col else -1
		side = next_side
		prev = cur
		cur = placed
	# Zirve: ekranın bir yanındaki dağdan çıkıntı yapan kaya sırtı
	var summit: Dictionary = _place_summit(rng, plats, cur, prev, mount)
	summit["route"] = true
	plats.append(summit)
	return {"plats": plats, "coins": coins, "summit": summit, "top_row": int(summit["r"]), "cluster": cluster, "mount": mount}


## Ana yol için aday platform: basamak, genişlik, tür ve yatay açıklık ilerlemeye (t) göre.
## Basamaklar ve açıklıklar eskisinden büyük: tırmanış kolay olmasın.
static func _route_candidate(rng: RandomNumberGenerator, cur: Dictionary, side: int, t: float, d: int, index: int, attempt: int, mount: int = 0, n: int = 0) -> Dictionary:
	var dy_lo: int = int(round(lerpf(3.0, 5.0, t)))
	var dy_hi: int = mini(int(round(lerpf(4.0, 6.0, t))), MAX_STEP_ROWS)
	var dy: int = rng.randi_range(dy_lo, maxi(dy_lo, dy_hi))
	if index == 1:
		dy = 4
	var p_oneway: float = lerpf(0.15, 0.5, t)
	# Çok deneme yapılmışsa tek yönlü platforma kay (yukarıdan blok sorunu çıkarmaz)
	var oneway: bool = rng.randf() < p_oneway or attempt >= 14
	var w: int
	if oneway:
		w = clampi(int(round(lerpf(5.0, 1.5, t))) + rng.randi_range(-1, 1), 1, 7)
	else:
		w = clampi(int(round(lerpf(10.0, 3.0, t))) + rng.randi_range(-1, 1), 3, 14)
	if index == 1:
		w = 10
		oneway = false
	var gap_cap: int = int(round(lerpf(4.0, 8.0, t) * (0.85 + 0.035 * float(d)))) - maxi(0, dy - 4)
	gap_cap = clampi(gap_cap, 2, 9)
	var gap_lo: int = mini(maxi(1, int(lerpf(1.0, 3.0, t))), gap_cap)
	var gap: int = rng.randi_range(gap_lo, gap_cap)
	if oneway and w == 1:
		gap = mini(gap, 3)   # tek karolu platforma çok uzak sıçranmaz
	if index == 1:
		gap = 2
	var s: int = side if attempt % 3 != 2 else -side
	var c0: int
	var c1: int
	if s > 0:
		c0 = int(cur["c1"]) + gap
		c1 = c0 + w
	else:
		c1 = int(cur["c0"]) - gap
		c0 = c1 - w
	# Sınır dışına taşarsa içeri çek
	if c0 < LEFT_COL:
		c1 += LEFT_COL - c0
		c0 = LEFT_COL
	if c1 > RIGHT_COL:
		c0 -= c1 - RIGHT_COL
		c1 = RIGHT_COL
	c0 = maxi(c0, LEFT_COL)
	var out: Dictionary = {"c0": c0, "c1": c1, "r": int(cur["r"]) - dy, "kind": "oneway" if oneway else "wall"}
	if not oneway:
		# Dağ yanına yakın katı platformlar çoğu zaman dağdan çıkıntı yapar (zirve ile aynı yön); son 8 platformda bağlanmaz
		var near_edge: bool = (mount > 0 and c1 >= RIGHT_COL - 11) or (mount < 0 and c0 <= LEFT_COL + 11)
		var mid_col: int = (c0 + c1) / 2
		var on_mount_half: bool = (mount > 0 and mid_col >= 30) or (mount < 0 and mid_col <= 30)
		var p_attach: float = 0.85 if near_edge else (0.5 if on_mount_half else 0.0)
		if index > 1 and mount != 0 and index <= n - 8 and rng.randf() < p_attach:
			_attach_mass(rng, out, mount)
		else:
			var prof: Array[int] = _make_profile(rng, c1 - c0)
			out["prof"] = prof
			out["dmax"] = prof.max()
	return out


## Katı platformun altını pürüzlü bir ada gibi şekillendirir: uçlar ince, ortada 2-5 satır kalınlık,
## en az 2 sütunluk parçalar (tek sütunluk çıkıntı terrain'de düzgün karo üretmez).
static func _make_profile(rng: RandomNumberGenerator, w: int) -> Array[int]:
	var prof: Array[int] = []
	var depth_cap: int = clampi(2 + w / 3, 2, 5)
	var remaining: int = w
	var first: bool = true
	while remaining > 0:
		var len: int = mini(remaining, rng.randi_range(2, 4))
		if remaining - len == 1:
			len += 1
		var last: bool = (remaining - len) <= 0
		var depth: int
		if first or last:
			depth = 2 if rng.randf() < 0.7 else 3
		else:
			depth = rng.randi_range(2, depth_cap)
		for k in range(len):
			prof.append(depth)
		remaining -= len
		first = false
	return prof


## Katı platformu dağa bağlar (zirvedekiyle aynı yön): serbest uç yerinde kalır, platform ekranın kenarına kadar uzanır ve
## kalınlaşan bir kütleyle dağa bağlanır.
static func _attach_mass(rng: RandomNumberGenerator, out: Dictionary, mount: int) -> void:
	if mount > 0:
		out["pc0"] = int(out["c0"])
		out["pc1"] = COLS + OVERSCAN
		out["c1"] = RIGHT_COL
	else:
		out["pc0"] = -OVERSCAN
		out["pc1"] = int(out["c1"])
		out["c0"] = LEFT_COL
	var mprof: Array[int] = _mass_profile(rng, int(out["pc1"]) - int(out["pc0"]), mount, 5)
	out["prof"] = mprof
	# Standart çakışma denetimi için serbest uca yakın 6 sütunun kalınlığı; tam kütle _mass_conflicts ile sütun sütun denetlenir
	var near_max: int = 2
	for k in range(mini(6, mprof.size())):
		near_max = maxi(near_max, int(mprof[k] if mount > 0 else mprof[mprof.size() - 1 - k]))
	out["dmax"] = near_max
	out["attached"] = true
	out["side"] = mount


static func _fallback_oneway(rng: RandomNumberGenerator, cur: Dictionary, t: float) -> Dictionary:
	var w: int = clampi(int(round(lerpf(5.0, 2.0, t))), 2, 6)
	var cc: int = (int(cur["c0"]) + int(cur["c1"])) / 2
	var c0: int = clampi(cc - w / 2 + rng.randi_range(-3, 3), LEFT_COL, RIGHT_COL - w)
	return {"c0": c0, "c1": c0 + w, "r": int(cur["r"]) - 4, "kind": "oneway"}


## Aday platform başka bir platformun zıplama alanını kapatıyor mu / durma noktasının başını örtüyor mu?
static func _conflicts(plats: Array[Dictionary], cand: Dictionary) -> bool:
	var c0: int = int(cand["c0"])
	var c1: int = int(cand["c1"])
	var r: int = int(cand["r"])
	var kind: String = String(cand["kind"])
	var thick: int = _depth(cand)
	var solid: bool = _is_solid(kind)
	# Zemin (tam genişlik): katı platformun altında en az 2 satır (64 px) boşluk kalmalı, oyuncu sıkışmasın
	if solid and r + thick <= FLOOR_ROW and (FLOOR_ROW - (r + thick)) < 2:
		return true
	for q in plats:
		var qc0: int = int(q["c0"])
		var qc1: int = int(q["c1"])
		# Yatay örtüşme (1 karo pay: yan yana değerse de çakışma sayılır)
		if not (c0 - 1 < qc1 and c1 + 1 > qc0):
			continue
		var qr: int = int(q["r"])
		var qkind: String = String(q["kind"])
		var qthick: int = _depth(q)
		var qsolid: bool = _is_solid(qkind)
		# Satırları üst üste binemez
		if r < qr + qthick and qr < r + thick:
			return true
		if r < qr:
			# Aday q'nun üstünde: katıysa q'nun zıplama alanını kapatmasın
			if solid and (qr - (r + thick)) < JUMP_ZONE_ROWS:
				return true
		else:
			# Aday q'nun altında: q katıysa adayın üstünde yeterli boşluk kalmalı
			if qsolid and (r - (qr + qthick)) < MIN_HEADROOM_ROWS:
				return true
	return false


## Ana yol platformuna altın: seyrek. Yüzeyde tek altın, ara sıra havada tek altın, nadiren kese ve boşlukta yay.
static func _add_route_coins(rng: RandomNumberGenerator, coins: Array[Dictionary], p: Dictionary, prev: Dictionary, t: float, d: int) -> void:
	var small_value: int = 1 + int(t * 3.0) + d / 4
	var sp: Vector2 = span_px(p)
	var width_px: float = sp.y - sp.x
	var surface: float = surface_y(p)
	if rng.randf() < 0.28:
		coins.append({"x": sp.x + rng.randf_range(0.25, 0.75) * width_px, "y": surface - 18.0, "v": small_value, "tier": 0})
	if rng.randf() < 0.12:
		coins.append({"x": sp.x + width_px * 0.5, "y": surface - 105.0, "v": small_value * 2, "tier": 1})
	if width_px >= 96.0 and rng.randf() < 0.06:
		coins.append({"x": sp.x + rng.randf_range(0.3, 0.7) * width_px, "y": surface - 14.0, "v": 5 + int(t * 6.0) + d / 2, "tier": 2})
	# Boşlukta yay: iki platform arası, atlayışı yönlendirir
	var gap_left: int = int(p["c0"]) - int(prev["c1"])
	var gap_right: int = int(prev["c0"]) - int(p["c1"])
	var gap: int = maxi(gap_left, gap_right)
	if gap >= 4 and rng.randf() < 0.12:
		var psp: Vector2 = span_px(prev)
		var from_x: float
		var to_x: float
		if gap_left >= gap_right:
			from_x = psp.y
			to_x = sp.x
		else:
			from_x = psp.x
			to_x = sp.y
		var y0: float = surface_y(prev)
		for f in [0.25, 0.5, 0.75]:
			var arc: float = 1.0 - pow(2.0 * f - 1.0, 2.0)
			coins.append({"x": lerpf(from_x, to_x, f), "y": lerpf(y0, surface, f) - 70.0 - 60.0 * arc, "v": small_value, "tier": 0})


## Yol dışı yan çıkıntı (ve ara sıra ikinci çıkıntı): ödülü büyük (kese), ulaşması riskli.
static func _try_branch(rng: RandomNumberGenerator, plats: Array[Dictionary], coins: Array[Dictionary], from_p: Dictionary, dir: int, t: float, d: int, mount: int = 0) -> void:
	var anchor: Dictionary = from_p
	var chain: int = 2 if rng.randf() < 0.25 * t + 0.1 else 1
	for step in range(chain):
		var oneway: bool = rng.randf() < lerpf(0.25, 0.6, t)
		var w: int = rng.randi_range(1, 4) if oneway else rng.randi_range(3, 6)
		var dy: int = rng.randi_range(-1, 3) if step == 0 else rng.randi_range(0, 3)
		var gap: int = rng.randi_range(2, clampi(int(round(lerpf(4.0, 7.0, t))), 3, 7))
		var c0: int
		var c1: int
		if dir > 0:
			c0 = int(anchor["c1"]) + gap
			c1 = c0 + w
		else:
			c1 = int(anchor["c0"]) - gap
			c0 = c1 - w
		if c0 < LEFT_COL or c1 > RIGHT_COL:
			return
		var cand: Dictionary = {"c0": c0, "c1": c1, "r": int(anchor["r"]) - dy, "kind": "oneway" if oneway else "wall", "route": false}
		if not oneway:
			var prof: Array[int] = _make_profile(rng, w)
			cand["prof"] = prof
			cand["dmax"] = prof.max()
		# Dağ yönündeki yan çıkıntılar da dağa bağlanabilir (kese serbest uçta kalır)
		if not oneway and mount != 0 and dir == mount and rng.randf() < 0.6:
			_attach_mass(rng, cand, mount)
		if _conflicts(plats, cand) or (bool(cand.get("attached", false)) and _mass_conflicts(plats, cand)):
			return
		plats.append(cand)
		# Kese: yan çıkıntı ödülü (zincirin sonu daha büyük)
		var surf: float = surface_y(cand)
		var cx: float = float(c0 * TILE) + float(w * TILE) * 0.5
		var last_step: bool = step == chain - 1
		var pouch_value: int = (6 + int(t * 8.0) + d) * (2 if last_step and chain == 2 else 1)
		coins.append({"x": cx, "y": surf - 14.0, "v": pouch_value, "tier": 2})
		anchor = cand


## Zirve platformunu arar: önceki platformun yanında (üstünde değil), en çok 6 karo açıklıkta; ekranın
## kenarına kadar uzanıp dağa bağlanır. Dağın kalınlığı serbest uçtan duvara doğru artar.
static func _place_summit(rng: RandomNumberGenerator, plats: Array[Dictionary], cur: Dictionary, prev: Dictionary, mount: int = 0) -> Dictionary:
	var cc: float = (float(cur["c0"]) + float(cur["c1"])) * 0.5
	var sides: Array = [1, -1] if cc < float(COLS) * 0.5 else [-1, 1]
	if mount != 0:
		sides = [mount, -mount]
	for dy in [4, 5, 3, 6]:
		for s in sides:
			var options: Array[Dictionary] = []
			for gap in range(1, 7):
				var cand: Dictionary = _summit_candidate(rng, cur, s, gap, dy)
				if cand.is_empty():
					continue
				if not _summit_conflicts(plats, cand, cur, prev):
					options.append(cand)
			if not options.is_empty():
				return options[rng.randi() % options.size()]
	# Son çare: çakışma denetimi olmadan yan tarafa
	var fallback: Dictionary = _summit_candidate(rng, cur, mount if mount != 0 else (1 if cc < float(COLS) * 0.5 else -1), 2, 4)
	if fallback.is_empty():
		fallback = _summit_candidate(rng, cur, -1, 2, 4)
	return fallback


## Dağdan çıkıntı kütlesinin sütun kalınlıkları: serbest uçta 3 satır, duvara doğru max_depth satıra kalınlaşır
## (ikişer üçer sütunluk parçalar, +-1 sapma). side > 0: dağ sağda (serbest uç solda), side < 0: tersi.
static func _mass_profile(rng: RandomNumberGenerator, width: int, side: int, max_depth: int) -> Array[int]:
	var prof: Array[int] = []
	var i: int = 0
	while i < width:
		var seg: int = mini(width - i, rng.randi_range(2, 3))
		var mid: int = i + seg / 2
		var dist: int = mid if side > 0 else (width - 1 - mid)
		var depth: int = clampi(3 + dist / 2 + rng.randi_range(-1, 1), 3, max_depth)
		for k in range(seg):
			prof.append(depth)
		i += seg
	return prof


static func _summit_candidate(rng: RandomNumberGenerator, cur: Dictionary, s: int, gap: int, dy: int) -> Dictionary:
	var c0: int
	var c1: int
	var pc0: int
	var pc1: int
	if s > 0:
		c0 = int(cur["c1"]) + gap
		if c0 > RIGHT_COL - 8:
			return {}
		c1 = RIGHT_COL
		pc0 = c0
		pc1 = COLS + OVERSCAN
	else:
		c1 = int(cur["c0"]) - gap
		if c1 < LEFT_COL + 8:
			return {}
		c0 = LEFT_COL
		pc0 = -OVERSCAN
		pc1 = c1
	var prof: Array[int] = _mass_profile(rng, pc1 - pc0, s, 11)
	return {
		"kind": "summit", "c0": c0, "c1": c1, "pc0": pc0, "pc1": pc1, "r": int(cur["r"]) - dy,
		"prof": prof, "dmax": prof.max(), "side": s,
	}


## Dağa bağlı çıkıntının kütlesi başka bir platformla kesişiyor mu (sütun sütun gerçek kalınlıkla, 1 satır/sütun payla)?
static func _mass_conflicts(plats: Array[Dictionary], cand: Dictionary) -> bool:
	var r: int = int(cand["r"])
	var pc0: int = int(cand["pc0"])
	var prof: Array = cand["prof"]
	for q in plats:
		var qc0: int = int(q["c0"])
		var qc1: int = int(q["c1"])
		var qr: int = int(q["r"])
		var qd: int = _depth(q)
		for i in range(prof.size()):
			var x: int = pc0 + i
			if x < qc0 - 1 or x > qc1:
				continue
			var sd: int = int(prof[i])
			if r - 1 < qr + qd and qr - 1 < r + sd:
				return true
	return false


## Zirve kütlesi başka bir platformla kesişiyor mu (sütun sütun gerçek kalınlıkla)?
## Son iki rota platformunun (cur, prev) zıplama alanı da kapanmamalı.
static func _summit_conflicts(plats: Array[Dictionary], cand: Dictionary, cur: Dictionary, prev: Dictionary) -> bool:
	var r: int = int(cand["r"])
	var pc0: int = int(cand["pc0"])
	var prof: Array = cand["prof"]
	for q in plats:
		var qc0: int = int(q["c0"])
		var qc1: int = int(q["c1"])
		var qr: int = int(q["r"])
		var qd: int = _depth(q)
		for i in range(prof.size()):
			var x: int = pc0 + i
			if x < qc0 - 1 or x > qc1:
				continue
			var sd: int = int(prof[i])
			if r - 1 < qr + qd and qr - 1 < r + sd:
				return true
	for q2 in [cur, prev]:
		if int(cand["c0"]) - 1 < int(q2["c1"]) and int(cand["c1"]) + 1 > int(q2["c0"]):
			return true
	return false


# --- Çizim ---------------------------------------------------------------------------------------

## Pürüzsüz, engebeli zemin satırları (sütun -> yüzey satırı). Doğma noktası ve ağaç öbeği düz kalır.
static func _ground_rows(rng: RandomNumberGenerator, flat_px: Vector2) -> Dictionary:
	var ph1: float = rng.randf() * TAU
	var ph2: float = rng.randf() * TAU
	var flat0: int = floori(flat_px.x / float(TILE))
	var flat1: int = ceili(flat_px.y / float(TILE))
	var rows: Dictionary = {}
	var is_flat: Dictionary = {}
	for x in range(-OVERSCAN, COLS + OVERSCAN):
		var off: int = int(round(1.3 * sin(float(x) * 0.16 + ph1) + 0.9 * sin(float(x) * 0.37 + ph2)))
		off = clampi(off, -2, 1)
		var flat: bool = (x >= SPAWN_FLAT_COLS.x and x <= SPAWN_FLAT_COLS.y) or (x >= flat0 and x <= flat1)
		if flat:
			off = 0
		is_flat[x] = flat
		rows[x] = FLOOR_ROW + off
	# Komşu sütunlar en çok 1 satır farklı olsun
	for pass_i in range(3):
		for x in range(-OVERSCAN + 1, COLS + OVERSCAN):
			if not is_flat[x]:
				rows[x] = clampi(int(rows[x]), int(rows[x - 1]) - 1, int(rows[x - 1]) + 1)
		for x in range(COLS + OVERSCAN - 2, -OVERSCAN - 1, -1):
			if not is_flat[x]:
				rows[x] = clampi(int(rows[x]), int(rows[x + 1]) - 1, int(rows[x + 1]) + 1)
	return rows


## Kulenin tamamını `root` altında kurar ve yerleşim sözlüğünü döndürür.
static func build(root: Node2D, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var d: int = clampi(difficulty, 1, 9)
	var data: Dictionary = plan(d, rng)
	# Zirve dağ yönüne bağlanamadıysa (nadir) düzeni yeniden üret
	for retry in range(6):
		if int((data["summit"] as Dictionary)["side"]) == int(data["mount"]):
			break
		data = plan(d, rng)
	var plats: Array = data["plats"]
	var summit: Dictionary = data["summit"]
	var cluster: Dictionary = data["cluster"]
	var top_row: int = int(data["top_row"])
	var ground: Dictionary = _ground_rows(rng, cluster["span"])

	# Zemin "TileMapLayer" adında: orman dekoru (ağaç/çiçek/kelebek) yalnız bu katmana yerleşir, platformlara değil
	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET_PATH) as TileSet
	root.add_child(layer)
	# Yol platformları ve zirve ayrı sahne kökleri: her birinin içindeki "TileMapLayer" orman dekoruna ayrı verilir
	# (yol platformlarına çalı/çiçek/çimen, zirveye ağaç da). Ağaçlı dekor yalnız zirvede açılır.
	var plat_holder := Node2D.new()
	plat_holder.name = "PlatformDecor"
	root.add_child(plat_holder)
	var plat_layer := TileMapLayer.new()
	plat_layer.name = "TileMapLayer"
	plat_layer.tile_set = layer.tile_set
	plat_holder.add_child(plat_layer)
	var summit_holder := Node2D.new()
	summit_holder.name = "SummitDecorRoot"
	root.add_child(summit_holder)
	var summit_layer := TileMapLayer.new()
	summit_layer.name = "TileMapLayer"
	summit_layer.tile_set = layer.tile_set
	summit_holder.add_child(summit_layer)
	# Tek yönlü platformlar ayrı katmanda: renk filtresi yalnız onlara uygulanır
	var ow_layer := TileMapLayer.new()
	ow_layer.name = "OnewayTiles"
	ow_layer.tile_set = layer.tile_set
	ow_layer.modulate = ONEWAY_TINT
	root.add_child(ow_layer)

	var ground_cells: Array[Vector2i] = []
	for x in range(-OVERSCAN, COLS + OVERSCAN):
		for y in range(int(ground[x]), FLOOR_ROW + GROUND_DEPTH + 4):
			ground_cells.append(Vector2i(x, y))
	var wall_cells: Array[Vector2i] = []
	var summit_cells: Array[Vector2i] = []
	var oneway_cells: Array[Vector2i] = []
	for p in plats:
		var kind: String = String(p["kind"])
		if kind == "branch":
			continue
		if kind == "oneway":
			for x in range(int(p["c0"]), int(p["c1"])):
				oneway_cells.append(Vector2i(x, int(p["r"])))
			continue
		var prof: Array = p["prof"]
		var px0: int = int(p.get("pc0", p["c0"]))
		for i in range(prof.size()):
			for k in range(int(prof[i])):
				if kind == "summit":
					summit_cells.append(Vector2i(px0 + i, int(p["r"]) + k))
				else:
					wall_cells.append(Vector2i(px0 + i, int(p["r"]) + k))
	layer.set_cells_terrain_connect(ground_cells, TERRAIN_SET_FOREST, 0)
	plat_layer.set_cells_terrain_connect(wall_cells, TERRAIN_SET_FOREST, 0)
	summit_layer.set_cells_terrain_connect(summit_cells, TERRAIN_SET_FOREST, 0)
	if not oneway_cells.is_empty():
		ow_layer.set_cells_terrain_connect(oneway_cells, TERRAIN_SET_DUNGEON, TERRAIN_ONEWAY)

	var floor_y: float = float(FLOOR_ROW * TILE)
	var left_x: float = float(LEFT_COL * TILE)
	var right_x: float = float(RIGHT_COL * TILE)
	var summit_y: float = surface_y(summit)
	var tower_height: float = floor_y - summit_y
	_add_boundaries(root, left_x, right_x, floor_y, summit_y)
	_spawn_cluster_trees(root, cluster)

	var coin_records: Array[Dictionary] = spawn_coins(root, data["coins"])
	var side: int = int(summit["side"])
	var flag_col: float = float(int(summit["c0"]) + 5) if side > 0 else float(int(summit["c1"]) - 5)
	var flag_pos := Vector2(flag_col * float(TILE), summit_y)
	_build_flag(root, flag_pos)

	return {
		"bounds": Rect2(left_x, summit_y - 600.0, right_x - left_x, tower_height + 600.0),
		"floor_y": floor_y,
		"left_x": left_x,
		"right_x": right_x,
		"center_x": (left_x + right_x) * 0.5,
		"player_spawn": Vector2((left_x + right_x) * 0.5, floor_y),
		"camera_position": Vector2(960.0, 540.0),
		"summit_y": summit_y,
		"summit_x0": float(int(summit["c0"]) * TILE),
		"summit_x1": float(int(summit["c1"]) * TILE),
		"flag_pos": flag_pos,
		"cam_min_y": summit_y - 420.0,
		"tower_height": tower_height,
		"top_row": top_row,
		"plats": plats,
		"coins": coin_records,
		"cluster_span": cluster["span"],
		"mount": int(data["mount"]),
		"platform_decor": plat_holder,
		"summit_decor": summit_holder,
	}


## Başlangıç ağaçları: sahnedeki hazır ağaçlar (dalları tek yönlü çarpışma); ayna çevrilirse sahne x ekseninde ters çevrilir.
static func _spawn_cluster_trees(root: Node2D, cluster: Dictionary) -> void:
	var mirror: bool = bool(cluster["mirror"])
	var width: float = float(COLS * TILE)
	var entries: Array = [
		[TREE1_PATH, float(cluster["x1"]), float(cluster["cy1"])],
		[TREE3_PATH, float(cluster["x3"]), float(cluster["cy3"])],
	]
	for e in entries:
		var packed := load(String(e[0])) as PackedScene
		if packed == null:
			continue
		var tree := packed.instantiate() as Node2D
		tree.name = "StartTree"
		tree.position = Vector2(width - float(e[1]) if mirror else float(e[1]), float(e[2]))
		tree.z_index = -2
		if mirror:
			tree.scale = Vector2(-1.0, 1.0)
		root.add_child(tree)


## Görünmez yan duvarlar (kule boyunca). Tutunulamaz: duvar zıplamasıyla sınırdan tırmanmak platformları atlatırdı.
static func _add_boundaries(root: Node2D, left_x: float, right_x: float, floor_y: float, summit_y: float) -> void:
	var body := StaticBody2D.new()
	body.name = "BoundaryWalls"
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.set_meta("no_wall_slide", true)
	var height: float = floor_y - summit_y + 3200.0
	var mid_y: float = summit_y - 1200.0 + height * 0.5
	for x in [left_x - 200.0, right_x + 200.0]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(400.0, height)
		shape.shape = rect
		shape.position = Vector2(x, mid_y)
		body.add_child(shape)
	root.add_child(body)


## Altınlar: tier 0/1 = oyunun normal madeni parası (8 karelik dönen şerit), tier 2 = altın kesesi.
## Orijinal boyutlarında çizilir (ölçek 1); toplamayı oda denetler.
static func spawn_coins(root: Node2D, coin_defs: Array) -> Array[Dictionary]:
	var coin_tex := load(COIN_TEX_PATH) as Texture2D
	var pouch_tex := load(POUCH_TEX_PATH) as Texture2D
	var holder := Node2D.new()
	holder.name = "Coins"
	holder.z_index = 3
	root.add_child(holder)
	var records: Array[Dictionary] = []
	for c in coin_defs:
		var tier: int = int(c["tier"])
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if tier == 2:
			sprite.texture = pouch_tex
			sprite.hframes = 2
			sprite.frame = 1   # yerde duran poşet karesi; zıplama animasyonu yok
		else:
			sprite.texture = coin_tex
			sprite.hframes = 8
			sprite.frame = randi() % 8
		sprite.position = Vector2(float(c["x"]), float(c["y"]))
		holder.add_child(sprite)
		records.append({"node": sprite, "pos": sprite.position, "v": int(c["v"]), "tier": tier, "taken": false})
	return records


## Zirvedeki bayrak: direk, kırmızı flama ve taş kaide (geçici sanat).
static func _build_flag(root: Node2D, pos: Vector2) -> void:
	var flag := Node2D.new()
	flag.name = "SummitFlag"
	flag.position = pos
	flag.z_index = 2
	var pole := ColorRect.new()
	pole.color = Color(0.35, 0.24, 0.14)
	pole.size = Vector2(6.0, 150.0)
	pole.position = Vector2(-3.0, -150.0)
	flag.add_child(pole)
	var cloth := Polygon2D.new()
	cloth.color = Color(0.78, 0.12, 0.16)
	cloth.polygon = PackedVector2Array([Vector2(3.0, -148.0), Vector2(70.0, -128.0), Vector2(3.0, -104.0)])
	flag.add_child(cloth)
	var base := ColorRect.new()
	base.color = Color(0.5, 0.48, 0.45)
	base.size = Vector2(36.0, 12.0)
	base.position = Vector2(-18.0, -12.0)
	flag.add_child(base)
	root.add_child(flag)
