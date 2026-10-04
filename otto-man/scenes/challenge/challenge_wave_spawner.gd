class_name ChallengeWaveSpawner
extends Node

## Challenge odalarında düzenli düşman dalgaları. Dalga bileşimi dalga numarasına ve zindan
## zorluğuna (1-9) göre belirlenir; düşmanlar iki kenardan gelir (uçanlar havadan) ve menzile
## bakmadan hedefe yürür (meta "always_aggro"). Tüm düşmanlar ölünce dalga biter.

signal wave_started(index: int, total: int)
signal wave_cleared(index: int, total: int)
signal all_waves_cleared
signal enemy_spawned(enemy: Node2D)

const ENEMY_SCENES: Dictionary = {
	"basic": "res://enemy/basic/basic_enemy.tscn",
	"spearman": "res://enemy/spearman/spearman_enemy.tscn",
	"heavy": "res://enemy/heavy/heavy_enemy.tscn",
	"flying": "res://enemy/flying/flying_enemy.tscn",
	"firemage": "res://enemy/firemage/firemage_enemy.tscn",
	"summoner": "res://enemy/summoner/summoner_enemy.tscn",
	"hunter": "res://enemy/hunter/hunter_enemy.tscn",
}
const SPAWN_INTERVAL: float = 0.9
## Aynı anda sahnede en fazla bu kadar canlı düşman (fazlası sıraya girer).
const MAX_ALIVE: int = 9
const ENEMY_Z_INDEX: int = 4
## Arena ~1800 px genişliğinde; tespit/takip menzili hepsini kapsar
const ARENA_DETECTION_RANGE: float = 3000.0

var layout: Dictionary = {}
var container: Node2D = null
var difficulty: int = 1
var wave_total: int = 5

var _wave_index: int = 0          # şu an oynanan dalga (1'den başlar), 0 = henüz başlamadı
var _queue: Array[String] = []    # bu dalgada doğacak kalan düşman türleri
var _alive: Array[Node2D] = []
var _spawn_timer: float = 0.0
var _side_toggle: bool = false
var _running: bool = false


func configure(arena_layout: Dictionary, enemy_container: Node2D, diff: int, total_waves: int) -> void:
	layout = arena_layout
	container = enemy_container
	difficulty = clampi(diff, 1, 9)
	wave_total = maxi(1, total_waves)


## Dalga arenası: 3 dalga (oyun testinde dengeli bulundu), yüksek zorlukta 4.
## Koruma'da dalga sayısı korunan köylü sayısını izler (bkz. waves_for_wards).
static func waves_for_difficulty(diff: int) -> int:
	return 3 + clampi(diff, 1, 9) / 5


## Koruma: tek köylü 1 dalga, 3 köylü 3 dalga, 4 ve üstü 4 dalga.
static func waves_for_wards(ward_count: int) -> int:
	return clampi(ward_count, 1, 4)


## Düşman sınıfları: "basic" (kolay harcanan kalabalık) ve "elit" (tek başına tehdit). Dalga bileşimi:
## az sayıda elit + çok sayıda basic (örn. 1 elit + 5 basic, 2 elit + 7 basic). Kaplumbağa arenalarda yok.
const BASIC_KINDS: Array[String] = ["basic", "basic", "basic", "basic", "flying"]
const CHARGER_KINDS: Array[String] = ["spearman", "heavy"]


## Elit havuzu dalga gücüne (dalga + zorluk) göre açılır. Mızrakçı ve ağır (koşan tanklar) "charger"dır;
## aynı dalgada en fazla 1 charger gelir (güç 9 ve üstünde 2).
static func _elite_pool(power: int, allow_hunter: bool = true) -> Array[String]:
	var pool: Array[String] = []
	if power >= 3:
		pool.append_array(["spearman", "firemage"])
	if power >= 4 and allow_hunter:
		pool.append("hunter")
	if power >= 5:
		pool.append_array(["summoner", "heavy"])
	if pool.is_empty():
		pool.append("spearman")
	return pool


## Bir dalganın düşman listesi (tür anahtarları, karışık sırada).
## allow_hunter: avcı sabit zemin ister (gezinme haritası çıkarır); hareketli asansörde kapalıdır.
static func plan_wave(wave: int, diff: int, allow_hunter: bool = true) -> Array[String]:
	var power: int = wave + diff
	var count: int = 3 + wave + diff / 2
	var elites: int = 0 if power < 3 else clampi((power + 1) / 4, 1, 3)
	var basics: int = maxi(2 * elites + 3, count - elites)
	var out: Array[String] = []
	var pool: Array[String] = _elite_pool(power, allow_hunter)
	var chargers: int = 0
	var max_chargers: int = 2 if power >= 9 else 1
	for i in range(elites):
		var pick: String = pool[randi() % pool.size()]
		var tries: int = 0
		while pick in CHARGER_KINDS and chargers >= max_chargers and tries < 12:
			pick = pool[randi() % pool.size()]
			tries += 1
		if pick in CHARGER_KINDS:
			if chargers >= max_chargers:
				pick = "firemage" if "firemage" in pool else "hunter"
			else:
				chargers += 1
		out.append(pick)
	for i in range(basics):
		# Güç düşükken uçan düşman çıkmaz (ilk dalga sade kalsın)
		var kind: String = BASIC_KINDS[randi() % BASIC_KINDS.size()]
		if kind == "flying" and power < 3:
			kind = "basic"
		out.append(kind)
	out.shuffle()
	# İlk doğanlar basic olsun: elit kuyruğun gerisine kayar (oyuncuya hazırlanma payı)
	var first_basic: int = -1
	for i in range(out.size()):
		if out[i] in BASIC_KINDS:
			first_basic = i
			break
	if first_basic > 0:
		var tmp: String = out[0]
		out[0] = out[first_basic]
		out[first_basic] = tmp
	return out

func start_next_wave() -> void:
	if _wave_index >= wave_total:
		return
	_wave_index += 1
	_queue = plan_wave(_wave_index, difficulty, not layout.has("drop_y"))
	_spawn_timer = 0.0
	_running = true
	wave_started.emit(_wave_index, wave_total)


func current_wave() -> int:
	return _wave_index


func alive_count() -> int:
	return _alive.size()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_prune_dead()
	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _alive.size() < MAX_ALIVE:
			_spawn_timer = SPAWN_INTERVAL
			_spawn_one(_queue.pop_front())
	elif _alive.is_empty():
		_running = false
		wave_cleared.emit(_wave_index, wave_total)
		if _wave_index >= wave_total:
			all_waves_cleared.emit()


func _prune_dead() -> void:
	var still: Array[Node2D] = []
	var arena: Rect2 = (layout["bounds"] as Rect2).grow(500.0) if layout.has("bounds") else Rect2()
	for e in _alive:
		if not is_instance_valid(e) or e.get("current_behavior") == "dead":
			continue
		# Dalga bitmeyi engelleyen takılmış düşmanlar: arenanın çok dışına kaçan ya da canı bitmiş
		# ama ölüm akışına girmemiş olanlar elenir (dalga/ödül akışı asla kilitlenmesin).
		var stuck: bool = arena.has_area() and not arena.has_point(e.global_position)
		var hp: Variant = e.get("health")
		if hp != null and float(hp) <= 0.0:
			var t: float = float(e.get_meta("_zombie_time", 0.0)) + get_physics_process_delta_time()
			e.set_meta("_zombie_time", t)
			stuck = stuck or t > 2.5
		if stuck:
			e.queue_free()
			continue
		still.append(e)
	_alive = still


func _spawn_one(kind: String) -> void:
	var path: String = String(ENEMY_SCENES.get(kind, ENEMY_SCENES["basic"]))
	var scene := load(path) as PackedScene
	if scene == null or container == null:
		return
	var enemy := scene.instantiate() as Node2D
	if enemy == null:
		return
	enemy.set_meta("always_aggro", true)
	var level: int = clampi(difficulty + (_wave_index - 1) / 2, 1, 9)
	container.add_child(enemy)
	_side_toggle = not _side_toggle
	var base: Vector2 = layout["spawn_left"] if _side_toggle else layout["spawn_right"]
	var jitter: float = randf_range(-30.0, 30.0)
	if kind == "flying":
		enemy.global_position = Vector2(base.x + jitter, float(layout["air_y"]) + randf_range(-60.0, 60.0))
	elif layout.has("drop_y"):
		# Asansör arenası: yer düşmanları ekranın üstünden asansörün üzerine düşer
		var lx: float = float(layout["left_x"]) + 120.0
		var rx: float = float(layout["right_x"]) - 120.0
		enemy.global_position = Vector2(randf_range(lx, rx), float(layout["drop_y"]))
	else:
		enemy.global_position = Vector2(base.x + jitter, base.y)
	enemy.z_index = ENEMY_Z_INDEX
	var stats = enemy.get("stats")
	if stats:
		# Kaynak ortak olabilir: kendi kopyası, menzil bütün arenayı kapsasın (uzaktan "mal mal yürüme" olmasın)
		stats = stats.duplicate(true)
		enemy.set("stats", stats)
		stats.detection_range = maxf(stats.detection_range, ARENA_DETECTION_RANGE)
	if "chase_start_distance" in enemy:
		enemy.set("chase_start_distance", ARENA_DETECTION_RANGE)
		enemy.set("chase_stop_distance", ARENA_DETECTION_RANGE + 40.0)
	if stats and stats.has_method("scale_to_level"):
		stats.scale_to_level(level - 1)
	if "enemy_level" in enemy:
		enemy.enemy_level = level
	if "is_sleeping" in enemy:
		enemy.is_sleeping = false
	if kind == "flying" and enemy.has_signal("enemy_defeated"):
		enemy.connect("enemy_defeated", _flee_away.bind(enemy), CONNECT_DEFERRED)
	_alive.append(enemy)
	enemy_spawned.emit(enemy)


## Uçan düşman "ölünce" düşmek yerine kanat çırparak yukarı ve yana doğru uçup gözden kaybolur.
func _flee_away(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var spr := enemy.get("sprite") as AnimatedSprite2D
	if spr != null:
		spr.play("fly")
		spr.speed_scale = 1.8
	var dir: float = 1.0 if enemy.global_position.x >= 960.0 else -1.0
	if spr != null:
		spr.flip_h = dir < 0.0
	var tw := enemy.create_tween()
	tw.set_parallel(true)
	tw.tween_property(enemy, "global_position", enemy.global_position + Vector2(dir * 700.0, -520.0), 1.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(enemy, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(enemy.queue_free)
