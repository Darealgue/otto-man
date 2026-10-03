class_name WardTarget
extends Node2D

## Korunan köylü (Koruma challenge'ı). "ward_targets" grubundadır: düşmanlar oyuncu kadar bunu da
## hedef alır (bkz. BaseEnemy.get_nearest_player). Hasarı WardHurtbox üzerinden alır.
## Görünüm: köy köylü üreticisiyle (AppearanceDB) rastgele bir köylü; zindan tutsaklarının
## kullandığı Worker "dungeon prisoner" kipinde, oturma pozunda sabit durur (DoorInteraction ile aynı yol).

signal died(ward: WardTarget)
signal health_changed(ward: WardTarget, health: float, max_health: float)

## preload yerine çalışma anında load: Worker/DoorInteraction autoload'lara bağlı olduğundan bu sınıf
## (class_name) erken derlenirken parse hatası vermesin.
const WORKER_SCENE_PATH := "res://village/scenes/Worker.tscn"
const NAME_SOURCE_PATH := "res://chunks/common/DoorInteraction.gd"
const BAR_SIZE := Vector2(46.0, 6.0)
## Köylünün isim şeridi (~-85) üstünde dursun
const BAR_OFFSET := Vector2(-23.0, -122.0)
## Oturma süresi pratikte sonsuz (prisoner kipi 30-45 sn sonra yürümeye başlar, biz istemiyoruz)
const SIT_FOREVER: float = 1.0e9

@export var max_health: float = 60.0

var health: float = 60.0
var is_dead: bool = false
## Düşman kodunun oyuncuya özgü alanlara bakması ihtimaline karşı sabit değerler.
var velocity: Vector2 = Vector2.ZERO
var villager_name: String = "Köylü"

var _worker: Node2D = null
var _hurtbox: WardHurtbox = null
var _flash: float = 0.0
var _snap_frames: int = 0


func _ready() -> void:
	add_to_group("ward_targets")
	health = max_health
	_build_worker()
	_build_hurtbox()
	z_index = 3


func _build_worker() -> void:
	var worker_scene := load(WORKER_SCENE_PATH) as PackedScene
	if worker_scene == null:
		return
	_worker = worker_scene.instantiate() as Node2D
	if _worker == null:
		return
	var names: Array = load(NAME_SOURCE_PATH).VILLAGER_NAMES
	villager_name = String(names[randi() % names.size()])
	_worker.set("is_dungeon_prisoner", true)
	_worker.set("worker_id", -1)
	var appearance_db: Node = get_node_or_null("/root/AppearanceDB")
	if appearance_db != null and appearance_db.has_method("generate_random_appearance"):
		_worker.set("appearance", appearance_db.call("generate_random_appearance"))
	_worker.set("NPC_Info", {"Info": {"Name": villager_name}, "Latest_news": []})
	add_child(_worker)
	# Prisoner kipi zemine yerçekimi + aşağı ışınla oturur; ışın yüzeyin tam üstünde başlarsa çarpmayı
	# kaçırır ve köylü zeminin içinden düşer. Yüzeyin biraz üstünden başlat, kendi oturur.
	_worker.position = Vector2(0.0, -24.0)
	# Oturma pozunda sabit kal
	_worker.set("dungeon_idle_duration", SIT_FOREVER)
	_worker.set("dungeon_wander_range", 0.0)
	_worker.set("dungeon_spawn_x", global_position.x)


func _build_hurtbox() -> void:
	_hurtbox = WardHurtbox.new()
	_hurtbox.name = "WardHurtbox"
	_hurtbox.ward = self
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(38.0, 70.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -38.0)
	_hurtbox.add_child(shape)
	add_child(_hurtbox)


## Kurtarma ödülü için köylünün görünümü ve adı (DungeonRunState.add_pending_villager_data biçimi).
func rescue_data() -> Dictionary:
	var app = _worker.get("appearance") if is_instance_valid(_worker) else null
	return {
		"appearance": app.to_dict() if app and app.has_method("to_dict") else null,
		"name": villager_name,
	}


## Düşman saldırısından hasar (WardHurtbox çağırır). Diğer take_damage imzalarıyla uyumlu.
func take_damage(amount: float, _kb: float = 0.0, _kb_up: float = 0.0, _apply_kb: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_flash = 0.15
	health_changed.emit(self, health, max_health)
	if health <= 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	is_dead = true
	remove_from_group("ward_targets")
	if is_instance_valid(_hurtbox):
		_hurtbox.set_deferred("monitoring", false)
		_hurtbox.set_deferred("monitorable", false)
	if is_instance_valid(_worker):
		_worker.set("dungeon_is_idling", true)
		if _worker.has_method("play_animation"):
			_worker.call("play_animation", "lie")
		_worker.set_physics_process(false)
		_worker.modulate = Color(0.6, 0.35, 0.35, 0.7)
	died.emit(self)
	queue_redraw()


func _process(delta: float) -> void:
	# Prisoner kipi yatayda dungeon_spawn_x'e sabitlenir; köylü bu düğümün x'ini izlesin
	if is_instance_valid(_worker) and not is_dead:
		_worker.set("dungeon_spawn_x", global_position.x)
		# Worker zemine kendi oturunca (yüzeyin 4 px üstü) bu düğümü de gerçek zemine indir:
		# karo çarpışması satır sınırından birkaç piksel farklı olabiliyor; hasar kutusu köylüyle hizalansın.
		_snap_frames += 1
		if _snap_frames == 8:
			global_position.y = _worker.global_position.y + 4.0
			# Üst düğüm kayınca köylü yüzeyin altına inmesin: ışın yüzeyin üstünden başlasın, yeniden oturur
			_worker.global_position.y = global_position.y - 24.0
	if _flash > 0.0:
		_flash -= delta
		if is_instance_valid(_worker) and not is_dead:
			_worker.modulate = Color(1.6, 0.6, 0.6) if _flash > 0.0 else Color.WHITE
		queue_redraw()


func _draw() -> void:
	if is_dead:
		return
	var ratio: float = clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(BAR_OFFSET - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.7))
	var col := Color(0.3, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), 1.0 - ratio)
	draw_rect(Rect2(BAR_OFFSET, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), col)
