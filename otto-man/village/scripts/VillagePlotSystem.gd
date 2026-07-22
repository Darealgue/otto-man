extends Node
class_name VillagePlotSystem
## Parsel/bina yakınlık etkileşimi: inşa popup, işçi +/- , ipuçları.

const PROXIMITY_X := 170.0
const PROXIMITY_Y := 150.0

const _IndicatorScript := preload("res://village/scripts/BuildingWorkerCapacityIndicator.gd")
const _PlotSpotScript := preload("res://village/scripts/VillagePlotInteractSpot.gd")
const _BuildPopupScript := preload("res://ui/PlotBuildPopupUI.gd")
const _OccupiedPopupScript := preload("res://ui/PlotOccupiedPopupUI.gd")
const _BarracksWeaponPopupScript := preload("res://ui/BarracksWeaponPopupUI.gd")

var _village_scene: Node2D
var _plot_spots: Array[VillagePlotInteractSpot] = []
var _active_spot: VillagePlotInteractSpot = null
var _active_building: Node2D = null
var _build_popup: PlotBuildPopupUI
var _occupied_popup: PlotOccupiedPopupUI
var _barracks_weapon_popup: BarracksWeaponPopupUI
var _popup_canvas: CanvasLayer
var _spots_root: Node2D


func setup(village_scene: Node2D) -> void:
	_village_scene = village_scene
	add_to_group("village_plot_system")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_input(true)
	_ensure_popups()
	_spawn_plot_spots()
	_sync_building_indicators()
	if is_instance_valid(VillageManager):
		if VillageManager.has_signal("construction_completed") and not VillageManager.construction_completed.is_connected(_on_construction_completed):
			VillageManager.construction_completed.connect(_on_construction_completed)
		if VillageManager.has_signal("village_data_changed") and not VillageManager.village_data_changed.is_connected(_on_village_data_changed):
			VillageManager.village_data_changed.connect(_on_village_data_changed)
	call_deferred("_refresh_active_spot")


func _ensure_popups() -> void:
	# Use the existing BuildMenuLayer CanvasLayer — known to render correctly.
	var canvas: CanvasLayer = null
	if is_instance_valid(_village_scene):
		canvas = _village_scene.get_node_or_null("BuildMenuLayer") as CanvasLayer
	if not is_instance_valid(canvas):
		# Fallback: reuse or create our own
		canvas = get_tree().root.get_node_or_null("PlotPopupCanvas") as CanvasLayer
		if not is_instance_valid(canvas):
			canvas = CanvasLayer.new()
			canvas.name = "PlotPopupCanvas"
			canvas.layer = 50
			canvas.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(canvas)
	_popup_canvas = canvas

	if not is_instance_valid(_build_popup):
		_build_popup = _BuildPopupScript.new()
		_build_popup.name = "PlotBuildPopup"
		canvas.add_child(_build_popup)
		_build_popup.build_selected.connect(_on_build_selected)

	if not is_instance_valid(_occupied_popup):
		_occupied_popup = _OccupiedPopupScript.new()
		_occupied_popup.name = "PlotOccupiedPopup"
		canvas.add_child(_occupied_popup)
		_occupied_popup.upgrade_requested.connect(_on_upgrade_requested)
		_occupied_popup.build_house_requested.connect(_on_build_house_requested)
		_occupied_popup.demolish_requested.connect(_on_demolish_requested)
		_occupied_popup.weaponize_requested.connect(_on_weaponize_requested)
		_occupied_popup.inventor_upgrades_requested.connect(_on_inventor_upgrades_requested)

	if not is_instance_valid(_barracks_weapon_popup):
		_barracks_weapon_popup = _BarracksWeaponPopupScript.new()
		_barracks_weapon_popup.name = "BarracksWeaponPopup"
		canvas.add_child(_barracks_weapon_popup)


func _spawn_plot_spots() -> void:
	if not is_instance_valid(_village_scene):
		return
	if is_instance_valid(_spots_root):
		_spots_root.queue_free()
	_plot_spots.clear()

	_spots_root = Node2D.new()
	_spots_root.name = "PlotInteractSpots"
	_village_scene.add_child(_spots_root)

	var markers := _village_scene.get_node_or_null("PlotMarkers")
	if not markers:
		push_warning("[VillagePlotSystem] PlotMarkers bulunamadı!")
		return

	for marker in markers.get_children():
		if not marker is Marker2D:
			continue
		var spot: VillagePlotInteractSpot = _PlotSpotScript.new()
		spot.name = "PlotSpot_%s" % marker.name
		_spots_root.add_child(spot)
		spot.setup((marker as Marker2D).global_position, self)
		_plot_spots.append(spot)


func _sync_building_indicators() -> void:
	if not is_instance_valid(_village_scene):
		return
	var placed := _village_scene.get_node_or_null("PlacedBuildings")
	if not placed:
		return
	for building in placed.get_children():
		if not building is Node2D:
			continue
		if not building.has_method("add_worker"):
			continue
		if building.get_node_or_null("WorkerCapacityIndicator") != null:
			continue
		var indicator := Node2D.new()
		indicator.name = "WorkerCapacityIndicator"
		indicator.set_script(_IndicatorScript)
		building.add_child(indicator)
		if indicator.has_method("setup"):
			indicator.setup(building)


func _process(_delta: float) -> void:
	if _is_popup_open():
		return
	_refresh_active_spot()


func _refresh_active_spot() -> void:
	if _should_defer_to_village_character():
		_active_spot = null
		_active_building = null
		for spot in _plot_spots:
			if is_instance_valid(spot):
				spot.set_player_inside(false)
				spot.HideInteractButton()
		return
	_active_spot = _pick_best_spot_by_distance()
	for spot in _plot_spots:
		if not is_instance_valid(spot):
			continue
		var is_active := spot == _active_spot
		spot.set_player_inside(is_active)
		if is_active and spot.can_interact():
			spot.ShowInteractButton()
		else:
			spot.HideInteractButton()
	_refresh_active_target()


func _pick_best_spot_by_distance() -> VillagePlotInteractSpot:
	var player := _get_player()
	if player == null:
		return null
	var best: VillagePlotInteractSpot = null
	var best_score := INF
	for spot in _plot_spots:
		if not is_instance_valid(spot) or not spot.can_interact():
			continue
		var dx := absf(player.global_position.x - spot.global_position.x)
		var dy := absf(player.global_position.y - spot.global_position.y)
		if dx > PROXIMITY_X or dy > PROXIMITY_Y:
			continue
		var score := dx + dy * 0.65
		if score < best_score:
			best_score = score
			best = spot
	return best


func _refresh_active_target() -> void:
	_active_building = null
	if not is_instance_valid(_active_spot):
		return
	var building := _active_spot.get_building()
	if is_instance_valid(building):
		_active_building = building


func try_interact_active_spot() -> bool:
	if _is_popup_open():
		return false
	if _should_defer_to_village_character():
		return false
	if not is_instance_valid(_active_spot) or not _active_spot.can_interact():
		return false
	_active_spot.interact()
	return true


func _should_defer_to_village_character() -> bool:
	var player := _get_player()
	if player == null:
		return false
	if player.has_method("has_village_priority_character_in_range"):
		return bool(player.call("has_village_priority_character_in_range"))
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _is_popup_open():
		return
	if not _is_in_village():
		return

	if is_instance_valid(_active_building):
		# Num7/Num9 klavye + L2/R2 gamepad tetikleyicisini birlikte destekle
		# (InputMap'teki village_worker_* joypad düğme indeksleri yanıltıcı, gerçek
		# L2/R2 tetikleyicileri l2_trigger/r2_trigger aksiyonlarından gelir).
		if event.is_action_pressed("village_worker_add") or event.is_action_pressed("r2_trigger"):
			if VillageManager.try_add_worker_to_building(_active_building):
				_notify_worker_assigned(_active_building)
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("village_worker_remove") or event.is_action_pressed("l2_trigger"):
			if VillageManager.try_remove_worker_from_building(_active_building):
				get_viewport().set_input_as_handled()


func open_build_popup(plot_position: Vector2) -> void:
	if not is_instance_valid(_build_popup):
		return
	_build_popup.show_for_plot(plot_position)
	if is_instance_valid(_village_scene) and _village_scene.has_method("tutorial_on_plot_build_opened"):
		_village_scene.tutorial_on_plot_build_opened()


func open_occupied_popup(building: Node2D) -> void:
	if not is_instance_valid(_occupied_popup) or not is_instance_valid(building):
		return
	_occupied_popup.show_for_building(building)


func _is_popup_open() -> bool:
	var b_open := is_instance_valid(_build_popup) and _build_popup._is_open
	var o_open := is_instance_valid(_occupied_popup) and _occupied_popup._is_open
	var w_open := is_instance_valid(_barracks_weapon_popup) and _barracks_weapon_popup._is_open
	if b_open or o_open or w_open:
		return true
	var host := VillageWorldPopups.get_host()
	if host and host.is_any_popup_open():
		return true
	# Mucit Odası paneli lazy/group tabanlı açılıyor (bkz. _on_inventor_upgrades_requested),
	# _build_popup/_occupied_popup gibi doğrudan bir referansımız yok — grup üzerinden bakıyoruz.
	var inventor_ui := get_tree().get_first_node_in_group("inventor_workshop_ui")
	if inventor_ui and "visible" in inventor_ui and bool(inventor_ui.get("visible")):
		return true
	return false


func _is_in_village() -> bool:
	return is_instance_valid(_village_scene) and _village_scene.is_inside_tree()


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _on_build_selected(scene_path: String) -> void:
	var plot_pos := Vector2.INF
	if is_instance_valid(_active_spot):
		plot_pos = _active_spot.plot_position
	if plot_pos == Vector2.INF:
		return
	# "Bina bitti" ilerlemesi burada değil, inşaat GERÇEKTEN bitince tetikleniyor (bkz.
	# VillageScene.gd _on_construction_completed_toast -> construction_completed sinyali).
	# İnşaat artık anında bitmediği için (gerçek süresi var), burada işaretlemek binayı henüz
	# fiziksel olarak yokken tutorial'ı "bitti" sayıp bekleme adımını atlıyordu. Sadece
	# "inşaata alındı" bilgisini bildiriyoruz (objective'in "kamp ateşine git"e dönmesi için).
	if VillageManager.request_build_building_at_plot(scene_path, plot_pos):
		var key := scene_path.get_file().trim_suffix(".tscn").to_lower()
		if is_instance_valid(_village_scene) and _village_scene.has_method("_tutorial_on_building_queued"):
			_village_scene.call_deferred("_tutorial_on_building_queued", key)


func _on_upgrade_requested() -> void:
	if is_instance_valid(_active_building):
		VillageManager.try_upgrade_building(_active_building)


func _on_build_house_requested() -> void:
	if is_instance_valid(_active_building):
		VillageManager.request_build_house_floor_on(_active_building)


func _on_demolish_requested() -> void:
	if is_instance_valid(_active_building):
		VillageManager.demolish_building(_active_building)
		_active_building = null


func _on_weaponize_requested() -> void:
	if is_instance_valid(_active_building) and is_instance_valid(_barracks_weapon_popup):
		_barracks_weapon_popup.show_for_barracks(_active_building)


func _on_inventor_upgrades_requested() -> void:
	# Mucit Odası'nın kendi Area2D tabanlı interact sistemi (InventorWorkshopInteractable)
	# VillagePlotSystem'in genel parsel etkileşimiyle aynı girdiyi dinlediği için hiç
	# tetiklenmiyordu — bu yüzden panel doğrudan burada, diğer bina popup'larıyla aynı
	# şekilde açılıyor.
	var ui := get_tree().get_first_node_in_group("inventor_workshop_ui")
	if not is_instance_valid(ui):
		var ui_script := preload("res://ui/InventorWorkshopUI.gd")
		ui = Control.new()
		ui.set_script(ui_script)
		ui.add_to_group("inventor_workshop_ui")
		# <<< DÜZELTME: get_tree().root'a değil, diğer popup'ların kullandığı YÜKSEK
		# KATMANLI CanvasLayer'a (_popup_canvas, layer=50) eklenmeli — aksi halde panel
		# oyun dünyasının ARKASINDA render olup görünmez oluyordu (mantıksal olarak
		# çalışıyordu, sadece ekranda görünmüyordu). >>>
		var parent_canvas: Node = _popup_canvas if is_instance_valid(_popup_canvas) else get_tree().root
		parent_canvas.add_child(ui)
	if ui.has_method("show_panel"):
		ui.show_panel()


func _on_construction_completed(_scene_path: String) -> void:
	call_deferred("_sync_building_indicators")
	call_deferred("_refresh_active_spot")


func _on_village_data_changed() -> void:
	call_deferred("_sync_building_indicators")
	call_deferred("_refresh_active_spot")


func _notify_worker_assigned(building: Node2D) -> void:
	if not is_instance_valid(_village_scene) or not is_instance_valid(building):
		return
	var key := String(building.scene_file_path).get_file().trim_suffix(".tscn").to_lower()
	if _village_scene.has_method("tutorial_on_mission_worker_assigned"):
		_village_scene.tutorial_on_mission_worker_assigned(key)
