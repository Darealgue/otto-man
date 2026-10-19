extends Node2D

## Ara sıra dolu (tam açık) bir pencerede köylü belirip dışarı bakar. Yeni karakter çizimi gerekmez: gerçek köylü gövdesi
## (Worker, bekleme karesi) pencere kemerinin şekline kırpılarak pencerenin içine yerleştirilir; yumuşakça belirir ve kaybolur.
## Pencere süslerinin (saksı, perde) ARKASINDA durur, pencere ışığının ÖNÜNDEDİR (geceleri ışık önünde silüet gibi görünür).

const WORKER_SCENE: String = "res://village/scenes/Worker.tscn"
const CLIP_SHADER_PATH: String = "res://shaders/window_watcher_clip.gdshader"

const CHECK_MIN: float = 12.0
const CHECK_MAX: float = 30.0
const SPAWN_CHANCE: float = 0.55
const MAX_WATCHERS: int = 2
const DAY_START_HOUR: float = 7.0
const DAY_END_HOUR: float = 21.5
const MAX_RAIN: float = 0.35
const STAY_MIN: float = 12.0
const STAY_MAX: float = 32.0
const FADE_SECONDS: float = 0.9
const VIEW_MARGIN: float = 250.0                 # kamera görüş alanının bu kadar çevresindeki pencereler seçilir (oyuncu görsün)
const FIGURE_HEIGHT: float = 50.0                # Worker figürünün çizilen yüksekliği (sprite karesi 96 px ama figür ~50 px; ayaklar orijinde)
const FIGURE_TOP_IN_ARCH: float = 19.0           # figürün tepesi kemerin üstünden bu kadar aşağıda (pencere yerel y); oyunda 15 px aşağı alındı
const ARCH_CENTER_X: float = 41.0                # açık pencere dokusunda kemerin yatay merkezi (genişlik 85'te)
const ARCH_X_JITTER: float = 12.0                # köylünün kemer ortasından sağa/sola en fazla kayma miktarı (piksel)

var _timer: float = 6.0
var _watchers: int = 0
var _shader: Shader = null

func _ready() -> void:
	name = "WindowWatcherDirector"
	_timer = randf_range(8.0, 18.0)
	_shader = load(CLIP_SHADER_PATH) as Shader
	if _shader == null:
		set_process(false)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(CHECK_MIN, CHECK_MAX)
	if _watchers >= MAX_WATCHERS or randf() >= SPAWN_CHANCE:
		return
	var tm := get_node_or_null("/root/TimeManager")
	var hour: float = float(tm.get_continuous_hour_float()) if tm != null and tm.has_method("get_continuous_hour_float") else 12.0
	if hour < DAY_START_HOUR or hour >= DAY_END_HOUR:
		return
	var weather := get_node_or_null("/root/WeatherManager")
	if weather != null and "rain_intensity" in weather and float(weather.rain_intensity) >= MAX_RAIN:
		return
	var entry: Dictionary = _pick_window()
	if not entry.is_empty():
		_watch(entry["window"], entry["floor"])

func _view_range() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Vector2(-INF, INF)
	var half: float = get_viewport().get_visible_rect().size.x / maxf(cam.zoom.x, 0.01) * 0.5 + VIEW_MARGIN
	var cx: float = cam.get_screen_center_position().x
	return Vector2(cx - half, cx + half)

func _pick_window() -> Dictionary:
	var view: Vector2 = _view_range()
	var options: Array = []
	for f in get_tree().get_nodes_in_group(&"house_floor_visual"):
		if not is_instance_valid(f) or not (f as Node2D).is_visible_in_tree():
			continue
		for entry in f.get_open_windows():
			var w: Sprite2D = entry["window"]
			if bool(entry["wide_decor"]) or w.has_node("Watcher"):
				continue
			if w.global_position.x < view.x or w.global_position.x > view.y:
				continue
			options.append(entry)
	return options[randi() % options.size()] if not options.is_empty() else {}

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

func _apply_parent_material(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasItem:
			(c as CanvasItem).use_parent_material = true
		_apply_parent_material(c)

func _watch(win: Sprite2D, floor_node: Node) -> void:
	var mask: Texture2D = floor_node.get_window_arch_mask(win)
	if mask == null:
		return
	var body: Node2D = _build_body()
	if body == null:
		return
	_watchers += 1
	var holder := Node2D.new()
	holder.name = "Watcher"
	win.add_child(holder)
	# Işık sprite'ının (index 0) üstünde, süslerin altında kalsın.
	win.move_child(holder, mini(1, win.get_child_count() - 1))
	holder.add_child(body)
	body.z_index = 0  # tutsak kipi z'yi 4'e sabitliyor: süslerin önüne geçmesin, sıra ağaç sırasıyla (ışık < köylü < süs) kalsın
	body.set_physics_process(false)
	body.set_process(false)
	var plate: Variant = body.get("_nameplate_container")
	if plate is CanvasItem:
		(plate as CanvasItem).visible = false
	# Pencere yerel koordinatı: kutu sol kenarı = offset.x (ayna çevrikte -genişlik); figür kemerin yatay ortasında,
	# ayaklar kemerin altında kalacak şekilde (tepe kemerin hemen altından başlar).
	var box_left: float = win.offset.x
	# Her seferinde kemerin ortasında değil, biraz solunda ya da sağında durur (yanlarda da görünsün).
	var jitter: float = randf_range(-ARCH_X_JITTER, ARCH_X_JITTER)
	var center_x: float = (float(mask.get_width()) - ARCH_CENTER_X - jitter) if win.flip_h else (ARCH_CENTER_X + jitter)
	var local_feet: Vector2 = Vector2(box_left + center_x, FIGURE_TOP_IN_ARCH + FIGURE_HEIGHT)
	body.position = local_feet
	body.scale.x = 1.0 if randf() < 0.5 else -1.0
	if body.has_method("play_animation"):
		body.call("play_animation", "idle")
		for part in ["BodySprite", "PantsSprite", "ClothingSprite", "MouthSprite", "EyesSprite", "BeardSprite", "HairSprite", "HatSprite"]:
			var spr: Sprite2D = body.get_node_or_null(part) as Sprite2D
			if spr != null:
				spr.frame = VillagerShowActor.IDLE_FRAME
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("mask", mask)
	mat.set_shader_parameter("mask_origin", win.global_position + Vector2(win.offset.x, 0.0))
	mat.set_shader_parameter("mask_size", Vector2(mask.get_width(), mask.get_height()))
	mat.set_shader_parameter("mask_flip_h", win.flip_h)
	mat.set_shader_parameter("fade", 0.0)
	body.material = mat
	_apply_parent_material(body)
	await _run_watch(win, holder, body, mat)
	if is_instance_valid(holder):
		holder.queue_free()
	_watchers -= 1

func _run_watch(win: Sprite2D, holder: Node2D, body: Node2D, mat: ShaderMaterial) -> void:
	if not await _fade(mat, 0.0, 1.0, holder):
		return
	var stay: float = randf_range(STAY_MIN, STAY_MAX)
	var base_y: float = body.position.y
	var turn_in: float = randf_range(3.0, 7.0)
	var t: float = 0.0
	while t < stay and _still_open(win, holder):
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if not is_instance_valid(body):
			return
		# Hafif yukarı aşağı (nefes) ve ara sıra başını çevirme (sağa/sola bakış).
		body.position.y = base_y + (1.0 if int(t * 1.6) % 2 == 0 else 0.0)
		turn_in -= 0.25
		if turn_in <= 0.0:
			body.scale.x = -body.scale.x
			turn_in = randf_range(3.0, 7.0)
	if is_instance_valid(holder):
		await _fade(mat, 1.0, 0.0, holder)

func _still_open(win: Sprite2D, holder: Node2D) -> bool:
	# Pencere kapandıysa / yarı açıldıysa (doku genişliği 85 değil) ya da bina yok olduysa bırak.
	return is_instance_valid(win) and is_instance_valid(holder) and win.is_visible_in_tree() \
			and win.texture != null and win.texture.get_width() == 85

func _fade(mat: ShaderMaterial, from_v: float, to_v: float, holder: Node2D) -> bool:
	var t: float = 0.0
	while t < FADE_SECONDS:
		if not is_instance_valid(holder) or not is_instance_valid(mat):
			return false
		mat.set_shader_parameter("fade", lerpf(from_v, to_v, t / FADE_SECONDS))
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(mat):
		mat.set_shader_parameter("fade", to_v)
	return is_instance_valid(holder)
