extends Area2D

const DEBUG_DOOR_INTERACTION: bool = false

const WorkerScene = preload("res://village/scenes/Worker.tscn")
const ConcubineScene = preload("res://village/scenes/Concubine.tscn")

@export var minigame_kind := "villager" # or "vip"
var _consumed: bool = false
var _player_overlapping: bool = false
var _prisoner_villager: Node = null  # Köylü kurtarma odasında spawn edilen Worker
var _prisoner_cariye: Node = null     # Cariye kurtarma odasında spawn edilen ConcubineNPC

const VILLAGER_NAMES := [
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Kemal", "Selim",
	"Murat", "Bayram", "Cemal", "Salih", "Hamza", "Bekir", "Veli", "Derviş"
]
const VIP_NAMES := [
	"Ayse", "Fatma", "Zeynep", "Elif", "Meryem", "Hatice", "Esma", "Zehra", "Humeyra", "Rabia",
	"Sirin", "Nermin", "Seda", "Derya", "Selin", "Sibel", "Eda", "Derin", "Naz", "Azra",
	"Hurrem", "Mihrimah", "Nurbanu", "Safiye", "Mahidevran", "Gulbahar", "Gulsah", "Ismihan",
	"Dilruba", "Fehime", "Feride", "Handan", "Halime", "Neslihan", "Nergis", "Nuriye",
	"Perihan", "Saliha", "Sehri", "Semiha", "Sermet", "Sitare", "Suhendan", "Sureyya",
	"Rukiye", "Sabiha", "Sahika", "Tuba"
]

func _ready():
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] _ready, minigame_kind=%s, consumed=%s, room=%s" % [
			str(minigame_kind),
			str(_consumed),
			str(get_parent() and get_parent().get("scene_file_path") if get_parent() else "NO_PARENT")
		])
	input_event.connect(_on_input_event)
	if has_signal("body_entered"):
		body_entered.connect(_on_body_entered)
	if has_signal("body_exited"):
		body_exited.connect(_on_body_exited)
	if not _consumed and minigame_kind == "villager":
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] Scheduling villager prisoner spawn...")
		call_deferred("_spawn_prisoner_villager")
	if not _consumed and minigame_kind == "vip":
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] Scheduling vip prisoner spawn...")
		call_deferred("_spawn_prisoner_cariye")

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
	# Köyde kapasite var mı? Yoksa minigame başlatma, uyarı göster.
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		if minigame_kind == "villager" and not vm.can_add_villager():
			_show_village_full_message("Köy dolu! Yeni köylü alacak barınak yok.")
			return
		if minigame_kind == "vip" and not vm.can_add_cariye():
			_show_village_full_message("Köy dolu! Yeni cariye alacak yer yok.")
			return
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

func _show_village_full_message(text: String) -> void:
	var canvas = get_viewport().get_canvas_layer(0)
	if not canvas:
		canvas = get_tree().root
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 100
	label.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 200, get_viewport().get_visible_rect().size.y * 0.4)
	label.size = Vector2(400, 60)
	canvas.add_child(label)
	var t = get_tree().create_timer(2.0)
	t.timeout.connect(func(): label.queue_free())

func _on_minigame_result(result: Dictionary):
	if result.get("success", false):
		_consumed = true
		if has_node("Sprite2D"):
			$Sprite2D.modulate.a = 0.5
		var drs = get_node_or_null("/root/DungeonRunState")
		if drs:
			if minigame_kind == "villager":
				if _prisoner_villager and is_instance_valid(_prisoner_villager):
					var app = _prisoner_villager.get("appearance")
					var appearance_dict = app.to_dict() if app and app.has_method("to_dict") else null
					var name_str = "Köylü"
					if _prisoner_villager.get("NPC_Info") is Dictionary:
						var info = _prisoner_villager.NPC_Info.get("Info", {})
						if info is Dictionary and info.has("Name"):
							name_str = info["Name"]
					drs.add_pending_villager_data({"appearance": appearance_dict, "name": name_str})
					_prisoner_villager.visible = false
				else:
					drs.add_pending_villager()
			elif minigame_kind == "vip":
				var payload: Dictionary = result.get("payload", {})
				var leverage: int = int(payload.get("leverage", 0))
				var appearance_dict = null
				var name_str = _random_vip_name()
				if _prisoner_cariye and is_instance_valid(_prisoner_cariye):
					var app = _prisoner_cariye.get("appearance")
					appearance_dict = app.to_dict() if app and app.has_method("to_dict") else null
					if _prisoner_cariye.get("display_name") != "":
						name_str = _prisoner_cariye.display_name
					_prisoner_cariye.visible = false
				else:
					var app = AppearanceDB.generate_random_concubine_appearance()
					appearance_dict = app.to_dict() if app and app.has_method("to_dict") else null
				var cariye_data := {
					"isim": name_str,
					"leverage": leverage,
					"appearance": appearance_dict
				}
				drs.add_pending_cariye(cariye_data)
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

func _random_villager_name() -> String:
	var idx: int = randi() % VILLAGER_NAMES.size()
	return String(VILLAGER_NAMES[idx])

func _spawn_prisoner_villager() -> void:
	if _consumed:
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] _spawn_prisoner_villager: consumed, abort.")
		return
	var chunk = get_parent()
	if not chunk or not WorkerScene:
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] _spawn_prisoner_villager: missing chunk or WorkerScene.")
		return
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] Spawning villager prisoner in chunk: %s" % str(chunk.get("scene_file_path") if chunk.has_method("get") else chunk.name))
	var worker = WorkerScene.instantiate()
	worker.is_dungeon_prisoner = true
	worker.worker_id = -1
	worker.appearance = AppearanceDB.generate_random_appearance()
	worker.NPC_Info = {
		"Info": {"Name": _random_villager_name()},
		"Latest_news": []
	}
	var offset_x := -400  # Sağ oda: köylü kapının solunda
	if chunk.get("scene_file_path"):
		var path_str: String = chunk.scene_file_path
		if path_str.get_file().to_lower().contains("left"):
			offset_x = 400  # Sol oda: köylü kapının sağında
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] Villager prisoner offset_x=%s base_position=%s" % [str(offset_x), str(position)])
	worker.position = position + Vector2(offset_x, 0)
	worker.z_index = 50  # Döşemelerin üstünde görünsün
	worker.visible = true
	chunk.add_child(worker)
	_snap_npc_to_floor(worker)
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] Villager prisoner spawned at global %s" % str(worker.global_position))
	_prisoner_villager = worker

func _spawn_prisoner_cariye() -> void:
	if _consumed:
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] _spawn_prisoner_cariye: consumed, abort.")
		return
	var chunk = get_parent()
	if not chunk or not ConcubineScene:
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] _spawn_prisoner_cariye: missing chunk or ConcubineScene.")
		return
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] Spawning vip prisoner in chunk: %s" % str(chunk.get("scene_file_path") if chunk.has_method("get") else chunk.name))
	var cariye = ConcubineScene.instantiate()
	cariye.is_dungeon_prisoner = true
	cariye.display_name = _random_vip_name()
	cariye.appearance = AppearanceDB.generate_random_concubine_appearance()
	var offset_x := -400
	if chunk.get("scene_file_path"):
		var path_str: String = chunk.scene_file_path
		if path_str.get_file().to_lower().contains("left"):
			offset_x = 400
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] VIP prisoner offset_x=%s base_position=%s" % [str(offset_x), str(position)])
	cariye.position = position + Vector2(offset_x, 0)
	cariye.z_index = 50
	cariye.visible = true
	chunk.add_child(cariye)
	_snap_npc_to_floor(cariye)
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] VIP prisoner spawned at global %s" % str(cariye.global_position))
	_prisoner_cariye = cariye

func _snap_npc_to_floor(npc: Node2D) -> void:
	# TileMapLayer üzerinden en yakın alt zemine hizala (sadece Y ekseni)
	var chunk = get_parent()
	if not chunk:
		return
	var tile_map = chunk.get_node_or_null("TileMapLayer")
	if tile_map == null:
		return
	# Dünya pozisyonunu tile hücresine çevir
	var world_pos: Vector2 = npc.global_position
	var local_pos: Vector2 = tile_map.to_local(world_pos)
	var cell: Vector2i = tile_map.local_to_map(local_pos)
	var found := false
	# Aşağı doğru makul bir aralıkta zemin ara
	for i in range(10):
		var source_id = tile_map.get_cell_source_id(cell)
		if source_id != -1:
			found = true
			break
		cell.y += 1
	if not found:
		return
	# Hücre merkezini dünya koordinatına çevir ve NPC'yi hafif yukarı kaydır
	var cell_local: Vector2 = tile_map.map_to_local(cell)
	var cell_world: Vector2 = tile_map.to_global(cell_local)
	# 32 px yukarı kaydırmak genelde 64x64 tile için ayak hizasına yakın olur
	npc.global_position.y = cell_world.y - 32.0

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		_player_overlapping = true

func _on_body_exited(body: Node):
	if body.is_in_group("player"):
		_player_overlapping = false
