class_name CampRescuedNpc
extends Node2D

## Kamp sahnesinde, zindanda kurtarılan bir köylü / cariyenin salt görsel hali. Gerçek Worker / Concubine
## sahnesi "zindan tutsağı" kipinde kullanılır (köy kaydı, görev, AI yok); davranışı burada sürülür:
## çeşmenin çevresinde yürür, durur; köylüler ayrıca oturur ve uzanır, cariyeler yürür ve durur.
## Etkileşim yoktur.

const WORKER_SCENE := "res://village/scenes/Worker.tscn"
const CONCUBINE_SCENE := "res://village/scenes/Concubine.tscn"
const WALK_SPEED := 36.0

var is_cariye: bool = false
var center_x: float = 0.0
var range_x: float = 240.0

var _body: Node2D = null
var _state: String = "idle"
var _state_left: float = 1.0
var _dir: float = 1.0
var _target_x: float = 0.0


## kind: "villager" | "cariye"; data: DungeonRunState'teki kurtarma kaydı.
func setup(kind: String, data: Dictionary, p_center_x: float, p_range: float, base_z: int) -> void:
	is_cariye = kind == "cariye"
	center_x = p_center_x
	range_x = p_range
	z_index = base_z
	_body = _build_body(data)
	if _body != null:
		add_child(_body)
		_body.set_physics_process(false)
		_body.set_process(false)
		_body.position = Vector2.ZERO
		_body.z_index = 0
		# İsim levhası kampta kalabalık yapıyor; salt görsel olduğu için gizli
		var plate: Variant = _body.get("name_plate_container" if is_cariye else "_nameplate_container")
		if plate is Control:
			(plate as Control).visible = false
	_target_x = global_position.x
	_dir = 1.0 if randf() < 0.5 else -1.0
	_enter("idle", randf_range(0.3, 3.0))


func _build_body(data: Dictionary) -> Node2D:
	var scene := load(CONCUBINE_SCENE if is_cariye else WORKER_SCENE) as PackedScene
	if scene == null:
		return null
	var n := scene.instantiate() as Node2D
	if n == null:
		return null
	var app: VillagerAppearance = null
	var app_dict: Variant = data.get("appearance", null)
	if app_dict is Dictionary and not (app_dict as Dictionary).is_empty():
		app = VillagerAppearance.new()
		app.from_dict(app_dict)
	var adb: Node = get_node_or_null("/root/AppearanceDB")
	if app == null and adb != null:
		app = adb.call("generate_random_concubine_appearance" if is_cariye else "generate_random_appearance")
	n.set("is_dungeon_prisoner", true)
	n.set("appearance", app)
	if is_cariye:
		n.set("display_name", String(data.get("isim", "")))
	else:
		n.set("worker_id", -1)
		n.set("NPC_Info", {"Info": {"Name": String(data.get("name", ""))}, "Latest_news": []})
	return n


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_state_left -= delta
	match _state:
		"walk":
			var dx: float = _target_x - global_position.x
			if absf(dx) <= 3.0 or _state_left <= 0.0:
				_pick_next()
			else:
				_dir = signf(dx)
				global_position.x += _dir * minf(WALK_SPEED * delta, absf(dx))
				_face(_dir)
		_:
			if _state_left <= 0.0:
				_pick_next()


func _pick_next() -> void:
	var r: float = randf()
	if is_cariye:
		if r < 0.6:
			_start_walk()
		else:
			_enter("idle", randf_range(2.0, 6.0))
		return
	if r < 0.45:
		_start_walk()
	elif r < 0.7:
		_enter("sit", randf_range(6.0, 14.0))
	elif r < 0.85:
		_enter("lie", randf_range(6.0, 12.0))
	else:
		_enter("idle", randf_range(1.5, 4.0))


func _start_walk() -> void:
	_target_x = center_x + randf_range(-range_x, range_x)
	_enter("walk", 8.0)


func _enter(state: String, duration: float) -> void:
	_state = state
	_state_left = duration
	if _body == null or not _body.has_method("play_animation"):
		return
	_body.call("play_animation", state)
	if state != "walk":
		# Dururken yüzünü rastgele ya da yürüdüğü yöne çevir
		if randf() < 0.3:
			_dir = -_dir
		_face(_dir)


func _face(dir: float) -> void:
	if _body == null or dir == 0.0:
		return
	_body.scale.x = dir
	var plate: Variant = _body.get("name_plate_container" if is_cariye else "_nameplate_container")
	if plate is Control:
		(plate as Control).scale.x = -1.0 if dir < 0.0 else 1.0
