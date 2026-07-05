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
