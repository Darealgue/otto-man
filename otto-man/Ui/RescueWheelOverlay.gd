class_name RescueWheelOverlay
extends CanvasLayer

## Erken çıkış çarkıfeleği: kurtarılan her kişi için sırayla küçük bir çark döner. Dilimler şansa göre
## boyutlanır (yeşil: seninle çıkar, kırmızı: geride kalır). Sonuç DungeonRunState.roll_early_exit_rescued
## ile ÖNCEDEN çekilmiştir; çark yalnız o sonuca iner, yani görsel ve mantık hep tutarlıdır.
## Kullanım: await RescueWheelOverlay.show_for(self, results, chance)

signal done

const WORKER_SCENE := "res://village/scenes/Worker.tscn"
const CONCUBINE_SCENE := "res://village/scenes/Concubine.tscn"
const COL_GOOD := Color(0.34, 0.68, 0.38)
const COL_BAD := Color(0.72, 0.27, 0.27)
const COL_PENDING := Color(0.45, 0.45, 0.5)
const SPIN_TIME := 2.0
const FAST_SPEED := 6.0

var _results: Array = []
var _chance: float = 0.6
var _fast: bool = false
var _spin_tween: Tween = null
var _finished_input: bool = false

var _wheel = null  # _WheelControl
var _portrait_holder: SubViewportContainer = null
var _portrait_vp: SubViewport = null
var _name_label: Label = null
var _result_label: Label = null
var _chips: HBoxContainer = null
var _chip_rects: Array[ColorRect] = []
var _summary_label: Label = null
var _skip_label: Label = null


static func show_for(host: Node, results: Array, chance: float) -> void:
	if results.is_empty():
		return
	var overlay := RescueWheelOverlay.new()
	overlay._results = results
	overlay._chance = chance
	host.get_tree().root.add_child(overlay)
	await overlay.done


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_run()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_fast = true
	_finished_input = true
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.set_speed_scale(FAST_SPEED)


# --- Arayüz ------------------------------------------------------------------------------------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var title := _make_label(tr("camp.wheel.title"), 46, Color(1.0, 0.86, 0.45))
	root.add_child(title)
	root.add_child(_make_label(tr("camp.wheel.sub"), 24, Color(0.85, 0.85, 0.85)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	root.add_child(row)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(176, 176)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.2, 0.17, 0.14, 1.0)
	frame_style.set_border_width_all(3)
	frame_style.border_color = Color(0.85, 0.7, 0.35)
	frame.add_theme_stylebox_override("panel", frame_style)
	left.add_child(frame)
	_portrait_holder = SubViewportContainer.new()
	_portrait_holder.stretch = true
	_portrait_holder.custom_minimum_size = Vector2(160, 160)
	_portrait_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(_portrait_holder)
	_name_label = _make_label("", 26, Color.WHITE)
	_name_label.custom_minimum_size = Vector2(220, 0)
	left.add_child(_name_label)

	var wheel_box := Control.new()
	wheel_box.custom_minimum_size = Vector2(300, 300)
	row.add_child(wheel_box)
	_wheel = _WheelControl.new()
	_wheel.chance = _chance
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel_box.add_child(_wheel)

	_result_label = _make_label("", 36, Color.WHITE)
	_result_label.custom_minimum_size = Vector2(0, 50)
	root.add_child(_result_label)

	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 8)
	root.add_child(_chips)
	for i in _results.size():
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(22, 22)
		chip.color = COL_PENDING
		_chips.add_child(chip)
		_chip_rects.append(chip)

	_summary_label = _make_label("", 30, Color(1.0, 0.86, 0.45))
	root.add_child(_summary_label)
	_skip_label = _make_label(tr("camp.wheel.skip"), 18, Color(0.7, 0.7, 0.7))
	root.add_child(_skip_label)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


# --- Akış ----------------------------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / (FAST_SPEED if _fast else 1.0), true).timeout


func _run() -> void:
	await get_tree().process_frame
	var survivors: int = 0
	for i in _results.size():
		var r: Dictionary = _results[i]
		_show_person(r)
		_result_label.text = ""
		_wheel.set("rot", 0.0)
		await _wait(0.45)
		var ok: bool = bool(r["survived"])
		# Hedef dilimin içinde rastgele bir nokta (kenarlara yakın değil)
		var slice_start: float = 0.0 if ok else _chance * TAU
		var slice_len: float = _chance * TAU if ok else (1.0 - _chance) * TAU
		var a: float = slice_start + slice_len * randf_range(0.18, 0.82)
		var final_rot: float = TAU * 4.0 - a
		_spin_tween = create_tween()
		_spin_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_spin_tween.tween_property(_wheel, "rot", final_rot, SPIN_TIME)
		if _fast:
			_spin_tween.set_speed_scale(FAST_SPEED)
		await _spin_tween.finished
		await _wait(0.2)
		if ok:
			survivors += 1
		_result_label.text = tr("camp.wheel.survive" if ok else "camp.wheel.lost")
		_result_label.add_theme_color_override("font_color", COL_GOOD if ok else COL_BAD)
		_chip_rects[i].color = COL_GOOD if ok else COL_BAD
		await _wait(0.9)
	_result_label.text = ""
	_summary_label.text = tr("camp.wheel.summary") % survivors if survivors > 0 else tr("camp.wheel.summary_none")
	_skip_label.text = ""
	_finished_input = false
	var waited: float = 0.0
	while not _finished_input and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	queue_free()
	done.emit()


func _show_person(r: Dictionary) -> void:
	var data: Dictionary = r.get("data", {})
	var is_cariye: bool = String(r.get("kind", "")) == "cariye"
	var nm: String = String(data.get("isim", "")) if is_cariye else String(data.get("name", ""))
	if nm.strip_edges().is_empty():
		nm = tr("camp.wheel.cariye" if is_cariye else "camp.wheel.villager")
	_name_label.text = nm
	_rebuild_portrait(data, is_cariye)


## Vesikalık: gerçek Worker/Concubine sahnesi küçük bir SubViewport'ta, kamera baş-omuz bölgesine yakın.
func _rebuild_portrait(data: Dictionary, is_cariye: bool) -> void:
	if _portrait_vp != null and is_instance_valid(_portrait_vp):
		_portrait_vp.queue_free()
	_portrait_vp = SubViewport.new()
	_portrait_vp.size = Vector2i(160, 160)
	_portrait_vp.transparent_bg = true
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_portrait_holder.add_child(_portrait_vp)

	var scene := load(CONCUBINE_SCENE if is_cariye else WORKER_SCENE) as PackedScene
	if scene == null:
		return
	var n := scene.instantiate() as Node2D
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
		n.set("display_name", "")
	else:
		n.set("worker_id", -1)
		n.set("NPC_Info", {"Info": {"Name": ""}, "Latest_news": []})
	_portrait_vp.add_child(n)
	n.set_physics_process(false)
	n.set_process(false)
	var plate: Variant = n.get("name_plate_container" if is_cariye else "_nameplate_container")
	if plate is Control:
		(plate as Control).visible = false
	if n.has_method("play_animation"):
		n.call("play_animation", "idle")
	var cam := Camera2D.new()
	cam.position = Vector2(0, -33)
	cam.zoom = Vector2(4.4, 4.4)
	_portrait_vp.add_child(cam)
	cam.make_current()


# --- Çark çizimi -----------------------------------------------------------------------------

class _WheelControl extends Control:
	var chance: float = 0.6
	var rot: float = 0.0:
		set(v):
			rot = v
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.46
		_slice(c, r, 0.0, chance * TAU, Color(0.34, 0.68, 0.38))
		_slice(c, r, chance * TAU, TAU, Color(0.72, 0.27, 0.27))
		draw_arc(c, r, 0.0, TAU, 96, Color(0.1, 0.07, 0.04), 6.0, true)
		draw_arc(c, r + 5.0, 0.0, TAU, 96, Color(0.85, 0.7, 0.35), 3.0, true)
		draw_circle(c, r * 0.14, Color(0.85, 0.7, 0.35))
		draw_circle(c, r * 0.08, Color(0.2, 0.14, 0.08))
		# İbre (sabit, üstte)
		var tip := c + Vector2(0.0, -r + 18.0)
		var pts := PackedVector2Array([tip, tip + Vector2(-16.0, -34.0), tip + Vector2(16.0, -34.0)])
		draw_colored_polygon(pts, Color(0.95, 0.9, 0.8))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.1, 0.07, 0.04), 3.0)

	## Yerel açı a0..a1 (yukarıdan saat yönünde) aralığını döndürülmüş çarkta doldurur
	func _slice(c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
		var steps: int = maxi(4, int(ceilf((a1 - a0) / TAU * 96.0)))
		var pts := PackedVector2Array([c])
		for i in steps + 1:
			var ang: float = -PI * 0.5 + rot + a0 + (a1 - a0) * float(i) / float(steps)
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(pts, col)
		# Dilim ayırıcı çizgiler
		var s: float = -PI * 0.5 + rot + a0
		draw_line(c, c + Vector2(cos(s), sin(s)) * r, Color(0.1, 0.07, 0.04), 3.0)
