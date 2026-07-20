class_name NpcOverheadUi
extends RefCounted

## Köylü kafasındaki isim plakası ve etkileşim tuşu — parşömen/çerçeve olmadan.

const NAMEPLATE_FONT_COLOR := Color(0.95, 0.93, 0.88, 1)
const NAMEPLATE_OUTLINE_COLOR := Color(0, 0, 0, 1)
const NAMEPLATE_OUTLINE_SIZE := 3
const NAMEPLATE_FONT_SIZE := 16


static func apply_frameless_nameplate(container: PanelContainer) -> void:
	if container == null:
		return
	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


static func apply_frameless_interact_button(button: Button, name_reference: Label = null) -> void:
	if button == null:
		return
	var empty := StyleBoxEmpty.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, empty)
	apply_nameplate_text_style(button, name_reference)


static func apply_nameplate_text_style(control: Control, name_reference: Label = null) -> void:
	if control == null:
		return
	TextOutline.apply_font_to_control(control)
	var font_size := NAMEPLATE_FONT_SIZE
	if name_reference != null:
		font_size = name_reference.get_theme_font_size("font_size")
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", NAMEPLATE_FONT_COLOR)
	control.add_theme_color_override("font_outline_color", NAMEPLATE_OUTLINE_COLOR)
	control.add_theme_constant_override("outline_size", NAMEPLATE_OUTLINE_SIZE)
	if control is Button:
		var btn := control as Button
		btn.add_theme_color_override("font_hover_color", NAMEPLATE_FONT_COLOR)
		btn.add_theme_color_override("font_pressed_color", NAMEPLATE_FONT_COLOR)
		btn.add_theme_color_override("font_focus_color", NAMEPLATE_FONT_COLOR)
		btn.add_theme_color_override("font_disabled_color", NAMEPLATE_FONT_COLOR)


static func configure_centered_overhead_hint(label: Label, width: float, top_y: float, height: float = 20.0, x_shift: float = 0.0) -> void:
	if label == null:
		return
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -width * 0.5 + x_shift
	label.offset_right = width * 0.5 + x_shift
	label.offset_top = top_y
	label.offset_bottom = top_y + height
	label.pivot_offset = Vector2(width * 0.5, height * 0.5)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH


static func sync_horizontal_flip(host: Node2D, ui_nodes: Array) -> void:
	if not is_instance_valid(host):
		return
	var flip := -1.0 if host.scale.x < 0.0 else 1.0
	for node in ui_nodes:
		if node is CanvasItem and is_instance_valid(node):
			(node as CanvasItem).scale.x = flip


static func get_interact_hint_text() -> String:
	var im := _get_input_manager()
	if im != null and im.has_method("get_tutorial_interact_hint"):
		return im.get_tutorial_interact_hint()
	return InputManager.get_interact_key_name()


static func _get_input_manager() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).root.get_node_or_null("/root/InputManager")
	return null


## Ring, interact_button'ın ÇOCUĞU olarak eklenir (host'un değil) — böylece buton sahne
## ışığından kaçmak için ayrı bir CanvasLayer'a taşınırsa (bkz. OverheadUiTracker) ring de
## otomatik olarak onunla birlikte taşınır, ayrıca senkronize edilmesine gerek kalmaz.
static func attach_hold_ring(host: Node, interact_button: Button) -> NpcInteractHoldRing:
	if host == null or interact_button == null:
		return null
	var ring := NpcInteractHoldRing.new()
	ring.name = "InteractHoldRing"
	ring.z_index = interact_button.z_index
	interact_button.add_child(ring)
	ring.sync_to_button(interact_button)
	ring.visible = false
	return ring
