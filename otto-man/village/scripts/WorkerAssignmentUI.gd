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

# --- Upgrade UI (info labels + progress bars) ---
var upgrade_info_labels := {}
var upgrade_progress_bars := {}

# --- YENİ: Bina Sahne Yolları (BuildMenuUI ile aynı olmalı) ---
const WOODCUTTER_SCENE = "res://village/buildings/WoodcutterCamp.tscn"
const STONE_MINE_SCENE = "res://village/buildings/StoneMine.tscn"
const HUNTER_HUT_SCENE = "res://village/buildings/HunterGathererHut.tscn"
const WELL_SCENE = "res://village/buildings/Well.tscn"
const BAKERY_SCENE = "res://village/buildings/Bakery.tscn"
const BLACKSMITH_SCENE = "res://village/buildings/Blacksmith.tscn"
const SAWMILL_SCENE = "res://village/buildings/Sawmill.tscn"
const BRICKWORKS_SCENE = "res://village/buildings/Brickworks.tscn"
const WEAVER_SCENE = "res://village/buildings/Weaver.tscn"
const TAILOR_SCENE = "res://village/buildings/Tailor.tscn"
const HERBALIST_SCENE = "res://village/buildings/Herbalist.tscn"
const TEAHOUSE_SCENE = "res://village/buildings/TeaHouse.tscn"
const SOAPMAKER_SCENE = "res://village/buildings/SoapMaker.tscn"
const GUNSMITH_SCENE = "res://village/buildings/Gunsmith.tscn"
const ARMORER_SCENE = "res://village/buildings/Armorer.tscn"

# Eski Script Yolu Sabitleri (Sadece add/remove buton bağlantıları için kalabilir)
const WOOD_SCRIPT = "res://village/scripts/WoodcutterCamp.gd"
const STONE_SCRIPT = "res://village/scripts/StoneMine.gd"
const FOOD_SCRIPT = "res://village/scripts/HunterGathererHut.gd"
const WATER_SCRIPT = "res://village/scripts/Well.gd"
const BREAD_SCRIPT = "res://village/scripts/Bakery.gd"

const EXTRA_PROCESSING_ORDER := [
	"lumber",
	"brick",
	"cloth",
	"garment",
	"medicine",
	"tea",
	"soap",
	"weapon",
	"armor"
]

const RESOURCE_SCENE_MAP := {
	"wood": WOODCUTTER_SCENE,
	"stone": STONE_MINE_SCENE,
	"food": HUNTER_HUT_SCENE,
	"water": WELL_SCENE,
	"bread": BAKERY_SCENE,
	"metal": BLACKSMITH_SCENE,
	"lumber": SAWMILL_SCENE,
	"brick": BRICKWORKS_SCENE,
	"cloth": WEAVER_SCENE,
	"garment": TAILOR_SCENE,
	"medicine": HERBALIST_SCENE,
	"tea": TEAHOUSE_SCENE,
	"soap": SOAPMAKER_SCENE,
	"weapon": GUNSMITH_SCENE,
	"armor": ARMORER_SCENE
}

const RESOURCE_LABEL_MAP := {
	"lumber": "Kereste:",
	"brick": "Tuğla:",
	"cloth": "Kumaş:",
	"garment": "Giysi:",
	"medicine": "İlaç:",
	"tea": "Çay:",
	"soap": "Sabun:",
	"weapon": "Silah:",
	"armor": "Zırh:"
}

var dynamic_rows: Dictionary = {}

# --- Periyodik Güncelleme ---
var update_interval: float = 0.5 # Saniyede 2 kez güncelle
var time_since_last_update: float = 0.0
# ---------------------------

func _ready() -> void:
	# Null Check for Idle Label
	if not idle_value_label:
		printerr("WorkerAssignmentUI Error: Node not found - IdleValueLabel")
	
	# Buton sinyallerini bağla
	add_wood_button.pressed.connect(_on_add_worker_pressed.bind("wood")) 
	remove_wood_button.pressed.connect(_on_remove_worker_pressed.bind("wood")) 
	add_stone_button.pressed.connect(_on_add_worker_pressed.bind("stone")) 
	remove_stone_button.pressed.connect(_on_remove_worker_pressed.bind("stone")) 
	add_food_button.pressed.connect(_on_add_worker_pressed.bind("food")) 
	remove_food_button.pressed.connect(_on_remove_worker_pressed.bind("food")) 
	add_water_button.pressed.connect(_on_add_worker_pressed.bind("water")) 
	remove_water_button.pressed.connect(_on_remove_worker_pressed.bind("water"))
	add_metal_button.pressed.connect(_on_add_worker_pressed.bind("metal"))
	remove_metal_button.pressed.connect(_on_remove_worker_pressed.bind("metal"))
	add_bread_button.pressed.connect(_on_add_worker_pressed.bind("bread"))
	remove_bread_button.pressed.connect(_on_remove_worker_pressed.bind("bread"))

	# Upgrade Buttons - DÜZELTME: Sahne yolunu bind et
	upgrade_wood_button.pressed.connect(_on_upgrade_button_pressed.bind(WOODCUTTER_SCENE))
	upgrade_stone_button.pressed.connect(_on_upgrade_button_pressed.bind(STONE_MINE_SCENE))
	upgrade_food_button.pressed.connect(_on_upgrade_button_pressed.bind(HUNTER_HUT_SCENE))
	upgrade_water_button.pressed.connect(_on_upgrade_button_pressed.bind(WELL_SCENE))
	upgrade_bread_button.pressed.connect(_on_upgrade_button_pressed.bind(BAKERY_SCENE))
	upgrade_metal_button.pressed.connect(_on_upgrade_button_pressed.bind(BLACKSMITH_SCENE))

	close_button.pressed.connect(_on_close_button_pressed)
	
	# Ensure upgrade UI widgets exist per row (created programmatically if missing)
	_ensure_upgrade_ui_for_row("wood", wood_hbox)
	_ensure_upgrade_ui_for_row("stone", stone_hbox)
	_ensure_upgrade_ui_for_row("food", food_hbox)
	_ensure_upgrade_ui_for_row("water", water_hbox)
	_ensure_upgrade_ui_for_row("metal", metal_hbox)
	_ensure_upgrade_ui_for_row("bread", bread_hbox)
	_create_dynamic_processing_rows()
	
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

# Create info label and progress bar for a given row if not present
func _ensure_upgrade_ui_for_row(resource_type: String, row: HBoxContainer) -> void:
	if not is_instance_valid(row):
		return
	var info_name := resource_type.capitalize() + "UpgradeInfo"
	var bar_name := resource_type.capitalize() + "UpgradeProgress"
	var info_label: Label = row.get_node_or_null(info_name)
	if info_label == null:
		info_label = Label.new()
		info_label.name = info_name
		info_label.visible = false
		row.add_child(info_label)
	upgrade_info_labels[resource_type] = info_label
	var bar: ProgressBar = row.get_node_or_null(bar_name)
	if bar == null:
		bar = ProgressBar.new()
		bar.name = bar_name
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.step = 0.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.visible = false
		row.add_child(bar)
	upgrade_progress_bars[resource_type] = bar

func _create_dynamic_processing_rows() -> void:
	var root_vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer")
	if not root_vbox:
		return
	var close_idx := close_button.get_index() if is_instance_valid(close_button) else root_vbox.get_child_count()
	for resource_type in EXTRA_PROCESSING_ORDER:
		if dynamic_rows.has(resource_type):
			continue
		var row := HBoxContainer.new()
		row.name = resource_type.capitalize() + "HBox"
		row.visible = false
		var label := Label.new()
		label.text = RESOURCE_LABEL_MAP.get(resource_type, resource_type.capitalize() + ":")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level_indicator := Label.new()
		level_indicator.text = "[Lv. -]"
		level_indicator.tooltip_text = "Bina Seviyesi"
		var level_label := Label.new()
		level_label.text = "0"
		level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var upgrade_button := Button.new()
		upgrade_button.text = "↑"
		upgrade_button.pressed.connect(_on_upgrade_button_pressed.bind(String(RESOURCE_SCENE_MAP.get(resource_type, ""))))
		var add_button := Button.new()
		add_button.text = "+"
		add_button.pressed.connect(_on_add_worker_pressed.bind(resource_type))
		var remove_button := Button.new()
		remove_button.text = "-"
		remove_button.pressed.connect(_on_remove_worker_pressed.bind(resource_type))
		row.add_child(label)
		row.add_child(level_indicator)
		row.add_child(level_label)
		row.add_child(upgrade_button)
		row.add_child(add_button)
		row.add_child(remove_button)
		root_vbox.add_child(row)
		root_vbox.move_child(row, close_idx)
		dynamic_rows[resource_type] = {
			"row": row,
			"level_indicator": level_indicator,
			"level_label": level_label,
			"upgrade_button": upgrade_button,
			"add_button": add_button,
			"remove_button": remove_button
		}
		_ensure_upgrade_ui_for_row(resource_type, row)

func _hide_upgrade_ui_for(resource_type: String) -> void:
	var info_label: Label = upgrade_info_labels.get(resource_type, null)
	if is_instance_valid(info_label):
		info_label.visible = false
	var bar: ProgressBar = upgrade_progress_bars.get(resource_type, null)
	if is_instance_valid(bar):
		bar.visible = false

func _format_upgrade_info(building: Node) -> String:
	var parts: Array[String] = []
	if building and building.has_method("get_next_upgrade_cost"):
		var cost: Dictionary = building.get_next_upgrade_cost()
		var gold := int(cost.get("gold", 0))
		if gold > 0:
			parts.append("💰 %d Altın" % gold)
	if building and ("upgrade_time_seconds" in building):
		var secs := int(building.upgrade_time_seconds)
		if secs > 0:
			parts.append("⏱ %ds" % secs)
	# Simple effect preview: max workers +1
	if building and ("max_workers" in building):
		var cur_workers := int(building.max_workers)
		parts.append("Etki: İşçi %d→%d" % [cur_workers, cur_workers + 1])
	return " • ".join(parts)

func _update_upgrade_ui_for(resource_type: String, building: Node) -> void:
	var info_label: Label = upgrade_info_labels.get(resource_type, null)
	var bar: ProgressBar = upgrade_progress_bars.get(resource_type, null)
	if not (is_instance_valid(info_label) and is_instance_valid(bar)):
		return
	# Info text
	var info_text := ""
	if is_instance_valid(building):
		info_text = _format_upgrade_info(building)
	info_label.text = info_text
	info_label.visible = info_text != ""
	# Progress
	var upgrading := false
	if is_instance_valid(building) and ("is_upgrading" in building):
		upgrading = bool(building.is_upgrading)
	if upgrading:
		var total := 0.0
		if ("upgrade_time_seconds" in building):
			total = float(building.upgrade_time_seconds)
		var ratio := 0.0
		if total > 0.0 and ("upgrade_timer" in building) and building.upgrade_timer:
			var left := float(building.upgrade_timer.time_left)
			ratio = clamp((total - left) / total, 0.0, 1.0)
			var percent := int(round(ratio * 100.0))
			# Show remaining time and percent inline
			var base := _format_upgrade_info(building)
			info_label.text = "⏳ %ds (%d%%) • %s" % [int(ceil(left)), percent, base]
			info_label.visible = true
		bar.max_value = 1.0
		bar.value = ratio
		bar.visible = true
	else:
		bar.visible = false

func _process(delta: float) -> void:
	# Panel görünür değilse hiçbir şey yapma
	if not visible:
		time_since_last_update = 0.0 # Görünmezken sayacı sıfırla
		return

	# Zamanı artır
	time_since_last_update += delta

	# Eğer interval dolduysa UI'ı güncelle
	if time_since_last_update >= update_interval:
		#print("WorkerAssignmentUI DEBUG: Calling update_ui() from _process") #<<< YENİ PRINT
		update_ui()
		time_since_last_update = 0.0 # Sayacı sıfırla

# Arayüzdeki etiketleri VillageManager'dan alınan verilerle günceller
func update_ui() -> void:
	#print("WorkerAssignmentUI DEBUG: --- update_ui() STARTED ---") #<<< YENİ PRINT
	#print("WorkerAssignmentUI: update_ui ENTERED") # <<< ESKİ PRINT YORUMLANDI
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
	
	wood_level_label.text = _level_with_cap("wood")
	stone_level_label.text = _level_with_cap("stone")
	food_level_label.text = _level_with_cap("food")
	water_level_label.text = _level_with_cap("water")
	metal_level_label.text = str(VillageManager.resource_levels["metal"]) # şimdilik kapasite yok

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
	var metal_building = _find_first_building(BLACKSMITH_SCENE, current_building_plots_node)

	# --- Wood Row Visibility & Buttons & Level ---
	var wood_building_exists = wood_building != null
	wood_hbox.visible = wood_building_exists
	#print("DEBUG update_ui: wood_hbox.visible set to: ", wood_hbox.visible) # DEBUG
	if wood_building_exists:
		# --- Null Kontrolleri Eklendi --- 
		var wood_is_upgrading = wood_building.is_upgrading if "is_upgrading" in wood_building else false 
		var wood_current_workers = wood_building.assigned_workers if "assigned_workers" in wood_building and wood_building.assigned_workers != null else 0
		var wood_max_workers_val = wood_building.max_workers if "max_workers" in wood_building and wood_building.max_workers != null else 1 # Varsayılan 1
		var wood_current_level = wood_building.level if "level" in wood_building and wood_building.level != null else 1 # Varsayılan 1
		var wood_max_level_val = wood_building.max_level if "max_level" in wood_building and wood_building.max_level != null else 1 # Varsayılan 1
		# --- Kontroller Sonu ---

		var can_add_wood = not wood_is_upgrading and wood_current_workers < wood_max_workers_val
		var can_remove_wood = not wood_is_upgrading and wood_current_workers > 0
		add_wood_button.disabled = not (idle_available and can_add_wood)
		remove_wood_button.disabled = not can_remove_wood

		# --- Upgrade Wood Button DEBUG --- 
		# print("--- Wood Upgrade Check DEBUG ---") #<<< KALDIRILDI
		# print("wood_current_level: %s, wood_max_level_val: %s" % [wood_current_level, wood_max_level_val]) #<<< KALDIRILDI
		var wood_is_max_level_check = wood_current_level >= wood_max_level_val #<<< Null kontrolünden sonra
		# print("wood_is_max_level_check: %s" % wood_is_max_level_check) #<<< KALDIRILDI
		var wood_can_meet_reqs = false
		if not wood_is_max_level_check:
			# TODO: can_meet_requirements içinde de null kontrolü var mı kontrol et
			var req_check_result = VillageManager.can_meet_requirements(WOODCUTTER_SCENE) # Sahne yolu
			# print("VillageManager.can_meet_requirements(WOODCUTTER_SCENE) result: %s" % req_check_result) #<<< KALDIRILDI
			wood_can_meet_reqs = req_check_result
		# else: #<<< KALDIRILDI
			# print("Skipping requirement check because max level reached or check failed.") #<<< KALDIRILDI

		# print("wood_is_upgrading: %s" % wood_is_upgrading) #<<< KALDIRILDI
		var can_upgrade_wood = not wood_is_upgrading and not wood_is_max_level_check and wood_can_meet_reqs
		# print("Final can_upgrade_wood: %s" % can_upgrade_wood) #<<< KALDIRILDI
		upgrade_wood_button.disabled = not can_upgrade_wood
		# print("upgrade_wood_button.disabled set to: %s" % upgrade_wood_button.disabled) #<<< KALDIRILDI
		# print("-------------------------------") #<<< KALDIRILDI
		# --- DEBUG END ---

		upgrade_wood_button.text = "Yükseltiliyor..." if wood_is_upgrading else "↑"
		var wood_upgrade_reqs = VillageManager.get_building_requirements(WOODCUTTER_SCENE) # Sahne yolu
		upgrade_wood_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(wood_upgrade_reqs) if not wood_upgrade_reqs.is_empty() and not wood_is_max_level_check else ("Maks Seviye" if wood_is_max_level_check else "Yükseltilemez")

		wood_level_indicator.text = "[Lv. %d]" % wood_current_level #<<< Güncel değişkeni kullan
		wood_level_label.text = _level_with_cap("wood")
		_update_upgrade_ui_for("wood", wood_building)
	else:
		_hide_upgrade_ui_for("wood")


	# --- Stone Row Visibility & Buttons & Level ---
	var stone_building_exists = stone_building != null
	stone_hbox.visible = stone_building_exists
	#print("DEBUG update_ui: stone_hbox.visible set to: ", stone_hbox.visible) # DEBUG
	if stone_building_exists:
		# --- Null Kontrolleri Eklendi --- 
		var stone_is_upgrading = stone_building.is_upgrading if "is_upgrading" in stone_building else false 
		var stone_current_workers = stone_building.assigned_workers if "assigned_workers" in stone_building and stone_building.assigned_workers != null else 0
		var stone_max_workers_val = stone_building.max_workers if "max_workers" in stone_building and stone_building.max_workers != null else 1
		var stone_current_level = stone_building.level if "level" in stone_building and stone_building.level != null else 1
		var stone_max_level_val = stone_building.max_level if "max_level" in stone_building and stone_building.max_level != null else 1
		# --- Kontroller Sonu ---

		var can_add_stone = not stone_is_upgrading and stone_current_workers < stone_max_workers_val
		var can_remove_stone = not stone_is_upgrading and stone_current_workers > 0
		add_stone_button.disabled = not (idle_available and can_add_stone)
		remove_stone_button.disabled = not can_remove_stone

		# Upgrade Stone Button
		var stone_is_max_level_check = stone_current_level >= stone_max_level_val #<<< Null kontrolünden sonra
		var stone_can_meet_reqs = false
		if not stone_is_max_level_check:
			stone_can_meet_reqs = VillageManager.can_meet_requirements(STONE_MINE_SCENE) # Sahne yolu

		var can_upgrade_stone = not stone_is_upgrading and not stone_is_max_level_check and stone_can_meet_reqs
		upgrade_stone_button.disabled = not can_upgrade_stone
		upgrade_stone_button.text = "Yükseltiliyor..." if stone_is_upgrading else "↑"
		var stone_upgrade_reqs = VillageManager.get_building_requirements(STONE_MINE_SCENE) # Sahne yolu
		upgrade_stone_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(stone_upgrade_reqs) if not stone_upgrade_reqs.is_empty() and not stone_is_max_level_check else ("Maks Seviye" if stone_is_max_level_check else "Yükseltilemez")

		stone_level_indicator.text = "[Lv. %d]" % stone_current_level #<<< Güncel değişkeni kullan
		stone_level_label.text = _level_with_cap("stone")
		_update_upgrade_ui_for("stone", stone_building)
	else:
		_hide_upgrade_ui_for("stone")

	# --- Food Row Visibility & Buttons & Level ---
	var food_building_exists = food_building != null
	food_hbox.visible = food_building_exists
	#print("DEBUG update_ui: food_hbox.visible set to: ", food_hbox.visible) # DEBUG
	if food_building_exists:
		# --- Null Kontrolleri Eklendi --- 
		var food_is_upgrading = food_building.is_upgrading if "is_upgrading" in food_building else false 
		var food_current_workers = food_building.assigned_workers if "assigned_workers" in food_building and food_building.assigned_workers != null else 0
		var food_max_workers_val = food_building.max_workers if "max_workers" in food_building and food_building.max_workers != null else 1
		var food_current_level = food_building.level if "level" in food_building and food_building.level != null else 1
		var food_max_level_val = food_building.max_level if "max_level" in food_building and food_building.max_level != null else 1
		# --- Kontroller Sonu ---

		var can_add_food = not food_is_upgrading and food_current_workers < food_max_workers_val
		var can_remove_food = not food_is_upgrading and food_current_workers > 0
		add_food_button.disabled = not (idle_available and can_add_food)
		remove_food_button.disabled = not can_remove_food

		# Upgrade Food Button
		var food_is_max_level_check = food_current_level >= food_max_level_val #<<< Null kontrolünden sonra
		var food_can_meet_reqs = false
		if not food_is_max_level_check:
			food_can_meet_reqs = VillageManager.can_meet_requirements(HUNTER_HUT_SCENE)

		var can_upgrade_food = not food_is_upgrading and not food_is_max_level_check and food_can_meet_reqs
		upgrade_food_button.disabled = not can_upgrade_food
		upgrade_food_button.text = "Yükseltiliyor..." if food_is_upgrading else "↑"
		var food_upgrade_reqs = VillageManager.get_building_requirements(HUNTER_HUT_SCENE)
		upgrade_food_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(food_upgrade_reqs) if not food_upgrade_reqs.is_empty() and not food_is_max_level_check else ("Maks Seviye" if food_is_max_level_check else "Yükseltilemez")

		food_level_indicator.text = "[Lv. %d]" % food_current_level #<<< Güncel değişkeni kullan
		food_level_label.text = _level_with_cap("food")
		_update_upgrade_ui_for("food", food_building)
	else:
		_hide_upgrade_ui_for("food")

	# --- Water Row Visibility & Buttons & Level ---
	var water_building_exists = water_building != null
	water_hbox.visible = water_building_exists
	#print("DEBUG update_ui: water_hbox.visible set to: ", water_hbox.visible) # DEBUG
	if water_building_exists:
		# --- Null Kontrolleri Eklendi --- 
		var water_is_upgrading = water_building.is_upgrading if "is_upgrading" in water_building else false 
		var water_current_workers = water_building.assigned_workers if "assigned_workers" in water_building and water_building.assigned_workers != null else 0
		var water_max_workers_val = water_building.max_workers if "max_workers" in water_building and water_building.max_workers != null else 1
		var water_current_level = water_building.level if "level" in water_building and water_building.level != null else 1
		var water_max_level_val = water_building.max_level if "max_level" in water_building and water_building.max_level != null else 1
		# --- Kontroller Sonu ---

		var can_add_water = not water_is_upgrading and water_current_workers < water_max_workers_val
		var can_remove_water = not water_is_upgrading and water_current_workers > 0
		add_water_button.disabled = not (idle_available and can_add_water)
		remove_water_button.disabled = not can_remove_water

		# Upgrade Water Button
		var water_is_max_level_check = water_current_level >= water_max_level_val #<<< Null kontrolünden sonra
		var water_can_meet_reqs = false
		if not water_is_max_level_check:
			water_can_meet_reqs = VillageManager.can_meet_requirements(WELL_SCENE)

		var can_upgrade_water = not water_is_upgrading and not water_is_max_level_check and water_can_meet_reqs
		upgrade_water_button.disabled = not can_upgrade_water
		upgrade_water_button.text = "Yükseltiliyor..." if water_is_upgrading else "↑"
		var water_upgrade_reqs = VillageManager.get_building_requirements(WELL_SCENE)
		upgrade_water_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(water_upgrade_reqs) if not water_upgrade_reqs.is_empty() and not water_is_max_level_check else ("Maks Seviye" if water_is_max_level_check else "Yükseltilemez")

		water_level_indicator.text = "[Lv. %d]" % water_current_level #<<< Güncel değişkeni kullan
		water_level_label.text = _level_with_cap("water")
		_update_upgrade_ui_for("water", water_building)
	else:
		_hide_upgrade_ui_for("water")

	# --- Metal Row Visibility & Buttons & Level ---
	var metal_building_exists = metal_building != null
	metal_hbox.visible = metal_building_exists
	if metal_building_exists:
		_update_generic_row_from_building("metal", metal_building, idle_available, metal_hbox, metal_level_indicator, metal_level_label, upgrade_metal_button, add_metal_button, remove_metal_button)
	else:
		_hide_upgrade_ui_for("metal")

	# --- Bread Row Visibility & Buttons & Level (Yeni) ---
	var bread_building_exists = bread_building != null
	bread_hbox.visible = bread_building_exists
	#print("DEBUG update_ui: bread_hbox.visible set to: ", bread_hbox.visible) # DEBUG
	if bread_building_exists:
		upgrade_bread_button.visible = true
		bread_level_indicator.visible = true
		_update_generic_row_from_building("bread", bread_building, idle_available, bread_hbox, bread_level_indicator, bread_level_label, upgrade_bread_button, add_bread_button, remove_bread_button)
	else: 
		if is_instance_valid(bread_level_label):
			bread_level_label.text = "0"
		_hide_upgrade_ui_for("bread")

	for resource_type in EXTRA_PROCESSING_ORDER:
		var widgets: Dictionary = dynamic_rows.get(resource_type, {})
		if widgets.is_empty():
			continue
		var scene_path := String(RESOURCE_SCENE_MAP.get(resource_type, ""))
		var building = _find_first_building(scene_path, current_building_plots_node)
		var row: HBoxContainer = widgets.get("row", null)
		if row == null:
			continue
		var exists := building != null
		row.visible = exists
		if exists:
			_update_generic_row_from_building(
				resource_type,
				building,
				idle_available,
				row,
				widgets.get("level_indicator", null),
				widgets.get("level_label", null),
				widgets.get("upgrade_button", null),
				widgets.get("add_button", null),
				widgets.get("remove_button", null)
			)
		else:
			_hide_upgrade_ui_for(resource_type)

	# print("DEBUG: --- update_ui FINISHED ---") # Debug print'leri kapattık

func _update_generic_row_from_building(
	resource_type: String,
	building: Node,
	idle_available: bool,
	_row: HBoxContainer,
	level_indicator: Label,
	level_label: Label,
	upgrade_button: Button,
	add_button: Button,
	remove_button: Button
) -> void:
	var is_upgrading = bool(building.is_upgrading) if "is_upgrading" in building else false
	var current_workers = int(building.assigned_workers) if "assigned_workers" in building else 0
	var max_workers_value = int(building.max_workers) if "max_workers" in building else 1
	var current_level = int(building.level) if "level" in building else 1
	var max_level_value = int(building.max_level) if "max_level" in building else 1
	var can_add = not is_upgrading and current_workers < max_workers_value
	var can_remove = not is_upgrading and current_workers > 0
	add_button.disabled = not (idle_available and can_add)
	remove_button.disabled = not can_remove
	var is_max_level = current_level >= max_level_value
	var scene_path := String(RESOURCE_SCENE_MAP.get(resource_type, ""))
	var can_upgrade = false
	if scene_path != "" and not is_max_level:
		can_upgrade = VillageManager.can_meet_requirements(scene_path)
	upgrade_button.disabled = is_upgrading or is_max_level or not can_upgrade
	upgrade_button.text = "Yükseltiliyor..." if is_upgrading else "↑"
	var reqs = VillageManager.get_building_requirements(scene_path)
	upgrade_button.tooltip_text = "Yükselt (%s)" % _format_requirements_tooltip(reqs) if not reqs.is_empty() and not is_max_level else ("Maks Seviye" if is_max_level else "Yükseltilemez")
	if is_instance_valid(level_indicator):
		level_indicator.visible = true
		level_indicator.text = "[Lv. %d]" % current_level
	if is_instance_valid(level_label):
		level_label.text = _level_with_cap(resource_type)
	_update_upgrade_ui_for(resource_type, building)

# "+" butonuna basıldığında çalışır
func _on_add_worker_pressed(resource_type: String) -> void:
	print("UI: İşçi atama isteği gönderiliyor: ", resource_type) # Debug

	# 1. İlgili bina türünün sahne yolunu al
	var target_building_scene_path = String(RESOURCE_SCENE_MAP.get(resource_type, ""))
	if target_building_scene_path == "":
		printerr("UI Error: Bilinmeyen kaynak türü için işçi eklenemiyor: ", resource_type)
		return

	# 2. Sahnedeki o türden ilk binayı bul
	var building_node = _find_first_building(target_building_scene_path, get_tree().current_scene.get_node_or_null("PlacedBuildings"))

	# 3. Binanın add_worker metodunu çağır
	if is_instance_valid(building_node):
		if building_node.has_method("add_worker"):
			if building_node.add_worker():
				print("UI: %s binasına işçi başarıyla atandı." % building_node.name)
				# update_ui() # Zaten periyodik olarak güncelleniyor
			else:
				# Hata mesajı binanın kendi add_worker metodundan gelmeli
				printerr("UI: %s binasına işçi atanamadı (%s.add_worker() false döndü)." % [building_node.name, building_node.name])
		else:
			printerr("UI Error: %s node'unda 'add_worker' metodu bulunamadı!" % building_node.name)
	else:
		printerr("UI Error: Aktif %s binası bulunamadı!" % resource_type.capitalize())


# "-" butonuna basıldığında çalışır
func _on_remove_worker_pressed(resource_type: String) -> void:
	print("UI: İşçi çıkarma isteği gönderiliyor: ", resource_type) # Debug

	# 1. İlgili bina türünün sahne yolunu al
	var target_building_scene_path = String(RESOURCE_SCENE_MAP.get(resource_type, ""))
	if target_building_scene_path == "":
		printerr("UI Error: Bilinmeyen kaynak türü için işçi çıkarılamıyor: ", resource_type)
		return

	# 2. Sahnedeki o türden ilk binayı bul
	var building_node = _find_first_building(target_building_scene_path, get_tree().current_scene.get_node_or_null("PlacedBuildings"))

	# 3. Binanın remove_worker metodunu çağır
	if is_instance_valid(building_node):
		if building_node.has_method("remove_worker"):
			if building_node.remove_worker():
				print("UI: %s binasından işçi başarıyla çıkarıldı." % building_node.name)
				# update_ui() # Zaten periyodik olarak güncelleniyor
			else:
				# Hata mesajı binanın kendi remove_worker metodundan gelmeli
				printerr("UI: %s binasından işçi çıkarılamadı (%s.remove_worker() false döndü)." % [building_node.name, building_node.name])
		else:
			printerr("UI Error: %s node'unda 'remove_worker' metodu bulunamadı!" % building_node.name)
	else:
		printerr("UI Error: Aktif %s binası bulunamadı!" % resource_type.capitalize())


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
			if VillageManager.has_method("prepare_building_upgrade"):
				VillageManager.prepare_building_upgrade(building_to_upgrade)
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

# --- Helper: Show level with capacity ---
func _level_with_cap(resource_type: String) -> String:
	var lvl := VillageManager.get_resource_level(resource_type)
	var cap := VillageManager.get_storage_capacity_for(resource_type)
	if cap > 0:
		return "%d/%d" % [lvl, cap]
	return str(lvl)
