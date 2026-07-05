extends Control

const ResourceType = preload("res://resources/resource_types.gd")
const ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

@onready var wood_label: Label = $VBoxContainer/WoodLabel
@onready var stone_label: Label = $VBoxContainer/StoneLabel
@onready var water_label: Label = $VBoxContainer/WaterLabel
@onready var food_label: Label = $VBoxContainer/FoodLabel
@onready var _vbox: VBoxContainer = $VBoxContainer

var _player_stats: Node = null
var _loot_labels: Dictionary = {}


func _ready() -> void:
	_player_stats = get_node_or_null("/root/PlayerStats")
	_ensure_loot_labels()
	if _player_stats:
		_player_stats.carried_resources_changed.connect(_on_resources_changed)
		if _player_stats.has_signal("expedition_loot_changed"):
			_player_stats.expedition_loot_changed.connect(_on_expedition_loot_changed)
		_update_display()
	else:
		print("[CarriedResourcesDisplay] ERROR: PlayerStats not found!")


func _ensure_loot_labels() -> void:
	if not _vbox:
		return
	for loot_id in ExpeditionLootType.all():
		var lbl := Label.new()
		lbl.name = "Loot_%s" % loot_id
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		match loot_id:
			ExpeditionLootType.RUSTY_WEAPON:
				lbl.add_theme_color_override("font_color", Color(0.75, 0.5, 0.35, 1))
			ExpeditionLootType.SKY_FEATHER:
				lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 1))
			ExpeditionLootType.HERB_BUNDLE:
				lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 0.45, 1))
		lbl.visible = false
		_vbox.add_child(lbl)
		_loot_labels[loot_id] = lbl


func _on_resources_changed(_new_totals: Dictionary) -> void:
	_update_display()


func _on_expedition_loot_changed(_new_totals: Dictionary) -> void:
	_update_display()


func _update_display() -> void:
	if not _player_stats:
		return

	var resources: Dictionary = _player_stats.get_carried_resources()
	var has_any_resources := false

	if wood_label:
		var wood_amount: int = int(resources.get(ResourceType.WOOD, 0))
		if wood_amount > 0:
			wood_label.text = "Odun: " + str(wood_amount)
			wood_label.visible = true
			has_any_resources = true
		else:
			wood_label.visible = false

	if stone_label:
		var stone_amount: int = int(resources.get(ResourceType.STONE, 0))
		if stone_amount > 0:
			stone_label.text = "Taş: " + str(stone_amount)
			stone_label.visible = true
			has_any_resources = true
		else:
			stone_label.visible = false

	if water_label:
		var water_row := water_label.get_parent() as Control
		if water_row:
			water_row.visible = false
		water_label.visible = false

	if food_label:
		var food_amount: int = int(resources.get(ResourceType.FOOD, 0))
		if food_amount > 0:
			food_label.text = "Yemek: " + str(food_amount)
			food_label.visible = true
			has_any_resources = true
		else:
			food_label.visible = false

	if _player_stats.has_method("get_carried_expedition_loot"):
		var loot: Dictionary = _player_stats.get_carried_expedition_loot()
		for loot_id in ExpeditionLootType.all():
			var lbl: Label = _loot_labels.get(loot_id, null)
			if lbl == null:
				continue
			var amount := int(loot.get(loot_id, 0))
			if amount > 0:
				lbl.text = "%s: %d" % [ExpeditionLootType.display_name(loot_id), amount]
				lbl.visible = true
				has_any_resources = true
			else:
				lbl.visible = false

	visible = has_any_resources
