extends Control

const ResourceType = preload("res://resources/resource_types.gd")
const ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

const _ICON_PATHS := {
	"wood": "res://assets/Icons/wood_icon.png",
	"stone": "res://assets/Icons/stone_icon.png",
	"food": "res://assets/Icons/food_icon.png",
}
const _ICON_SIZE := Vector2(22, 22)

@onready var _hbox: HBoxContainer = $HBoxContainer

var _player_stats: Node = null
var _resource_chips: Dictionary = {}
var _loot_chips: Dictionary = {}


func _ready() -> void:
	_player_stats = get_node_or_null("/root/PlayerStats")
	_ensure_resource_chips()
	_ensure_loot_chips()
	if _player_stats:
		_player_stats.carried_resources_changed.connect(_on_resources_changed)
		if _player_stats.has_signal("expedition_loot_changed"):
			_player_stats.expedition_loot_changed.connect(_on_expedition_loot_changed)
		_update_display()
	else:
		print("[CarriedResourcesDisplay] ERROR: PlayerStats not found!")


## Odun/Taş/Yemek: ikon + sayı çipi — yazı okumak yerine tek bakışta anlaşılsın.
func _ensure_resource_chips() -> void:
	if not _hbox:
		return
	for resource_key in ResourceType.all():
		var icon_path: String = _ICON_PATHS.get(resource_key, "")
		var chip := _build_icon_count_chip(icon_path, _resource_tint(resource_key))
		chip.name = resource_key.capitalize() + "Chip"
		chip.visible = false
		_hbox.add_child(chip)
		_resource_chips[resource_key] = chip


func _resource_tint(resource_key: String) -> Color:
	match resource_key:
		"wood":
			return Color(0.8, 0.6, 0.2, 1)
		"stone":
			return Color(0.75, 0.75, 0.78, 1)
		"food":
			return Color(1, 0.6, 0.2, 1)
		_:
			return Color(1, 1, 1, 1)


func _ensure_loot_chips() -> void:
	if not _hbox:
		return
	for loot_id in ExpeditionLootType.all():
		var chip := _build_emoji_count_chip(ExpeditionLootType.placeholder_emoji(loot_id))
		chip.name = "Loot_%s" % loot_id
		chip.visible = false
		_hbox.add_child(chip)
		_loot_chips[loot_id] = chip


## icon_path boşsa (henüz asset yoksa) ikon yerine boş bırakılır, sadece sayı görünür.
func _build_icon_count_chip(icon_path: String, tint: Color) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = _ICON_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = tint
		chip.add_child(icon)
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "0"
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	count_label.add_theme_constant_override("outline_size", 3)
	chip.add_child(count_label)
	return chip


func _build_emoji_count_chip(emoji: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emoji_label := ExpeditionLootType.make_emoji_label(emoji, 18)
	emoji_label.position = Vector2.ZERO
	emoji_label.custom_minimum_size = Vector2(20, 20)
	chip.add_child(emoji_label)
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "0"
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	count_label.add_theme_constant_override("outline_size", 3)
	chip.add_child(count_label)
	return chip


func _on_resources_changed(_new_totals: Dictionary) -> void:
	_update_display()


func _on_expedition_loot_changed(_new_totals: Dictionary) -> void:
	_update_display()


func _update_display() -> void:
	if not _player_stats:
		return

	var resources: Dictionary = _player_stats.get_carried_resources()
	var has_any_resources := false

	for resource_key in ResourceType.all():
		var chip: HBoxContainer = _resource_chips.get(resource_key, null)
		if chip == null:
			continue
		var amount: int = int(resources.get(resource_key, 0))
		if amount > 0:
			(chip.get_node("CountLabel") as Label).text = str(amount)
			chip.visible = true
			has_any_resources = true
		else:
			chip.visible = false

	if _player_stats.has_method("get_carried_expedition_loot"):
		var loot: Dictionary = _player_stats.get_carried_expedition_loot()
		for loot_id in ExpeditionLootType.all():
			var chip: HBoxContainer = _loot_chips.get(loot_id, null)
			if chip == null:
				continue
			var amount := int(loot.get(loot_id, 0))
			if amount > 0:
				(chip.get_node("CountLabel") as Label).text = str(amount)
				chip.visible = true
				has_any_resources = true
			else:
				chip.visible = false

	visible = has_any_resources
