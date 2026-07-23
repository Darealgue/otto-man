extends Control
## Zindan sefer ganimetleri — yalnızca toplanan öğeler (çerçevesiz chip satırı).

const HudLayout = preload("res://ui/hud_layout.gd")
const ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

var _row: HBoxContainer
var _chips: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	_connect_signals()
	call_deferred("_position_row")
	_refresh()


func _connect_signals() -> void:
	var ps := get_node_or_null("/root/PlayerStats")
	if ps != null:
		if ps.has_signal("expedition_loot_changed") and not ps.expedition_loot_changed.is_connected(_refresh):
			ps.expedition_loot_changed.connect(_refresh)
	var drs := get_node_or_null("/root/DungeonRunState")
	if drs != null and drs.has_signal("collectibles_changed"):
		if not drs.collectibles_changed.is_connected(_refresh):
			drs.collectibles_changed.connect(_refresh)


func _process(_delta: float) -> void:
	# run_started şartı yok: editörden direkt açılan test sahnelerinde de çalışsın.
	# Taşınan hiçbir şey yoksa _refresh zaten gizliyor.
	_refresh()


func _position_row() -> void:
	if _row == null:
		return
	var top_y: float = HudLayout.get_hud_block_bottom(HudLayout.HUD_ORIGIN) + 46.0
	_row.position = Vector2(12.0, top_y)


func _ensure_chip(chip_id: String, emoji: String, tint: Color) -> Dictionary:
	if _chips.has(chip_id):
		return _chips[chip_id]
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	chip.visible = false
	var icon := Label.new()
	icon.text = emoji
	icon.add_theme_font_size_override("font_size", 17)
	chip.add_child(icon)
	var count := Label.new()
	count.add_theme_font_size_override("font_size", 15)
	count.add_theme_color_override("font_color", tint)
	chip.add_child(count)
	_row.add_child(chip)
	var entry := {"root": chip, "count": count}
	_chips[chip_id] = entry
	return entry


func _refresh(_arg: Variant = null) -> void:
	if _row == null:
		return
	var drs := get_node_or_null("/root/DungeonRunState")
	var ps := get_node_or_null("/root/PlayerStats")
	var any_visible := false

	if is_instance_valid(drs) and drs.has_method("has_dungeon_key"):
		var key_id: String = String(drs.get("SEGMENT_EXIT_KEY_ID"))
		var key_chip := _ensure_chip("segment_key", ExpeditionLootType.dungeon_key_emoji(), Color(1.0, 0.9, 0.55))
		if drs.has_dungeon_key(key_id):
			key_chip["count"].text = "1"
			key_chip["root"].visible = true
			any_visible = true
		else:
			key_chip["root"].visible = false

	# Kurtarılan köylü/cariyeler (zindandan sağ çıkınca köye katılacaklar)
	if is_instance_valid(drs):
		var villagers: Array = drs.get("pending_rescued_villagers") if drs.get("pending_rescued_villagers") is Array else []
		var cariyes: Array = drs.get("pending_rescued_cariyes") if drs.get("pending_rescued_cariyes") is Array else []
		var v_chip := _ensure_chip("rescued_villager", "🧑", Color(0.65, 0.9, 0.6))
		if villagers.size() > 0:
			v_chip["count"].text = str(villagers.size())
			v_chip["root"].visible = true
			any_visible = true
		else:
			v_chip["root"].visible = false
		var c_chip := _ensure_chip("rescued_cariye", "👩", Color(0.95, 0.6, 0.75))
		if cariyes.size() > 0:
			c_chip["count"].text = str(cariyes.size())
			c_chip["root"].visible = true
			any_visible = true
		else:
			c_chip["root"].visible = false

	if is_instance_valid(ps) and ps.has_method("get_carried_expedition_loot"):
		var loot: Dictionary = ps.get_carried_expedition_loot()
		for loot_id in ExpeditionLootType.all():
			var amount := int(loot.get(loot_id, 0))
			var tint := Color(0.85, 0.85, 0.85)
			match loot_id:
				ExpeditionLootType.RUSTY_WEAPON:
					tint = Color(0.82, 0.58, 0.38)
				ExpeditionLootType.SKY_FEATHER:
					tint = Color(0.72, 0.84, 1.0)
				ExpeditionLootType.HERB_BUNDLE:
					tint = Color(0.55, 0.88, 0.55)
			var chip := _ensure_chip(loot_id, ExpeditionLootType.placeholder_emoji(loot_id), tint)
			if amount > 0:
				chip["count"].text = str(amount)
				chip["root"].visible = true
				any_visible = true
			else:
				chip["root"].visible = false

	visible = any_visible
