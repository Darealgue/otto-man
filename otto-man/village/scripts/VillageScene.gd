extends Node2D # Veya sahnenizin kök node türü neyse (Node2D, Control vb.)

# Bina sahnelerini önceden yükle (Bunlar kalabilir, belki başka yerde kullanılır)
const WoodcutterCampScene = preload("res://village/buildings/WoodcutterCamp.tscn")
const StoneMineScene = preload("res://village/buildings/StoneMine.tscn")
const HunterGathererHutScene = preload("res://village/buildings/HunterGathererHut.tscn")
const WellScene = preload("res://village/buildings/Well.tscn")
const BakeryScene = preload("res://village/buildings/Bakery.tscn")
# Sahnedeki UI ve Diğer Referanslar (Eski inşa butonları kaldırıldı)
@onready var worker_assignment_ui = $WorkerAssignmentUI
@onready var cariye_management_ui = $CariyeManagementUI # YENİ PANEL
@onready var open_worker_ui_button = $OpenWorkerUIButton
@onready var open_cariye_ui_button = $OpenCariyeUIButton # YENİ BUTON
@onready var open_build_ui_button = $OpenBuildUIButton
@onready var add_villager_button = $AddVillagerButton
@onready var placed_buildings_node = $PlacedBuildings
@onready var plot_markers_node = $PlotMarkers
@onready var time_manager: TimeManager = get_node("/root/TimeManager") # Veya doğru yolu kullanın
@onready var time_skip_notification = $TimeSkipNotification
@onready var build_menu_ui = $BuildMenuLayer/BuildMenuUI
var world_map_panel: PanelContainer = null
var world_map_label: Label = null
var _world_map_move_cooldown: float = 0.0

## Zindandan dönüşte kurtarılan NPC'leri sadece BİR KEZ uygulamak için guard
var _dungeon_rescue_applied: bool = false

## Kamera sınırları - Village sahnesinde oyuncu bu sınırlar dışına çıktığında kamera takibi durur
## Bu değerleri Godot editöründe VillageScene.tscn'de ayarlayabilirsiniz
## Veya sahne içinde "CameraLeftLimit" ve "CameraRightLimit" isimli Marker2D node'ları varsa onların pozisyonları kullanılır
@export var camera_left_limit: float = -2000.0
@export var camera_right_limit: float = 2000.0



func _ready() -> void:
	# VillageManager'a bu sahneyi tanıt
	VillagerAiInitializer.LoadComplete.connect(VillagersLoaded)

	# Sinyalleri bağla (Eski inşa buton bağlantıları kaldırıldı)
	open_worker_ui_button.pressed.connect(_on_open_worker_ui_button_pressed)
	open_cariye_ui_button.pressed.connect(_on_open_cariye_ui_button_pressed)
	open_build_ui_button.pressed.connect(_on_open_build_ui_button_pressed)
	add_villager_button.pressed.connect(VillageManager.add_villager)
	# UI görünürlük sinyallerini bağla
	worker_assignment_ui.visibility_changed.connect(_on_worker_ui_visibility_changed)
	cariye_management_ui.visibility_changed.connect(_on_cariye_ui_visibility_changed) # Yeni panel bağlandı
	if build_menu_ui:
		build_menu_ui.visibility_changed.connect(_on_build_menu_visibility_changed)
		if build_menu_ui.has_signal("build_requested"):
			build_menu_ui.build_requested.connect(_on_build_menu_build_requested)
		if build_menu_ui.has_signal("close_requested"):
			build_menu_ui.close_requested.connect(_on_build_menu_close_requested)

	# Connect time skip notification signal
	if not VillageManager.time_skip_completed.is_connected(_on_time_skip_completed):
		VillageManager.time_skip_completed.connect(_on_time_skip_completed)
		print("[VillageScene] ✅ Connected time_skip_completed signal")
	else:
		print("[VillageScene] Signal already connected")
	if not VillageManager.construction_completed.is_connected(_on_construction_completed_toast):
		VillageManager.construction_completed.connect(_on_construction_completed_toast)
	if not VillageManager.morale_game_over.is_connected(_on_morale_game_over):
		VillageManager.morale_game_over.connect(_on_morale_game_over)

	# Moral 0 = oyun kaybı (köye girerken veya köyde düşerse)
	if VillageManager.get_morale() <= 0.0:
		_on_morale_game_over()
		return

	# Debug: Check notification node
	if time_skip_notification:
		print("[VillageScene] ✅ TimeSkipNotification node found: ", time_skip_notification)
	else:
		print("[VillageScene] ⚠️ TimeSkipNotification node NOT found!")

	# Başlangıçta UI'ları gizle
	worker_assignment_ui.hide()
	cariye_management_ui.hide()
	if build_menu_ui:
		build_menu_ui.hide()
	# Açma butonlarını göster
	
	# Kamera sınırlarını ayarla
	_setup_camera_limits()
	open_worker_ui_button.show()
	open_cariye_ui_button.show()
	open_build_ui_button.show()
	_setup_world_map_panel()
	_connect_world_map_signals()
	_refresh_world_map_panel()

	# <<< YENİ: Set up example NPCs after the scene is fully loaded >>>
	# Use call_deferred to ensure all workers are created first
	# Note: These methods are for debug/testing only, skip in exported builds
	if OS.has_feature("debug") or OS.has_feature("editor"):
		call_deferred("setup_example_npcs")
		call_deferred("print_dialogue_test_instructions")
	# <<< YENİ SONU >>>
	Load_Existing_Villagers()
	VillageManager.apply_current_time_schedule()
	# Transfer forest resources to village if returning from forest
	call_deferred("_check_and_transfer_forest_resources")
	call_deferred("_show_delivery_summary_from_payload")
	
	# Reset player state after scene load (fix fall state bug)
	call_deferred("_reset_player_on_scene_load")
	
	# Kamera sınırlarını ayarla (oyuncu yüklendikten sonra)
	call_deferred("_setup_camera_limits")
# --- UI Açma / Kapatma Fonksiyonları ---

func Load_Existing_Villagers():
	VillagerAiInitializer.Load_existing_villagers()

func VillagersLoaded():
	VillageManager.register_village_scene(self)
	call_deferred("_refresh_npc_schedule")

func _exit_tree() -> void:
	if is_instance_valid(VillageManager) and VillageManager.has_method("on_village_scene_tree_exiting"):
		VillageManager.on_village_scene_tree_exiting(self)

func _refresh_npc_schedule() -> void:
	if is_instance_valid(VillageManager):
		VillageManager.apply_current_time_schedule()

func _on_open_worker_ui_button_pressed() -> void:
	# Diğer paneli kapat (aynı anda sadece biri açık olsun)
	cariye_management_ui.hide()
	worker_assignment_ui.show()

func _on_open_cariye_ui_button_pressed() -> void:
	# Diğer paneli kapat
	worker_assignment_ui.hide()
	cariye_management_ui.show()

func _on_open_build_ui_button_pressed() -> void:
	# Diğer panelleri kapat
	worker_assignment_ui.hide()
	cariye_management_ui.hide()
	if build_menu_ui:
		build_menu_ui.show_centered()

func _on_worker_ui_visibility_changed() -> void:
	# İşçi paneli kapandığında butonu göster, açıksa gizle
	open_worker_ui_button.visible = not worker_assignment_ui.visible
	# Eğer işçi paneli açıldıysa, cariye butonunu da göster (kapatılmış olabilir)
	if worker_assignment_ui.visible:
		open_cariye_ui_button.show()

func _on_cariye_ui_visibility_changed() -> void:
	# Cariye paneli kapandığında butonu göster, açıksa gizle
	open_cariye_ui_button.visible = not cariye_management_ui.visible
	# Eğer cariye paneli açıldıysa, işçi butonunu da göster
	if cariye_management_ui.visible:
		open_worker_ui_button.show()

func _on_build_menu_visibility_changed() -> void:
	if not build_menu_ui:
		return
	open_build_ui_button.visible = not build_menu_ui.visible
	if build_menu_ui.visible:
		open_worker_ui_button.show()
		open_cariye_ui_button.show()

func _on_build_menu_build_requested(building_scene_path: String) -> void:
	if VillageManager.request_build_building(building_scene_path):
		if build_menu_ui:
			build_menu_ui.hide()

func _on_build_menu_close_requested() -> void:
	if build_menu_ui:
		build_menu_ui.hide()

func _on_time_skip_completed(total_hours: float, produced_resources: Dictionary, construction_footnote: String = "") -> void:
	print("[VillageScene] _on_time_skip_completed called: %.1f hours, resources: %s" % [total_hours, produced_resources])
	# Use call_deferred to ensure scene is fully loaded
	call_deferred("_show_notification_deferred", total_hours, produced_resources, construction_footnote)

func _show_notification_deferred(total_hours: float, produced_resources: Dictionary, construction_footnote: String = "") -> void:
	if not time_skip_notification:
		print("[VillageScene] ⚠️ time_skip_notification node not found!")
		# Try to find it manually
		time_skip_notification = get_node_or_null("TimeSkipNotification")
		if not time_skip_notification:
			print("[VillageScene] ⚠️ Could not find TimeSkipNotification node manually either!")
			return
		print("[VillageScene] ✅ Found TimeSkipNotification manually")
	
	if not time_skip_notification.has_method("show_time_skip_notification"):
		print("[VillageScene] ⚠️ time_skip_notification doesn't have show_time_skip_notification method!")
		return
	print("[VillageScene] ✅ Showing notification...")
	time_skip_notification.show_time_skip_notification(total_hours, produced_resources, construction_footnote)

func _on_construction_completed_toast(scene_path: String) -> void:
	var disp := String(scene_path).get_file().trim_suffix(".tscn")
	call_deferred("_show_build_complete_toast_deferred", disp)

func _show_build_complete_toast_deferred(building_display_name: String) -> void:
	if not time_skip_notification:
		time_skip_notification = get_node_or_null("TimeSkipNotification")
	if not time_skip_notification or not time_skip_notification.has_method("show_simple_toast"):
		return
	time_skip_notification.show_simple_toast("İnşaat tamamlandı", building_display_name)

func _on_morale_game_over() -> void:
	"""Köy morali 0'a düştü - ana menüye dön (oyun kaybı)."""
	var sm = get_node_or_null("/root/SceneManager")
	if sm and sm.has_method("return_to_main_menu"):
		sm.return_to_main_menu()

func _check_and_transfer_forest_resources() -> void:
	"""Check if player is returning from forest and transfer carried resources to village."""
	var scene_manager = get_node_or_null("/root/SceneManager")
	if not scene_manager:
		print("[VillageScene] ⚠️ SceneManager not found")
		return
	
	var payload = scene_manager.get_current_payload()
	var source = payload.get("source", "")
	
	print("[VillageScene] 🔍 Checking for forest resources transfer. Payload source: '%s', payload: %s" % [source, payload])
	
	# Check PlayerStats for carried resources before transfer
	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats:
		var carried = player_stats.get_carried_resources()
		print("[VillageScene] 📦 Carried resources before transfer: %s" % carried)
	
	if source == "forest":
		var game_manager = get_node_or_null("/root/GameManager")
		if not game_manager:
			push_warning("[VillageScene] GameManager not found, cannot transfer resources")
			return
		
		print("[VillageScene] 🌲 Transferring forest resources to village...")
		var transferred = game_manager.transfer_carried_resources_to_village()
		
		if transferred.is_empty():
			print("[VillageScene] ⚠️ No resources transferred (transferred dict is empty)")
		else:
			var log_parts := []
			for type in transferred.keys():
				var amount: int = int(transferred[type])
				if amount > 0:
					log_parts.append("%d %s" % [amount, type])
			if log_parts.size() > 0:
				print("[VillageScene] ✅ Forest resources transferred to village: %s" % ", ".join(log_parts))
			else:
				print("[VillageScene] ⚠️ Transferred dict not empty but no positive amounts found: %s" % transferred)
	else:
		print("[VillageScene] ℹ️ Not returning from forest (source: '%s'), skipping resource transfer" % source)

func _show_delivery_summary_from_payload() -> void:
	var scene_manager = get_node_or_null("/root/SceneManager")
	if not scene_manager:
		return
	var payload: Dictionary = scene_manager.get_current_payload()
	var lines: Array[String] = []
	
	var delivered_gold: int = int(payload.get("delivered_dungeon_gold", 0))
	if delivered_gold > 0:
		lines.append("+%d zindan altını" % delivered_gold)
	
	var delivered_resources: Dictionary = payload.get("forest_resources_delivered", {})
	if delivered_resources is Dictionary and not delivered_resources.is_empty():
		var total_res: int = 0
		for res_type in delivered_resources.keys():
			total_res += int(delivered_resources[res_type])
		if total_res > 0:
			lines.append("+%d kaynak" % total_res)
	
	var delivered_villagers: int = int(payload.get("delivered_rescued_villagers", 0))
	var delivered_cariyes: int = int(payload.get("delivered_rescued_cariyes", 0))
	if delivered_villagers > 0 or delivered_cariyes > 0:
		lines.append("+%d köylü, +%d cariye" % [delivered_villagers, delivered_cariyes])
	
	if lines.is_empty():
		return
	if not time_skip_notification:
		time_skip_notification = get_node_or_null("TimeSkipNotification")
	if not time_skip_notification or not time_skip_notification.has_method("show_simple_toast"):
		return
	time_skip_notification.show_simple_toast("Teslimat Tamamlandı", ", ".join(lines))

func _apply_dungeon_rescued() -> void:
	"""Zindandan sağ çıkışta kurtarılan köylü ve cariyeleri köye ekler."""
	if _dungeon_rescue_applied:
		print("[VillageScene] ⚠️ Dungeon rescued already applied once, skipping.")
		return
	var scene_manager = get_node_or_null("/root/SceneManager")
	if not scene_manager:
		return
	var payload = scene_manager.get_current_payload()
	var villagers: Array = payload.get("rescued_villagers", [])
	var cariyes: Array = payload.get("rescued_cariyes", [])
	var delivered_from_dungeon: bool = bool(payload.get("delivered_from_dungeon_run", false))
	if payload.get("source", "") != "dungeon" and not delivered_from_dungeon and villagers.is_empty() and cariyes.is_empty():
		return
	if villagers.is_empty() and cariyes.is_empty():
		print("[VillageScene] ⚠️ Dungeon payload has no villagers/cariyes, skipping.")
		return
	var vm = get_node_or_null("/root/VillageManager")
	var mm = get_node_or_null("/root/MissionManager")
	if not vm or not mm:
		print("[VillageScene] ⚠️ Cannot apply dungeon rescued; vm=%s mm=%s" % [str(vm), str(mm)])
		return
	print("[VillageScene] 🔄 Applying dungeon rescued AFTER worker restoration. villagers=%d, cariyes=%d" % [villagers.size(), cariyes.size()])
	for villager_data in villagers:
		if villager_data is Dictionary and vm.has_method("add_villager_with_data"):
			vm.add_villager_with_data(villager_data)
		else:
			vm.add_villager()
	for cariye_data in cariyes:
		if cariye_data is Dictionary:
			var cid = mm.add_concubine_from_rescue(cariye_data)
			vm.add_cariye_with_id(cid, cariye_data)
	if vm.has_method("_spawn_concubines_in_scene"):
		vm._spawn_concubines_in_scene()
	print("[VillageScene] ✅ Dungeon rescued applied: %d villagers, %d cariyes" % [villagers.size(), cariyes.size()])
	_dungeon_rescue_applied = true

func _reset_player_on_scene_load() -> void:
	# Ensure time scale is normal (critical fix)
	Engine.time_scale = 1.0
	# Ensure TimeManager time scale is also reset
	if time_manager and time_manager.has_method("set_time_scale_index"):
		time_manager.set_time_scale_index(0)
	
	# Find and reset player
	var player = get_node_or_null("Player")
	if not player:
		return
	
	# Wait a few frames for physics to initialize properly
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reset death state if player was dead
	if player.has_method("reset_death_state"):
		player.reset_death_state()
	
	# Check if player is in problematic state
	var needs_reset = false
	var current_state_name = ""
	if player.has_node("StateMachine"):
		var state_machine = player.get_node("StateMachine")
		if state_machine and "current_state" in state_machine:
			var current_state = state_machine.current_state
			if current_state and "name" in current_state:
				current_state_name = current_state.name
				if current_state_name == "Fall":
					needs_reset = true
	
	# Also check if player is in air or has non-zero velocity
	if not needs_reset:
		if "velocity" in player:
			if player.velocity.length_squared() > 100.0:  # Significant velocity
				needs_reset = true
		if player.has_method("is_on_floor"):
			if not player.is_on_floor():
				needs_reset = true
	
	if needs_reset:
		# Force player to ground using raycast
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + Vector2(0, 1000))
		query.collision_mask = 1  # Ground layer
		var result = space_state.intersect_ray(query)
		
		if result:
			var ground_pos = result.get("position", player.global_position)
			player.global_position = ground_pos
			# Move slightly up to ensure player is on top of ground
			player.global_position.y -= 5.0
		else:
			# No ground found, place at safe default position
			player.global_position = Vector2(2, 0)
		
		# Reset all physics state
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		if "was_on_floor" in player:
			player.was_on_floor = true
		if "is_jumping" in player:
			player.is_jumping = false
		if "has_double_jumped" in player:
			player.has_double_jumped = false
		if "can_double_jump" in player:
			player.can_double_jump = false
		if "coyote_timer" in player:
			player.coyote_timer = 0.0
		
		# Force state transition to idle
		if player.has_node("StateMachine"):
			var state_machine = player.get_node("StateMachine")
			if state_machine and state_machine.has_method("transition_to"):
				state_machine.transition_to("Idle", true)  # Force transition

# Verilen bina sahnesini belirtilen pozisyona yerleştirir (Artık VillageManager'da)
# func place_building(building_scene: PackedScene, position: Vector2) -> void:
# 	var new_building = building_scene.instantiate()
# 	# Binayı 'PlacedBuildings' altına ekle
# 	placed_buildings_node.add_child(new_building)
# 	new_building.global_position = position
# 	print("Bina inşa edildi: ", new_building.name, " at ", position)
# 	# UI'ların güncellenmesi için sinyal yay
# 	VillageManager.emit_signal("village_data_changed")

# --- Köylü Ekleme Fonksiyonu ---
func _on_add_villager_button_pressed() -> void:
	VillageManager.add_villager()
	# UI'ları sadece açıksa güncelle
	if worker_assignment_ui and worker_assignment_ui.visible: worker_assignment_ui.update_ui()
	if cariye_management_ui and cariye_management_ui.visible:
		cariye_management_ui.populate_cariye_list() # Veya daha genel bir update fonksiyonu varsa o çağrılır

# Belki UI'ın içindeki Kapat butonu yerine burada Esc ile kapatmak istersin? (Opsiyonel)
# func _input(event):
# 	if event.is_action_pressed("ui_cancel") and worker_assignment_ui.visible:
# 		worker_assignment_ui.hide()

func _input(event: InputEvent) -> void:
	# Block time forwarding inputs when dialogue window is open
	if VillageManager.active_dialogue_npc != null:
		return
	
	if event.is_action_pressed("open_world_map"):
		var scene_manager = get_node_or_null("/root/SceneManager")
		if scene_manager and scene_manager.has_method("change_to_world_map"):
			scene_manager.change_to_world_map({"source": "village"})
		get_viewport().set_input_as_handled()
		return

	# Sadece klavye tuş basımlarını dinle
	if event is InputEventKey and event.pressed and not event.is_echo():
		# 1 tuşu: Normal hız (x1)
		if event.keycode == KEY_1:
			if time_manager: # Null kontrolü
				time_manager.set_time_scale_index(0)
		# 2 tuşu: Hızlı hız (x4)
		elif event.keycode == KEY_2:
			if time_manager:
				time_manager.set_time_scale_index(1)
		# 3 tuşu: Çok hızlı hız (x16)
		elif event.keycode == KEY_3:
			if time_manager:
				time_manager.set_time_scale_index(2)
		# Veya 'T' tuşu ile hızlar arasında geçiş yap (isteğe bağlı)
		elif event.keycode == KEY_T:
			if time_manager:
				time_manager.cycle_time_scale()
		# 'N' tuşuna basıldığında yeni işçi ekle (DEBUG)
		elif event.keycode == KEY_N:
			# VillageManager autoload ise direkt çağır:
			VillageManager._add_new_worker({})
			# Eğer autoload değilse ve yukarıdaki gibi @onready ile aldıysak:
			# if village_manager: village_manager._add_new_worker()
			print("DEBUG: 'N' key pressed, attempting to add new worker.")
		
		# 'M' tuşuna basıldığında rastgele işçi sil (DEBUG)
		elif event.keycode == KEY_M:
			var worker_ids = VillageManager.get_active_worker_ids() # VillageManager'da bu fonksiyonu eklememiz gerekecek
			if not worker_ids.is_empty():
				var random_worker_id = worker_ids.pick_random()
				print("DEBUG: 'M' key pressed, attempting to remove random worker: %d" % random_worker_id)
				VillageManager.remove_worker_from_village(random_worker_id)
			else:
				print("DEBUG: 'M' key pressed, but no active workers to remove.")
		elif event.alt_pressed:
			if event.keycode == KEY_UP:
				_try_move_on_world_map(0, -1)
			elif event.keycode == KEY_DOWN:
				_try_move_on_world_map(0, 1)
			elif event.keycode == KEY_LEFT:
				_try_move_on_world_map(-1, 0)
			elif event.keycode == KEY_RIGHT:
				_try_move_on_world_map(1, 0)
		
# Debug methods for testing NPCs (only in editor/debug builds)
func setup_example_npcs() -> void:
	# This method is intentionally empty - it's for debug/testing only
	# In exported builds, this won't be called due to OS.has_feature check
	pass

func print_dialogue_test_instructions() -> void:
	# This method is intentionally empty - it's for debug/testing only
	pass

# --- Kamera Sınırları ---
func _setup_camera_limits() -> void:
	# Önce Marker2D node'larını kontrol et (görsel sınır belirleme için)
	# Marker'lar CameraLimits node'unun altında
	var left_marker = get_node_or_null("CameraLimits/CameraLeftLimit")
	var right_marker = get_node_or_null("CameraLimits/CameraRightLimit")
	
	# Eğer Marker2D node'ları varsa, onların pozisyonlarını kullan
	var final_left_limit = camera_left_limit
	var final_right_limit = camera_right_limit
	
	if left_marker and left_marker is Marker2D:
		final_left_limit = left_marker.global_position.x
		print("[VillageScene] Using CameraLeftLimit Marker2D position: ", final_left_limit)
	
	if right_marker and right_marker is Marker2D:
		final_right_limit = right_marker.global_position.x
		print("[VillageScene] Using CameraRightLimit Marker2D position: ", final_right_limit)
	
	# Oyuncuyu bul
	var player = get_node_or_null("Player")
	if not player:
		print("[VillageScene] Warning: Player not found for camera limits setup")
		return
	
	# Oyuncunun kamerasını bul
	var camera = player.get_node_or_null("Camera2D")
	if not camera:
		print("[VillageScene] Warning: Player Camera2D not found")
		return
	
	# Eğer kamera zaten VillageCameraController scriptine sahipse, sadece limitleri güncelle
	if camera.get_script() and camera.get_script().resource_path.ends_with("VillageCameraController.gd"):
		camera.left_limit = final_left_limit
		camera.right_limit = final_right_limit
		print("[VillageScene] Updated camera limits: left=", final_left_limit, " right=", final_right_limit)
		return
	
	# VillageCameraController scriptini ekle
	var camera_script = load("res://village/scripts/VillageCameraController.gd")
	if camera_script:
		camera.set_script(camera_script)
		# Script eklendikten sonra limitleri ayarla ve _ready()'nin çalışması için bekle
		await get_tree().process_frame
		camera.left_limit = final_left_limit
		camera.right_limit = final_right_limit
		# _initialize_player'ı manuel çağır (eğer _ready() çalışmadıysa)
		if camera.has_method("_initialize_player"):
			camera.call_deferred("_initialize_player")
		print("[VillageScene] Added VillageCameraController to player camera with limits: left=", final_left_limit, " right=", final_right_limit)
	else:
		print("[VillageScene] Error: Could not load VillageCameraController.gd")
	# In exported builds, this won't be called due to OS.has_feature check
	pass

func _setup_world_map_panel() -> void:
	if world_map_panel != null:
		return
	world_map_panel = PanelContainer.new()
	world_map_panel.name = "WorldMapPanel"
	world_map_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	world_map_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	world_map_panel.position = Vector2(1220, 90)
	world_map_panel.custom_minimum_size = Vector2(520, 230)
	add_child(world_map_panel)
	var vb := VBoxContainer.new()
	world_map_panel.add_child(vb)
	var title := Label.new()
	title.text = "Hex Harita (Alt + yon tuslari kesif | Numpad Enter / Select: dunya haritasi ac/kapat)"
	vb.add_child(title)
	world_map_label = Label.new()
	world_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_map_label.text = "Harita yukleniyor..."
	vb.add_child(world_map_label)

func _connect_world_map_signals() -> void:
	var wm = get_node_or_null("/root/WorldManager")
	if not wm:
		return
	if wm.has_signal("world_map_updated") and not wm.world_map_updated.is_connected(_refresh_world_map_panel):
		wm.world_map_updated.connect(_refresh_world_map_panel)
	if wm.has_signal("world_map_tile_discovered") and not wm.world_map_tile_discovered.is_connected(_on_world_map_tile_discovered):
		wm.world_map_tile_discovered.connect(_on_world_map_tile_discovered)

func _on_world_map_tile_discovered(_tile_key: String, _tile_data: Dictionary) -> void:
	_refresh_world_map_panel()

func _refresh_world_map_panel() -> void:
	if world_map_label == null:
		return
	var wm = get_node_or_null("/root/WorldManager")
	if not wm:
		world_map_label.text = "WorldManager bulunamadi."
		return
	if wm.has_method("get_world_map_state") and wm.has_method("get_discovered_settlements"):
		var map_state: Dictionary = wm.get_world_map_state()
		var tiles: Dictionary = map_state.get("tiles", {})
		var discovered_count: int = 0
		var visible_count: int = 0
		for key in tiles.keys():
			var t = tiles[key]
			if bool(t.get("discovered", false)):
				discovered_count += 1
			if bool(t.get("visible", false)):
				visible_count += 1
		var pos: Dictionary = map_state.get("player_pos", {"q": 0, "r": 0})
		var discovered_settlements: Array = wm.get_discovered_settlements()
		var lines: PackedStringArray = []
		lines.append("Seed: %s  Radius: %d" % [str(map_state.get("seed", 0)), int(map_state.get("radius", 0))])
		lines.append("Konum: q=%d r=%d" % [int(pos.get("q", 0)), int(pos.get("r", 0))])
		lines.append("Kesif: %d/%d tile  |  Gorunen: %d" % [discovered_count, tiles.size(), visible_count])
		if discovered_settlements.is_empty():
			lines.append("Kesfedilen komsu koy: henuz yok")
		else:
			lines.append("Kesfedilen komsu koyler:")
			for s in discovered_settlements:
				lines.append("- %s (%d,%d)" % [s.get("name", "?"), int(s.get("q", 0)), int(s.get("r", 0))])
		world_map_label.text = "\n".join(lines)

func _try_move_on_world_map(dq: int, dr: int) -> void:
	var wm = get_node_or_null("/root/WorldManager")
	if not wm or not wm.has_method("get_world_map_state") or not wm.has_method("move_player_on_world_map"):
		return
	var state: Dictionary = wm.get_world_map_state()
	var pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
	var target_q: int = int(pos.get("q", 0)) + dq
	var target_r: int = int(pos.get("r", 0)) + dr
	wm.move_player_on_world_map(target_q, target_r)
