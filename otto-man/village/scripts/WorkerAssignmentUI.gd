# otto-man/village/scripts/WorkerAssignmentUI.gd
extends PanelContainer

# UI Elemanlarına Referanslar (unique_name_in_owner sayesinde % ile erişeceğiz)
@onready var idle_value_label: Label = %IdleValueLabel

# Resource Row Containers
@onready var wood_hbox: HBoxContainer = %WoodHBox
@onready var stone_hbox: HBoxContainer = %StoneHBox
@onready var food_hbox: HBoxContainer = %FoodHBox
@onready var water_hbox: HBoxContainer = %WaterHBox
@onready var metal_hbox: HBoxContainer = %MetalHBox
@onready var bread_hbox: HBoxContainer = %BreadHBox

# Labels within rows
@onready var wood_level_label: Label = %WoodLevelLabel
@onready var stone_level_label: Label = %StoneLevelLabel
@onready var food_level_label: Label = %FoodLevelLabel
@onready var water_level_label: Label = %WaterLevelLabel
@onready var metal_level_label: Label = %MetalLevelLabel
@onready var bread_level_label: Label = %BreadLevelLabel

@onready var wood_level_indicator: Label = %WoodLevelIndicator
@onready var stone_level_indicator: Label = %StoneLevelIndicator
@onready var food_level_indicator: Label = %FoodLevelIndicator
@onready var water_level_indicator: Label = %WaterLevelIndicator
@onready var metal_level_indicator: Label = %MetalLevelIndicator
@onready var bread_level_indicator: Label = %BreadLevelIndicator

@onready var add_wood_button: Button = %AddWoodButton
@onready var remove_wood_button: Button = %RemoveWoodButton
@onready var upgrade_wood_button: Button = %UpgradeWoodButton

@onready var add_stone_button: Button = %AddStoneButton
@onready var remove_stone_button: Button = %RemoveStoneButton
@onready var upgrade_stone_button: Button = %UpgradeStoneButton

@onready var add_food_button: Button = %AddFoodButton
@onready var remove_food_button: Button = %RemoveFoodButton
@onready var upgrade_food_button: Button = %UpgradeFoodButton

@onready var add_water_button: Button = %AddWaterButton
@onready var remove_water_button: Button = %RemoveWaterButton
@onready var upgrade_water_button: Button = %UpgradeWaterButton

@onready var add_metal_button: Button = %AddMetalButton
@onready var remove_metal_button: Button = %RemoveMetalButton
@onready var upgrade_metal_button: Button = %UpgradeMetalButton

@onready var add_bread_button: Button = %AddBreadButton
@onready var remove_bread_button: Button = %RemoveBreadButton
@onready var upgrade_bread_button: Button = %UpgradeBreadButton

@onready var close_button: Button = %CloseButton

# --- YENİ: Bina Sahne Yolları (BuildMenuUI ile aynı olmalı) ---
const WOODCUTTER_SCENE = "res://village/buildings/WoodcutterCamp.tscn"
const STONE_MINE_SCENE = "res://village/buildings/StoneMine.tscn"
const HUNTER_HUT_SCENE = "res://village/buildings/HunterGathererHut.tscn"
const WELL_SCENE = "res://village/buildings/Well.tscn"
const BAKERY_SCENE = "res://village/buildings/Bakery.tscn"

# Eski Script Yolu Sabitleri (Sadece add/remove buton bağlantıları için kalabilir)
const WOOD_SCRIPT = "res://village/scripts/WoodcutterCamp.gd"
const STONE_SCRIPT = "res://village/scripts/StoneMine.gd"
const FOOD_SCRIPT = "res://village/scripts/HunterGathererHut.gd"
const WATER_SCRIPT = "res://village/scripts/Well.gd"
const BREAD_SCRIPT = "res://village/scripts/Bakery.gd"

# --- Periyodik Güncelleme ---
var update_interval: float = 0.5 # Saniyede 2 kez güncelle
var time_since_last_update: float = 0.0
# ---------------------------

func _ready() -> void:
	# Null Check for Idle Label
	if not idle_value_label:
		printerr("WorkerAssignmentUI Error: Node not found - IdleValueLabel")
	
	# Buton sinyallerini bağla
	add_wood_button.pressed.connect(_on_add_worker_pressed.bind("wood", WOOD_SCRIPT)) 
	remove_wood_button.pressed.connect(_on_remove_worker_pressed.bind("wood", WOOD_SCRIPT)) 
	add_stone_button.pressed.connect(_on_add_worker_pressed.bind("stone", STONE_SCRIPT)) 
	remove_stone_button.pressed.connect(_on_remove_worker_pressed.bind("stone", STONE_SCRIPT)) 
	add_food_button.pressed.connect(_on_add_worker_pressed.bind("food", FOOD_SCRIPT)) 
	remove_food_button.pressed.connect(_on_remove_worker_pressed.bind("food", FOOD_SCRIPT)) 
	add_water_button.pressed.connect(_on_add_worker_pressed.bind("water", WATER_SCRIPT)) 
	remove_water_button.pressed.connect(_on_remove_worker_pressed.bind("water", WATER_SCRIPT))
	add_bread_button.pressed.connect(_on_add_worker_pressed.bind("bread", BREAD_SCRIPT))
	remove_bread_button.pressed.connect(_on_remove_worker_pressed.bind("bread", BREAD_SCRIPT))

	# Upgrade Buttons - DÜZELTME: Sahne yolunu bind et
	upgrade_wood_button.pressed.connect(_on_upgrade_button_pressed.bind(WOODCUTTER_SCENE))
	upgrade_stone_button.pressed.connect(_on_upgrade_button_pressed.bind(STONE_MINE_SCENE))
	upgrade_food_button.pressed.connect(_on_upgrade_button_pressed.bind(HUNTER_HUT_SCENE))
	upgrade_water_button.pressed.connect(_on_upgrade_button_pressed.bind(WELL_SCENE))
	upgrade_bread_button.pressed.connect(_on_upgrade_button_pressed.bind(BAKERY_SCENE)) # Ekmek için de bağlayalım (ama buton hala pasif)

	close_button.pressed.connect(_on_close_button_pressed)
	
	# VillageManager'dan sinyal gelince UI'ı güncellemek için:
	# --- BU BAĞLANTIYI KALDIRIYORUZ/YORUMLUYORUZ ---
#	if VillageManager.has_signal("building_state_changed"):
#		# Bağlantıyı dene ve sonucu kontrol et
#		var error = VillageManager.building_state_changed.connect(update_ui)
#		if error == OK:
#			print("WorkerAssignmentUI: Successfully connected to VillageManager.building_state_changed") # DEBUG
#		else:
#			printerr("WorkerAssignmentUI: FAILED to connect to VillageManager.building_state_changed, error code: %s" % error) # DEBUG
#	else:
#		printerr("WorkerAssignmentUI: VillageManager does not have building_state_changed signal!")
	# ---------------------------------------------

	# Eski village_data_changed bağlantısını kaldır (varsa)
	if VillageManager.has_signal("village_data_changed") and VillageManager.is_connected("village_data_changed", update_ui):
		VillageManager.disconnect("village_data_changed", update_ui)

	# Başlangıç odağını ayarla (Gamepad için)
	# Mümkünse ilk satırdaki ekle butonuna odaklan
	if add_wood_button.visible and not add_wood_button.disabled:
		add_wood_button.grab_focus()
	elif add_stone_button.visible and not add_stone_button.disabled: # Eğer odun yoksa taşa bak
		add_stone_button.grab_focus()
	# TODO: Diğer kaynaklar için benzer kontroller eklenebilir (food, water, bread)
	elif close_button.visible and not close_button.disabled: # Hiçbiri uygun değilse kapat butonuna odaklan
		close_button.grab_focus()

func _process(delta: float) -> void:
	# Panel görünür değilse hiçbir şey yapma
	if not visible:
		time_since_last_update = 0.0 # Görünmezken sayacı sıfırla
		return

	# Zamanı artır
	time_since_last_update += delta

	# Eğer interval dolduysa UI'ı güncelle
	if time_since_last_update >= update_interval:
		# print("WorkerAssignmentUI: Updating UI via _process timer") # Opsiyonel Debug
		update_ui()
		time_since_last_update = 0.0 # Sayacı sıfırla

# Arayüzdeki etiketleri VillageManager'dan alınan verilerle günceller
func update_ui() -> void:
	#print("WorkerAssignmentUI: update_ui ENTERED") # <<< YENİ PRINT
	#print("WorkerAssignmentUI: update_ui CALLED (Signal received or manual call)") # DEBUG
	# Eğer UI görünür değilse güncelleme yapma
	if not visible:
		#print("WorkerAssignmentUI: update_ui returning early because not visible.") # DEBUG
		return

	if not is_node_ready(): await ready
	
	# --- YENİ: building_plots_node referansını burada al ---
	var current_building_plots_node = get_tree().current_scene.get_node_or_null("PlacedBuildings")
	if not current_building_plots_node:
		#printerr("WorkerAssignmentUI: update_ui - PlacedBuildings node could not be found!")
		return # Eğer node bulunamazsa devam etme
	# ----------------------------------------------------

	# Update Labels
	# --- IDLE LABEL DEBUG --- 
	if idle_value_label:
		var current_idle = VillageManager.idle_workers
		#print("WorkerAssignmentUI DEBUG: Updating idle_value_label. Current VillageManager.idle_workers: ", current_idle) # DEBUG
		idle_value_label.text = str(current_idle)
	#else:
		#print("WorkerAssignmentUI DEBUG: Cannot update idle_value_label because it is null.") # DEBUG
	# --- IDLE LABEL DEBUG SONU ---
	
	wood_level_label.text = str(VillageManager.get_resource_level("wood"))
	stone_level_label.text = str(VillageManager.get_resource_level("stone"))
	food_level_label.text = str(VillageManager.get_resource_level("food"))
	water_level_label.text = str(VillageManager.get_resource_level("water"))
	metal_level_label.text = str(VillageManager.resource_levels["metal"])

	# Update Button States
	var idle_available = VillageManager.idle_workers > 0

	# Find first building of each type - Sahne Yolu Kullan
	#print("DEBUG update_ui: Finding wood building...") # DEBUG
	var wood_building = _find_first_building(WOODCUTTER_SCENE, current_building_plots_node) # <-- Değişiklik
	#print("DEBUG update_ui: wood_building result: ", wood_building) # DEBUG

	#print("DEBUG update_ui: Finding stone building...") # DEBUG
	var stone_building = _find_first_building(STONE_MINE_SCENE, current_building_plots_node) # <-- Değişiklik
	#print("DEBUG update_ui: stone_building result: ", stone_building) # DEBUG

	#print("DEBUG update_ui: Finding food building...") # DEBUG
	var food_building = _find_first_building(HUNTER_HUT_SCENE, current_building_plots_node)
	#print("DEBUG update_ui: food_building result: ", food_building) # DEBUG
	#print("DEBUG update_ui: Finding water building...") # DEBUG
	var water_building = _find_first_building(WELL_SCENE, current_building_plots_node)
	#print("DEBUG update_ui: water_building result: ", water_building) # DEBUG
	#print("DEBUG update_ui: Finding bread building...") # DEBUG
	var bread_building = _find_first_building(BAKERY_SCENE, current_building_plots_node)
	#print("DEBUG update_ui: bread_building result: ", bread_building) # DEBUG

	# --- Wood Row Visibility & Buttons & Level ---
	var wood_building_exists = wood_building != null
	wood_hbox.visible = wood_building_exists
	#print("DEBUG update_ui: wood_hbox.visible set to: ", wood_hbox.visible) # DEBUG
	if wood_building_exists:
		var wood_is_upgrading = wood_building.is_upgrading
		var can_add_wood = not wood_is_upgrading and wood_building.assigned_workers < wood_building.max_workers
		var can_remove_wood = not wood_is_upgrading and wood_building.assigned_workers > 0
		add_wood_button.disabled = not (idle_available and can_add_wood)
		remove_wood_button.disabled = not can_remove_wood

		# Upgrade Wood Button - DÜZELTME: Sahne yolunu kullan
		var wood_is_max_level = wood_building.level >= wood_building.max_level
		var wood_can_meet_reqs = false
		if not wood_is_max_level:
			wood_can_meet_reqs = VillageManager.can_meet_requirements(WOODCUTTER_SCENE) # Sahne yolu

		var can_upgrade_wood = not wood_is_upgrading and not wood_is_max_level and wood_can_meet_reqs
		upgrade_wood_button.disabled = not can_upgrade_wood
		upgrade_wood_button.text = "Yükseltiliyor..." if wood_is_upgrading else "↑"
		var wood_upgrade_reqs = VillageManager.get_building_requirements(WOODCUTTER_SCENE) # Sahne yolu
		upgrade_wood_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(wood_upgrade_reqs) if not wood_upgrade_reqs.is_empty() and not wood_is_max_level else ("Maks Seviye" if wood_is_max_level else "Yükseltilemez")

		wood_level_indicator.text = "[Lv. %d]" % wood_building.level
		wood_level_label.text = str(VillageManager.get_resource_level("wood")) # resource_levels yerine get_resource_level kullan


	# --- Stone Row Visibility & Buttons & Level ---
	var stone_building_exists = stone_building != null
	stone_hbox.visible = stone_building_exists
	#print("DEBUG update_ui: stone_hbox.visible set to: ", stone_hbox.visible) # DEBUG
	if stone_building_exists:
		var stone_is_upgrading = stone_building.is_upgrading
		var can_add_stone = not stone_is_upgrading and stone_building.assigned_workers < stone_building.max_workers
		var can_remove_stone = not stone_is_upgrading and stone_building.assigned_workers > 0
		add_stone_button.disabled = not (idle_available and can_add_stone)
		remove_stone_button.disabled = not can_remove_stone

		# Upgrade Stone Button - DÜZELTME: Sahne yolunu kullan
		var stone_is_max_level = stone_building.level >= stone_building.max_level
		var stone_can_meet_reqs = false
		if not stone_is_max_level:
			stone_can_meet_reqs = VillageManager.can_meet_requirements(STONE_MINE_SCENE) # Sahne yolu

		var can_upgrade_stone = not stone_is_upgrading and not stone_is_max_level and stone_can_meet_reqs
		upgrade_stone_button.disabled = not can_upgrade_stone
		upgrade_stone_button.text = "Yükseltiliyor..." if stone_is_upgrading else "↑"
		var stone_upgrade_reqs = VillageManager.get_building_requirements(STONE_MINE_SCENE) # Sahne yolu
		upgrade_stone_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(stone_upgrade_reqs) if not stone_upgrade_reqs.is_empty() and not stone_is_max_level else ("Maks Seviye" if stone_is_max_level else "Yükseltilemez")

		stone_level_indicator.text = "[Lv. %d]" % stone_building.level
		stone_level_label.text = str(VillageManager.get_resource_level("stone")) # resource_levels yerine get_resource_level kullan

	# --- Food Row Visibility & Buttons & Level ---
	var food_building_exists = food_building != null
	food_hbox.visible = food_building_exists
	#print("DEBUG update_ui: food_hbox.visible set to: ", food_hbox.visible) # DEBUG
	if food_building_exists:
		var food_is_upgrading = food_building.is_upgrading
		var can_add_food = not food_is_upgrading and food_building.assigned_workers < food_building.max_workers
		var can_remove_food = not food_is_upgrading and food_building.assigned_workers > 0
		add_food_button.disabled = not (idle_available and can_add_food)
		remove_food_button.disabled = not can_remove_food

		# Upgrade Food Button - DÜZELTME: Sahne yolunu kullan
		var food_is_max_level = food_building.level >= food_building.max_level
		var food_can_meet_reqs = false
		if not food_is_max_level:
			food_can_meet_reqs = VillageManager.can_meet_requirements(HUNTER_HUT_SCENE)

		var can_upgrade_food = not food_is_upgrading and not food_is_max_level and food_can_meet_reqs
		upgrade_food_button.disabled = not can_upgrade_food
		upgrade_food_button.text = "Yükseltiliyor..." if food_is_upgrading else "↑"
		var food_upgrade_reqs = VillageManager.get_building_requirements(HUNTER_HUT_SCENE)
		upgrade_food_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(food_upgrade_reqs) if not food_upgrade_reqs.is_empty() and not food_is_max_level else ("Maks Seviye" if food_is_max_level else "Yükseltilemez")

		food_level_indicator.text = "[Lv. %d]" % food_building.level
		food_level_label.text = str(VillageManager.get_resource_level("food")) # resource_levels yerine get_resource_level kullan

	# --- Water Row Visibility & Buttons & Level ---
	var water_building_exists = water_building != null
	water_hbox.visible = water_building_exists
	#print("DEBUG update_ui: water_hbox.visible set to: ", water_hbox.visible) # DEBUG
	if water_building_exists:
		var water_is_upgrading = water_building.is_upgrading
		var can_add_water = not water_is_upgrading and water_building.assigned_workers < water_building.max_workers
		var can_remove_water = not water_is_upgrading and water_building.assigned_workers > 0
		add_water_button.disabled = not (idle_available and can_add_water)
		remove_water_button.disabled = not can_remove_water

		# Upgrade Water Button - DÜZELTME: Sahne yolunu kullan
		var water_is_max_level = water_building.level >= water_building.max_level
		var water_can_meet_reqs = false
		if not water_is_max_level:
			water_can_meet_reqs = VillageManager.can_meet_requirements(WELL_SCENE)

		var can_upgrade_water = not water_is_upgrading and not water_is_max_level and water_can_meet_reqs
		upgrade_water_button.disabled = not can_upgrade_water
		upgrade_water_button.text = "Yükseltiliyor..." if water_is_upgrading else "↑"
		var water_upgrade_reqs = VillageManager.get_building_requirements(WELL_SCENE)
		upgrade_water_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(water_upgrade_reqs) if not water_upgrade_reqs.is_empty() and not water_is_max_level else ("Maks Seviye" if water_is_max_level else "Yükseltilemez")

		water_level_indicator.text = "[Lv. %d]" % water_building.level
		water_level_label.text = str(VillageManager.get_resource_level("water")) # resource_levels yerine get_resource_level kullan

	# --- Metal Row Visibility & Buttons & Level ---
	metal_hbox.visible = false
	#print("DEBUG update_ui: metal_hbox.visible set to: ", metal_hbox.visible) # DEBUG
	# Metal butonları/seviyesi için kod (bina eklenince)... 

	# --- Bread Row Visibility & Buttons & Level (Yeni) ---
	var bread_building_exists = bread_building != null
	bread_hbox.visible = bread_building_exists
	#print("DEBUG update_ui: bread_hbox.visible set to: ", bread_hbox.visible) # DEBUG
	if bread_building_exists:
		print("DEBUG (Bakery): Fırın bulundu.") 
		# Doğrudan Erişim Denemesi
		var bread_is_upgrading = bread_building.is_upgrading if "is_upgrading" in bread_building else false 
		var bread_current_workers = bread_building.assigned_workers if "assigned_workers" in bread_building else -1
		var bread_max_workers = bread_building.max_workers if "max_workers" in bread_building else 0
		print("DEBUG (Bakery): Assigned=%s, Max=%s, Upgrading=%s" % [bread_current_workers, bread_max_workers, bread_is_upgrading]) 
		
		var can_add_bread = not bread_is_upgrading and bread_current_workers < bread_max_workers
		var can_remove_bread = not bread_is_upgrading and bread_current_workers > 0
		print("DEBUG (Bakery): idle_available=%s, can_add_bread=%s, can_remove_bread=%s" % [idle_available, can_add_bread, can_remove_bread]) 
		
		add_bread_button.disabled = not (idle_available and can_add_bread)
		remove_bread_button.disabled = not can_remove_bread
		print("DEBUG (Bakery): add_button.disabled=%s, remove_button.disabled=%s" % [add_bread_button.disabled, remove_bread_button.disabled]) 
		
		# Upgrade Bread Button (Şimdilik pasif)
		upgrade_bread_button.disabled = true 
		upgrade_bread_button.text = "↑"
		upgrade_bread_button.tooltip_text = "Yükseltilemez"
		
		# Seviye Göstergesi
		var bread_level = bread_building.level if "level" in bread_building else 1 
		bread_level_indicator.text = "[Lv. %d]" % bread_level
			
		# Ekmek Miktarı Göstergesi - resource_levels'dan al
		bread_level_label.text = str(VillageManager.resource_levels.get("bread", 0))
	else: 
		if is_instance_valid(bread_level_label):
			bread_level_label.text = "0"

	# print("DEBUG: --- update_ui FINISHED ---") # Debug print'leri kapattık


# "+" butonuna basıldığında çalışır
func _on_add_worker_pressed(resource_type: String, building_script_path: String) -> void: 
	if VillageManager.idle_workers <= 0: return # Kısa kontrol

	# --- YENİ: Burada da güncel node referansını al ---
	var current_building_plots_node = get_tree().current_scene.get_node_or_null("PlacedBuildings")
	if not current_building_plots_node: 
		printerr("_on_add_worker_pressed: PlacedBuildings node could not be found!")
		return # Bulamazsa çık
	# ----------------------------------------------

	var available_building = _find_building_with_capacity(building_script_path, current_building_plots_node) # <-- Değişiklik
	if available_building and available_building.add_worker():
		print("UI: İşçi başarıyla %s binasına atandı." % building_script_path.get_file())
	else:
		print("UI: %s türünde uygun bina bulunamadı veya atama başarısız." % building_script_path.get_file())
	# update_ui() # Sinyal ile güncelleniyor olmalı


# "-" butonuna basıldığında çalışır
func _on_remove_worker_pressed(resource_type: String, building_script_path: String) -> void: 
	print("\n--- _on_remove_worker_pressed ---") # Debug
	print("Button Pressed For: %s (Script: %s)" % [resource_type, building_script_path]) # Debug

	# --- YENİ: Burada da güncel node referansını al ---
	var current_building_plots_node = get_tree().current_scene.get_node_or_null("PlacedBuildings")
	if not current_building_plots_node: 
		printerr("_on_remove_worker_pressed: PlacedBuildings node could not be found!")
		return # Bulamazsa çık
	# ----------------------------------------------
	
	var removable_building = _find_building_with_worker(building_script_path, current_building_plots_node) # <-- Değişiklik 
	print("Found Removable Building: ", removable_building) # Debug

	if removable_building: # Null kontrolü
		# remove_worker'ın dönüş değerini kontrol et (eğer varsa)
		var success = removable_building.remove_worker()
		print("removable_building.remove_worker() returned: ", success) # Debug
		if success:
			print("UI: İşçi başarıyla %s binasından çıkarıldı." % building_script_path.get_file())
		else:
			print("UI: İşçi %s binasından çıkarılamadı (remove_worker false döndü)." % building_script_path.get_file())
	else:
		print("UI: İşçi çıkarılacak %s türünde bina bulunamadı (_find_building_with_worker null döndü)." % building_script_path.get_file())

	# update_ui() # Sinyal mekanizması varsa bu gereksiz olabilir, ama şimdilik kalsın
	print("--- end _on_remove_worker_pressed ---\n") # Debug


# Helper: Belirtilen script yoluna sahip, kapasitesi dolmamış bir bina bulur
func _find_building_with_capacity(building_script_path: String, plots_node): # <-- Yeni parametre
	# print("DEBUG (find_available): Searching for available building with script: ", building_script_path)
	if plots_node == null: # Parametreyi kontrol et
		# print("DEBUG (find_available): Error - plots_node is null!")
		return null
	for building in plots_node.get_children():
		var attached_script = building.get_script()
		if attached_script != null and attached_script.resource_path == building_script_path: 
			# print("DEBUG (find_available): Found building instance with matching script: ", building.name)
			# Doğrudan Erişim Denemesi
			var upgrading = building.is_upgrading if "is_upgrading" in building else false
			var current_assigned = building.assigned_workers if "assigned_workers" in building else -1
			var current_max = building.max_workers if "max_workers" in building else 0 # Max workers get ile hesaplanıyor, doğrudan erişim güvenli olmayabilir
			# print("DEBUG (find_available):   Checking building: Assigned=", current_assigned, ", Max=", current_max, ", Upgrading=", upgrading)
			if building.has_method("add_worker") and not upgrading:
				# current_max'ı get metodu ile almak daha doğru olabilir
				var real_max = building.max_workers if "max_workers" in building else 0
				if current_assigned < real_max:
					# print("DEBUG (find_available):   Condition met! Returning this building.")
					# print("--- end _find_building_with_capacity (found) ---\n")
					return building 
				# else:
					# print("Building found but has no capacity (Assigned=%s, Max=%s)" % [current_assigned, real_max])
			# else:
				# print("Building found but no add_worker method or is upgrading.")
	# print("No suitable building found.")
	# print("--- end _find_building_with_capacity (not found) ---\n")
	return null

# Helper: Belirtilen script yoluna sahip, içinde işçi olan bir bina bulur
func _find_building_with_worker(building_script_path: String, plots_node): # <-- Yeni parametre
	print("--- _find_building_with_worker ---") # Debug - Yeni isim
	print("Searching for removable building with script: ", building_script_path) # Debug
	if plots_node == null: # Parametreyi kontrol et
		print("Error: plots_node is null!") # Debug
		return null
	for building in plots_node.get_children():
		# print("Checking building: ", building.name)
		var attached_script = building.get_script()
		if attached_script != null and attached_script.resource_path == building_script_path: 
			# print("Script match found: ", building.name)
			# Doğrudan Erişim Denemesi
			var upgrading = building.is_upgrading if "is_upgrading" in building else false
			var current_assigned = building.assigned_workers if "assigned_workers" in building else -1 # Hata durumunu görmek için -1
			# print("Checking state: Upgrading=%s, Assigned=%s" % [upgrading, current_assigned])
			if building.has_method("remove_worker") and not upgrading:
				if current_assigned > 0:
					# print("Found suitable building: ", building.name)
					# print("--- end _find_building_with_worker (found) ---\n")
					return building
				# else:
					# print("Building found but has no workers (Assigned=%s)" % current_assigned)
			# else:
				# print("Building found but no remove_worker method or is upgrading.")
	# print("No suitable building found.")
	# print("--- end _find_building_with_worker (not found) ---\n")
	return null

# Finds the first building instance with the matching scene path (Güncellendi: sahne yolu alır)
func _find_first_building(building_scene_path: String, plots_node): # <-- Yeni parametre
	if plots_node == null: return null # Parametreyi kontrol et

	for building in plots_node.get_children():
		if building.scene_file_path == building_scene_path:
			return building
	return null

# Kapat butonuna basıldığında çalışır
func _on_close_button_pressed() -> void:
	hide() # Arayüzü gizle

# Arayüz görünür olduğunda UI'ı güncellemek için (opsiyonel)
func _on_visibility_changed() -> void:
	if visible:
		update_ui()

# --- Utility ---
# Formats a cost dictionary into a readable string (e.g., "1 Odun, 2 Taş")
func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty(): return "Yok"
	var parts: Array[String] = []
	for resource_type in cost:
		parts.append("%d %s" % [cost[resource_type], resource_type.capitalize()])
	return ", ".join(parts)

# Tooltip için yeni yardımcı fonksiyon (veya mevcut _format_cost güncellenir)
func _format_requirements_tooltip(requirements: Dictionary) -> String:
	if requirements.is_empty(): return "Bilinmiyor"
	var cost = requirements.get("cost", {})
	var levels = requirements.get("requires_level", {})
	var tooltip_parts: Array[String] = []
	if not cost.is_empty():
		for resource_type in cost:
			tooltip_parts.append("%s: %d" % [resource_type.capitalize(), cost[resource_type]])
	if not levels.is_empty():
		for resource_type in levels:
			tooltip_parts.append("%s Sv: %d" % [resource_type.capitalize(), levels[resource_type]]) # "Sv" eklendi
	if tooltip_parts.is_empty(): return "Gereksinim Yok"
	return ", ".join(tooltip_parts)

# --- YENİ: Yükseltme Butonu İşleyici ---
func _on_upgrade_button_pressed(building_scene_path: String) -> void:
	print("UI: Yükseltme isteği gönderiliyor: ", building_scene_path)

	# Yükseltilecek binayı bul (Sahne yoluna göre)
	var building_to_upgrade = _find_first_building(building_scene_path, get_tree().current_scene.get_node_or_null("PlacedBuildings"))

	if building_to_upgrade:
		# Binanın kendi yükseltme fonksiyonunu çağır
		if building_to_upgrade.has_method("start_upgrade"):
			if building_to_upgrade.start_upgrade():
				print("UI: %s yükseltmesi başlatıldı." % building_scene_path.get_file())
				# Yükseltme başladığı için UI'ı hemen güncelle
				update_ui()
			else:
				# start_upgrade false döndürdü (örn. kaynaklar kilitlenemedi)
				print("UI: %s yükseltmesi başlatılamadı (start_upgrade false döndü)." % building_scene_path.get_file())
		else:
			printerr("UI: %s binasında 'start_upgrade' metodu bulunamadı!" % building_scene_path.get_file())
	else:
		print("UI: Yükseltilecek %s türünde bina bulunamadı." % building_scene_path.get_file())

	# Her durumda UI'ı güncellemek faydalı olabilir (nadiren de olsa buton durumu değişmiş olabilir)
	# update_ui() # Zaten start_upgrade başarılıysa yukarıda çağrılıyor.

# --- YENİ: Ortalanmış Gösterme Fonksiyonu (await ve print ile) ---
func show_centered() -> void:
	# Önce görünür yap
	visible = true
	# Boyutların hesaplanması için bir frame bekle
	await get_tree().process_frame
	# Viewport ve panel boyutlarını al
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = size
	# Ortalanmış pozisyonu hesapla
	var centered_pos = (viewport_size - panel_size) / 2
	
	# --- DEBUG PRINTLER ---
	# ... (debug printleri kaldırabiliriz artık) ...
	# print("--- WorkerAssignmentUI.show_centered() DEBUG ---")
	# print("Viewport Size: ", viewport_size)
	# print("Panel Size: ", panel_size)
	# print("Calculated Centered Position: ", centered_pos)
	# print("----------------------------------------------")
	# --- DEBUG PRINTLER SONU ---

	# Pozisyonu ayarla
	position = centered_pos
	# --- YENİ DEBUG PRINT ---
	# print("Position AFTER setting: ", position) # Ayarladıktan sonraki değeri yazdır
	# print("----------------------------------------------")
	# --- YENİ DEBUG PRINT SONU ---

	# Açılır açılmaz güncelle
	update_ui()
	# Periyodik güncelleme sayacını da sıfırla ki hemen tekrar güncellemesin
	time_since_last_update = 0.0
