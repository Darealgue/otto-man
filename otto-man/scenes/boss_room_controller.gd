extends Node2D
## Boss odası bootstrap: oyuncu, sabit kamera, boss spawn, giriş kapısı ve UI.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const BOSS_BAR_SCENE: PackedScene = preload("res://ui/boss_health_bar.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/door.tscn")

@export var boss_id: String = "tepegoz"
@export var boss_scene: PackedScene
@export var arena_bounds: Rect2 = Rect2(96.0, 128.0, 1728.0, 820.0)
@export var default_player_spawn: Vector2 = Vector2(32.0, 928.0)
@export var default_boss_spawn: Vector2 = Vector2(960.0, 280.0)
@export var default_door_spawn: Vector2 = Vector2(128.0, 928.0)
@export var fixed_camera_position: Vector2 = Vector2(960.0, 540.0)
@export var arena_enter_x: float = 192.0

var _player: Node = null
var _boss: Node2D = null
var _projectile_container: Node2D = null
var _entrance_door: Door = null
var _fight_started: bool = false
var _exit_unlocked: bool = false
var _leaving_dungeon: bool = false
var _loot_spawner: DecorationSpawner = null


func _ready() -> void:
	_setup_camera()
	_setup_containers()
	_spawn_entrance_door()
	_spawn_player()
	_spawn_boss()
	_setup_boss_bar()


func _process(_delta: float) -> void:
	if _fight_started or not is_instance_valid(_player):
		return
	if _player.global_position.x >= arena_enter_x:
		_begin_boss_fight()


func _setup_camera() -> void:
	var fixed_camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if fixed_camera:
		fixed_camera.enabled = true
		fixed_camera.position = fixed_camera_position
		fixed_camera.make_current()


func _setup_containers() -> void:
	_projectile_container = get_node_or_null("ProjectileContainer") as Node2D
	if _projectile_container == null:
		_projectile_container = Node2D.new()
		_projectile_container.name = "ProjectileContainer"
		add_child(_projectile_container)


func _spawn_entrance_door() -> void:
	var door_spawn: Vector2 = _resolve_door_spawn()

	_entrance_door = DOOR_SCENE.instantiate() as Door
	_entrance_door.name = "EntranceDoor"
	_entrance_door.global_position = door_spawn
	_entrance_door.door_type = "Boss"
	_entrance_door.door_opened.connect(_on_entrance_door_opened)
	add_child(_entrance_door)

	call_deferred("_open_entrance_door")


func _resolve_door_spawn() -> Vector2:
	var door_marker: Node2D = get_node_or_null("SpawnPoints/DoorSpawn") as Node2D
	if door_marker:
		return door_marker.global_position
	return default_door_spawn


func _open_entrance_door() -> void:
	if not is_instance_valid(_entrance_door):
		return
	_entrance_door.is_locked = false
	if _entrance_door.has_method("open_door_immediately"):
		_entrance_door.open_door_immediately()
	elif _entrance_door.has_method("_open_door_immediately"):
		_entrance_door._open_door_immediately()


func _spawn_player() -> void:
	_player = get_node_or_null("Player")
	if _player == null:
		_player = PLAYER_SCENE.instantiate()
		add_child(_player)

	var spawn: Vector2 = default_player_spawn
	var spawn_marker: Node2D = get_node_or_null("SpawnPoints/PlayerSpawn") as Node2D
	if spawn_marker:
		var marker_pos := spawn_marker.global_position
		if marker_pos.x < arena_enter_x:
			spawn = marker_pos
	_player.global_position = spawn

	var player_camera: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		player_camera.enabled = false


func _spawn_boss() -> void:
	var container: Node = get_node_or_null("BossContainer")
	if container == null:
		container = self

	var existing: Node2D = _find_existing_boss(container)
	if existing:
		_boss = existing
	else:
		var scene := _resolve_boss_scene()
		if scene == null:
			push_error("[BossRoom] boss_scene atanmamış (boss_id=%s)" % boss_id)
			return
		_boss = scene.instantiate() as Node2D
		container.add_child(_boss)

	var boss_spawn: Vector2 = default_boss_spawn
	var boss_marker: Node2D = get_node_or_null("SpawnPoints/BossSpawn") as Node2D
	if boss_marker:
		boss_spawn = boss_marker.global_position
	_boss.global_position = boss_spawn
	var room_layout := _build_boss_room_layout(boss_spawn)
	if _boss.has_method("setup_boss_room"):
		_boss.setup_boss_room(room_layout)
	elif _boss.has_method("setup_arena"):
		_boss.setup_arena(arena_bounds)
	if _boss.has_method("set_hazard_container"):
		_boss.set_hazard_container(_projectile_container)
	elif _boss.has_method("set_projectile_container"):
		_boss.set_projectile_container(_projectile_container)
	_apply_run_difficulty_to_boss()

	if _boss.has_signal("enemy_defeated"):
		_boss.enemy_defeated.connect(_on_boss_defeated)


func _find_existing_boss(container: Node) -> Node2D:
	for child in container.get_children():
		if child is Node2D and child.is_in_group("boss"):
			return child as Node2D
	for node_name in ["TepegozBoss", "OrbScatterBoss"]:
		var n := container.get_node_or_null(node_name) as Node2D
		if n:
			return n
	return null


func _resolve_boss_scene() -> PackedScene:
	if boss_scene:
		return boss_scene
	push_warning("[BossRoom] boss_scene boş — Tepegöz fallback (boss_id=%s)" % boss_id)
	return preload("res://boss/tepegoz_boss.tscn") as PackedScene


func _build_boss_room_layout(boss_anchor: Vector2) -> Dictionary:
	var floor_y := default_player_spawn.y
	var player_marker: Node2D = get_node_or_null("SpawnPoints/PlayerSpawn") as Node2D
	if player_marker:
		floor_y = player_marker.global_position.y
	var hand_inset := 140.0
	return {
		"bounds": arena_bounds,
		"floor_y": floor_y,
		"ceiling_y": arena_bounds.position.y + 36.0,
		"boss_anchor": boss_anchor,
		"hand_left_x": arena_bounds.position.x + hand_inset,
		"hand_right_x": arena_bounds.position.x + arena_bounds.size.x - hand_inset,
		"hand_y": floor_y - 68.0,
	}


func _setup_boss_bar() -> void:
	if not is_instance_valid(_boss):
		return

	var ui_layer: CanvasLayer = null
	if _player and _player.has_node("UI") and _player.get_node("UI") is CanvasLayer:
		ui_layer = _player.get_node("UI")
	else:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "BossUILayer"
		add_child(ui_layer)

	var existing_bar := ui_layer.get_node_or_null("BossHealthBar")
	if existing_bar:
		existing_bar.queue_free()

	var boss_bar := BOSS_BAR_SCENE.instantiate()
	boss_bar.name = "BossHealthBar"
	ui_layer.add_child(boss_bar)

	if boss_bar.has_method("setup_silent") and _boss.get("max_health") != null:
		boss_bar.setup_silent(float(_boss.max_health))
	if boss_bar.has_method("reveal"):
		boss_bar.reveal()

	if _boss.has_signal("health_changed"):
		_boss.health_changed.connect(boss_bar.update_health)
	if _boss.has_signal("enemy_defeated") and boss_bar.has_method("conceal"):
		_boss.enemy_defeated.connect(boss_bar.conceal)


func _begin_boss_fight() -> void:
	if _fight_started:
		return
	_fight_started = true
	_seal_entrance_door()
	if is_instance_valid(_boss) and _boss.has_method("start_fight"):
		_boss.start_fight()


func _seal_entrance_door() -> void:
	if not is_instance_valid(_entrance_door):
		return
	_entrance_door.lock_door()
	if _entrance_door.has_method("close_door_now"):
		_entrance_door.close_door_now()


func _apply_run_difficulty_to_boss() -> void:
	if not is_instance_valid(_boss):
		return
	var base_hp: float = 200.0
	if "max_health" in _boss:
		base_hp = float(_boss.get("max_health"))
	var clear_bonus: int = 0
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs):
		clear_bonus = int(drs.get("run_base_difficulty"))
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	var scaled_hp: float = base_hp
	if is_instance_valid(dp) and dp.has_method("get_boss_max_health"):
		scaled_hp = float(dp.call("get_boss_max_health", base_hp, clear_bonus))
	else:
		scaled_hp = base_hp + float(clear_bonus) * 50.0
	_boss.set("max_health", scaled_hp)
	_boss.set("health", scaled_hp)


func _on_boss_defeated() -> void:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	if is_instance_valid(drs) and is_instance_valid(dp) and dp.has_method("record_clear"):
		var did: String = String(drs.get("dungeon_id"))
		dp.call("record_clear", did)
	_scatter_boss_gold(drs)
	_exit_unlocked = true
	if not is_instance_valid(_entrance_door):
		return
	_entrance_door.unlock_door()
	_entrance_door.close_door_now()
	print("[BossRoom] Boss yenildi — giriş kapısından çıkabilirsin")


func _on_entrance_door_opened(_door_type: String) -> void:
	if not _exit_unlocked or _leaving_dungeon:
		return
	_leave_dungeon()


func _scatter_boss_gold(drs: Node) -> void:
	if not is_instance_valid(_boss):
		return
	var total: int = 20
	if is_instance_valid(drs) and drs.has_method("get_boss_scatter_gold_total"):
		total = int(drs.call("get_boss_scatter_gold_total"))
	if total <= 0:
		return
	var spawner := _get_loot_spawner()
	if spawner == null:
		push_warning("[BossRoom] Loot spawner yok — boss altını saçılamadı")
		return
	var origin: Vector2 = _boss.global_position
	spawner.call_deferred("spawn_boss_gold_burst", origin, total)
	if is_instance_valid(drs):
		print("[BossRoom] Boss altını saçıldı: %d (gold_mult=%.2f, segment=%d)" % [
			total,
			float(drs.get("gold_multiplier_accumulated")),
			int(drs.get("run_segment_count")),
		])


func _get_loot_spawner() -> DecorationSpawner:
	if is_instance_valid(_loot_spawner):
		return _loot_spawner
	for n in get_tree().get_nodes_in_group("decoration_spawner"):
		if n is DecorationSpawner:
			_loot_spawner = n as DecorationSpawner
			return _loot_spawner
	_loot_spawner = DecorationSpawner.new()
	_loot_spawner.name = "BossLootSpawner"
	add_child(_loot_spawner)
	return _loot_spawner


func _leave_dungeon() -> void:
	if _leaving_dungeon:
		return
	_leaving_dungeon = true
	var sm := get_node_or_null("/root/SceneManager")
	if sm and sm.has_method("change_to_world_map"):
		sm.change_to_world_map({"source": "dungeon", "return_reason": "boss_defeated"})
	else:
		_leaving_dungeon = false
