extends Node2D

# UI Panels
@onready var top_bar: Panel = $UI/TopBar
@onready var villager_panel: Panel = $UI/VillagerPanel
@onready var build_panel: Panel = $UI/BuildPanel

# Resource Display
@onready var wood_count: Label = $UI/TopBar/ResourcePanel/MarginContainer/HBoxContainer/WoodContainer/WoodCount
@onready var food_count: Label = $UI/TopBar/ResourcePanel/MarginContainer/HBoxContainer/FoodContainer/FoodCount
@onready var stone_count: Label = $UI/TopBar/ResourcePanel/MarginContainer/HBoxContainer/StoneContainer/StoneCount

# Villager Management
@onready var villager_list: ItemList = $UI/VillagerPanel/VBoxContainer/VillagerList
@onready var task_menu: PopupMenu = $UI/VillagerPanel/VBoxContainer/TaskMenu

# Building System
@onready var build_list: ItemList = $UI/BuildPanel/MarginContainer/VBoxContainer/BuildList
@onready var build_button: Button = $UI/BuildPanel/MarginContainer/VBoxContainer/BuildButton

# Timer
@onready var resource_timer: Timer = $ResourceTimer

const TASKS: Dictionary = {
	0: "Gather Wood",
	1: "Farm",
	2: "Build",
	3: "Guard"
}

# Base production rates
const BASE_PRODUCTION_RATES: Dictionary = {
	"Gather Wood": {"wood": 2},
	"Farm": {"food": 2},
	"Build": {"stone": 1},
	"Guard": {}  # Guards don't produce resources directly
}

const RESOURCE_UPDATE_INTERVAL = 1.0

const BUILDINGS: Dictionary = {
	"House": {
		"wood": 50,
		"stone": 20,
		"effect": "Increases population cap by 2",
		"description": "A cozy home for your villagers"
	},
	"Blacksmith": {
		"wood": 100,
		"stone": 50,
		"effect": "Improves villager tool efficiency by 20%",
		"description": "Crafts better tools for your villagers"
	},
	"Storehouse": {
		"wood": 75,
		"stone": 30,
		"effect": "Increases resource storage capacity",
		"description": "Stores more resources for your village"
	},
	"Farm": {
		"wood": 40,
		"stone": 15,
		"effect": "Increases food production efficiency",
		"description": "Grows food more efficiently"
	},
	"Watchtower": {
		"wood": 60,
		"stone": 40,
		"effect": "Improves village defense",
		"description": "Helps protect your village"
	}
}

func _ready() -> void:
	if !_verify_nodes():
		return
		
	_setup_ui_layout()
	setup_nodes()
	setup_resource_timer()
	setup_ui()
	setup_build_panel()

func _setup_ui_layout() -> void:
	# TopBar layout
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size.y = 40
	
	# Set text and color for resource labels
	wood_count.text = "Wood: 0"
	wood_count.add_theme_color_override("font_color", Color(1, 1, 1))  # White color
	
	food_count.text = "Food: 0"
	food_count.add_theme_color_override("font_color", Color(1, 1, 1))  # White color
	
	stone_count.text = "Stone: 0"
	stone_count.add_theme_color_override("font_color", Color(1, 1, 1))  # White color
	
	# VillagerPanel layout
	villager_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	villager_panel.custom_minimum_size.x = 200
	
	# BuildPanel layout
	build_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	build_panel.custom_minimum_size.x = 200
	
	# Set text for build button
	build_button.text = "Build"
	build_button.add_theme_color_override("font_color", Color(1, 1, 1))  # White color
	build_button.custom_minimum_size.y = 40

func _verify_nodes() -> bool:
	var required_nodes = [
		wood_count, food_count, stone_count,
		villager_list, task_menu,
		build_list, build_button,
		resource_timer
	]
	
	for node in required_nodes:
		if !node:
			push_error("Required node not found. Please check scene structure.")
			return false
	return true

func setup_nodes() -> void:
	# Connect signals using new syntax
	villager_list.item_selected.connect(_on_villager_selected)
	task_menu.id_pressed.connect(_on_task_selected)
	GameManager.villager_added.connect(_on_villager_added)

func setup_resource_timer() -> void:
	if !resource_timer:
		resource_timer = Timer.new()
		add_child(resource_timer)
	
	resource_timer.wait_time = RESOURCE_UPDATE_INTERVAL  # Use constant for clarity
	resource_timer.timeout.connect(_on_resource_tick)
	resource_timer.start()

func setup_ui() -> void:
	task_menu.clear()  # Clear existing items first
	for id in TASKS:
		task_menu.add_item(TASKS[id], id)
	
	update_villager_list()

func _on_resource_tick() -> void:
	var village_level = GameManager.get_village_level()
	var production_multiplier = 1.0 + (village_level * 0.1)  # 10% increase per level
	
	for villager in GameManager.village_data.villagers:
		var task: String = villager.current_task
		if BASE_PRODUCTION_RATES.has(task):
			for resource_type in BASE_PRODUCTION_RATES[task]:
				var base_amount: int = BASE_PRODUCTION_RATES[task][resource_type]
				var final_amount: int = roundi(base_amount * production_multiplier)
				GameManager.add_resource(resource_type, final_amount)

func update_villager_list() -> void:
	villager_list.clear()
	for villager in GameManager.village_data.villagers:
		var display_text: String = "%s - %s" % [villager.name, villager.current_task]
		villager_list.add_item(display_text)

func _on_villager_selected(index: int) -> void:
	task_menu.set_meta("selected_villager", index)
	
	# Use get_global_mouse_position() for more accurate positioning
	var mouse_pos: Vector2 = get_global_mouse_position()
	task_menu.position = mouse_pos
	task_menu.popup()

func _on_task_selected(task_id: int) -> void:
	var selected_index: int = task_menu.get_meta("selected_villager", -1)
	if selected_index == -1:
		push_warning("No villager selected")
		return
		
	if !TASKS.has(task_id):
		push_warning("Invalid task ID selected")
		return
		
	var task: String = TASKS[task_id]
	GameManager.assign_villager_task(selected_index, task)
	update_villager_list()

func _on_villager_added(_villager_data: Dictionary) -> void:
	update_villager_list()

# For testing purposes
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameManager.add_villager("Villager " + str(GameManager.village_data.population + 1))

func setup_build_panel() -> void:
	build_list.clear()
	for building in BUILDINGS.keys():
		var costs = BUILDINGS[building]
		var description = "%s\nCost: %d wood, %d stone\n%s" % [
			building,
			costs["wood"],
			costs["stone"],
			costs["effect"]
		]
		build_list.add_item(description)
	
	build_list.item_selected.connect(_on_build_selected)
	build_button.text = "Build"
	build_button.pressed.connect(_on_build_button_pressed)

func _on_build_selected(index: int) -> void:
	# Handle build selection logic here
	pass

func _on_build_button_pressed() -> void:
	var selected_index = build_list.get_selected_items()[0]
	var building_name = BUILDINGS.keys()[selected_index]
	var costs = BUILDINGS[building_name]
	
	# Check if we have enough resources
	if GameManager.get_resource("wood") >= costs["wood"] and \
	   GameManager.get_resource("stone") >= costs["stone"]:
		# Deduct resources
		GameManager.add_resource("wood", -costs["wood"])
		GameManager.add_resource("stone", -costs["stone"])
		# Add building
		GameManager.add_building(building_name)
		print("Built: %s" % building_name)
	else:
		print("Not enough resources to build: %s" % building_name)
