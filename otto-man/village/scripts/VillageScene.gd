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

# TimeManager node'una referans lazım (eğer farklı bir yolla erişiyorsanız ona göre ayarlayın)
@onready var time_manager: TimeManager = get_node("/root/TimeManager") # Veya doğru yolu kullanın

# <<< YENİ: NPC Dialogue System Variables >>>
# Track all dialogue-enabled NPCs in the scene
var dialogue_npcs: Array[Node] = []
# Currently active dialogue NPC (if any)
var active_dialogue_npc: Node = null
# <<< YENİ SONU >>>

func _ready() -> void:
	# VillageManager'a bu sahneyi tanıt
	VillageManager.register_village_scene(self)

	# Sinyalleri bağla (Eski inşa buton bağlantıları kaldırıldı)
	open_worker_ui_button.pressed.connect(_on_open_worker_ui_button_pressed)
	open_cariye_ui_button.pressed.connect(_on_open_cariye_ui_button_pressed)
	add_villager_button.pressed.connect(VillageManager.add_villager)

	# UI görünürlük sinyallerini bağla
	worker_assignment_ui.visibility_changed.connect(_on_worker_ui_visibility_changed)
	cariye_management_ui.visibility_changed.connect(_on_cariye_ui_visibility_changed) # Yeni panel bağlandı

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

# --- UI Açma / Kapatma Fonksiyonları ---
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
			VillageManager._add_new_worker()
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
		
		# <<< YENİ: Dialogue System Test Keys >>>
		# 'F' tuşu: Test dialogue with closest NPC
		elif event.keycode == KEY_F:
			test_dialogue_with_closest_npc()
		
		# 'G' tuşu: Test "Hello" dialogue with closest NPC
		elif event.keycode == KEY_G:
			test_simple_greeting()
		# <<< YENİ SONU >>>

	# Varsa diğer _input kodları...

# <<< YENİ: NPC Dialogue System Methods >>>

# Set up a worker as an NPC with dialogue capability
# This should be called after a worker is added to the scene
func setup_worker_as_npc(worker: Node, npc_name: String, initial_info: Dictionary = {}, initial_history: Array = []):
	if not worker.has_method("initialize_as_npc"):
		printerr("VillageScene: Worker does not have dialogue capability!")
		return
	
	# Initialize the worker as an NPC
	worker.initialize_as_npc(npc_name, initial_info, initial_history)
	
	# Connect to the worker's dialogue signal
	if not worker.is_connected("show_dialogue_to_player", Callable(self, "_on_npc_dialogue_response")):
		var error_code = worker.connect("show_dialogue_to_player", Callable(self, "_on_npc_dialogue_response"))
		if error_code == OK:
			print("VillageScene: Connected to dialogue signal for %s" % npc_name)
		else:
			printerr("VillageScene: Failed to connect to dialogue signal for %s: Error %d" % [npc_name, error_code])
	
	# Add to our tracking list
	dialogue_npcs.append(worker)
	print("VillageScene: Set up %s as dialogue NPC" % npc_name)

# Handle NPC dialogue responses (this is where you'll connect to your UI)
func _on_npc_dialogue_response(npc_name: String, dialogue_text: String):
	print("VillageScene: NPC %s says: '%s'" % [npc_name, dialogue_text])
	# TODO: You'll implement the UI display here
	# For now, just print to console
	# Example: DialogueUI.show_dialogue(npc_name, dialogue_text)

# Find the closest NPC to a given position within max_distance
func get_closest_npc(position: Vector2, max_distance: float = 200.0) -> Node:
	var closest_npc: Node = null
	var closest_distance: float = max_distance
	
	for npc in dialogue_npcs:
		if not is_instance_valid(npc) or not npc.can_start_dialogue():
			continue
			
		var distance = position.distance_to(npc.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_npc = npc
	
	return closest_npc

# <<< YENİ: Helper function to get nearby NPCs >>>
# Get all NPCs within a certain distance
func get_nearby_npcs(position: Vector2, max_distance: float = 200.0) -> Array:
	var nearby_npcs: Array = []
	
	for npc in dialogue_npcs:
		if not is_instance_valid(npc):
			continue
			
		var distance = position.distance_to(npc.global_position)
		if distance <= max_distance:
			var npc_info = {
				"npc": npc,
				"distance": distance,
				"name": npc.get_dialogue_name() if npc.has_method("get_dialogue_name") else "Unknown",
				"can_dialogue": npc.can_start_dialogue() if npc.has_method("can_start_dialogue") else false
			}
			nearby_npcs.append(npc_info)
	
	# Sort by distance
	nearby_npcs.sort_custom(func(a, b): return a.distance < b.distance)
	return nearby_npcs
# <<< YENİ SONU >>>

# Start dialogue with a specific NPC
func start_dialogue_with_npc(npc: Node, player_input: String):
	if not is_instance_valid(npc) or not npc.has_method("start_dialogue"):
		printerr("VillageScene: Invalid NPC or NPC doesn't support dialogue!")
		return
	
	if not npc.can_start_dialogue():
		print("VillageScene: NPC cannot start dialogue in current state")
		return
	
	active_dialogue_npc = npc
	npc.start_dialogue(player_input)

# Example: Set up some test NPCs (call this after workers are created)
func setup_example_npcs():
	# Get some workers from the scene to turn into NPCs
	var workers_container = get_node_or_null("WorkersContainer")
	if not is_instance_valid(workers_container):
		print("VillageScene: No WorkersContainer found for NPC setup")
		return
	
	var worker_count = 0
	for child in workers_container.get_children():
		if child.has_method("initialize_as_npc"):
			worker_count += 1
			
			# Set up first worker as "Osman" - based on your example
			if worker_count == 1:
				var osman_info = {
					"Name": "Osman",
					"Occupation": "Village Worker",
					"Mood": "Content", 
					"Gender": "Male",
					"Age": "35",
					"Health": "Good"
				}
				var osman_history = [
					"Grew up in this village",
					"Started working as a laborer at age 16",
					"Known for his reliability and strong work ethic"
				]
				# Initialize with empty DialogueHistory - it will be populated as conversations happen
				var osman_dialogue_history = {}
				
				# Set up the NPC state manually to match your format
				child.initialize_as_npc("Osman", osman_info, osman_history)
				# Override the DialogueHistory to match your format if needed
				child.npc_state["DialogueHistory"] = osman_dialogue_history
			
			# Set up second worker as "Kamil" - based on your example
			elif worker_count == 2:
				var kamil_info = {
					"Name": "Kamil",
					"Occupation": "Logger",
					"Mood": "Depressed",
					"Gender": "Male",
					"Age": "25",
					"Health": "Injured"
				}
				var kamil_history = [
					"Witnessed the murder of his own mother",
					"Fell in love with a girl in the same village",
					"Sprained own ankle"
				]
				# Add initial DialogueHistory matching your example format
				var kamil_dialogue_history = {
					"Dialogue with Bandits": {
						"speaker": "If you want to take revenge some day, I'll be waiting for you, and I'll be ready.",
						"self": "*cries in agony*"
					}
				}
				
				# Set up the NPC
				child.initialize_as_npc("Kamil", kamil_info, kamil_history)
				# Override the DialogueHistory to match your format
				child.npc_state["DialogueHistory"] = kamil_dialogue_history
			
			# Only set up first 2 workers as NPCs for now
			if worker_count >= 2:
				break
	
	print("VillageScene: Set up %d NPCs for dialogue" % worker_count)

# <<< YENİ: Test Dialogue Functions >>>

# Test dialogue with the closest NPC to the player
func test_dialogue_with_closest_npc():
	# Get player position (assuming Player node exists)
	var player = get_node_or_null("Player")
	if not is_instance_valid(player):
		print("VillageScene: No Player node found for dialogue test")
		return
	
	# Check for nearby NPCs first
	var nearby_npcs = get_nearby_npcs(player.global_position, 200.0)
	print("VillageScene: Found %d nearby NPCs within 200 units" % nearby_npcs.size())
	
	var closest_npc = get_closest_npc(player.global_position, 200.0)
	if is_instance_valid(closest_npc):
		var npc_name = closest_npc.get_dialogue_name()
		var distance = player.global_position.distance_to(closest_npc.global_position)
		print("VillageScene: Testing dialogue with %s (distance: %.1f)" % [npc_name, distance])
		
		# Provide different dialogue based on NPC
		if npc_name == "Kamil":
			start_dialogue_with_npc(closest_npc, "I heard about your mother. I'm sorry for your loss.")
		elif npc_name == "Osman":
			start_dialogue_with_npc(closest_npc, "How's the work been treating you lately?")
		else:
			start_dialogue_with_npc(closest_npc, "How are you today?")
	else:
		print("VillageScene: No NPCs nearby for dialogue test. Move closer to an NPC and try again.")
		print("VillageScene: Make sure NPCs are visible and in AWAKE_IDLE or SOCIALIZING state.")

# Test simple greeting
func test_simple_greeting():
	var player = get_node_or_null("Player")
	if not is_instance_valid(player):
		print("VillageScene: No Player node found for greeting test")
		return
	
	var closest_npc = get_closest_npc(player.global_position, 200.0)
	if is_instance_valid(closest_npc):
		var npc_name = closest_npc.get_dialogue_name()
		var distance = player.global_position.distance_to(closest_npc.global_position)
		print("VillageScene: Testing greeting with %s (distance: %.1f)" % [npc_name, distance])
		start_dialogue_with_npc(closest_npc, "Hello!")
	else:
		print("VillageScene: No NPCs nearby for greeting test. Move closer to an NPC and try again.")

# <<< YENİ SONU: Test Dialogue Functions >>>

# Print instructions for testing
func print_dialogue_test_instructions():
	print("=== NPC Dialogue System Test Instructions ===")
	print("F key: Test contextual dialogue with closest NPC")
	print("G key: Test simple greeting with closest NPC") 
	print("Move close to an NPC (you'll see their name above them)")
	print("NPCs must be visible and in AWAKE_IDLE or SOCIALIZING state")
	print("==============================================")

# <<< YENİ SONU: NPC Dialogue System Methods >>>
