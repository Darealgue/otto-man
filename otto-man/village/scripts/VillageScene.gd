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
@onready var add_villager_button = $AddVillagerButton
@onready var placed_buildings_node = $PlacedBuildings
@onready var plot_markers_node = $PlotMarkers
@onready var time_manager: TimeManager = get_node("/root/TimeManager") # Veya doğru yolu kullanın
@onready var time_skip_notification = $TimeSkipNotification



func _ready() -> void:
	# VillageManager'a bu sahneyi tanıt
	VillagerAiInitializer.LoadComplete.connect(VillagersLoaded)

	# Sinyalleri bağla (Eski inşa buton bağlantıları kaldırıldı)
	open_worker_ui_button.pressed.connect(_on_open_worker_ui_button_pressed)
	open_cariye_ui_button.pressed.connect(_on_open_cariye_ui_button_pressed)
	add_villager_button.pressed.connect(VillageManager.add_villager)
	# UI görünürlük sinyallerini bağla
	worker_assignment_ui.visibility_changed.connect(_on_worker_ui_visibility_changed)
	cariye_management_ui.visibility_changed.connect(_on_cariye_ui_visibility_changed) # Yeni panel bağlandı
	
	# Connect time skip notification signal
	if not VillageManager.time_skip_completed.is_connected(_on_time_skip_completed):
		VillageManager.time_skip_completed.connect(_on_time_skip_completed)
		print("[VillageScene] ✅ Connected time_skip_completed signal")
	else:
		print("[VillageScene] Signal already connected")
	
	# Debug: Check notification node
	if time_skip_notification:
		print("[VillageScene] ✅ TimeSkipNotification node found: ", time_skip_notification)
	else:
		print("[VillageScene] ⚠️ TimeSkipNotification node NOT found!")

	# Başlangıçta UI'ları gizle
	worker_assignment_ui.hide()
	cariye_management_ui.hide()
	# Açma butonlarını göster
	open_worker_ui_button.show()
	open_cariye_ui_button.show()

	# <<< YENİ: Set up example NPCs after the scene is fully loaded >>>
	# Use call_deferred to ensure all workers are created first
	call_deferred("setup_example_npcs")
	# Print instructions for testing
	call_deferred("print_dialogue_test_instructions")
	# <<< YENİ SONU >>>
	Load_Existing_Villagers()
	VillageManager.apply_current_time_schedule()
	
	# Reset player state after scene load (fix fall state bug)
	call_deferred("_reset_player_on_scene_load")
# --- UI Açma / Kapatma Fonksiyonları ---

func Load_Existing_Villagers():
	VillagerAiInitializer.Load_existing_villagers()

func VillagersLoaded():
	VillageManager.register_village_scene(self)
	call_deferred("_refresh_npc_schedule")

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

func _on_time_skip_completed(total_hours: float, produced_resources: Dictionary) -> void:
	print("[VillageScene] _on_time_skip_completed called: %.1f hours, resources: %s" % [total_hours, produced_resources])
	# Use call_deferred to ensure scene is fully loaded
	call_deferred("_show_notification_deferred", total_hours, produced_resources)

func _show_notification_deferred(total_hours: float, produced_resources: Dictionary) -> void:
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
	time_skip_notification.show_time_skip_notification(total_hours, produced_resources)

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
		
