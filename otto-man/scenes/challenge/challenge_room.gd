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
## Asansör arenası: kat başına yükselme, yükselme süresi, zemin kalınlığı, ulaşılabilecek en yüksek yüzey y'si
const LIFT_RISE_PER_FLOOR: float = 420.0
const LIFT_RISE_TIME: float = 3.0
const LIFT_THICKNESS: float = 32.0
const LIFT_TOP_LIMIT: float = 900.0
## Kovalamaca: bu kadar yakalanınca başarısız (ölüm)
const CHASE_MAX_CATCHES: int = 3
## Oyuncu başlangıçtan bu kadar sağa gidince kuşlar sahneye girer (px)
const CHASE_TRIGGER_DISTANCE: float = 120.0
## Oyuncunun ölçülen düz koşu hızı (px/s); sürü hızı buna oranlanır
const PLAYER_RUN_SPEED: float = 560.0
## Tuzak Geçidi: tuzağa çarpınca kalan süreden düşen saniye
const TRAP_HIT_TIME_PENALTY: float = 4.0

var kind: String = "koruma"
var biome: String = "orman"
var difficulty: int = 1

var _layout: Dictionary = {}
var _player: Node2D = null
var _spawner: ChallengeWaveSpawner = null
var _enemy_container: Node2D = null
var _wards: Array[WardTarget] = []
var _cam: Camera2D = null
var _lift: AnimatableBody2D = null
var _lift_top: float = 0.0
var _lift_creeping: bool = false
var _chase_floor_y: float = 928.0
var _swarm: ChaseSwarm = null
## Tuzak Geçidi: zindan teması, kalan süre, sayaç çalışıyor mu
var _theme: String = ""
var _time_left: float = 0.0
var _timer_running: bool = false
var _ward_total: int = 0
var _ward_override: int = 0
var _finished: bool = false

var _wave_label: Label = null
var _ward_label: Label = null
var _message_label: Label = null


func _ready() -> void:
	_read_payload()
	if kind == "kovalamaca":
		_layout = ChaseCorridorBuilder.build(self, biome, difficulty)
	elif kind == "tuzak":
		_layout = TrapMazeBuilder.build(self, difficulty, _theme)
	else:
		_layout = ChallengeArenaBuilder.build(self, biome, kind == "asansor")
	if biome == "orman":
		_decorate_forest()
	_setup_camera()
	_enemy_container = Node2D.new()
	_enemy_container.name = "Enemies"
	add_child(_enemy_container)
	if kind == "asansor":
		_build_lift()
	_spawn_player()
	if kind == "koruma":
		_spawn_wards()
	_build_hud()
	if kind == "tuzak":
		_setup_trap_run()
	if kind == "kovalamaca":
		_setup_chase()
	elif kind == "tuzak":
		pass   # düşman/dalga yok
	else:
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
	_ward_override = int(payload.get("wards", 0))
	_theme = String(payload.get("theme", ""))
	if not ChallengeRoomRegistry.KINDS.has(kind):
		kind = "koruma"
	if biome not in ChallengeRoomRegistry.BIOMES:
		biome = "orman"
	biome = ChallengeRoomRegistry.biome_for(kind, biome)
	if kind == "tuzak" and not DungeonThemeStyle.STYLES.has(_theme):
		var themes: Array = DungeonThemeStyle.STYLES.keys()
		_theme = String(themes[randi() % themes.size()])


## Orman arenası: gerçek orman sahnesinin gökyüzü/güneş/parallax/bulut ve zemin dekoru.
func _decorate_forest() -> void:
	var decorator := ForestArenaDecorator.new()
	decorator.name = "ForestDecor"
	add_child(decorator)
	decorator.decorate(self)


func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "FixedCamera"
	cam.position = _layout["camera_position"]
	add_child(cam)
	cam.enabled = true
	cam.make_current()
	_cam = cam


# --- Asansör arenası ------------------------------------------------------------------------

## Kuyunun iç genişliğini kaplayan hareketli zemin: kenardan düşme yok, düşmanlar tepeden iner.
func _build_lift() -> void:
	var left_x: float = float(_layout["left_x"])
	var width: float = float(_layout["right_x"]) - left_x
	_lift = AnimatableBody2D.new()
	_lift.name = "Lift"
	_lift.sync_to_physics = true
	_lift.collision_layer = CollisionLayers.WORLD
	_lift.collision_mask = 0
	_lift.z_index = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, LIFT_THICKNESS)
	shape.shape = rect
	_lift.add_child(shape)
	# Görünüm (geçici sanat): ahşap/metal zemin, altında makine gövdesi, kenarlarda ışıklar
	var plank := ColorRect.new()
	plank.color = Color(0.42, 0.30, 0.20)
	plank.size = Vector2(width, 12.0)
	plank.position = Vector2(-width * 0.5, -LIFT_THICKNESS * 0.5)
	_lift.add_child(plank)
	var rim := ColorRect.new()
	rim.color = Color(0.62, 0.46, 0.30)
	rim.size = Vector2(width, 3.0)
	rim.position = Vector2(-width * 0.5, -LIFT_THICKNESS * 0.5)
	_lift.add_child(rim)
	var body := ColorRect.new()
	body.color = Color(0.17, 0.15, 0.15)
	body.size = Vector2(width, 520.0)
	body.position = Vector2(-width * 0.5, -LIFT_THICKNESS * 0.5 + 12.0)
	_lift.add_child(body)
	var x: float = -width * 0.5 + 60.0
	while x < width * 0.5:
		var lamp := ColorRect.new()
		lamp.color = Color(1.0, 0.72, 0.3)
		lamp.size = Vector2(10.0, 6.0)
		lamp.position = Vector2(x, -LIFT_THICKNESS * 0.5 + 18.0)
		_lift.add_child(lamp)
		x += 140.0
	_lift.position = Vector2(float(_layout["center_x"]), 0.0)
	add_child(_lift)
	_set_lift_top(float(_layout["floor_y"]) + 4.0)


## Asansör yüzeyini (üst kenarını) verilen y'ye taşır; kamera, doğma noktaları ve sınırlar onu izler.
func _set_lift_top(y: float) -> void:
	_lift_top = y
	_lift.position.y = y + LIFT_THICKNESS * 0.5
	if _cam:
		_cam.position.y = y - 388.0
	var left_x: float = float(_layout["left_x"])
	var right_x: float = float(_layout["right_x"])
	_layout["floor_y"] = y
	_layout["bounds"] = Rect2(left_x, y - 1100.0, right_x - left_x, 1100.0)
	_layout["spawn_left"] = Vector2(left_x + 40.0, y - 40.0)
	_layout["spawn_right"] = Vector2(right_x - 40.0, y - 40.0)
	_layout["air_y"] = y - 420.0
	_layout["drop_y"] = y - 388.0 - 540.0 - 80.0


func _rise_lift() -> void:
	_show_message(tr("challenge.lift.rising"), LIFT_RISE_TIME)
	var target: float = maxf(_lift_top - LIFT_RISE_PER_FLOOR, LIFT_TOP_LIMIT)
	var tween := create_tween()
	tween.tween_method(_set_lift_top, _lift_top, target, LIFT_RISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## --- Kovalamaca ---------------------------------------------------------------------------

func _setup_chase() -> void:
	_swarm = ChaseSwarm.new()
	_swarm.name = "ChaseSwarm"
	_swarm.target = _player
	_swarm.floor_y = float(_layout["floor_y"])
	# Oyuncunun koşu hızı ~560 px/s; sürü biraz yavaş (zorlukla artar), açılırsa kauçuk bant yetiştirir
	# Gerilim: sürü oyuncunun arkasında bu mesafede kalmaya çalışır (zorluk 1: 480, 3: 400, 9: 160 px)
	_swarm.tension_gap = 520.0 - 40.0 * float(difficulty)
	_swarm.position = Vector2(-450.0, float(_layout["floor_y"]) - 100.0)
	_swarm.caught.connect(_on_swarm_caught)
	add_child(_swarm)
	_swarm.visible = false   # oyuncu koşmaya başlayana kadar görünmez (başta oyuncuyla yan yana beklemesin)
	_update_ward_label()


func _start_chase() -> void:
	_show_message(tr("challenge.chase.run"), 1.4)
	# Sürü, oyuncu sağa doğru koşmaya başlayınca ekranın solundan girer
	var start_x: float = _player.global_position.x
	while is_instance_valid(_player) and not _finished and _player.global_position.x < start_x + CHASE_TRIGGER_DISTANCE:
		await get_tree().physics_frame
	if _swarm != null and not _finished:
		_swarm.begin()


func _on_swarm_caught(count: int) -> void:
	_update_ward_label()
	if _finished or not is_instance_valid(_player):
		return
	# Hasar + sarsıntı + yavaşlama: yakalanan oyuncu havaya sekip hızını kaybeder
	_player.call("take_damage", 20.0, true, _swarm)
	var pv: Vector2 = _player.get("velocity")
	_player.set("velocity", Vector2(pv.x * 0.2, -260.0))
	if count >= CHASE_MAX_CATCHES:
		_finished = true
		_swarm.engulf()
		_show_message(tr("challenge.chase.caught"))
		# Başarısızlık = ölüm (normal ölüm akışı)
		_player.call("take_damage", 99999.0, true, _swarm)
		# Ölüm dizisi hurt state'inde zeminde bitmesini bekler; oyuncu alçak tavanın altında kayarken
		# yakalandıysa fırlama tamamlanamayıp ekranda takılı kalıyordu. Süre dolunca ölümü zorla bitir.
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(_player) and not bool(_player.get("is_dead")):
			_player.call("_finalize_player_death")


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_player) or _cam == null:
		return
	var length: float = float(_layout["length"])
	var want_x: float = clampf(_player.global_position.x + 160.0, 960.0, length - 960.0)
	_cam.position.x = lerpf(_cam.position.x, want_x, minf(1.0, 8.0 * delta))
	if _layout.has("fixed_cam_y"):
		# Labirent odası ekrana dikey olarak sığar: kamera yalnız yatayda kayar
		_cam.position.y = float(_layout["fixed_cam_y"])
	else:
		# Dikey: zemin seviyesi değişen koridorda kamera, oyuncunun en son bastığı zemini yumuşakça izler
		# (zıplayınca sallanmasın diye havadayken güncellenmez)
		if bool(_player.call("is_on_floor")):
			_chase_floor_y = _player.global_position.y
		_cam.position.y = lerpf(_cam.position.y, _chase_floor_y - ChaseCorridorBuilder.CAM_FLOOR_OFFSET, minf(1.0, 4.0 * delta))
	if _swarm != null:
		_swarm.floor_y = _chase_floor_y
	if not _finished and _player.global_position.x >= float(_layout["end_x"]) + 160.0:
		_finish(true)


func _physics_process(delta: float) -> void:
	if _swarm != null or kind == "tuzak":
		_update_chase(delta)
	if _timer_running and not _finished:
		_tick_trap_timer(delta)
	# Dalga sürerken zemin yavaşça yükselmeye devam eder (hız zorlukla artar)
	if _lift != null and _lift_creeping and not _finished:
		_set_lift_top(maxf(_lift_top - (8.0 + 2.0 * float(difficulty)) * delta, LIFT_TOP_LIMIT))
	if _lift != null:
		_carry_corpses()


## Ölünce çarpışması kapanan bazı düşmanların (örn. mızrakçı) cesedi dünyada sabit kalıyor; asansör
## yükselince cesetler altta kalıp aşağı sızıyordu. Asansör yüzeyine yakın ölenlerin cesedi yüzeyle birlikte taşınır.
func _carry_corpses() -> void:
	for e in _enemy_container.get_children():
		if not (e is Node2D) or e.get("current_behavior") != "dead":
			continue
		if not e.has_meta("_lift_off"):
			var off: float = (e as Node2D).global_position.y - _lift_top
			e.set_meta("_lift_off", off if absf(off) < 80.0 else INF)
		var stored: float = float(e.get_meta("_lift_off"))
		if stored != INF:
			(e as Node2D).global_position.y = _lift_top + stored


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
	# Payload "wards" verilirse o sayı (1-5), yoksa zorluğa göre
	_ward_total = clampi(_ward_override if _ward_override > 0 else WARDS_BASE + difficulty / 4, 1, 5)
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
	var wave_count: int = ChallengeWaveSpawner.waves_for_wards(_ward_total) if kind == "koruma" else ChallengeWaveSpawner.waves_for_difficulty(difficulty)
	_spawner.configure(_layout, _enemy_container, difficulty, wave_count)
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
	_ward_label.visible = kind == "koruma" or kind == "kovalamaca" or kind == "tuzak"
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
	if kind == "tuzak":
		_ward_label.text = tr("challenge.trap.time") % maxi(0, int(ceil(_time_left)))
		return
	if kind == "kovalamaca":
		_ward_label.text = tr("challenge.chase.catches") % [_swarm.catch_count if _swarm else 0, CHASE_MAX_CATCHES]
		return
	var alive: int = 0
	for w in _wards:
		if is_instance_valid(w) and not w.is_dead:
			alive += 1
	_ward_label.text = tr("challenge.wards") % [alive, _ward_total]


# --- Tuzak Geçidi ---------------------------------------------------------------------------

## Tuzakları dizer, temanın zindan kurallarını (kaygan zemin, yıldırım, karanlık) uygular, süreyi hesaplar.
func _setup_trap_run() -> void:
	var count: int = TrapMazeBuilder.populate(self, _layout, _theme, difficulty)
	print("[TuzakGecidi] tema=%s zorluk=%d tuzak=%d" % [_theme, difficulty, count])
	_apply_theme_rules()
	# Süre: labirent uzunluğuna göre; tuzağa çarpmak süreden düşer (kısa ama sık tuzaklı bir yol)
	_time_left = 30.0 + 0.3 * float(_layout["cols"])
	if _player.has_signal("player_took_damage"):
		_player.connect("player_took_damage", _on_trap_hit)
	_update_ward_label()


## Zindan temasının oyuncuya etkileyen kuralları (level_generator'daki gerçek zindanla aynı ayarlar).
func _apply_theme_rules() -> void:
	_player.set("ground_traction", DungeonThemeStyle.get_ground_traction(_theme))
	var idle_strike: Dictionary = DungeonThemeStyle.get_idle_strike(_theme)
	if not idle_strike.is_empty():
		var watcher := StormWatcher.new()
		watcher.name = "StormWatcher"
		add_child(watcher)
		watcher.setup(idle_strike, difficulty)
	var lighting: Dictionary = DungeonThemeStyle.get_lighting(_theme)
	if not lighting.is_empty():
		var ambient := CanvasModulate.new()
		ambient.name = "ThemeAmbient"
		ambient.color = lighting.get("ambient", Color(0.1, 0.09, 0.16))
		add_child(ambient)
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 1)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		var light := PointLight2D.new()
		light.name = "ThemeLantern"
		light.texture = tex
		light.texture_scale = float(lighting.get("player_light_radius", 220.0)) * 2.0 / 256.0
		light.energy = float(lighting.get("player_light_energy", 0.9))
		light.color = lighting.get("player_light_color", Color(1.0, 0.92, 0.8))
		light.position = Vector2(0.0, -40.0)
		_player.add_child(light)


func _start_trap_run() -> void:
	await _show_message(tr("challenge.trap.go"), 1.2)
	_timer_running = true


func _tick_trap_timer(delta: float) -> void:
	_time_left -= delta
	_update_ward_label()
	if _time_left <= 0.0:
		_on_time_up()


func _on_trap_hit(_amount: float, _attacker: Node2D) -> void:
	if _finished:
		return
	_time_left -= TRAP_HIT_TIME_PENALTY
	_show_message(tr("challenge.trap.penalty") % int(TRAP_HIT_TIME_PENALTY), 1.0)


## Süre bitti: başarısızlık = ölüm (kovalamacadaki gibi; ölüm takılırsa süre sonunda zorla bitirilir).
func _on_time_up() -> void:
	if _finished:
		return
	_finished = true
	_timer_running = false
	_show_message(tr("challenge.trap.timeup"))
	if is_instance_valid(_player):
		_player.call("take_damage", 99999.0, true, null)
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(_player) and not bool(_player.get("is_dead")):
			_player.call("_finalize_player_death")


## Ödül: altın (zorlukla artar) ve kalan süreye göre bonus; hammadde de eklenir.
func _grant_trap_reward() -> String:
	var gold: int = 30 + 25 * difficulty + int(maxf(_time_left, 0.0))
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if is_instance_valid(gpd) and gpd.has_method("add_gold"):
		gpd.call("add_gold", gold)
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if is_instance_valid(ps) and ps.has_method("add_carried_resource"):
		var carried: Variant = ps.get("carried_resources")
		for res_type in ["stone", "wood"]:
			if carried is Dictionary and (carried as Dictionary).has(res_type):
				ps.call("add_carried_resource", res_type, 2 + difficulty)
	return tr("challenge.win.tuzak") % gold

# --- Akış ---------------------------------------------------------------------------------

func _begin_sequence() -> void:
	_wave_label.text = tr(String(ChallengeRoomRegistry.KINDS[kind]))
	await get_tree().create_timer(0.6).timeout
	# Build kurma: oyuncunun açtığı item'lardan START_PICKS kez kart seçimi
	var im: Node = get_node_or_null("/root/ItemManager")
	# Kovalamaca'da başlangıç build seçimi yok (koşuyu item'larla değil hareketle kazanırsın)
	if kind != "kovalamaca" and kind != "tuzak" and is_instance_valid(im) and im.has_method("queue_item_selections"):
		_show_message(tr("challenge.pick") % START_PICKS)
		im.call("queue_item_selections", START_PICKS)
		await im.item_selection_sequence_finished
	if kind == "kovalamaca":
		_start_chase()
		return
	if kind == "tuzak":
		_start_trap_run()
		return
	await _show_message(tr("challenge.ready"), 1.6)
	_spawner.start_next_wave()


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = tr("challenge.wave") % [index, total]
	_lift_creeping = _lift != null


func _on_wave_cleared(index: int, total: int) -> void:
	_lift_creeping = false
	if _finished or index >= total:
		return
	if kind == "asansor":
		await _show_message(tr("challenge.cleared") % index, BREAK_SECONDS)
		if _finished:
			return
		await _rise_lift()
		if not _finished:
			_spawner.start_next_wave()
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
	_timer_running = false
	if _spawner != null:
		_spawner.set_physics_process(false)
	if _swarm != null:
		if won:
			_swarm.fly_off()
		else:
			_swarm.running = false
	var reward_text: String = ""
	if won:
		if _swarm != null:
			# Kuşların çıkışını izlemek için ödül ekranından önce bekle
			await get_tree().create_timer(2.6).timeout
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
				# Kurtarılan köylü, korunan köylünün kendi görünümü ve adıyla köye gelir
				if is_instance_valid(drs) and drs.has_method("add_pending_villager_data"):
					drs.call("add_pending_villager_data", w.rescue_data())
		return tr("challenge.win.koruma") % survivors
	if kind == "asansor":
		return _grant_random_item_unlock()
	if kind == "tuzak":
		return _grant_trap_reward()
	if kind == "kovalamaca":
		# Sona ulaşmak 1 unlock teklifi; hiç yakalanmadan ulaşmak 2 teklif
		var flawless: bool = _swarm != null and _swarm.catch_count == 0
		var cim: Node = get_node_or_null("/root/ItemManager")
		if is_instance_valid(cim) and cim.has_method("queue_unlock_offer"):
			var cthemes: Array = cim.DUNGEON_THEME_POOLS.keys()
			cim.call("queue_unlock_offer", String(cthemes[randi() % cthemes.size()]), "kesif", 2 if flawless else 1)
			if cim.has_method("resolve_pending_unlock_offers"):
				await cim.call("resolve_pending_unlock_offers")
		return tr("challenge.win.kovalamaca.flawless" if flawless else "challenge.win.kovalamaca")
	# Dalga arenası: koleksiyona yeni item (rastgele temanın keşif havuzundan seçim kartı)
	var im: Node = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("queue_unlock_offer"):
		var themes: Array = im.DUNGEON_THEME_POOLS.keys()
		var theme: String = String(themes[randi() % themes.size()])
		im.call("queue_unlock_offer", theme, "kesif", 1)
		if im.has_method("resolve_pending_unlock_offers"):
			await im.call("resolve_pending_unlock_offers")
	return tr("challenge.win.dalga")


## Asansör ödülü: rastgele bir temadan, henüz açılmamış rastgele bir item doğrudan koleksiyona eklenir.
func _grant_random_item_unlock() -> String:
	var im: Node = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("get_unlock_candidates"):
		var pool: Array[String] = []
		for theme in im.DUNGEON_THEME_POOLS.keys():
			for tier in [im.UNLOCK_TIER_KESIF, im.UNLOCK_TIER_BOSS]:
				pool.append_array(im.call("get_unlock_candidates", String(theme), String(tier)))
		pool.shuffle()
		for id in pool:
			if bool(im.call("unlock_item", id)):
				return tr("challenge.win.asansor") % tr("item.%s.name" % id)
	return tr("challenge.win.dalga")


func _leave_to_world_map(won: bool) -> void:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if is_instance_valid(sm) and sm.has_method("change_to_world_map"):
		sm.call("change_to_world_map", {
			"source": "dungeon",
			"return_reason": "challenge_complete" if won else "challenge_failed",
		})
