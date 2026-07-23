extends Area2D

const DEBUG_DOOR_INTERACTION: bool = false

const WorkerScene = preload("res://village/scenes/Worker.tscn")
const ConcubineScene = preload("res://village/scenes/Concubine.tscn")
const DoorTexture = preload("res://assets/objects/dungeon/door_1.png")
const ArrowHint = preload("res://ui/InteractArrowHint.gd")

@export var minigame_kind := "villager" # or "vip"
## Otomatik zemin hizalaması yanlış kalırsa editörden kapı görselini kaydırmak için.
@export var door_sprite_offset: Vector2 = Vector2.ZERO
var _consumed: bool = false
var _player_overlapping: bool = false
var _door_busy: bool = false  # kapı animasyonu / minigame sürerken tekrar tetiklemeyi engeller
var _prisoner_villagers: Array = []  # Köylü odasında spawn edilen Worker'lar (1-3 kişi)
var _prisoner_cariye: Node = null     # Cariye kurtarma odasında spawn edilen ConcubineNPC
var _arrow: Sprite2D = null           # "Yukarı bas" etkileşim ok ikonu
var _arrow_offset := Vector2(0.0, -130.0)  # vip: kapı kemerinin üstü; villager'da pen'e göre hesaplanır

## Köylü odasında kaç mahkum olabilir
const VILLAGER_ROOM_MIN_COUNT := 1
const VILLAGER_ROOM_MAX_COUNT := 3
## Tutsakların gezinebildiği hücre bölgesinin yarı genişliği (parmaklık sprite'ı
## bu bölgeyi kapatacak: toplam genişlik = 2 * bu değer)
const VILLAGER_PEN_HALF_WIDTH := 72.0

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
	if minigame_kind == "villager":
		_setup_villager_pen_interaction()
	if not _consumed and minigame_kind == "villager":
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] Scheduling villager prisoner spawn...")
		call_deferred("_spawn_prisoner_villager")
	if not _consumed and minigame_kind == "vip":
		if DEBUG_DOOR_INTERACTION:
			print("[DoorInteraction] Scheduling vip prisoner spawn...")
		call_deferred("_spawn_prisoner_cariye")
	if minigame_kind == "vip":
		call_deferred("_spawn_door_sprite")
	_spawn_interact_arrow()


## Köylü odasında etkileşim noktasını parmaklığın ("Prison" sprite) önüne taşır ve
## algılama alanını parmaklık genişliğine göre büyütür (oyuncu bariyer yüzünden
## merkezine yaklaşamadığı için eski küçük daire yetmez).
func _setup_villager_pen_interaction() -> void:
	var pen: Node2D = get_parent().get_node_or_null("Prison") as Node2D
	if pen == null:
		return
	position = pen.position
	var half_w: float = VILLAGER_PEN_HALF_WIDTH
	var half_h: float = 64.0
	var tex = pen.get("texture")
	if tex != null:
		half_w = float(tex.get_width()) * 0.5 * absf(pen.scale.x)
		half_h = float(tex.get_height()) * 0.5 * absf(pen.scale.y)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		var circ := CircleShape2D.new()
		circ.radius = half_w + 72.0
		cs.set_deferred("shape", circ)
	_arrow_offset = Vector2(0.0, -half_h - 28.0)


## Etkileşim noktasının üstünde, oyuncu yaklaşınca beliren "yukarı bas" ok ikonu.
func _spawn_interact_arrow() -> void:
	_arrow = ArrowHint.create()
	_arrow.position = _arrow_offset
	add_child(_arrow)

func _process(_delta):
	if _arrow != null:
		if _player_overlapping and not _consumed and not _door_busy:
			_arrow.show_hint()
		else:
			_arrow.hide_hint()
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
	if _consumed or _door_busy:
		return
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
	if minigame_kind == "villager":
		ctx["villager_count"] = maxi(1, _count_unrescued_villagers())
	if minigame_kind == "vip" and _prisoner_cariye and is_instance_valid(_prisoner_cariye):
		var dn = _prisoner_cariye.get("display_name")
		if typeof(dn) == TYPE_STRING and dn != "":
			ctx["cariye_name"] = dn
		var app = _prisoner_cariye.get("appearance")
		if app != null:
			ctx["cariye_appearance"] = app
	var stealth_mgr: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("get_rescue_minigame_difficulty_multiplier"):
		ctx["difficulty_multiplier"] = stealth_mgr.call("get_rescue_minigame_difficulty_multiplier")
	# Önce kapı açılır, sonra "odanın içinde" pazarlık başlar
	_door_busy = true
	await _animate_door(true)
	var callback := Callable(self, "_on_minigame_result")
	if MinigameRouter.is_connected("minigame_finished", callback):
		MinigameRouter.disconnect("minigame_finished", callback)
	MinigameRouter.connect("minigame_finished", callback, CONNECT_ONE_SHOT)
	var started := MinigameRouter.start_minigame(minigame_kind, ctx)
	if not started:
		if MinigameRouter.is_connected("minigame_finished", callback):
			MinigameRouter.disconnect("minigame_finished", callback)
		await _animate_door(false)
		_door_busy = false

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
	if minigame_kind == "villager":
		_handle_villager_result(result)
		return
	if result.get("success", false):
		_consumed = true
		_door_busy = false
		# Kapı zaten açık (minigame başlamadan açıldı); açık kalır.
		var drs = get_node_or_null("/root/DungeonRunState")
		if drs:
			var fragile: bool = _is_fragile_rescue_context()
			if minigame_kind == "vip":
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
				if drs.has_method("add_pending_cariye"):
					drs.call("add_pending_cariye", cariye_data, fragile)
				else:
					drs.add_pending_cariye(cariye_data)
			if fragile:
				var sm: Node = get_node_or_null("/root/StealthManager")
				if is_instance_valid(sm) and sm.has_method("refresh_fragile_hud"):
					sm.call_deferred("refresh_fragile_hud")
	else:
		# Kaybedilen kurtarma tekrar denenemez: oda kapanır
		_consumed = true
		_apply_failure_penalty()
		_animate_door(false)
		_door_busy = false


## Köylü kurtarma sonucu: kısmi kurtarma destekli. payload.rescued_count kadar köylü
## köye aktarılır; hiç kurtarılamadıysa ceza uygulanır. Oyun her halükarda bir kez
## oynanır: haklar bitince (kısmi kurtarmayla bile) oda kapanır, tekrar denenemez.
func _handle_villager_result(result: Dictionary) -> void:
	_door_busy = false
	_consumed = true
	var payload: Dictionary = result.get("payload", {})
	var rescued_count: int = int(payload.get("rescued_count", 1 if result.get("success", false) else 0))
	var drs = get_node_or_null("/root/DungeonRunState")
	var fragile: bool = _is_fragile_rescue_context()
	for i in range(rescued_count):
		var w: Node = _next_unrescued_villager()
		var appearance_dict = null
		var name_str = "Köylü"
		if w != null:
			var app = w.get("appearance")
			appearance_dict = app.to_dict() if app and app.has_method("to_dict") else null
			if w.get("NPC_Info") is Dictionary:
				var info = w.NPC_Info.get("Info", {})
				if info is Dictionary and info.has("Name"):
					name_str = info["Name"]
			w.visible = false
		if drs:
			if drs.has_method("add_pending_villager_data"):
				drs.call("add_pending_villager_data", {"appearance": appearance_dict, "name": name_str}, fragile)
			else:
				drs.add_pending_villager_data({"appearance": appearance_dict, "name": name_str})
	if rescued_count > 0:
		if fragile:
			var sm: Node = get_node_or_null("/root/StealthManager")
			if is_instance_valid(sm) and sm.has_method("refresh_fragile_hud"):
				sm.call_deferred("refresh_fragile_hud")
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


func _is_fragile_rescue_context() -> bool:
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm):
		return false
	if not sm.has_method("is_stealth_enabled") or not bool(sm.call("is_stealth_enabled")):
		return false
	if not sm.has_method("is_stealth_mode"):
		return false
	return bool(sm.call("is_stealth_mode"))

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
	var offset_x := -400  # Sağ oda: köylüler kapının solunda
	if chunk.get("scene_file_path"):
		var path_str: String = chunk.scene_file_path
		if path_str.get_file().to_lower().contains("left"):
			offset_x = 400  # Sol oda: köylüler kapının sağında
	var dir: int = signi(offset_x)
	# Hücre bölgesi: chunk'ta "Prison" (parmaklık) sprite'ı varsa o belirler;
	# yoksa kapıya göre sabit offset kullanılır.
	var pen: Node2D = chunk.get_node_or_null("Prison") as Node2D
	var pen_center_local: Vector2 = position + Vector2(offset_x + dir * 48, 0)
	var pen_half: float = VILLAGER_PEN_HALF_WIDTH
	if pen != null:
		pen_center_local = pen.position
		pen.z_index = 60  # parmaklık oyuncunun ve tutsak NPC'lerin ÖNÜNDE
		var tex = pen.get("texture")
		if tex != null:
			pen_half = maxf(32.0, float(tex.get_width()) * 0.5 * absf(pen.scale.x) - 24.0)
		_spawn_pen_barrier(chunk, pen)
	var count: int = randi_range(VILLAGER_ROOM_MIN_COUNT, VILLAGER_ROOM_MAX_COUNT)
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] Spawning %d villager prisoner(s), pen_center=%s pen_half=%.0f" % [count, str(pen_center_local), pen_half])
	var spacing: float = 48.0
	if count > 1:
		spacing = minf(48.0, (pen_half * 2.0 - 48.0) / float(count - 1))
	for i in range(count):
		var worker = WorkerScene.instantiate()
		worker.is_dungeon_prisoner = true
		worker.worker_id = -1
		worker.appearance = AppearanceDB.generate_random_appearance()
		worker.NPC_Info = {
			"Info": {"Name": _random_villager_name()},
			"Latest_news": []
		}
		var slot_x: float = pen_center_local.x + (float(i) - float(count - 1) * 0.5) * spacing
		worker.position = Vector2(slot_x, position.y)
		worker.z_index = 50  # Döşemelerin üstünde görünsün (Worker script'i zindanda kendi z'sini uygular)
		worker.visible = true
		chunk.add_child(worker)
		_snap_npc_to_floor(worker)
		_prisoner_villagers.append(worker)
	# Tutsaklar parmaklığın dışına çıkmasın: ortak merkez + dar gezinme alanı
	var pen_center_global_x: float = (chunk as Node2D).to_global(pen_center_local).x
	for w in _prisoner_villagers:
		if is_instance_valid(w):
			w.dungeon_spawn_x = pen_center_global_x
			w.dungeon_wander_range = pen_half


## Parmaklık bölgesine oyuncuyu sokmayan görünmez duvar (StaticBody2D).
## Tutsak NPC'ler fizik gövdesiyle hareket etmediği için onları etkilemez.
func _spawn_pen_barrier(chunk: Node, pen: Node2D) -> void:
	if chunk.get_node_or_null("PrisonBarrier") != null:
		return
	var tex = pen.get("texture")
	if tex == null:
		return
	var w: float = float(tex.get_width()) * absf(pen.scale.x)
	var h: float = float(tex.get_height()) * absf(pen.scale.y)
	var body := StaticBody2D.new()
	body.name = "PrisonBarrier"
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Sprite'ın kapladığı alan kadar katı blok: oyuncu içeri giremez
	# (üstüne çıkabilir — kafes çatısı gibi davranır)
	rect.size = Vector2(maxf(8.0, w - 8.0), maxf(8.0, h - 8.0))
	shape.shape = rect
	body.add_child(shape)
	body.position = pen.position
	chunk.add_child(body)


## Henüz kurtarılmamış (görünür) ilk köylü mahkumu döndürür.
func _next_unrescued_villager() -> Node:
	for w in _prisoner_villagers:
		if is_instance_valid(w) and w.visible:
			return w
	return null


func _count_unrescued_villagers() -> int:
	var n := 0
	for w in _prisoner_villagers:
		if is_instance_valid(w) and w.visible:
			n += 1
	return n

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
	chunk.add_child(cariye)
	# Cariye odada görünmez; görünümü İkna Düellosu ekranında gösteriliyor.
	# Node yine de spawn ediliyor: isim + appearance verisi kurtarma akışında kullanılıyor.
	cariye.visible = false
	cariye.set_physics_process(false)
	_snap_npc_to_floor(cariye)
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] VIP prisoner spawned at global %s" % str(cariye.global_position))
	_prisoner_cariye = cariye

## VIP (cariye) odasında etkileşim noktasına görsel kapı koyar. Akış: oyuncu
## etkileşime geçince kapı açılır → minigame başlar; kaybederse kapı kapanır,
## kazanırsa açık kalır. Konum otomatik zemine oturur; yanlışsa editörden
## door_sprite_offset ile düzeltilebilir.
func _spawn_door_sprite() -> void:
	if has_node("Sprite2D"):
		return
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = DoorTexture
	spr.hframes = 8
	spr.frame = 7 if _consumed else 0
	spr.z_index = 0  # tile'ların üstünde ama oyuncunun (ağaçta sonra çizilir) arkasında
	spr.visible = false  # zemine oturtulana kadar gizle (yanlış yerde belirmesin)
	add_child(spr)
	_snap_door_sprite_to_floor(spr)


## Kapı tabanını yürünebilir yüzeye oturtur. Chunk'ın kendi TileMapLayer'ı
## UnifiedTerrain birleştirmesi sonrası BOŞALTILDIĞI için tile verisine güvenilemez;
## bunun yerine yüzeyin üstünden (açık havadan) fizik raycast atılır. Birleşik
## terrain'in collision'ı hazır olana kadar birkaç frame denenir.
func _snap_door_sprite_to_floor(spr: Sprite2D) -> void:
	var floor_top := INF
	for _attempt in range(60):
		floor_top = _find_floor_top_by_ray()
		if floor_top != INF:
			break
		await get_tree().process_frame
		if not is_instance_valid(spr):
			return
	if floor_top == INF:
		floor_top = _find_floor_top_below(global_position)
	if floor_top != INF:
		# door_1 karesinde kapı görselinin alt kenarı kare merkezinin ~96 px altında;
		# tabanı yüzeyin tam üstüne oturt.
		spr.global_position = Vector2(global_position.x, floor_top - 96.0) + door_sprite_offset
	else:
		spr.position = door_sprite_offset
	spr.visible = true
	if DEBUG_DOOR_INTERACTION:
		print("[DoorInteraction] Door sprite snapped to %s (floor_top=%s)" % [str(spr.global_position), str(floor_top)])


## Yüzeyin üstünden aşağı fizik raycast: yürünebilir zeminin üst Y'si (bulamazsa INF).
func _find_floor_top_by_ray() -> float:
	var space := get_world_2d().direct_space_state
	if space == null:
		return INF
	var from := global_position + Vector2(0.0, -128.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2.DOWN * 700.0)
	q.collision_mask = CollisionLayers.WORLD
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		return float(hit.position.y)
	return INF


## Kapı kare animasyonu (0=kapalı, 7=açık). Kapı sprite'ı yoksa anında döner.
func _animate_door(open: bool) -> void:
	if not has_node("Sprite2D"):
		return
	var spr = $Sprite2D
	if not (spr is Sprite2D) or spr.hframes < 8:
		return
	var target := 7 if open else 0
	if spr.frame == target:
		return
	var tw := create_tween()
	tw.tween_property(spr, "frame", target, 0.45)
	await tw.finished


## Verilen dünya konumunun altındaki YÜRÜNEBİLİR yüzeyin üst Y'sini döndürür.
## Kapının birkaç tile üstünden (açık havadan) aşağı doğru tarayıp ilk BOŞ→DOLU
## geçişini arar; bu, yüzeyin altındaki dolu gövde hücrelerine takılmayı önler
## (raycast merkez collision içinde kaldığında hiç vurmuyordu, düz tile taraması
## da yüzeyin altındaki ilk dolu hücreyi bulup kapıyı gömüyordu).
func _find_floor_top_below(world_pos: Vector2) -> float:
	var chunk = get_parent()
	if not chunk:
		return INF
	var tile_map = chunk.get_node_or_null("TileMapLayer")
	if tile_map == null:
		return INF
	var tile_h := 32.0
	if tile_map.tile_set:
		tile_h = float(tile_map.tile_set.tile_size.y)
	var cell: Vector2i = tile_map.local_to_map(tile_map.to_local(world_pos))
	cell.y -= 3  # kapının üstündeki açık alandan taramaya başla
	var prev_solid: bool = int(tile_map.get_cell_source_id(cell)) != -1
	for i in range(18):
		cell.y += 1
		var solid: bool = int(tile_map.get_cell_source_id(cell)) != -1
		if solid and not prev_solid:
			var cell_world: Vector2 = tile_map.to_global(tile_map.map_to_local(cell))
			return cell_world.y - tile_h * 0.5
		prev_solid = solid
	return INF


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
