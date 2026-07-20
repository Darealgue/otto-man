class_name DungeonRunReport
extends CanvasLayer
## Zindan run'ı bittiğinde (ölüm veya çıkış) gösterilen retro "bölüm sonu" raporu.
## Klasik arcade oyunlarındaki gibi istatistikler satır satır, sayarak açılır:
## süre, geçilen bölüm, öldürülen düşman, toplanan/teslim edilen altın, kurtarılanlar.
## Sahne dosyası yok — tamamen kod ile kurulur (CampScene._setup_run_stats_ui ile aynı yaklaşım).

const ROW_REVEAL_DELAY := 0.32
const COUNT_UP_TIME := 0.45
const ICON_SIZE := Vector2(28, 28)

const COLOR_GOOD := Color(0.5, 0.95, 0.55)
const COLOR_BAD := Color(1.0, 0.5, 0.5)
const COLOR_NEUTRAL := Color(0.92, 0.9, 0.85)
const COLOR_GOLD := Color(1.0, 0.82, 0.35)
const COLOR_TEXT := Color(0.88, 0.86, 0.8)
const COLOR_TEXT_MUTED := Color(0.62, 0.6, 0.56)

var _dim: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _rows_container: VBoxContainer
var _continue_label: Label
var _rows: Array[Control] = []
var _confirmed: bool = false
var _all_revealed: bool = false
var _skip_requested: bool = false


## Tek giriş noktası: raporu oluşturur, ekranı karartıp gösterir, oyuncu onaylayana kadar
## bekler, sonra kendini temizler. Çağıran taraf sadece await eder.
static func run(tree: SceneTree, data: Dictionary) -> void:
	if tree == null:
		return
	var report := DungeonRunReport.new()
	tree.root.add_child(report)
	tree.paused = true
	await report._present(data)
	tree.paused = false
	if is_instance_valid(report):
		report.queue_free()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 250


func _present(data: Dictionary) -> void:
	_build_ui(data)
	await get_tree().process_frame
	await _play_entrance()
	await _reveal_rows()
	_all_revealed = true
	_continue_label.visible = true
	_blink_continue_label()
	while not _confirmed:
		await get_tree().process_frame
	await _play_exit()


func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if not _all_revealed:
		_skip_requested = true
	else:
		_confirmed = true


## ---------------- UI kurulumu ----------------

func _build_ui(data: Dictionary) -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	center.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	content.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_subtitle_label)

	content.add_child(HSeparator.new())

	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 8)
	content.add_child(_rows_container)

	content.add_child(HSeparator.new())

	_continue_label = Label.new()
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_label.add_theme_font_size_override("font_size", 14)
	_continue_label.text = "Devam etmek için onayla"
	_continue_label.visible = false
	content.add_child(_continue_label)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.96)
	sb.border_color = Color(0.4, 0.38, 0.34, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)

	_set_title(data)
	TextOutline.apply_font_to_control(_subtitle_label)
	TextOutline.apply_label_color(_subtitle_label, COLOR_TEXT_MUTED)
	TextOutline.apply_font_to_control(_continue_label)
	TextOutline.apply_label_color(_continue_label, COLOR_TEXT_MUTED)

	_populate_rows(data)


func _set_title(data: Dictionary) -> void:
	var info: Dictionary = _resolve_title(data)
	_title_label.text = String(info.get("text", ""))
	TextOutline.apply_font_to_control(_title_label)
	TextOutline.apply_label_color(_title_label, info.get("color", COLOR_NEUTRAL))
	_subtitle_label.text = String(info.get("sub", ""))


func _resolve_title(data: Dictionary) -> Dictionary:
	var is_dead: bool = bool(data.get("is_dead", false))
	var return_reason: String = String(data.get("return_reason", ""))
	var is_complete: bool = bool(data.get("is_run_complete", false))
	if is_dead:
		return {"text": "ÖLDÜN", "sub": "Zindanda düştün — toplanan ganimet kayboldu.", "color": COLOR_BAD}
	match return_reason:
		"boss_defeated":
			return {"text": "ZAFER!", "sub": "Boss yenildi, zindandan sağ çıktın.", "color": COLOR_GOOD}
		"stealth_exit":
			return {"text": "GİZLİCE KAÇTIN", "sub": "Fark edilmeden zindandan sıvıştın.", "color": Color(0.25, 0.4, 0.55)}
		_:
			if is_complete:
				return {"text": "KEŞİF TAMAMLANDI", "sub": "Zindandan sağ çıktın.", "color": COLOR_GOOD}
			return {"text": "ERKEN ÇIKIŞ", "sub": "Zindanı bitirmeden ayrıldın.", "color": Color(0.55, 0.4, 0.1)}


## ---------------- İstatistik satırları ----------------

func _populate_rows(data: Dictionary) -> void:
	_rows.clear()

	var elapsed: float = float(data.get("elapsed_seconds", 0.0))
	_rows.append(_make_row("", "Süre", _format_time(elapsed), COLOR_NEUTRAL))

	var segs_done: int = int(data.get("segments_completed", 0))
	var segs_target: int = int(data.get("segments_target", 0))
	var seg_value: String = "%d / %d" % [segs_done, segs_target]
	if bool(data.get("is_warmup", false)):
		seg_value += "  (alıştırma)"
	_rows.append(_make_row("", "Geçilen Bölüm", seg_value, COLOR_NEUTRAL))

	_rows.append(_make_count_up_row("", "Öldürülen Düşman", int(data.get("enemies_killed", 0)), COLOR_NEUTRAL))

	var gold_held: int = int(data.get("gold_held_at_end", 0))
	_rows.append(_make_count_up_row("res://assets/Icons/gold_icon.png", "Toplanan Altın", gold_held, COLOR_GOLD))
	var gold_lost: int = int(data.get("gold_lost_final", 0))
	if gold_lost > 0:
		_rows.append(_make_row("", "    zindanda kaybedilen", "-%d" % gold_lost, COLOR_BAD))
	var gold_delivered: int = int(data.get("gold_delivered", 0))
	if not bool(data.get("is_dead", false)) and gold_delivered != gold_held:
		_rows.append(_make_row("", "    kasaya teslim edilen", "%d" % gold_delivered, COLOR_GOOD))

	var rescued_total: int = int(data.get("rescued_total", 0))
	var rescued_lost: int = int(data.get("rescued_lost", 0))
	var rescued_color: Color = COLOR_GOOD if rescued_total > 0 else COLOR_NEUTRAL
	_rows.append(_make_count_up_row("res://assets/Icons/rescue_icon.png", "Kurtarılan", rescued_total, rescued_color))
	if rescued_lost > 0:
		_rows.append(_make_row("", "    zindanda kaldı", "-%d" % rescued_lost, COLOR_BAD))
	var fragile_lost: int = int(data.get("fragile_rescue_lost_total", 0))
	if fragile_lost > 0:
		_rows.append(_make_row("", "    kaçarken kaybedilen esir", "-%d" % fragile_lost, COLOR_BAD))

	for row in _rows:
		_rows_container.add_child(row)
		row.modulate.a = 0.0
		row.scale = Vector2(0.9, 0.9)


func _make_row(icon_path: String, label_text: String, value_text: String, value_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(icon_path)
		row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TextOutline.apply_font_to_control(name_lbl)
	TextOutline.apply_label_color(name_lbl, COLOR_TEXT)
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = value_text
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	TextOutline.apply_font_to_control(value_lbl)
	TextOutline.apply_label_color(value_lbl, value_color)
	row.add_child(value_lbl)

	row.set_meta("value_label", value_lbl)
	return row


func _make_count_up_row(icon_path: String, label_text: String, target_value: int, value_color: Color) -> HBoxContainer:
	var row := _make_row(icon_path, label_text, "0", value_color)
	row.set_meta("count_up_target", target_value)
	return row


## ---------------- Reveal / animasyon ----------------

func _reveal_rows() -> void:
	for row in _rows:
		if not is_instance_valid(self):
			return
		if _skip_requested:
			_finalize_row_instant(row)
			continue
		_reveal_one_row(row)
		var sm := get_node_or_null("/root/SoundManager")
		if is_instance_valid(sm) and sm.has_method("play_ui"):
			sm.call("play_ui", "click")
		await get_tree().create_timer(ROW_REVEAL_DELAY).timeout


func _reveal_one_row(row: Control) -> void:
	row.pivot_offset = row.size * 0.5
	var tw := row.create_tween()
	tw.set_parallel(true)
	tw.tween_property(row, "modulate:a", 1.0, 0.2)
	tw.tween_property(row, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if row.has_meta("count_up_target"):
		var target: int = int(row.get_meta("count_up_target"))
		var value_lbl: Label = row.get_meta("value_label")
		tw.tween_method(_update_count_label.bind(value_lbl), 0.0, float(target), COUNT_UP_TIME)


func _finalize_row_instant(row: Control) -> void:
	row.modulate.a = 1.0
	row.scale = Vector2.ONE
	if row.has_meta("count_up_target") and row.has_meta("value_label"):
		var lbl: Label = row.get_meta("value_label")
		_update_count_label(float(row.get_meta("count_up_target")), lbl)


func _update_count_label(value: float, label: Label) -> void:
	if is_instance_valid(label):
		label.text = str(int(round(value)))


func _blink_continue_label() -> void:
	var tw := _continue_label.create_tween()
	tw.set_loops()
	tw.tween_property(_continue_label, "modulate:a", 0.35, 0.55)
	tw.tween_property(_continue_label, "modulate:a", 1.0, 0.55)


func _play_entrance() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	var tw_dim := _dim.create_tween()
	tw_dim.tween_property(_dim, "color:a", 0.82, 0.25)
	var tw := _panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _play_exit() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if is_instance_valid(sm) and sm.has_method("play_ui"):
		sm.call("play_ui", "confirm")
	var tw := _panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tw_dim := _dim.create_tween()
	tw_dim.tween_property(_dim, "color:a", 0.0, 0.2)
	await tw.finished


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(round(seconds)))
	var m: int = total / 60
	var s: int = total % 60
	return "%d:%02d" % [m, s]
