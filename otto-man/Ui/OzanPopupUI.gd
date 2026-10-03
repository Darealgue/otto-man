extends Control
class_name OzanPopupUI
## Gezgin ozan — köy deposundan yemek karşılığı bir türkü söyler; türkü, henüz keşfedilmemiş bir
## zindanın yerini bulanık anlatır (yön + uzaklık + temanın sözleri; bkz. village/scripts/OzanSongs.gd).
## Falcı penceresiyle aynı parşömen iskeleti; oyunu durdurmaz.

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const FOOD_ICON_PATH := "res://assets/Icons/bread_icon.png"

var _panel: PanelContainer
var _food_label: Label
var _song_label: Label
var _sing_button: Button
var _info_label: Label
var _is_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	_build_ui()
	visible = false
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -300
	_panel.offset_top = -230
	_panel.offset_right = 300
	_panel.offset_bottom = 230
	ParchmentTextures.apply_large_panel_style(_panel, 20)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.text = tr("ozan.title")
	root.add_child(title)

	var food_row := HBoxContainer.new()
	food_row.alignment = BoxContainer.ALIGNMENT_CENTER
	food_row.add_theme_constant_override("separation", 8)
	root.add_child(food_row)
	if ResourceLoader.exists(FOOD_ICON_PATH):
		var icon := TextureRect.new()
		icon.texture = load(FOOD_ICON_PATH)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		food_row.add_child(icon)
	_food_label = Label.new()
	_food_label.add_theme_font_size_override("font_size", 22)
	_food_label.modulate = Color(1, 0.9, 0.55)
	_food_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	food_row.add_child(_food_label)

	root.add_child(_make_divider())

	var desc := Label.new()
	desc.text = tr("ozan.desc")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.modulate = Color(1, 1, 1, 0.75)
	root.add_child(desc)

	_sing_button = Button.new()
	_sing_button.text = tr("ozan.sing") % OzanSongs.FOOD_COST
	_sing_button.add_theme_font_size_override("font_size", 17)
	_sing_button.custom_minimum_size = Vector2(0, 44)
	_sing_button.pressed.connect(_on_sing_pressed)
	_style_focus(_sing_button)
	root.add_child(_sing_button)

	root.add_child(_make_divider())

	# Türkünün sözleri
	_song_label = Label.new()
	_song_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_song_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_song_label.add_theme_font_size_override("font_size", 19)
	_song_label.modulate = Color(0.95, 0.85, 0.6)
	_song_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_song_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_song_label)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_info_label)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var close_lbl := Label.new()
	close_lbl.text = tr("ozan.close")
	close_lbl.add_theme_font_size_override("font_size", 13)
	close_lbl.modulate = Color(1, 1, 1, 0.5)
	bar.add_child(close_lbl)
	root.add_child(bar)
	TextOutline.apply_to_tree(self)


func _make_divider() -> Control:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	return divider


func show_popup() -> void:
	_reapply_full_rect()
	_is_open = true
	_song_label.text = ""
	_info_label.text = ""
	_refresh()
	visible = true
	call_deferred("_grab_initial_focus")


func hide_popup() -> void:
	_is_open = false
	visible = false
	closed.emit()


func _village_manager() -> Node:
	return get_node_or_null("/root/VillageManager")


func _food_stock() -> int:
	var vm := _village_manager()
	return int(vm.call("get_resource_level", "food")) if vm and vm.has_method("get_resource_level") else 0


func _refresh() -> void:
	_food_label.text = tr("ozan.food") % _food_stock()
	_sing_button.disabled = _food_stock() < OzanSongs.FOOD_COST


func _on_sing_pressed() -> void:
	var vm := _village_manager()
	if vm == null or not vm.has_method("spend_resources"):
		return
	if _food_stock() < OzanSongs.FOOD_COST:
		_show_info(tr("ozan.info.no_food"), false)
		return
	var clue: Dictionary = OzanSongs.pick_clue()
	if clue.is_empty():
		# Anlatılacak zindan kalmadı: yemek harcanmaz
		_song_label.text = ""
		_show_info(tr("ozan.none"), false)
		return
	if not bool(vm.call("spend_resources", {"food": OzanSongs.FOOD_COST})):
		_show_info(tr("ozan.info.no_food"), false)
		return
	OzanSongs.mark_sung(clue)
	_song_label.text = OzanSongs.song_text(clue)
	_show_info("", true)
	_refresh()


func _show_info(text: String, good: bool) -> void:
	_info_label.text = text
	_info_label.modulate = Color(0.6, 1.0, 0.6) if good else Color(1, 0.55, 0.5)


func _style_focus(button: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("focus", sb)


func _grab_initial_focus() -> void:
	if not _sing_button.disabled:
		_sing_button.grab_focus()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		hide_popup()
