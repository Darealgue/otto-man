# otto-man/village/scripts/WorkerAssignmentUI.gd
extends PanelContainer

# UI Elemanlarına Referanslar (unique_name_in_owner sayesinde % ile erişeceğiz)
@onready var idle_value_label: Label = %IdleValueLabel
@onready var wood_level_label: Label = %WoodLevelLabel
@onready var stone_level_label: Label = %StoneLevelLabel
@onready var food_level_label: Label = %FoodLevelLabel
@onready var water_level_label: Label = %WaterLevelLabel
@onready var metal_level_label: Label = %MetalLevelLabel

@onready var wood_level_indicator: Label = %WoodLevelIndicator
@onready var stone_level_indicator: Label = %StoneLevelIndicator
@onready var food_level_indicator: Label = %FoodLevelIndicator
@onready var water_level_indicator: Label = %WaterLevelIndicator
@onready var metal_level_indicator: Label = %MetalLevelIndicator

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

@onready var close_button: Button = %CloseButton

# Ana köy sahnesindeki bina konteynerine erişim (varsayılan yol, gerekirse ayarla)
# Bu yol, VillageScene.tscn içindeki yapıyla eşleşmeli!
@onready var building_plots_node = get_tree().current_scene.get_node_or_null("PlacedBuildings") 

# Script yollarını sabit olarak tanımla
const WOOD_SCRIPT = "res://village/scripts/WoodcutterCamp.gd"
const STONE_SCRIPT = "res://village/scripts/StoneMine.gd"
const FOOD_SCRIPT = "res://village/scripts/HunterGathererHut.gd"
const WATER_SCRIPT = "res://village/scripts/Well.gd"
# const METAL_SCRIPT = "res://village/scripts/MetalMine.gd" # Metal için eklenince


func _ready() -> void:
	# Buton sinyallerini bağla
	add_wood_button.pressed.connect(_on_add_worker_pressed.bind("wood", WOOD_SCRIPT)) 
	remove_wood_button.pressed.connect(_on_remove_worker_pressed.bind("wood", WOOD_SCRIPT)) 
	add_stone_button.pressed.connect(_on_add_worker_pressed.bind("stone", STONE_SCRIPT)) 
	remove_stone_button.pressed.connect(_on_remove_worker_pressed.bind("stone", STONE_SCRIPT)) 
	add_food_button.pressed.connect(_on_add_worker_pressed.bind("food", FOOD_SCRIPT)) 
	remove_food_button.pressed.connect(_on_remove_worker_pressed.bind("food", FOOD_SCRIPT)) 
	add_water_button.pressed.connect(_on_add_worker_pressed.bind("water", WATER_SCRIPT)) 
	remove_water_button.pressed.connect(_on_remove_worker_pressed.bind("water", WATER_SCRIPT)) 
	# Metal butonları şimdilik bağlı değil
	# add_metal_button.pressed.connect(...)
	# remove_metal_button.pressed.connect(...)

	# Upgrade Buttons
	upgrade_wood_button.pressed.connect(_on_upgrade_button_pressed.bind(WOOD_SCRIPT))
	upgrade_stone_button.pressed.connect(_on_upgrade_button_pressed.bind(STONE_SCRIPT))
	upgrade_food_button.pressed.connect(_on_upgrade_button_pressed.bind(FOOD_SCRIPT))
	upgrade_water_button.pressed.connect(_on_upgrade_button_pressed.bind(WATER_SCRIPT))
	# Metal upgrade button disabled in .tscn for now

	close_button.pressed.connect(_on_close_button_pressed)
	
	# UI ilk açıldığında değerleri güncelle
	update_ui()
	
	# (Opsiyonel) VillageManager'dan sinyal gelince UI'ı güncellemek için:
	if VillageManager.has_signal("village_data_changed"):
		VillageManager.village_data_changed.connect(update_ui)
	else:
		printerr("WorkerAssignmentUI: VillageManager does not have village_data_changed signal!")


# Arayüzdeki etiketleri VillageManager'dan alınan verilerle günceller
func update_ui() -> void:
	if not is_node_ready(): await ready
	
	# print("\nDEBUG: --- update_ui CALLED ---") # Debug print'leri şimdilik kapatalım

	# Update Labels
	idle_value_label.text = str(VillageManager.idle_workers)
	wood_level_label.text = str(VillageManager.resource_levels["wood"])
	stone_level_label.text = str(VillageManager.resource_levels["stone"])
	food_level_label.text = str(VillageManager.resource_levels["food"])
	water_level_label.text = str(VillageManager.resource_levels["water"])
	metal_level_label.text = str(VillageManager.resource_levels["metal"])

	# Update Button States
	var idle_available = VillageManager.idle_workers > 0

	# Find first building of each type
	var wood_building = _find_first_building(WOOD_SCRIPT)
	var stone_building = _find_first_building(STONE_SCRIPT)
	var food_building = _find_first_building(FOOD_SCRIPT)
	var water_building = _find_first_building(WATER_SCRIPT)
	
	# --- Wood Buttons & Level ---
	var wood_building_exists = wood_building != null
	var wood_is_upgrading = wood_building_exists and wood_building.is_upgrading
	var can_add_wood = wood_building_exists and not wood_is_upgrading and wood_building.assigned_workers < wood_building.max_workers
	var can_remove_wood = wood_building_exists and not wood_is_upgrading and wood_building.assigned_workers > 0
	add_wood_button.disabled = not (idle_available and can_add_wood)
	remove_wood_button.disabled = not can_remove_wood
	# Upgrade Wood Button
	var wood_upgrade_cost = wood_building.get_next_upgrade_cost() if wood_building_exists else {}
	var wood_can_afford = VillageManager.can_afford_and_lock(wood_upgrade_cost) if not wood_upgrade_cost.is_empty() else false
	var wood_is_max_level = wood_building_exists and wood_building.level >= wood_building.max_level
	var can_upgrade_wood = wood_building_exists and not wood_is_upgrading and not wood_is_max_level and wood_can_afford
	upgrade_wood_button.disabled = not can_upgrade_wood
	upgrade_wood_button.text = "Yükseltiliyor..." if wood_is_upgrading else "↑" # METİN GÜNCELLEME
	upgrade_wood_button.tooltip_text = "Yükselt (%s)" % _format_cost(wood_upgrade_cost) if wood_building and not wood_upgrade_cost.is_empty() and not wood_is_max_level else ("Maks Seviye" if wood_is_max_level else "Yükseltilemez")
	wood_level_indicator.text = "[Lv. %d]" % wood_building.level if wood_building_exists else "[Lv. -]" # SEVİYE GÜNCELLEME


	# --- Stone Buttons & Level ---
	var stone_building_exists = stone_building != null
	var stone_is_upgrading = stone_building_exists and stone_building.is_upgrading
	var can_add_stone = stone_building_exists and not stone_is_upgrading and stone_building.assigned_workers < stone_building.max_workers
	var can_remove_stone = stone_building_exists and not stone_is_upgrading and stone_building.assigned_workers > 0
	add_stone_button.disabled = not (idle_available and can_add_stone)
	remove_stone_button.disabled = not can_remove_stone
	# Upgrade Stone Button
	var stone_upgrade_cost = stone_building.get_next_upgrade_cost() if stone_building_exists else {}
	var stone_can_afford = VillageManager.can_afford_and_lock(stone_upgrade_cost) if not stone_upgrade_cost.is_empty() else false
	var stone_is_max_level = stone_building_exists and stone_building.level >= stone_building.max_level
	var can_upgrade_stone = stone_building_exists and not stone_is_upgrading and not stone_is_max_level and stone_can_afford
	upgrade_stone_button.disabled = not can_upgrade_stone
	upgrade_stone_button.text = "Yükseltiliyor..." if stone_is_upgrading else "↑" # METİN GÜNCELLEME
	upgrade_stone_button.tooltip_text = "Yükselt (%s)" % _format_cost(stone_upgrade_cost) if stone_building and not stone_upgrade_cost.is_empty() and not stone_is_max_level else ("Maks Seviye" if stone_is_max_level else "Yükseltilemez")
	stone_level_indicator.text = "[Lv. %d]" % stone_building.level if stone_building_exists else "[Lv. -]" # SEVİYE GÜNCELLEME

	# --- Food Buttons & Level ---
	var food_building_exists = food_building != null
	var food_is_upgrading = food_building_exists and food_building.is_upgrading
	var can_add_food = food_building_exists and not food_is_upgrading and food_building.assigned_workers < food_building.max_workers
	var can_remove_food = food_building_exists and not food_is_upgrading and food_building.assigned_workers > 0
	add_food_button.disabled = not (idle_available and can_add_food)
	remove_food_button.disabled = not can_remove_food
	# Upgrade Food Button
	var food_upgrade_cost = food_building.get_next_upgrade_cost() if food_building_exists else {}
	var food_can_afford = VillageManager.can_afford_and_lock(food_upgrade_cost) if food_building and not food_upgrade_cost.is_empty() else false
	var food_is_max_level = food_building_exists and food_building.level >= food_building.max_level
	var can_upgrade_food = food_building_exists and not food_is_upgrading and not food_is_max_level and food_can_afford
	upgrade_food_button.disabled = not can_upgrade_food
	upgrade_food_button.text = "Yükseltiliyor..." if food_is_upgrading else "↑" # METİN GÜNCELLEME
	upgrade_food_button.tooltip_text = "Yükselt (%s)" % _format_cost(food_upgrade_cost) if food_building and not food_upgrade_cost.is_empty() and not food_is_max_level else ("Maks Seviye" if food_is_max_level else "Yükseltilemez")
	food_level_indicator.text = "[Lv. %d]" % food_building.level if food_building_exists else "[Lv. -]" # SEVİYE GÜNCELLEME

	# --- Water Buttons & Level ---
	var water_building_exists = water_building != null
	var water_is_upgrading = water_building_exists and water_building.is_upgrading
	var can_add_water = water_building_exists and not water_is_upgrading and water_building.assigned_workers < water_building.max_workers
	var can_remove_water = water_building_exists and not water_is_upgrading and water_building.assigned_workers > 0
	add_water_button.disabled = not (idle_available and can_add_water)
	remove_water_button.disabled = not can_remove_water
	# Upgrade Water Button
	var water_upgrade_cost = water_building.get_next_upgrade_cost() if water_building_exists else {}
	var water_can_afford = VillageManager.can_afford_and_lock(water_upgrade_cost) if water_building and not water_upgrade_cost.is_empty() else false
	var water_is_max_level = water_building_exists and water_building.level >= water_building.max_level
	var can_upgrade_water = water_building_exists and not water_is_upgrading and not water_is_max_level and water_can_afford
	upgrade_water_button.disabled = not can_upgrade_water
	upgrade_water_button.text = "Yükseltiliyor..." if water_is_upgrading else "↑" # METİN GÜNCELLEME
	upgrade_water_button.tooltip_text = "Yükselt (%s)" % _format_cost(water_upgrade_cost) if water_building and not water_upgrade_cost.is_empty() and not water_is_max_level else ("Maks Seviye" if water_is_max_level else "Yükseltilemez")
	water_level_indicator.text = "[Lv. %d]" % water_building.level if water_building_exists else "[Lv. -]" # SEVİYE GÜNCELLEME

	# --- Metal Buttons & Level ---
	add_metal_button.disabled = true
	remove_metal_button.disabled = true
	upgrade_metal_button.disabled = true
	upgrade_metal_button.text = "↑"
	upgrade_metal_button.tooltip_text = "Yükseltilemez"
	metal_level_indicator.text = "[Lv. -]" # Metal henüz aktif değil
	
	# print("DEBUG: --- update_ui FINISHED ---") # Debug print'leri kapattık


# "+" butonuna basıldığında çalışır
func _on_add_worker_pressed(resource_type: String, building_script_path: String) -> void: 
	if VillageManager.idle_workers <= 0: return # Kısa kontrol

	var available_building = _find_available_building(building_script_path) 
	if available_building and available_building.add_worker():
		print("UI: İşçi başarıyla %s binasına atandı." % building_script_path.get_file())
	else:
		print("UI: %s türünde uygun bina bulunamadı veya atama başarısız." % building_script_path.get_file())
	update_ui() # Her durumda UI'ı güncelle


# "-" butonuna basıldığında çalışır
func _on_remove_worker_pressed(resource_type: String, building_script_path: String) -> void: 
	if VillageManager.resource_levels[resource_type] <= 0: return # Kısa kontrol

	var removable_building = _find_removable_building(building_script_path) 
	if removable_building and removable_building.remove_worker():
		print("UI: İşçi başarıyla %s binasından çıkarıldı." % building_script_path.get_file())
	else:
		print("UI: İşçi çıkarılacak %s türünde bina bulunamadı veya çıkarma başarısız." % building_script_path.get_file())
	update_ui() # Her durumda UI'ı güncelle


# Helper: Belirtilen script yoluna sahip, kapasitesi dolmamış bir bina bulur
func _find_available_building(building_script_path: String):
	if building_plots_node == null: return null
	for building in building_plots_node.get_children():
		var attached_script = building.get_script()
		if attached_script != null and attached_script.resource_path == building_script_path: 
			if building.has_method("add_worker") and not building.is_upgrading:
				var current_assigned = building.get("assigned_workers") 
				var current_max = building.get("max_workers")
				if current_assigned != null and current_max != null and current_assigned < current_max:
					return building 
	return null

# Helper: Belirtilen script yoluna sahip, içinde işçi olan bir bina bulur
func _find_removable_building(building_script_path: String):
	if building_plots_node == null: return null
	for building in building_plots_node.get_children():
		var attached_script = building.get_script()
		if attached_script != null and attached_script.resource_path == building_script_path: 
			if building.has_method("remove_worker") and not building.is_upgrading:
				var current_assigned = building.get("assigned_workers")
				if current_assigned != null and current_assigned > 0:
					return building 
	return null

# Finds the first building instance with the matching script path
func _find_first_building(building_script_path: String):
	if building_plots_node == null: return null
	for building in building_plots_node.get_children():
		var attached_script = building.get_script()
		if attached_script != null and attached_script.resource_path == building_script_path:
			return building # Return the first match
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

# --- NEW Upgrade Handler ---
func _on_upgrade_button_pressed(building_script_path: String) -> void:
	# Find the first available building of this type to upgrade
	var building_to_upgrade = _find_first_building(building_script_path)

	if building_to_upgrade:
		# Check again if affordable (UI might be slightly outdated)
		var cost = building_to_upgrade.get_next_upgrade_cost()
		if VillageManager.can_afford_and_lock(cost): # Check only, don't lock yet
			if building_to_upgrade.start_upgrade(): # start_upgrade will attempt the actual lock
				print("UI: %s yükseltmesi başlatıldı." % building_script_path.get_file())
			else:
				print("UI: %s yükseltmesi başlatılamadı (kaynaklar kilitlenemedi?)." % building_script_path.get_file())
		else:
			print("UI: %s yükseltmesi için kaynaklar yetersiz." % building_script_path.get_file())
	else:
		print("UI: Yükseltilecek %s türünde bina bulunamadı." % building_script_path.get_file())
	
	# Update UI regardless to reflect any state changes (like button disabling)
	update_ui()
