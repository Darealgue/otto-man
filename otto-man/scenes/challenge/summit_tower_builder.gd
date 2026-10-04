class_name SummitTowerBuilder
extends RefCounted

## Zirve Tırmanışı: gökyüzünde yukarı doğru dizilen platformlar. Oyuncu zıplayarak zirveye çıkar,
## yolda altın toplar. Yükseldikçe platformlar küçülür, aralar ve basamak yüksekliği artar.
## İki platform türü:
##   "wall"   : orman zemin karosu (2 satır kalın, her yandan katı; altından zıplanamaz)
##   "oneway" : tek satırlık tek yönlü platform (dungeon tileset'in "walls2" terrain'i; alttan geçilir,
##              1-2 karoluk parçalar çok daha zor)
## Ana yoldaki her platform bir öncekinden ulaşılabilir (basamak <= MAX_STEP_ROWS, yatay açıklık sınırlı);
## yol dışı yan çıkıntılar ("branch") daha değerli altın taşır ve risk ister.
## Düzen yalnızca karo/koordinat verisidir; çizim ve altın yerleşimi build() içinde yapılır.

const TILESET_PATH := "res://Tile set/dungeon_master_tileset.tres"
const COIN_TEX_PATH := "res://assets/objects/dungeon/coin_small.png"
const TILE: int = 32
const COLS: int = 60
const WALL_COLS: int = 3
const FLOOR_ROW: int = 29
const GROUND_DEPTH: int = 8
const OVERSCAN: int = 6
const LEFT_COL: int = WALL_COLS
const RIGHT_COL: int = COLS - WALL_COLS            # dışlayıcı
const TERRAIN_SET_DUNGEON: int = 0
const TERRAIN_SET_FOREST: int = 1
const TERRAIN_ONEWAY: int = 1                      # dungeon set içindeki "walls2"
## Bir basamakta en çok çıkılan satır. Ölçüm (headless): tek zıplama 5.0 satır, çift zıplama 7.7 satır; 1.7 satır pay bırakıldı.
const MAX_STEP_ROWS: int = 6
## Katı platformun altına bu kadar satır mesafe içinde başka bir platform varsa zıplama alanı kapanır sayılır.
const JUMP_ZONE_ROWS: int = 11
## Yüzeydeki durma noktasının üstündeki en az boşluk (satır)
const MIN_HEADROOM_ROWS: int = 4
## Karo üst kenarından çarpışma yüzeyine fark (px)
const WALL_SURFACE_OFFSET: float = 8.0
const ONEWAY_SURFACE_OFFSET: float = 4.0


## Platform sayısı zorlukla artar: zorluk 1 ~19, zorluk 9 ~59 (yaklaşık 2 ekran -> 8 ekran yükseklik).
static func platform_count(difficulty: int) -> int:
	return 14 + 5 * clampi(difficulty, 1, 9)


## Düzeni üretir (çizmeden): {"plats": [...], "coins": [...], "summit": {...}, "top_row": int}
static func plan(difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var d: int = clampi(difficulty, 1, 9)
	var n: int = platform_count(d)
	var plats: Array[Dictionary] = []
	var coins: Array[Dictionary] = []
	# Başlangıç referansı: zemin (tam genişlik); ilk platform ortaya yakın
	var cur: Dictionary = {"c0": 26, "c1": 34, "r": FLOOR_ROW, "kind": "ground"}
	var side: int = 1 if rng.randf() < 0.5 else -1
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		# Zorluk düşükse kulenin en sert kısmına hiç ulaşılmaz (zorluk 1: %55, zorluk 9: %100)
		var te: float = t * lerpf(0.55, 1.0, float(d - 1) / 8.0)
		var placed: Dictionary = {}
		for attempt in range(40):
			var cand: Dictionary = _route_candidate(rng, cur, side, te, d, i, attempt)
			if not _conflicts(plats, cand):
				placed = cand
				break
		if placed.is_empty():
			# Çözülemeyen düzende yol kopmasın: aynı sütunların üstüne tek yönlü platform
			placed = _fallback_oneway(rng, cur, te)
		placed["route"] = true
		plats.append(placed)
		_add_route_coins(rng, coins, plats, placed, cur, t, d)
		# Yan çıkıntı: yeni platformun gittiği yönün tersinde
		var went: int = 1 if int(placed["c0"]) >= int(cur["c1"]) else -1
		if i >= 2 and i < n and rng.randf() < lerpf(0.55, 0.35, t):
			_try_branch(rng, plats, coins, cur, -went, te, d)
		# Sonraki yön: kenara yakınsa içeri, değilse çoğunlukla zikzak
		var next_side: int = -went if rng.randf() < 0.72 else went
		var center: float = (float(placed["c0"]) + float(placed["c1"])) * 0.5
		if center < 18.0:
			next_side = 1
		elif center > float(COLS - 18):
			next_side = -1
		side = next_side
		cur = placed
	# Zirve: geniş katı platform. Önceki platformun yanına (üstüne değil) yerleşir ki altından zıplamak engellenmesin.
	var summit: Dictionary = _place_summit(rng, plats, cur)
	summit["route"] = true
	plats.append(summit)
	return {"plats": plats, "coins": coins, "summit": summit, "top_row": int(summit["r"])}


## Zirve platformunu arar: önceki platformdan en çok 6 karo açıklıkta, çakışmasız; olmazsa daralır.
static func _place_summit(rng: RandomNumberGenerator, plats: Array[Dictionary], cur: Dictionary) -> Dictionary:
	var cc: float = (float(cur["c0"]) + float(cur["c1"])) * 0.5
	for w in [14, 10, 8, 6]:
		for dy in [4, 5, 3, 6]:
			var best: Dictionary = {}
			var best_score: float = 1.0e9
			for c0 in range(LEFT_COL, RIGHT_COL - w + 1):
				var c1: int = c0 + w
				var gap: int = maxi(c0 - int(cur["c1"]), int(cur["c0"]) - c1)
				if gap < 1 or gap > 6:
					continue
				var cand: Dictionary = {"c0": c0, "c1": c1, "r": int(cur["r"]) - dy, "kind": "summit"}
				if _conflicts(plats, cand):
					continue
				var score: float = absf(float(c0 + c1) * 0.5 - cc) + rng.randf() * 6.0
				if score < best_score:
					best_score = score
					best = cand
			if not best.is_empty():
				return best
	# Son çare: çakışma denetimi olmadan yan tarafa
	var right: bool = cc < 30.0
	var sc0: int = int(cur["c1"]) + 2 if right else int(cur["c0"]) - 2 - 8
	sc0 = clampi(sc0, LEFT_COL, RIGHT_COL - 8)
	return {"c0": sc0, "c1": sc0 + 8, "r": int(cur["r"]) - 4, "kind": "summit"}


static func _thickness(kind: String) -> int:
	return 1 if kind == "oneway" else 2


## Ana yol için aday platform: basamak, genişlik, tür ve yatay açıklık ilerlemeye (t) göre.
static func _route_candidate(rng: RandomNumberGenerator, cur: Dictionary, side: int, t: float, d: int, index: int, attempt: int) -> Dictionary:
	var dy_lo: int = int(round(lerpf(2.0, 4.0, t)))
	var dy_hi: int = mini(int(round(lerpf(3.0, 6.0, t))), MAX_STEP_ROWS)
	var dy: int = rng.randi_range(dy_lo, maxi(dy_lo, dy_hi))
	if index == 1:
		dy = 4
	var p_oneway: float = lerpf(0.12, 0.5, t)
	# Çok deneme yapılmışsa tek yönlü platforma kay (yukarıdan blok sorunu çıkarmaz)
	var oneway: bool = rng.randf() < p_oneway or attempt >= 14
	var w: int
	if oneway:
		w = clampi(int(round(lerpf(6.0, 1.5, t))) + rng.randi_range(-1, 1), 1, 7)
	else:
		w = clampi(int(round(lerpf(11.0, 3.0, t))) + rng.randi_range(-1, 1), 3, 14)
	if index == 1:
		w = 12
		oneway = false
	var gap_cap: int = int(round(lerpf(3.0, 7.0, t) * (0.85 + 0.035 * float(d)))) - maxi(0, dy - 4)
	gap_cap = clampi(gap_cap, 1, 8)
	var gap_lo: int = mini(int(lerpf(0.0, 2.0, t)), gap_cap)
	var gap: int = rng.randi_range(gap_lo, gap_cap)
	if oneway and w == 1:
		gap = mini(gap, 3)   # tek karolu platforma çok uzak sıçranmaz
	if index == 1:
		gap = 0
	var s: int = side if attempt % 3 != 2 else -side
	var c0: int
	var c1: int
	if index == 1:
		# Doğma noktasının (ortada) üstünde olmasın: soldaki ya da sağdaki uçta başlar
		c0 = (6 if rng.randf() < 0.5 else 42) + rng.randi_range(-1, 1)
		c1 = c0 + w
	elif s > 0:
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
	return {"c0": c0, "c1": c1, "r": int(cur["r"]) - dy, "kind": "oneway" if oneway else "wall"}


static func _fallback_oneway(rng: RandomNumberGenerator, cur: Dictionary, t: float) -> Dictionary:
	var w: int = clampi(int(round(lerpf(5.0, 2.0, t))), 2, 6)
	var cc: int = (int(cur["c0"]) + int(cur["c1"])) / 2
	var c0: int = clampi(cc - w / 2 + rng.randi_range(-3, 3), LEFT_COL, RIGHT_COL - w)
	return {"c0": c0, "c1": c0 + w, "r": int(cur["r"]) - 3, "kind": "oneway"}


## Aday platform başka bir platformun zıplama alanını kapatıyor mu / durma noktasının başını örtüyor mu?
static func _conflicts(plats: Array[Dictionary], cand: Dictionary) -> bool:
	var c0: int = int(cand["c0"])
	var c1: int = int(cand["c1"])
	var r: int = int(cand["r"])
	var kind: String = String(cand["kind"])
	var thick: int = _thickness(kind)
	var solid: bool = kind != "oneway"
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
		var qthick: int = _thickness(qkind)
		var qsolid: bool = qkind != "oneway"
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


## Ana yol platformuna altın: yüzeyde dizi, ara sıra havada tek altın ve boşlukta yay.
static func _add_route_coins(rng: RandomNumberGenerator, coins: Array[Dictionary], plats: Array[Dictionary], p: Dictionary, prev: Dictionary, t: float, d: int) -> void:
	var small_value: int = 1 + int(t * 3.0) + d / 4
	var w: int = int(p["c1"]) - int(p["c0"])
	var sx0: float = float(int(p["c0"]) * TILE)
	var surface: float = surface_y(p)
	if rng.randf() < 0.75:
		var k: int = rng.randi_range(1, clampi(w - 1, 1, 4))
		for j in range(k):
			var fx: float = sx0 + (float(j) + 0.5) * float(w * TILE) / float(k)
			coins.append({"x": fx, "y": surface - 26.0, "v": small_value, "tier": 0})
	if rng.randf() < 0.3:
		coins.append({"x": sx0 + float(w * TILE) * 0.5, "y": surface - 110.0, "v": small_value * 2, "tier": 1})
	# Boşlukta yay: iki platform arası, atlayışı yönlendirir
	var pw0: int = int(prev["c0"])
	var pw1: int = int(prev["c1"])
	var gap_left: int = int(p["c0"]) - pw1
	var gap_right: int = pw0 - int(p["c1"])
	var gap: int = maxi(gap_left, gap_right)
	if gap >= 3 and rng.randf() < 0.45:
		var from_x: float
		var to_x: float
		if gap_left >= gap_right:
			from_x = float(pw1 * TILE)
			to_x = float(int(p["c0"]) * TILE)
		else:
			from_x = float(pw0 * TILE)
			to_x = float(int(p["c1"]) * TILE)
		var y0: float = surface_y(prev)
		for f in [0.25, 0.5, 0.75]:
			var arc: float = 1.0 - pow(2.0 * f - 1.0, 2.0)
			coins.append({"x": lerpf(from_x, to_x, f), "y": lerpf(y0, surface, f) - 70.0 - 60.0 * arc, "v": 1, "tier": 0})


## Yol dışı yan çıkıntı (ve ara sıra ikinci çıkıntı): ödülü büyük, ulaşması riskli.
static func _try_branch(rng: RandomNumberGenerator, plats: Array[Dictionary], coins: Array[Dictionary], from_p: Dictionary, dir: int, t: float, d: int) -> void:
	var anchor: Dictionary = from_p
	var chain: int = 2 if rng.randf() < 0.25 * t + 0.1 else 1
	for step in range(chain):
		var oneway: bool = rng.randf() < lerpf(0.25, 0.6, t)
		var w: int = rng.randi_range(1, 4) if oneway else rng.randi_range(3, 6)
		var dy: int = rng.randi_range(-1, 3) if step == 0 else rng.randi_range(0, 3)
		var gap: int = rng.randi_range(1, clampi(int(round(lerpf(3.0, 6.0, t))), 2, 6))
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
		if _conflicts(plats, cand):
			return
		plats.append(cand)
		# Büyük altın: yan çıkıntı ödülü
		var surf: float = surface_y(cand)
		var cx: float = float(c0 * TILE) + float(w * TILE) * 0.5
		var last_step: bool = step == chain - 1
		var big_value: int = (6 + int(t * 8.0) + d) * (2 if last_step and chain == 2 else 1)
		coins.append({"x": cx, "y": surf - 30.0, "v": big_value, "tier": 2})
		if w >= 3:
			coins.append({"x": cx - 36.0, "y": surf - 26.0, "v": 2 + d / 3, "tier": 0})
			coins.append({"x": cx + 36.0, "y": surf - 26.0, "v": 2 + d / 3, "tier": 0})
		anchor = cand


## Platformun yürünebilir yüzeyinin dünya y'si.
static func surface_y(p: Dictionary) -> float:
	var off: float = ONEWAY_SURFACE_OFFSET if String(p["kind"]) == "oneway" else WALL_SURFACE_OFFSET
	return float(int(p["r"]) * TILE) + off


## Kulenin tamamını `root` altında kurar ve yerleşim sözlüğünü döndürür.
static func build(root: Node2D, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var d: int = clampi(difficulty, 1, 9)
	var data: Dictionary = plan(d, rng)
	var plats: Array = data["plats"]
	var summit: Dictionary = data["summit"]
	var top_row: int = int(data["top_row"])

	var layer := TileMapLayer.new()
	layer.name = "TileMapLayer"
	layer.tile_set = load(TILESET_PATH) as TileSet
	root.add_child(layer)

	var wall_cells: Array[Vector2i] = []
	for x in range(-OVERSCAN, COLS + OVERSCAN):
		for y in range(FLOOR_ROW, FLOOR_ROW + GROUND_DEPTH):
			wall_cells.append(Vector2i(x, y))
	var oneway_cells: Array[Vector2i] = []
	for p in plats:
		var kind: String = String(p["kind"])
		for x in range(int(p["c0"]), int(p["c1"])):
			if kind == "oneway":
				oneway_cells.append(Vector2i(x, int(p["r"])))
			else:
				wall_cells.append(Vector2i(x, int(p["r"])))
				wall_cells.append(Vector2i(x, int(p["r"]) + 1))
	layer.set_cells_terrain_connect(wall_cells, TERRAIN_SET_FOREST, 0)
	if not oneway_cells.is_empty():
		layer.set_cells_terrain_connect(oneway_cells, TERRAIN_SET_DUNGEON, TERRAIN_ONEWAY)

	var floor_y: float = float(FLOOR_ROW * TILE)
	var left_x: float = float(LEFT_COL * TILE)
	var right_x: float = float(RIGHT_COL * TILE)
	var summit_y: float = surface_y(summit)
	var tower_height: float = floor_y - summit_y
	_add_boundaries(root, left_x, right_x, floor_y, summit_y)

	var coin_records: Array[Dictionary] = spawn_coins(root, data["coins"])
	var flag_pos := Vector2((float(summit["c0"]) + float(summit["c1"])) * 0.5 * float(TILE), summit_y)
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
	}


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


## Altın sprite'ları (8 karelik dönen madeni para) ve toplama kayıtları. Toplamayı oda denetler.
static func spawn_coins(root: Node2D, coin_defs: Array) -> Array[Dictionary]:
	var tex := load(COIN_TEX_PATH) as Texture2D
	var holder := Node2D.new()
	holder.name = "Coins"
	holder.z_index = 3
	root.add_child(holder)
	var records: Array[Dictionary] = []
	for c in coin_defs:
		var tier: int = int(c["tier"])
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = 8
		sprite.frame = randi() % 8
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var s: float = [2.4, 3.4, 5.0][tier]
		sprite.scale = Vector2(s, s)
		if tier == 2:
			sprite.modulate = Color(1.0, 0.85, 0.35)
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
