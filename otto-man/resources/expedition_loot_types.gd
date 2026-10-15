class_name ExpeditionLootType
extends RefCounted

const RUSTY_WEAPON := "rusty_weapon"
const SKY_FEATHER := "sky_feather"
const HERB_BUNDLE := "herb_bundle"

static func all() -> Array[String]:
	return [RUSTY_WEAPON, SKY_FEATHER, HERB_BUNDLE]

static func is_valid(value: String) -> bool:
	return value in all()

static func placeholder_emoji(loot_id: String) -> String:
	match loot_id:
		RUSTY_WEAPON:
			return "🗡"
		SKY_FEATHER:
			return "🪶"
		HERB_BUNDLE:
			return "🌿"
		_:
			return "📦"

static func dungeon_key_emoji() -> String:
	return "🔑"

static func make_emoji_label(emoji: String, font_size: int = 22) -> Label:
	var lbl := Label.new()
	lbl.text = emoji
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.custom_minimum_size = Vector2(font_size + 8, font_size + 8)
	lbl.position = Vector2(-(font_size + 8) * 0.5, -(font_size + 8) * 0.5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

## Toplanan loot için oyuncunun üstünde "+1 🗡" belirip yukarı süzülen kısa geri bildirim.
static func spawn_pickup_popup(loot_id: String, amount: int = 1) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	var lbl := Label.new()
	lbl.text = "+%d %s" % [amount, placeholder_emoji(loot_id)]
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.04))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100
	lbl.size = Vector2(120, 36)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tree.current_scene.add_child(lbl)
	var start := player.global_position + Vector2(-60.0 + randf_range(-12.0, 12.0), -120.0)
	lbl.global_position = start
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", start.y - 60.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(lbl.queue_free)


static func display_name(loot_id: String) -> String:
	match loot_id:
		RUSTY_WEAPON:
			return "Paslı Silah"
		SKY_FEATHER:
			return "Uçan Tüy"
		HERB_BUNDLE:
			return "Ot Demeti"
		_:
			return loot_id
