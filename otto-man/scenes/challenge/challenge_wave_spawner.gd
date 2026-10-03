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
	"turtle": "res://enemy/turtle/turtle_enemy.tscn",
	"spearman": "res://enemy/spearman/spearman_enemy.tscn",
	"heavy": "res://enemy/heavy/heavy_enemy.tscn",
	"flying": "res://enemy/flying/flying_enemy.tscn",
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


## Dalga sayısı zorluğa bağlı: 1 -> 4, 3 -> 5, 5 -> 6, 9 -> 8
## Dalga arenası: 3 dalga (oyun testinde dengeli bulundu), yüksek zorlukta 4.
## Koruma'da dalga sayısı korunan köylü sayısını izler (bkz. waves_for_wards).
static func waves_for_difficulty(diff: int) -> int:
	return 3 + clampi(diff, 1, 9) / 5


## Koruma: tek köylü 1 dalga, 3 köylü 3 dalga, 4 ve üstü 4 dalga.
static func waves_for_wards(ward_count: int) -> int:
	return clampi(ward_count, 1, 4)


## Bir dalganın düşman listesi (tür anahtarları, karışık sırada).
static func plan_wave(wave: int, diff: int) -> Array[String]:
	var count: int = 3 + wave + diff / 2
	var pool: Array[String] = ["basic", "basic", "basic", "basic", "basic"]
	var power: int = wave + diff
	if wave >= 2:
		pool.append("turtle")
	if power >= 3:
		pool.append_array(["spearman", "spearman", "flying", "flying"])
	if power >= 4:
		pool.append_array(["heavy", "heavy"])
	var out: Array[String] = []
	for i in range(count):
		out.append(pool[randi() % pool.size()])
	return out


func start_next_wave() -> void:
	if _wave_index >= wave_total:
		return
	_wave_index += 1
	_queue = plan_wave(_wave_index, difficulty)
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
	for e in _alive:
		if is_instance_valid(e) and e.get("current_behavior") != "dead":
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
	_alive.append(enemy)
	enemy_spawned.emit(enemy)
