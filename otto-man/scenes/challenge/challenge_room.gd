extends Node2D
class_name ChallengeRoom

## Challenge odası kontrolcüsü (bkz. docs/CHALLENGE_ROOMS.md). Tek sahne; tür (kind), mekân (biome)
## ve zorluk SceneManager payload'ından gelir:
##   {"kind": "koruma" | "dalga", "biome": "orman" | "zindan", "difficulty": 1-9}
## Akış: arena kurulur -> oyuncuya 3 kart seçimi (build kurma) -> dalgalar -> ödül -> haritaya dönüş.
## Başarısızlık = oyuncunun ölümü (normal ölüm akışı: 1 canla köyde doğar). Koruma'da bütün
## köylüler ölürse ödül yok ve haritaya dönülür.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const START_PICKS: int = 3
const BREAK_SECONDS: float = 3.0
const WARDS_BASE: int = 3
const WARD_HEALTH: float = 70.0

var kind: String = "koruma"
var biome: String = "orman"
var difficulty: int = 1

var _layout: Dictionary = {}
var _player: Node2D = null
var _spawner: ChallengeWaveSpawner = null
var _enemy_container: Node2D = null
var _wards: Array[WardTarget] = []
var _ward_total: int = 0
var _finished: bool = false

var _wave_label: Label = null
var _ward_label: Label = null
var _message_label: Label = null


func _ready() -> void:
	_read_payload()
	_layout = ChallengeArenaBuilder.build(self, biome)
	_setup_camera()
	_enemy_container = Node2D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)
	_spawn_player()
	if kind == "koruma":
		_spawn_wards()
	_build_hud()
	_setup_spawner()
	_begin_sequence()


func _read_payload() -> void:
	var sm: Node = get_node_or_null("/root/SceneManager")
	var payload: Dictionary = {}
	if is_instance_valid(sm) and "current_payload" in sm:
		payload = sm.get("current_payload")
	kind = String(payload.get("kind", kind))
	biome = String(payload.get("biome", biome))
	difficulty = clampi(int(payload.get("difficulty", difficulty)), 1, 9)
	if not ChallengeRoomRegistry.KINDS.has(kind):
		kind = "koruma"
	if biome not in ChallengeRoomRegistry.BIOMES:
		biome = "orman"


func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "FixedCamera"
	cam.position = _layout["camera_position"]
	add_child(cam)
	cam.enabled = true
	cam.make_current()


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as Node2D
	add_child(_player)
	_player.global_position = _layout["player_spawn"]
	_player.z_index = 7
	# Oyuncu kamerası kapalı: sabit arena kamerası kullanılır (boss odasıyla aynı)
	var player_camera: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if player_camera:
		player_camera.enabled = false


func _spawn_wards() -> void:
	_ward_total = clampi(WARDS_BASE + difficulty / 4, 2, 5)
	var cx: float = float(_layout["center_x"])
	var spacing: float = 90.0
	for i in range(_ward_total):
		var ward := WardTarget.new()
		ward.max_health = WARD_HEALTH
		add_child(ward)
		ward.global_position = Vector2(cx + (float(i) - float(_ward_total - 1) * 0.5) * spacing, float(_layout["floor_y"]))
		ward.died.connect(_on_ward_died)
		_wards.append(ward)


func _setup_spawner() -> void:
	_spawner = ChallengeWaveSpawner.new()
	_spawner.name = "WaveSpawner"
	add_child(_spawner)
	_spawner.configure(_layout, _enemy_container, difficulty, ChallengeWaveSpawner.waves_for_difficulty(difficulty))
	_spawner.wave_started.connect(_on_wave_started)
	_spawner.wave_cleared.connect(_on_wave_cleared)
	_spawner.all_waves_cleared.connect(_on_all_waves_cleared)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ChallengeHud"
	layer.layer = 40
	add_child(layer)
	_wave_label = _make_label(layer, Vector2(0, 24), 28)
	_ward_label = _make_label(layer, Vector2(0, 62), 20)
	_message_label = _make_label(layer, Vector2(0, 300), 40)
	_ward_label.visible = kind == "koruma"
	_update_ward_label()


func _make_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.position = pos
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _show_message(text: String, seconds: float = 0.0) -> void:
	_message_label.text = text
	_message_label.visible = not text.is_empty()
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
		if _message_label.text == text:
			_message_label.visible = false


func _update_ward_label() -> void:
	if _ward_label == null:
		return
	var alive: int = 0
	for w in _wards:
		if is_instance_valid(w) and not w.is_dead:
			alive += 1
	_ward_label.text = tr("challenge.wards") % [alive, _ward_total]


# --- Akış ---------------------------------------------------------------------------------

func _begin_sequence() -> void:
	_wave_label.text = tr(String(ChallengeRoomRegistry.KINDS[kind]))
	await get_tree().create_timer(0.6).timeout
	# Build kurma: oyuncunun açtığı item'lardan START_PICKS kez kart seçimi
	var im: Node = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("queue_item_selections"):
		_show_message(tr("challenge.pick") % START_PICKS)
		im.call("queue_item_selections", START_PICKS)
		await im.item_selection_sequence_finished
	await _show_message(tr("challenge.ready"), 1.6)
	_spawner.start_next_wave()


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = tr("challenge.wave") % [index, total]


func _on_wave_cleared(index: int, total: int) -> void:
	if _finished or index >= total:
		return
	# Dalga arenasında her dalgadan sonra level-up (kart seçimi); korumada kısa nefes
	if kind == "dalga":
		var im: Node = get_node_or_null("/root/ItemManager")
		if is_instance_valid(im) and im.has_method("queue_item_selections"):
			im.call("queue_item_selections", 1)
			await im.item_selection_sequence_finished
	await _show_message(tr("challenge.cleared") % index, BREAK_SECONDS)
	if not _finished:
		_spawner.start_next_wave()


func _on_ward_died(_ward: WardTarget) -> void:
	_update_ward_label()
	if _finished:
		return
	for w in _wards:
		if is_instance_valid(w) and not w.is_dead:
			return
	_finish(false)


func _on_all_waves_cleared() -> void:
	_finish(true)


func _finish(won: bool) -> void:
	if _finished:
		return
	_finished = true
	_spawner.set_physics_process(false)
	var reward_text: String = ""
	if won:
		reward_text = await _grant_reward()
		await _show_message(reward_text, 3.2)
	else:
		await _show_message(tr("challenge.fail.koruma"), 3.0)
	_leave_to_world_map(won)


## Türe uygun ödül; ödülü anlatan metni döndürür.
func _grant_reward() -> String:
	if kind == "koruma":
		var survivors: int = 0
		var drs: Node = get_node_or_null("/root/DungeonRunState")
		for w in _wards:
			if is_instance_valid(w) and not w.is_dead:
				survivors += 1
				if is_instance_valid(drs) and drs.has_method("add_pending_villager"):
					drs.call("add_pending_villager")
		return tr("challenge.win.koruma") % survivors
	# Dalga arenası: koleksiyona yeni item (rastgele temanın keşif havuzundan seçim kartı)
	var im: Node = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("queue_unlock_offer"):
		var themes: Array = im.DUNGEON_THEME_POOLS.keys()
		var theme: String = String(themes[randi() % themes.size()])
		im.call("queue_unlock_offer", theme, "kesif", 1)
		if im.has_method("resolve_pending_unlock_offers"):
			await im.call("resolve_pending_unlock_offers")
	return tr("challenge.win.dalga")


func _leave_to_world_map(won: bool) -> void:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if is_instance_valid(sm) and sm.has_method("change_to_world_map"):
		sm.call("change_to_world_map", {
			"source": "dungeon",
			"return_reason": "challenge_complete" if won else "challenge_failed",
		})
