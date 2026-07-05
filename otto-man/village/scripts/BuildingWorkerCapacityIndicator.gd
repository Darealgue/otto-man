class_name BuildingWorkerCapacityIndicator
extends Node2D
## Bina üstünde işçi doluluk göstergesi (yeşil = dolu slot).
## Oyuncu binaya yaklaşınca görünür; uzaklaşınca fade out.

const DOT_RADIUS := 4.5
const DOT_GAP := 3.0
const Y_OFFSET := -118.0
const FADE_NEAR := 130.0
const FADE_FAR := 300.0

var _building: Node = null
var _dots: Array[ColorRect] = []


func setup(building: Node) -> void:
	_building = building
	position = Vector2(0, Y_OFFSET)
	z_index = 20
	set_process(true)
	_rebuild_dots()
	if is_instance_valid(VillageManager) and VillageManager.has_signal("building_state_changed"):
		if not VillageManager.building_state_changed.is_connected(_on_building_state_changed):
			VillageManager.building_state_changed.connect(_on_building_state_changed)
	if is_instance_valid(VillageManager) and VillageManager.has_signal("village_data_changed"):
		if not VillageManager.village_data_changed.is_connected(_on_village_data_changed):
			VillageManager.village_data_changed.connect(_on_village_data_changed)
	refresh()


func _process(_delta: float) -> void:
	_update_proximity_alpha()


func _update_proximity_alpha() -> void:
	if not is_instance_valid(_building):
		modulate.a = 0.0
		visible = false
		return
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	if max_w <= 0:
		modulate.a = 0.0
		visible = false
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		modulate.a = 1.0
		visible = true
		return
	var dist := player.global_position.distance_to(_building.global_position)
	var alpha := 1.0
	if dist > FADE_NEAR:
		alpha = 1.0 - clampf((dist - FADE_NEAR) / maxf(FADE_FAR - FADE_NEAR, 1.0), 0.0, 1.0)
	modulate.a = alpha
	visible = alpha > 0.03


func _on_building_state_changed(changed_building: Node) -> void:
	if changed_building == _building:
		refresh()


func _on_village_data_changed() -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(_building):
		visible = false
		return
	if not _building.has_method("add_worker"):
		visible = false
		return
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	var assigned := int(_building.assigned_workers) if "assigned_workers" in _building else 0
	if max_w <= 0:
		visible = false
		return
	if _dots.size() != max_w:
		_rebuild_dots()
	for i in max_w:
		if i >= _dots.size():
			break
		var dot: ColorRect = _dots[i]
		if i < assigned:
			dot.color = Color(0.35, 0.9, 0.45, 0.95)
		else:
			dot.color = Color(0.25, 0.25, 0.28, 0.55)
	_update_proximity_alpha()


func _rebuild_dots() -> void:
	for d in _dots:
		if is_instance_valid(d):
			d.queue_free()
	_dots.clear()
	if not is_instance_valid(_building):
		return
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	if max_w <= 0:
		return
	var total_w := float(max_w) * (DOT_RADIUS * 2.0 + DOT_GAP) - DOT_GAP
	var start_x := -total_w * 0.5
	for i in max_w:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_RADIUS * 2.0, DOT_RADIUS * 2.0)
		dot.size = dot.custom_minimum_size
		dot.position = Vector2(start_x + float(i) * (DOT_RADIUS * 2.0 + DOT_GAP), -DOT_RADIUS)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)
