extends Node2D
class_name VillagePlotInteractSpot
## Tek inşa parseli — oyuncunun W/↑ etkileşim sistemiyle uyumlu Area2D.

const OverheadUiTracker = preload("res://ui/overhead_ui_tracker.gd")

var plot_position: Vector2 = Vector2.ZERO
var plot_system: VillagePlotSystem = null

const WORKER_HINT_MARGIN := 14.0

var _interact_area: Area2D
var _build_hint_icon: TextureRect
var _worker_remove_hint: Label
var _worker_add_hint: Label
var _worker_remove_tracker: OverheadUiTracker
var _worker_add_tracker: OverheadUiTracker
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
	# Ev ikonu artık okun üzerine bindirilmiyor — sprite'ın kendisi zaten "yukarı bas" bilgisini
	# taşıyor, bu yüzden ayrı bir ok ikonuna gerek kalmadı. Boş parselde de, üzerinde bina olan
	# parselde de gösteriliyor; ekran uzayında self'i takip ediyor.
	_build_hint_icon = NpcOverheadUi.build_house_hint_icon()
	_build_hint_icon.visible = false
	add_child(_build_hint_icon)
	# Sahne ışığından (gece CanvasModulate) etkilenmesin diye ayrı bir CanvasLayer'a taşınıp
	# ekran uzayında takip ettiriliyor.
	OverheadUiTracker.attach(_build_hint_icon, self, Vector2(0, -78))

	# İşçi ekle/çıkar tuş ipuçları — BuildingWorkerCapacityIndicator'ın nokta göstergesinin
	# solunda (çıkar) ve sağında (ekle) konumlanıyor; genişlik binanın max_workers'ına göre
	# _update_worker_hints() içinde her seferinde yeniden hesaplanıyor.
	_worker_remove_hint = _make_worker_key_label("WorkerRemoveHint")
	add_child(_worker_remove_hint)
	_worker_remove_tracker = OverheadUiTracker.attach(_worker_remove_hint, self, Vector2.ZERO)

	_worker_add_hint = _make_worker_key_label("WorkerAddHint")
	add_child(_worker_add_hint)
	_worker_add_tracker = OverheadUiTracker.attach(_worker_add_hint, self, Vector2.ZERO)


func _make_worker_key_label(label_name: String) -> Label:
	var lbl := Label.new()
	lbl.name = label_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.size = Vector2(40, 20)
	lbl.visible = false
	return lbl


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
	if not _build_hint_icon:
		return
	NpcOverheadUi.fade_show_icon(_build_hint_icon)
	var building := get_building()
	if is_instance_valid(building) and (building.has_method("add_worker") or "assigned_workers" in building):
		_update_worker_hints(building)
	else:
		_hide_worker_hints()


## Çıkar/ekle tuş ipuçlarını binanın nokta göstergesinin (BuildingWorkerCapacityIndicator)
## solunda ve sağında ortalar. Hizalamayı kendi kendine (building.global_position +
## varsayılan Y_OFFSET) yeniden hesaplamak yerine, göstergenin KENDİ global_position'ını ve
## slot sayısını doğrudan okuyoruz — böylece bina/plaset arasında olabilecek herhangi bir
## konum farkından (ör. get_building_at_plot_position'daki tolerans payı) tamamen bağımsız,
## piksel piksel doğru hizalanıyor. Tuş metinleri bilinçli olarak sabit: klavyede Q/E,
## gamepad'de L2/R2 (bkz. project.godot village_worker_add/remove varsayılan bağlamaları) —
## dinamik InputMap çözümlemesi bu aksiyonlar için güvenilmez sonuç veriyordu.
func _update_worker_hints(building: Node2D) -> void:
	if not _worker_remove_hint or not _worker_add_hint:
		return
	var indicator := building.get_node_or_null("WorkerCapacityIndicator")
	var max_w: int
	var anchor_world: Vector2
	if is_instance_valid(indicator) and indicator.has_method("get_slot_count"):
		max_w = int(indicator.get_slot_count())
		anchor_world = indicator.global_position
	else:
		max_w = int(building.max_workers) if "max_workers" in building else 0
		anchor_world = building.global_position + Vector2(0, BuildingWorkerCapacityIndicator.Y_OFFSET)
	if max_w <= 0:
		_hide_worker_hints()
		return
	var total_w := float(max_w) * (BuildingWorkerCapacityIndicator.SLOT_ICON_SIZE + BuildingWorkerCapacityIndicator.SLOT_GAP) - BuildingWorkerCapacityIndicator.SLOT_GAP
	var half_w := total_w * 0.5 + WORKER_HINT_MARGIN
	var anchor_offset := anchor_world - global_position
	if _worker_remove_tracker:
		_worker_remove_tracker.set_world_center_offset(Vector2(anchor_offset.x - half_w, anchor_offset.y))
	if _worker_add_tracker:
		_worker_add_tracker.set_world_center_offset(Vector2(anchor_offset.x + half_w, anchor_offset.y))

	var im := get_node_or_null("/root/InputManager")
	var is_pad: bool = bool(im.last_input_from_joypad) if im and "last_input_from_joypad" in im else false
	_worker_remove_hint.text = "L2−" if is_pad else "Q−"
	_worker_add_hint.text = "R2+" if is_pad else "E+"
	_worker_remove_hint.visible = true
	_worker_add_hint.visible = true


func _hide_worker_hints() -> void:
	if _worker_remove_hint:
		_worker_remove_hint.visible = false
	if _worker_add_hint:
		_worker_add_hint.visible = false


func HideInteractButton() -> void:
	if _build_hint_icon:
		NpcOverheadUi.fade_hide_icon(_build_hint_icon)
	_hide_worker_hints()


func refresh_visuals() -> void:
	if not _player_inside:
		return
	if can_interact():
		ShowInteractButton()
	else:
		HideInteractButton()
