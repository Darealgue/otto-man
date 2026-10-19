extends Node2D

## Köyü "yaşıyor" gösteren küçük köylü etkinlikleri: akşam köy merkezinde toplanma, öğle şekerlemesi, sohbet, yağmurda
## sığınma, yüzme, balık tutma, su taşıma, sırtında bohça taşıma, sandalyede oturma. Hiçbiri oyun mantığına dokunmaz;
## köylü boştayken (oyuncu köyünde AWAKE_IDLE/SOCIALIZING, ziyaret köyünde meydandayken) kısa süreliğine sürülür (bkz.
## VillagerShowActor), bitince rutinine döner. Yeni karakter çizimi gerekmez: mevcut animasyonlar + kodla çizilen efektler.
## Oyuncu köyünde (mode "village") ve ziyaret köylerinde (mode "visit") aynı kodla çalışır.

const _Actor = preload("res://village/scripts/show/VillagerShowActor.gd")
const _Bubble = preload("res://ui/npc_ambient_bubble.gd")
const _FishingLine = preload("res://village/scripts/show/ShowFishingLine.gd")
const _Ripple = preload("res://village/scripts/show/ShowWaterRipple.gd")
const _SwimVisual = preload("res://village/scripts/show/ShowSwimVisual.gd")

@export var mode: String = "village"             # "village" (Worker'lar) | "visit" (VisitVillager'lar)
@export var center_x: float = 0.0                # köy merkezi (kamp ateşi / meydan)
@export var has_water: bool = true               # suya girilebilen / balık tutulabilen bir kıyı var mı
@export var buildings_root_path: NodePath        # bina düğümlerinin kökü (kapı konumları, sınırlar)
@export var visit_scene_path: NodePath           # mode "visit": agents dizisini veren sahne
@export var enabled: bool = true

# Su geometrisi (köy ve ziyaret sahnelerinde aynı "Water" sprite'ı): yüzey y=98, su sprite'ı z 20'de oyuncu/köylülerin üstünde.
const WATER_SURFACE_Y: float = 98.0
const FISH_BANK_Y: float = 56.0                   # balıkçının oturduğu kıyı (çimen kenarı)
## Köylü sprite karesi 96 px ama çizilen figür ~50 px boyunda (ayaklar orijinde). Ayak y = su yüzeyi + ~24 olunca su çizgisi
## göğüs hizasına gelir: baş ve omuzlar görünür, vücudun alt yarısı su sprite'ının altında kalır.
const FIGURE_HEIGHT: float = 50.0
## Yüzücünün su çizgisi (ayak y - 28), su yüzeyinin (y 98) üstüne çıkmasın diye en sığ yüzme y'si yüzey + 28'dir. Band bunun
## altında 24 px genişliğindedir (çok aşağı inmeden aşağı yukarı gezinme).
const SWIM_DEPTH_MIN: float = WATER_SURFACE_Y + 28.0
const SWIM_DEPTH_MAX: float = WATER_SURFACE_Y + 52.0
const BAND_EDGE_Y: float = 30.0                   # yürünebilir bandın alt sınırı
const SIT_CHAIR_Y_OFFSET: float = -6.0            # oturma animasyonunu sandalyeye oturtmak için yukarı kayma (ayarlanır)

const TICK_MIN: float = 2.0
const TICK_MAX: float = 4.5
const COOLDOWN_MIN_MSEC: int = 40000
const COOLDOWN_MAX_MSEC: int = 90000
const RAIN_SHELTER: float = 0.35
const RAIN_CLEAR: float = 0.12
const GATHER_START_HOUR: float = 18.0
const GATHER_END_HOUR: float = 21.5
const CHAT_PARTNER_RANGE: float = 450.0
const CHAIR_SEARCH_RANGE: float = 650.0
const CHAT_BUBBLES: Array[String] = ["...", "..!", "?", "...?", "!"]

var _busy: Dictionary = {}                        # köylü düğümü id -> {"activity": String}
var _cooldown_until: Dictionary = {}              # köylü düğümü id -> msec
var _tick: float = 3.0
var _gather_spots: Array[float] = []
var _chairs_taken: Dictionary = {}                # sandalye düğümü id -> true

func _ready() -> void:
	name = "VillageShowDirector"
	_tick = randf_range(4.0, 8.0)

func _process(delta: float) -> void:
	if not enabled:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = randf_range(TICK_MIN, TICK_MAX)
	_try_start()

# ─── Köylüleri bul ───────────────────────────────────────────────────────────

func _villager_nodes() -> Array:
	var out: Array = []
	if mode == "visit":
		var scene: Node = get_node_or_null(visit_scene_path)
		if scene != null and "agents" in scene:
			for v in scene.agents:
				if is_instance_valid(v):
					out.append(v)
		return out
	var vm := get_node_or_null("/root/VillageManager")
	var container: Node = vm.get("workers_container") if vm != null and "workers_container" in vm else null
	if is_instance_valid(container):
		for c in container.get_children():
			if c is Node2D and not c.is_in_group("cats"):
				out.append(c)
	return out

func _is_eligible(n: Node2D) -> bool:
	if not n.visible or _busy.has(n.get_instance_id()):
		return false
	if _cooldown_until.get(n.get_instance_id(), 0) > Time.get_ticks_msec():
		return false
	if mode == "visit":
		# Sadece meydandaki, işi/taşıması olmayan köylüler (State: 1 WALK, 2 IDLE, 3 SIT).
		if not ("place_key" in n) or not ("show_puppet" in n):
			return false
		if bool(n.get("show_puppet")) or int(n.get("inside_idx")) != -1 or String(n.get("_haul_phase")) != "":
			return false
		if not (int(n.get("state")) in [1, 2, 3]):
			return false
		return String(n.get("place_key")) == "plaza"
	# workers_container sadece Worker barındırmayabilir (ör. başka NPC türleri): Worker olmayanlar atlanır.
	if not ("current_state" in n) or not n.has_method("play_animation") or not ("idle_activity_timer" in n):
		return false
	for flag in ["is_guest_villager", "is_deployed", "is_dungeon_prisoner", "is_sick"]:
		if flag in n and n.get(flag) == true:
			return false
	if not (int(n.get("current_state")) in _Actor.WORKER_IDLE_STATES):
		return false
	if String(n.get("_current_idle_activity")) == "show":
		return false
	if n.has_method("_is_on_night_watch") and bool(n.call("_is_on_night_watch")):
		return false
	var nw: Variant = n.get("_npc_window_ref") if "_npc_window_ref" in n else null
	if nw != null and is_instance_valid(nw) and (nw as Node).visible:
		return false
	return not _Bubble.has_active_bubble(n)

func _make_actor(n: Node2D) -> VillagerShowActor:
	return _Actor.for_visit(n) if mode == "visit" else _Actor.for_worker(n)

# ─── Zaman / hava / dünya ───────────────────────────────────────────────────

func _hour() -> float:
	var tm := get_node_or_null("/root/TimeManager")
	if tm == null:
		return 12.0
	if tm.has_method("get_continuous_hour_float"):
		return float(tm.get_continuous_hour_float())
	return float(tm.get_hour()) if tm.has_method("get_hour") else 12.0

func _rain() -> float:
	var weather := get_node_or_null("/root/WeatherManager")
	return float(weather.rain_intensity) if weather != null and "rain_intensity" in weather else 0.0

func _building_xs() -> Array[float]:
	var xs: Array[float] = []
	var root: Node = get_node_or_null(buildings_root_path)
	if root != null:
		for c in root.get_children():
			if c is Node2D and (c as Node2D).visible:
				xs.append((c as Node2D).global_position.x)
	return xs

func _world_bounds() -> Vector2:
	var xs: Array[float] = _building_xs()
	if xs.is_empty():
		return Vector2(-1200.0, 1200.0)
	var lo: float = xs[0]
	var hi: float = xs[0]
	for x in xs:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo - 250.0, hi + 250.0)

func _clamp_x(x: float) -> float:
	var b: Vector2 = _world_bounds()
	return clampf(x, b.x, b.y)

func _nearest_door_x(from_x: float) -> float:
	var best: float = INF
	var best_d: float = INF
	for x in _building_xs():
		var d: float = absf(x - from_x)
		if d < best_d:
			best_d = d
			best = x
	return best

func _find_wells() -> Array[float]:
	var out: Array[float] = []
	for n in get_tree().get_nodes_in_group("WorkBuildings"):
		if n is Node2D and String((n as Node2D).scene_file_path).ends_with("Well.tscn") and (n as Node2D).visible:
			out.append((n as Node2D).global_position.x)
	return out

# ─── Etkinlik seçimi ────────────────────────────────────────────────────────

func _max_concurrent(total: int) -> int:
	return clampi(int(ceil(float(total) * 0.4)), 1, 6)

func _try_start() -> void:
	var nodes: Array = _villager_nodes()
	var pool: Array = []
	for n in nodes:
		if _is_eligible(n):
			pool.append(n)
	if pool.is_empty():
		return
	var h: float = _hour()
	var rain: float = _rain()
	# Yağmurda boştakiler en yakın binaya sığınır.
	if rain >= RAIN_SHELTER:
		var starts: int = 0
		for n in pool:
			if starts >= 2:
				break
			if randf() < 0.6 and not _building_xs().is_empty():
				_start("shelter", n)
				starts += 1
		return
	# Akşam: köy merkezinde birkaç kişi toplanır.
	if h >= GATHER_START_HOUR and h < GATHER_END_HOUR:
		var gatherers: int = _count_activity("gather")
		if gatherers < mini(6, int(ceil(float(nodes.size()) * 0.6))):
			_start("gather", pool[randi() % pool.size()])
			return
	if _busy.size() >= _max_concurrent(nodes.size()):
		return
	var weights: Dictionary = _weights(h)
	var activity: String = _weighted_pick(weights)
	if activity.is_empty():
		return
	var n: Node2D = pool[randi() % pool.size()]
	if activity == "chat":
		var partner: Node2D = _find_chat_partner(n, pool)
		if partner == null:
			return
		_start("chat", n, {"partner": partner})
		return
	_start(activity, n)

func _weights(h: float) -> Dictionary:
	var w: Dictionary = {"chat": 1.4, "bundle": 1.0}
	var chairs_ok: bool = not _chairs().is_empty()
	if h >= 6.0 and h < 10.0:
		w["bundle"] = 2.0
		if has_water:
			w["carry_water"] = 3.0
			w["fish"] = 1.5
	elif h >= 10.0 and h < 12.0:
		if has_water:
			w["fish"] = 2.0
			w["swim"] = 1.0 if h >= 11.0 else 0.0
	elif h >= 12.0 and h < 15.5:
		w["nap"] = 2.2
		if has_water:
			w["swim"] = 3.0
			w["fish"] = 1.0
		if chairs_ok:
			w["chair"] = 2.0
	elif h >= 15.5 and h < 18.0:
		w["chat"] = 2.2
		if has_water:
			w["fish"] = 2.0
			w["swim"] = 2.0 if h < 17.5 else 0.0
		if chairs_ok:
			w["chair"] = 1.5
	elif h >= 18.0 and h < 21.5:
		if has_water:
			w["fish"] = 1.0
		if chairs_ok:
			w["chair"] = 1.0
	else:
		return {}
	return w

func _weighted_pick(weights: Dictionary) -> String:
	var total: float = 0.0
	for k in weights.keys():
		total += float(weights[k])
	if total <= 0.0:
		return ""
	var roll: float = randf() * total
	for k in weights.keys():
		roll -= float(weights[k])
		if roll <= 0.0 and float(weights[k]) > 0.0:
			return String(k)
	return ""

func _count_activity(activity: String) -> int:
	var n: int = 0
	for v in _busy.values():
		if String(v["activity"]) == activity:
			n += 1
	return n

func _find_chat_partner(a: Node2D, pool: Array) -> Node2D:
	var best: Node2D = null
	var best_d: float = CHAT_PARTNER_RANGE
	for n in pool:
		if n == a:
			continue
		var d: float = absf((n as Node2D).global_position.x - a.global_position.x)
		if d < best_d:
			best_d = d
			best = n
	return best

func _chairs() -> Array:
	var mgr: Node = get_tree().get_first_node_in_group(&"ground_decor_manager")
	if mgr == null or not mgr.has_method("get_chair_sprites"):
		return []
	var out: Array = []
	for c in mgr.get_chair_sprites():
		if not _chairs_taken.has(c.get_instance_id()):
			out.append(c)
	return out

# ─── Çalıştırma ─────────────────────────────────────────────────────────────

func _start(activity: String, node: Node2D, extra: Dictionary = {}) -> void:
	var a: VillagerShowActor = _make_actor(node)
	var id: int = node.get_instance_id()
	a.begin()
	_busy[id] = {"activity": activity}
	_run_activity(activity, a, extra, id)

func _run_activity(activity: String, a: VillagerShowActor, extra: Dictionary, id: int) -> void:
	match activity:
		"gather": await _act_gather(a)
		"nap": await _act_nap(a)
		"chat": await _act_chat(a, extra)
		"shelter": await _act_shelter(a)
		"swim": await _act_swim(a)
		"fish": await _act_fish(a)
		"carry_water": await _act_carry_water(a)
		"bundle": await _act_bundle(a)
		"chair": await _act_chair(a)
	await _finish(a, id)

func _finish(a: VillagerShowActor, id: int) -> void:
	await a.return_to_band()
	a.end()
	_busy.erase(id)
	_cooldown_until[id] = Time.get_ticks_msec() + randi_range(COOLDOWN_MIN_MSEC, COOLDOWN_MAX_MSEC)

func _rand_band_y() -> float:
	return randf_range(9.0, 26.0)

# ─── Etkinlikler ─────────────────────────────────────────────────────────────

## Akşam köy merkezinde (ateşin etrafında) oturma animasyonuyla toplanır.
func _act_gather(a: VillagerShowActor) -> void:
	var spot: float = _pick_gather_spot()
	_gather_spots.append(spot)
	var y: float = _rand_band_y()
	if await a.walk_to(spot, y):
		a.face(1.0 if center_x >= spot else -1.0)
		a.play("sit")
		var sit_seconds: float = randf_range(30.0, 75.0)
		while sit_seconds > 0.0 and _hour() < GATHER_END_HOUR + 0.2 and _rain() < RAIN_SHELTER:
			if not await a.wait(1.0):
				break
			sit_seconds -= 1.0
	_gather_spots.erase(spot)

func _pick_gather_spot() -> float:
	for _try in range(12):
		var side: float = 1.0 if randf() < 0.5 else -1.0
		var x: float = center_x + side * randf_range(45.0, 200.0)
		var free: bool = true
		for s in _gather_spots:
			if absf(s - x) < 38.0:
				free = false
				break
		if free:
			return x
	return center_x + randf_range(-200.0, 200.0)

## Öğle şekerlemesi: uzanma animasyonu.
func _act_nap(a: VillagerShowActor) -> void:
	var x: float = _clamp_x(a.node.global_position.x + randf_range(-150.0, 150.0))
	if await a.walk_to(x, _rand_band_y()):
		a.play("lie")
		await a.wait(randf_range(25.0, 55.0))

## İki köylü yan yana gelip karşılıklı durur, sırayla kısa balonlarla konuşur ("...", "?"); metinler sonra eklenebilir.
func _act_chat(a: VillagerShowActor, extra: Dictionary) -> void:
	var partner_node: Node2D = extra.get("partner")
	if partner_node == null or not is_instance_valid(partner_node):
		return
	var b: VillagerShowActor = _make_actor(partner_node)
	var id_b: int = partner_node.get_instance_id()
	b.begin()
	_busy[id_b] = {"activity": "chat_partner"}
	var chat: Dictionary = {"done": false, "b_ready": false}
	var mid: float = _clamp_x((a.node.global_position.x + partner_node.global_position.x) * 0.5)
	var y: float = _rand_band_y()
	_run_chat_partner(b, id_b, chat, mid + 30.0, y)
	var a_ok: bool = await a.walk_to(mid - 30.0, y)
	var waited: float = 0.0
	while a_ok and not chat["b_ready"] and waited < 15.0 and b.alive():
		await a.node.get_tree().create_timer(0.2).timeout
		waited += 0.2
	if a_ok and chat["b_ready"]:
		a.face(1.0)
		b.face(-1.0)
		a.play("idle")
		b.play("idle")
		var turns: int = randi_range(3, 6)
		for i in range(turns):
			var speaker: VillagerShowActor = a if i % 2 == 0 else b
			if not speaker.alive():
				break
			_Bubble.show_on_npc(speaker.node, CHAT_BUBBLES[randi() % CHAT_BUBBLES.size()], 2.2)
			if not await a.wait(randf_range(2.0, 3.2)):
				break
	chat["done"] = true

func _run_chat_partner(b: VillagerShowActor, id_b: int, chat: Dictionary, x: float, y: float) -> void:
	var ok: bool = await b.walk_to(x, y)
	chat["b_ready"] = ok
	while not chat["done"] and b.alive() and not b.should_stop():
		await b.node.get_tree().create_timer(0.25).timeout
	await _finish(b, id_b)

## Yağmurda en yakın binaya gidip içeri girer (görünmez olur); yağmur dinince çıkar.
func _act_shelter(a: VillagerShowActor) -> void:
	var door: float = _nearest_door_x(a.node.global_position.x)
	if door == INF:
		return
	if await a.walk_to(door + randf_range(-30.0, 30.0), _rand_band_y(), "walk", 1.25):
		a.node.visible = false
		var waited: float = 0.0
		while _rain() > RAIN_CLEAR and waited < 240.0:
			if not await a.wait(2.0):
				break
			waited += 2.0
		if a.alive():
			a.node.visible = true

## Kıyıdan suya yürüyüp yüzer: yürüme animasyonu, vücudun alt yarısı su sprite'ının altında kalır.
func _act_swim(a: VillagerShowActor) -> void:
	var x0: float = _clamp_x(a.node.global_position.x + randf_range(-220.0, 220.0))
	if not await a.walk_to(x0, BAND_EDGE_Y):
		return
	# Erkek köylüler suya girerken üstlerini çıkarır (üstsüz yüzer); kadınlar giysisiyle kalır.
	a.set_shirtless(a.is_male())
	# Her yüzücünün kendi su çizgisi vardır (ShowSwimVisual): suda yukarı aşağı gezerken boyu değişmez, hep baş ve göğsü görünür.
	var visual := _SwimVisual.new()
	visual.setup(a.node, a.body)
	add_child(visual)
	# Her yüzücü suda farklı bir derinlik bandında (SWIM_DEPTH_MIN..MAX) yüzer ve bu bandın içinde aşağı yukarı gezinir.
	var depth: float = randf_range(SWIM_DEPTH_MIN, SWIM_DEPTH_MAX)
	if not await a.walk_to(x0, depth, "walk", 0.55):
		a.set_shirtless(false)
		visual.restore()
		return
	var ripple := _Ripple.new()
	ripple.swimmer = a.node
	ripple.visual = visual
	add_child(ripple)
	var seconds_left: float = randf_range(25.0, 60.0)
	while seconds_left > 0.0 and a.alive() and not a.should_stop():
		var tx: float = _clamp_x(a.node.global_position.x + randf_range(-170.0, 170.0))
		var ty: float = randf_range(SWIM_DEPTH_MIN, SWIM_DEPTH_MAX)
		seconds_left -= await _swim_to(a, tx, ty)
	if is_instance_valid(ripple):
		ripple.queue_free()
	if a.alive():
		await a.walk_to(a.node.global_position.x, BAND_EDGE_Y + 4.0, "walk", 0.55)
		a.set_shirtless(false)
		a.play("walk")  # kıyıda giysi geri görünür
	if is_instance_valid(visual):
		visual.restore()

## Suda hedefe (tx, ty) yüzer: yatayda yüzer, derinlik bandında dikey kayar ve hafif dalgalanır; geçen süreyi döndürür.
func _swim_to(a: VillagerShowActor, tx: float, ty: float) -> float:
	var elapsed: float = 0.0
	var base_y: float = a.node.global_position.y
	a.play("walk")
	a._apply_strip()
	while a.alive() and not a.should_stop():
		var pos: Vector2 = a.node.global_position
		var dx: float = tx - pos.x
		if absf(dx) <= 3.0 and absf(base_y - ty) <= 1.5:
			break
		var dt: float = a.node.get_physics_process_delta_time()
		if absf(dx) > 3.0:
			a.face(signf(dx))
		var step_x: float = minf(a.speed * 0.45 * dt, absf(dx))
		base_y = move_toward(base_y, ty, a.speed * 0.25 * dt)
		elapsed += dt
		a.node.global_position = Vector2(pos.x + signf(dx) * step_x, base_y + sin(elapsed * 2.2 + pos.x * 0.02) * 2.0)
		a.update_depth()
		a._enforce_anim()
		await a.node.get_tree().physics_frame
	return maxf(elapsed, 0.5)

## Kıyıda oturup olta atar: oturma animasyonu + kodla çizilen olta çizgisi ve şamandıra.
func _act_fish(a: VillagerShowActor) -> void:
	var x: float = _clamp_x(a.node.global_position.x + randf_range(-300.0, 300.0))
	if not await a.walk_to(x, BAND_EDGE_Y):
		return
	if not await a.walk_to(x, FISH_BANK_Y, "walk", 0.7):
		return
	var dir: float = 1.0 if randf() < 0.5 else -1.0
	a.face(dir)
	a.play("sit")
	var line := _FishingLine.new()
	line.fisher = a.node
	line.dir = dir
	add_child(line)
	await a.wait(randf_range(35.0, 85.0))
	if is_instance_valid(line):
		line.queue_free()
	if a.alive():
		await a.walk_to(a.node.global_position.x, BAND_EDGE_Y + 2.0, "walk", 0.8)

## Gösterme amaçlı su taşıma (iş değil): kuyudan ya da kıyıdan kova doldurup en yakın eve götürür.
func _act_carry_water(a: VillagerShowActor) -> void:
	var wells: Array[float] = _find_wells()
	var from_x: float
	var from_y: float
	if not wells.is_empty():
		from_x = wells[randi() % wells.size()]
		from_y = _rand_band_y()
	elif has_water:
		from_x = _clamp_x(a.node.global_position.x + randf_range(-400.0, 400.0))
		from_y = FISH_BANK_Y - 6.0
	else:
		return
	if not await a.walk_to(from_x, from_y):
		return
	a.play("drink")
	if not await a.wait(2.0):
		return
	var door: float = _nearest_door_x(from_x + (180.0 if randf() < 0.5 else -180.0))
	if door == INF:
		return
	a.play_with_item("bucket")
	await a.walk_to(door + randf_range(-25.0, 25.0), _rand_band_y(), "walk_tool", 0.9)
	a.play_with_item("bucket")
	if a.alive():
		a.play("idle")
		await a.wait(1.5)

## Sırtında/elinde bohça taşıyarak köyün bir ucundan ötekine gider (walk_carry).
func _act_bundle(a: VillagerShowActor) -> void:
	var dist: float = randf_range(350.0, 800.0) * (1.0 if randf() < 0.5 else -1.0)
	var tx: float = _clamp_x(a.node.global_position.x + dist)
	a.play_with_item("bundle")
	if await a.walk_to(tx, _rand_band_y(), "walk_carry", 0.95):
		a.play("idle")
		await a.wait(randf_range(2.0, 4.5))

## Süs sandalyesine oturur (oturma animasyonu sandalyenin üstüne oturtulur; konum SIT_CHAIR_Y_OFFSET ile ayarlanır).
func _act_chair(a: VillagerShowActor) -> void:
	var chair: Sprite2D = null
	var best_d: float = CHAIR_SEARCH_RANGE
	for c in _chairs():
		var d: float = absf((c as Sprite2D).global_position.x - a.node.global_position.x)
		if d < best_d:
			best_d = d
			chair = c
	if chair == null:
		return
	var chair_id: int = chair.get_instance_id()
	_chairs_taken[chair_id] = true
	var seat_x: float = chair.global_position.x
	var floor_y: float = clampf(chair.global_position.y, 5.0, BAND_EDGE_Y)
	if await a.walk_to(seat_x, floor_y):
		a.node.global_position = Vector2(seat_x, chair.global_position.y + SIT_CHAIR_Y_OFFSET)
		a.node.z_index = chair.z_index + 1
		a.face(-1.0 if chair.flip_h else 1.0)
		a.play("sit")
		var sit_seconds: float = randf_range(30.0, 80.0)
		while sit_seconds > 0.0 and is_instance_valid(chair) and chair.visible:
			if not await a.wait(1.0):
				break
			sit_seconds -= 1.0
		if a.alive():
			a.node.global_position = Vector2(seat_x, floor_y)
			a.update_depth()
	_chairs_taken.erase(chair_id)
