class_name VisitVillager
extends Node2D
## Ziyaret köyünde yaşayan bir köylü: saate göre evine, işyerine ya da meydana gider, binalara girer ve çıkar.
## Görünüm oyuncu köyündeki gerçek Worker sahnesidir ("zindan tutsağı" kipinde: köy kaydı, görev, yapay
## zeka yok; bkz. camp_rescued_npc.gd), davranış burada sürülür. Hiçbir köy ekonomisine dokunmaz.
##
## Gün düzeni (köylüye özgü küçük kayma ile): 22:00-05:30 evde (içeride, pencere ışığı yanar),
## 06:30-18:00 işyerinde (içeride, ara sıra kapıya çıkar; işi yoksa meydanda), 18:00-21:30 meydanda
## dolaşır, 21:30'dan sonra eve yürür.

const WORKER_SCENE := "res://village/scenes/Worker.tscn"
const PLAZA_HALF_RANGE: float = 700.0
const ARRIVE_DIST: float = 4.0
## Yürüme şeridindeki (12 kare) dik duruş karesi.
const IDLE_FRAME: int = 6
const HAUL_INTERVAL_MIN: float = 30.0
const HAUL_INTERVAL_MAX: float = 70.0
const HAUL_DELIVER_MIN: float = 3.0
const HAUL_DELIVER_MAX: float = 6.0
const Y_MIN: float = 8.0
const Y_MAX: float = 28.0

enum State { INSIDE, WALK, IDLE, SIT }

var scene_ref: Node = null  # VillageVisitScene (kapı konumu ve doluluk bildirimi için)
var home_idx: int = -1
var work_idx: int = -1
var shift_shift: float = 0.0

var state: int = State.IDLE
var inside_idx: int = -1
var place_key: String = ""

var _body: Node2D = null
var _speed: float = 55.0
var _target_x: float = 0.0
var _arrive_action: String = "idle"  # "enter" | "idle"
var _arrive_building: int = -1
var _timer: float = 1.0
## Taşıma işi: "" | "to_dest" (malla hedefe yürür) | "at_dest" (hedefte) | "back" (boş elle işyerine döner)
var _haul_phase: String = ""
var _haul_work: int = -1
var _dir: float = 1.0


func setup(p_scene: Node, p_home: int, p_work: int, p_shift: float, start_hour: float) -> void:
	scene_ref = p_scene
	home_idx = p_home
	work_idx = p_work
	shift_shift = p_shift
	_speed = randf_range(45.0, 65.0)
	z_index = 2
	_body = _build_body()
	if _body != null:
		add_child(_body)
		# Worker "tutsak" kipi isim plakasını açar (içi boş siyah şerit kalıyor); ziyarette isim yok.
		var plate: Variant = _body.get("_nameplate_container")
		if plate is CanvasItem:
			(plate as CanvasItem).visible = false
		_body.set_physics_process(false)
		_body.set_process(false)
		_body.position = Vector2.ZERO
	# Başlangıç: günün saatine göre ya içeride ya meydanda.
	place_key = place_key_for(start_hour)
	var target: Dictionary = parse_place(place_key)
	if String(target["type"]) == "plaza":
		global_position = Vector2(randf_range(-PLAZA_HALF_RANGE, PLAZA_HALF_RANGE), randf_range(Y_MIN, Y_MAX))
		_enter_idle(randf_range(0.5, 4.0))
	else:
		_go_inside(int(target["building"]), true)


## Saat -> yer anahtarı: "home:<i>" | "work:<i>" | "plaza". Aynı anahtar sürdüğü sürece yer değişmez.
func place_key_for(hour: float) -> String:
	var h: float = fposmod(hour + shift_shift, 24.0)
	if h >= 21.5 or h < 5.5:
		return "home:%d" % home_idx if home_idx >= 0 else "plaza"
	if h < 6.5:
		return "plaza"
	if h < 18.0:
		return "work:%d" % work_idx if work_idx >= 0 else "plaza"
	return "plaza"


static func parse_place(key: String) -> Dictionary:
	if key.begins_with("home:"):
		return {"type": "home", "building": int(key.substr(5))}
	if key.begins_with("work:"):
		return {"type": "work", "building": int(key.substr(5))}
	return {"type": "plaza", "building": -1}


func _build_body() -> Node2D:
	var scene := load(WORKER_SCENE) as PackedScene
	if scene == null:
		return null
	var n := scene.instantiate() as Node2D
	if n == null:
		return null
	var adb: Node = get_node_or_null("/root/AppearanceDB")
	var app: Variant = null
	if adb != null and adb.has_method("generate_random_appearance"):
		app = adb.call("generate_random_appearance")
	n.set("is_dungeon_prisoner", true)
	n.set("appearance", app)
	n.set("worker_id", -1)
	n.set("NPC_Info", {"Info": {"Name": ""}, "Latest_news": []})
	return n


func _physics_process(delta: float) -> void:
	if scene_ref == null:
		return
	update_agent(delta, float(scene_ref.call("current_hour_value")))


## Test edilebilsin diye saat dışarıdan verilir.
func update_agent(delta: float, hour: float) -> void:
	var key: String = place_key_for(hour)
	if key != place_key:
		place_key = key
		_on_place_changed()
	match state:
		State.INSIDE:
			_timer -= delta
			var place: Dictionary = parse_place(place_key)
			if _timer <= 0.0:
				if _haul_phase == "at_dest":
					_finish_delivery()
				elif String(place["type"]) == "work" and int(place["building"]) == inside_idx:
					_start_haul()
		State.WALK:
			var dx: float = _target_x - global_position.x
			if absf(dx) <= ARRIVE_DIST:
				_arrived()
			else:
				_dir = signf(dx)
				global_position.x += _dir * minf(_speed * delta, absf(dx))
				_face(_dir)
		State.IDLE, State.SIT:
			_timer -= delta
			if _timer <= 0.0:
				_next_idle_action()


func _on_place_changed() -> void:
	var place: Dictionary = parse_place(place_key)
	# Saat dilimi değişti: yarım kalan taşıma işi bırakılır.
	_haul_phase = ""
	if state == State.INSIDE:
		# Aynı binada kalacaksa (ör. işten evi aynı bina) içeride kal, değilse çık ve yeni yere git.
		if String(place["type"]) != "plaza" and int(place["building"]) == inside_idx:
			return
		_exit_building()
	_go_to_place()


func _go_to_place() -> void:
	var place: Dictionary = parse_place(place_key)
	if String(place["type"]) == "plaza":
		_arrive_action = "idle"
		_arrive_building = -1
		_target_x = randf_range(-PLAZA_HALF_RANGE, PLAZA_HALF_RANGE)
	else:
		_arrive_action = "enter"
		_arrive_building = int(place["building"])
		_target_x = float(scene_ref.call("door_x", _arrive_building))
	state = State.WALK
	_play("walk")


func _arrived() -> void:
	if _arrive_action == "deliver" and _arrive_building >= 0:
		# Malı teslim eder: hedef binaya girer, kısa süre kalır (içeride bırakıp çıkar).
		var dest: int = _arrive_building
		_go_inside(dest, false)
		_haul_phase = "at_dest"
		_timer = randf_range(HAUL_DELIVER_MIN, HAUL_DELIVER_MAX)
	elif _arrive_action == "enter" and _arrive_building >= 0:
		_haul_phase = ""
		_go_inside(_arrive_building, false)
	else:
		_enter_idle(randf_range(1.5, 5.0))


func _next_idle_action() -> void:
	var place: Dictionary = parse_place(place_key)
	if String(place["type"]) != "plaza":
		_go_to_place()
		return
	var r: float = randf()
	if r < 0.5:
		_arrive_action = "idle"
		_target_x = clampf(global_position.x + randf_range(-300.0, 300.0), -PLAZA_HALF_RANGE, PLAZA_HALF_RANGE)
		state = State.WALK
		_play("walk")
	elif r < 0.75:
		state = State.SIT
		_timer = randf_range(6.0, 14.0)
		_play("sit")
	else:
		_enter_idle(randf_range(2.0, 6.0))


## Oyuncu konuşmaya geldi: köylü durur, oyuncuya döner ve biraz bekler.
func talk_to(player_x: float, seconds: float = 6.0) -> void:
	if state == State.INSIDE:
		return
	_face(signf(player_x - global_position.x))
	_enter_idle(seconds)


## Dışarıda (görünür) mü: konuşulabilir.
func is_outside() -> bool:
	return state != State.INSIDE and visible


func _enter_idle(duration: float) -> void:
	state = State.IDLE
	_timer = duration
	_play("idle")


## Binaya girer: görünmez olur, bina doluluğu güncellenir (pencere ışığı için).
func _go_inside(building: int, instant: bool) -> void:
	if building < 0:
		_enter_idle(2.0)
		return
	inside_idx = building
	state = State.INSIDE
	_timer = randf_range(HAUL_INTERVAL_MIN, HAUL_INTERVAL_MAX)
	visible = false
	if instant:
		global_position = Vector2(float(scene_ref.call("door_x", building)), randf_range(Y_MIN, Y_MAX))
	if scene_ref != null:
		scene_ref.call("on_villager_entered", building)


## Taşıma işi: işyerinden bir mal alıp başka bir binaya (ambar ya da başka dükkân) götürür, teslim edip
## boş elle geri döner. Sebepsiz girip çıkma yok; her çıkışın bir işi var.
func _start_haul() -> void:
	var work: int = inside_idx
	var dest: int = int(scene_ref.call("haul_destination", work)) if scene_ref != null else -1
	if dest < 0 or dest == work:
		_timer = randf_range(HAUL_INTERVAL_MIN, HAUL_INTERVAL_MAX)
		return
	var key: String = String(scene_ref.call("haul_resource_key", work))
	_exit_building()
	_haul_phase = "to_dest"
	_haul_work = work
	_arrive_action = "deliver"
	_arrive_building = dest
	_target_x = float(scene_ref.call("door_x", dest))
	state = State.WALK
	_play_carry(key)


## Teslim bitti: hedef binadan çıkar, boş elle işyerine yürür ve girer.
func _finish_delivery() -> void:
	_exit_building()
	_haul_phase = "back"
	_arrive_action = "enter"
	_arrive_building = _haul_work
	_target_x = float(scene_ref.call("door_x", _haul_work))
	state = State.WALK
	_play("walk")


## Elinde mal taşıyarak yürür (Worker'ın walk_carry animasyonu ve kaynak rozeti).
func _play_carry(resource_key: String) -> void:
	if _body == null:
		return
	_body.set("_fetch_resource_type", resource_key)
	_body.call("play_animation", "walk_carry")


func _exit_building() -> void:
	if inside_idx >= 0 and scene_ref != null:
		scene_ref.call("on_villager_left", inside_idx)
	visible = true
	global_position = Vector2(float(scene_ref.call("door_x", inside_idx)) + randf_range(-25.0, 25.0), randf_range(Y_MIN, Y_MAX))
	inside_idx = -1


func _play(anim: String) -> void:
	if _body != null and _body.has_method("play_animation"):
		_body.call("play_animation", anim)
		# Worker "idle" için klip oynatmaz ve yürüme dokusunun 0. karesini bırakır; o kare adım atma pozu
		# (bacaklar açık). Yürüme şeridinde bacakları birleşik dik duruş 6. karede, onu kullan.
		if anim == "idle":
			for part in ["BodySprite", "PantsSprite", "ClothingSprite", "MouthSprite", "EyesSprite", "BeardSprite", "HairSprite", "HatSprite"]:
				var spr: Sprite2D = _body.get_node_or_null(part) as Sprite2D
				if spr != null:
					spr.frame = IDLE_FRAME


func _face(dir: float) -> void:
	if _body == null or dir == 0.0:
		return
	_body.scale.x = dir
