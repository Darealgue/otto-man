extends Area2D

@export var minigame_kind := "villager" # or "vip"
var _consumed: bool = false
var _player_overlapping: bool = false
const VIP_NAMES := [
	"Ayse", "Fatma", "Zeynep", "Elif", "Meryem", "Hatice", "Esma", "Zehra", "Humeyra", "Rabia",
	"Sirin", "Nermin", "Seda", "Derya", "Selin", "Sibel", "Eda", "Derin", "Naz", "Azra",
	"Hurrem", "Mihrimah", "Nurbanu", "Safiye", "Mahidevran", "Gulbahar", "Gulsah", "Ismihan",
	"Dilruba", "Fehime", "Feride", "Handan", "Halime", "Neslihan", "Nergis", "Nuriye",
	"Perihan", "Saliha", "Sehri", "Semiha", "Sermet", "Sitare", "Suhendan", "Sureyya",
	"Rukiye", "Sabiha", "Sahika", "Tuba"
]

func _ready():
	input_event.connect(_on_input_event)
	if has_signal("body_entered"):
		body_entered.connect(_on_body_entered)
	if has_signal("body_exited"):
		body_exited.connect(_on_body_exited)

func _process(_delta):
	if _consumed:
		return
	if _player_overlapping and InputManager.is_interact_just_pressed():
		_start_minigame()

func _on_input_event(_viewport, event, _shape_idx):
	if _consumed:
		return
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed):
		_start_minigame()

func _start_minigame():
	var level := 1
	var lg = get_tree().get_first_node_in_group("level_generator")
	if lg:
		var v = lg.get("current_level")
		if typeof(v) == TYPE_INT:
			level = v
	var ctx = {"room_path": get_parent().scene_file_path, "level": level}
	var callback := Callable(self, "_on_minigame_result")
	if MinigameRouter.is_connected("minigame_finished", callback):
		MinigameRouter.disconnect("minigame_finished", callback)
	MinigameRouter.connect("minigame_finished", callback, CONNECT_ONE_SHOT)
	var started := MinigameRouter.start_minigame(minigame_kind, ctx)
	if not started and MinigameRouter.is_connected("minigame_finished", callback):
		MinigameRouter.disconnect("minigame_finished", callback)

func _on_minigame_result(result: Dictionary):
	if result.get("success", false):
		_consumed = true
		if has_node("Sprite2D"):
			$Sprite2D.modulate.a = 0.5
		var vm = get_node_or_null("/root/VillageManager")
		if vm:
			if minigame_kind == "villager":
				vm.add_villager()
			elif minigame_kind == "vip":
				var payload: Dictionary = result.get("payload", {})
				var leverage: int = int(payload.get("leverage", 0))
				var cariye_data := {
					"isim": _random_vip_name(),
					"leverage": leverage
				}
				vm.add_cariye(cariye_data)
	else:
		_apply_failure_penalty()

func _apply_failure_penalty() -> void:
	var ps = get_node_or_null("/root/PlayerStats")
	if ps:
		var max_h: float = ps.get_max_health()
		var cur_h: float = ps.get_current_health()
		var damage: float = max_h * 0.5
		var new_h: float = cur_h - damage
		ps.set_current_health(new_h, true)

func _random_vip_name() -> String:
	var idx: int = randi() % VIP_NAMES.size()
	return String(VIP_NAMES[idx])

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		_player_overlapping = true

func _on_body_exited(body: Node):
	if body.is_in_group("player"):
		_player_overlapping = false
