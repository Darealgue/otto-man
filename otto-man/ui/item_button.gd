# item_button.gd
# Button for displaying item info in selection UI

extends Button

var item_scene: PackedScene
var progress: float = 0.0

func setup(scene: PackedScene) -> void:
	item_scene = scene
	
	# Instance the item to get its info
	var item = scene.instantiate()
	
	if item is ItemEffect:
		var item_name = item.item_name
		var description = item.description
		var rarity = item.rarity
		
		# Get rarity color
		var rarity_color = Color.WHITE
		match rarity:
			ItemEffect.ItemRarity.COMMON:
				rarity_color = Color(0.7, 0.7, 0.7)  # Gray
			ItemEffect.ItemRarity.UNCOMMON:
				rarity_color = Color(0.0, 0.5, 1.0)  # Blue
			ItemEffect.ItemRarity.RARE:
				rarity_color = Color(0.6, 0.0, 1.0)  # Purple
			ItemEffect.ItemRarity.LEGENDARY:
				rarity_color = Color(1.0, 0.5, 0.0)  # Orange
		
		# Format text with rarity color
		var rarity_text = ""
		match rarity:
			ItemEffect.ItemRarity.COMMON:
				rarity_text = "[Common] "
			ItemEffect.ItemRarity.UNCOMMON:
				rarity_text = "[Uncommon] "
			ItemEffect.ItemRarity.RARE:
				rarity_text = "[Rare] "
			ItemEffect.ItemRarity.LEGENDARY:
				rarity_text = "[Legendary] "
		
		text = rarity_text + item_name + "\n" + description
	else:
		text = "Unknown Item"
	
	item.queue_free()

func set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	if progress > 0:
		var size = get_size()
		var radius = min(size.x, size.y) * 0.4
		var center = size * 0.5
		var angle_from = -PI/2
		var angle_to = angle_from + (PI * 2 * progress)
		
		draw_arc(center, radius, angle_from, angle_to, 32, Color(1, 1, 1, 0.5), 2.0)
