extends Node2D
class_name VillagePlotInteractSpot
## Tek inşa parseli — oyuncunun W/↑ etkileşim sistemiyle uyumlu Area2D.

const OverheadUiTracker = preload("res://ui/overhead_ui_tracker.gd")

var plot_position: Vector2 = Vector2.ZERO
var plot_system: VillagePlotSystem = null

var _interact_area: Area2D
var _interact_hint: Label
var _player_inside := false


func setup(world_pos: Vector2, system: VillagePlotSystem) -> void:
	plot_position = world_pos
	plot_system = system
	global_position = world_pos
	_build_area()
	_build_hint()


func _build_area() -> void:
	_interact_area = Area2D.new()
	_interact_area.name = "InteractArea"
	_interact_area.collision_layer = 1
	_interact_area.collision_mask = 2
	_interact_area.monitoring = true
	_interact_area.monitorable = true
	add_child(_interact_area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(240, 140)
	shape.shape = rect
	shape.position = Vector2(0, -50)
	_interact_area.add_child(shape)


func _build_hint() -> void:
	_interact_hint = Label.new()
	_interact_hint.name = "InteractHint"
	_interact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint.add_theme_font_size_override("font_size", 12)
	_interact_hint.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	_interact_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_interact_hint.add_theme_constant_override("outline_size", 3)
	_interact_hint.position = Vector2(-48, -88)
	_interact_hint.size = Vector2(96, 20)
	_interact_hint.visible = false
	add_child(_interact_hint)
	# Sahne ışığından (gece CanvasModulate) etkilenmesin diye ayrı bir CanvasLayer'a taşınıp
	# ekran uzayında takip ettiriliyor.
	OverheadUiTracker.attach(_interact_hint, self, Vector2(0, -78))


func is_player_inside() -> bool:
	return _player_inside


func set_player_inside(inside: bool) -> void:
	_player_inside = inside


func get_building() -> Node2D:
	if not is_instance_valid(VillageManager):
		return null
	return VillageManager.get_building_at_plot_position(plot_position)


func can_interact() -> bool:
	if not is_instance_valid(VillageManager):
		return false
	if get_building() != null:
		return true
	return VillageManager.is_plot_position_empty(plot_position, 24.0)


func interact() -> void:
	if plot_system == null:
		return
	var building := get_building()
	if is_instance_valid(building):
		plot_system.open_occupied_popup(building)
	elif VillageManager.is_plot_position_empty(plot_position):
		plot_system.open_build_popup(plot_position)


func ShowInteractButton() -> void:
	if not _interact_hint:
		return
	var im := get_node_or_null("/root/InputManager")
	var up_hint := "↑"
	if im and im.has_method("get_tutorial_ui_up_hint"):
		up_hint = "[%s]" % im.get_tutorial_ui_up_hint()
	var building := get_building()
	if is_instance_valid(building):
		if building.has_method("add_worker") or "assigned_workers" in building:
			var worker_hint := _worker_hint(im)
			_interact_hint.text = "%s  %s" % [up_hint, worker_hint]
		else:
			_interact_hint.text = up_hint
	else:
		_interact_hint.text = "🏗 %s" % up_hint
	_interact_hint.visible = true


func _worker_hint(im: Node) -> String:
	if im == null:
		return "[7−  9+]"
	var is_pad: bool = bool(im.last_input_from_joypad) if "last_input_from_joypad" in im else false
	if is_pad:
		return "[L2−  R2+]"
	var remove_key: String = InputManager.get_action_key_name(&"village_worker_remove")
	var add_key: String = InputManager.get_action_key_name(&"village_worker_add")
	return "[%s−  %s+]" % [remove_key, add_key]


func HideInteractButton() -> void:
	if _interact_hint:
		_interact_hint.visible = false


func refresh_visuals() -> void:
	if not _player_inside:
		return
	if can_interact():
		ShowInteractButton()
	else:
		HideInteractButton()
