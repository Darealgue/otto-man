class_name DungeonEventInteractable
extends Area2D
## Zindan yan yol mini-event: tüccar veya lanetli sunak.

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

const GROUP_NAME: StringName = &"dungeon_event_interactable"
const EVENT_Z_INDEX: int = 3

var event_type: String = "merchant"
var level: int = 1
var _resolved: bool = false
var _player_in_range: bool = false
var _dialog_open: bool = false
var _placeholder: Polygon2D
var _sprite: Sprite2D
var _hint: Label

const MERCHANT_TEXTURE_PATHS: Array[String] = [
	"res://assets/decorations/crate_1.png",
	"res://assets/decorations/barrel_1.png",
	"res://assets/decorations/chest_1.png",
]
const CURSE_TEXTURE_PATHS: Array[String] = [
	"res://assets/decorations/crystal_1.png",
	"res://assets/decorations/pillar_1.png",
	"res://assets/decorations/stone_block_1.png",
]


func setup(type: String, dungeon_level: int = 1) -> void:
	event_type = type if type == "curse" else "merchant"
	level = maxi(1, dungeon_level)


func _ready() -> void:
	add_to_group(GROUP_NAME)
	collision_layer = CollisionLayers.ITEM
	collision_mask = CollisionLayers.PLAYER
	monitoring = true
	monitorable = true
	z_index = EVENT_Z_INDEX

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80.0, 64.0)
	shape.shape = rect
	add_child(shape)

	_placeholder = Polygon2D.new()
	_placeholder.name = "Placeholder"
	if event_type == "curse":
		_placeholder.color = Color(0.45, 0.18, 0.55, 1.0)
		_placeholder.polygon = PackedVector2Array([
			Vector2(-20.0, 18.0), Vector2(20.0, 18.0), Vector2(28.0, 0.0),
			Vector2(16.0, -34.0), Vector2(-16.0, -34.0), Vector2(-28.0, 0.0),
		])
	else:
		_placeholder.color = Color(0.55, 0.42, 0.22, 1.0)
		_placeholder.polygon = PackedVector2Array([
			Vector2(-30.0, 10.0), Vector2(30.0, 10.0), Vector2(34.0, -8.0),
			Vector2(22.0, -26.0), Vector2(-22.0, -26.0), Vector2(-34.0, -8.0),
		])
	add_child(_placeholder)

	var tex_paths: Array = CURSE_TEXTURE_PATHS if event_type == "curse" else MERCHANT_TEXTURE_PATHS
	_sprite = InteractableVisualHelper.attach_centered_sprite(
		self,
		tex_paths,
		Vector2(0.0, -8.0),
		Vector2(64.0, 56.0),
		[_placeholder]
	)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-64.0, -62.0)
	_hint.size = Vector2(128.0, 22.0)
	_hint.add_theme_font_size_override("normal_font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.12))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.visible = false
	add_child(_hint)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _resolved or _dialog_open or not _player_in_range:
		return
	if InputManager.is_ui_up_just_pressed():
		_open_event_dialog()


func _on_body_entered(body: Node2D) -> void:
	if _resolved or not body.is_in_group(&"player"):
		return
	_player_in_range = true
	_hint.visible = true
	_hint.text = "[↑] %s" % ("Lanetli Sunak" if event_type == "curse" else "Gizli Tüccar")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		if not _resolved:
			_hint.visible = false


func _open_event_dialog() -> void:
	if _resolved or _dialog_open:
		return
	_dialog_open = true
	_hint.visible = false
	if event_type == "curse":
		_show_choice_dialog(
			"Lanetli Sunak",
			"Taşların arasında eski bir sunak. Dokunursan lanetlenebilirsin — ama hazinesi de cazip.",
			[
				{"id": "accept", "label": "Lanet kabul et (can kaybı, altın)"},
				{"id": "cleanse", "label": "Arındır (%d altın)" % _cleanse_cost()},
				{"id": "leave", "label": "Uzak dur"},
			]
		)
	else:
		_show_choice_dialog(
			"Gizli Tüccar",
			"Yol kenarında bir tüccar kamp kurmuş. Erzak ve altın takası yapabilirsin.",
			[
				{"id": "supplies", "label": "Erzak al (%d altın)" % _merchant_supply_cost()},
				{"id": "key", "label": "Anahtar al (%d altın)" % _merchant_key_cost()},
				{"id": "gamble", "label": "Pazarlık (%d altın)" % _merchant_gamble_cost()},
				{"id": "leave", "label": "Devam et"},
			]
		)


func _show_choice_dialog(title: String, body: String, options: Array) -> void:
	var win := Window.new()
	win.title = title
	win.size = Vector2i(460, 240)
	win.unresizable = true
	win.transient = true
	win.exclusive = true
	win.process_mode = Node.PROCESS_MODE_ALWAYS
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	win.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var label := Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 64)
	vbox.add_child(label)
	for opt in options:
		if not (opt is Dictionary):
			continue
		var btn := Button.new()
		btn.text = String(opt.get("label", "Seç"))
		btn.custom_minimum_size = Vector2(420, 32)
		var choice_id: String = String(opt.get("id", "leave"))
		btn.pressed.connect(func() -> void:
			_on_dialog_choice(choice_id, win)
		)
		vbox.add_child(btn)
	get_tree().root.add_child(win)
	win.popup_centered()
	win.close_requested.connect(func() -> void:
		_on_dialog_choice("leave", win)
	)


func _on_dialog_choice(choice_id: String, win: Window) -> void:
	if is_instance_valid(win):
		win.queue_free()
	_dialog_open = false
	if _resolved:
		return
	match event_type:
		"merchant":
			_resolve_merchant(choice_id)
		"curse":
			_resolve_curse(choice_id)
	if _resolved:
		_finish_event()


func _resolve_merchant(choice_id: String) -> void:
	match choice_id:
		"supplies":
			var cost: int = _merchant_supply_cost()
			if not _spend_run_gold(cost):
				_show_feedback("Yeterli altın yok (%d gerekli)." % cost)
				return
			var ps: Node = get_node_or_null("/root/PlayerStats")
			if ps and ps.has_method("add_carried_resources"):
				var bundle: Dictionary = {"medicine": 2, "food": 1}
				if level >= 4:
					bundle["water"] = 1
				ps.add_carried_resources(bundle)
			_show_feedback("Tüccardan erzak aldın.")
			_resolved = true
		"key":
			var key_cost: int = _merchant_key_cost()
			if not _spend_run_gold(key_cost):
				_show_feedback("Yeterli altın yok (%d gerekli)." % key_cost)
				return
			if _grant_dungeon_key():
				_show_feedback("Demir anahtar aldın.")
				_resolved = true
			else:
				_show_feedback("Bu anahtar zaten sende.")
		"gamble":
			var cost: int = _merchant_gamble_cost()
			if not _spend_run_gold(cost):
				_show_feedback("Yeterli altın yok (%d gerekli)." % cost)
				return
			if randf() < 0.55:
				var gain: int = randi_range(12, 22) + level
				_credit_run_gold(gain)
				_show_feedback("Pazarlık tuttu! +%d altın." % gain)
			else:
				_show_feedback("Tüccar seni dolandırdı.")
			_resolved = true
		_:
			pass


func _resolve_curse(choice_id: String) -> void:
	match choice_id:
		"accept":
			var ps: Node = get_node_or_null("/root/PlayerStats")
			if ps and ps.has_method("set_current_health"):
				var dmg: float = 6.0 + float(level) * 1.5
				var cur: float = float(ps.get("current_health")) if "current_health" in ps else 100.0
				ps.set_current_health(maxf(1.0, cur - dmg))
			var gold_gain: int = randi_range(18, 30) + level * 2
			_credit_run_gold(gold_gain)
			var drs: Node = get_node_or_null("/root/DungeonRunState")
			if is_instance_valid(drs) and "gold_multiplier_accumulated" in drs:
				drs.gold_multiplier_accumulated -= 0.12
			_show_feedback("Lanet kabul edildi. +%d altın, çıkış altın çarpanı düştü." % gold_gain)
			_resolved = true
		"cleanse":
			var cost: int = _cleanse_cost()
			if not _spend_run_gold(cost):
				_show_feedback("Arındırma için %d altın gerekli." % cost)
				return
			var drs: Node = get_node_or_null("/root/DungeonRunState")
			if is_instance_valid(drs) and "gold_multiplier_accumulated" in drs:
				drs.gold_multiplier_accumulated += 0.08
			var heal_ps: Node = get_node_or_null("/root/PlayerStats")
			if heal_ps and heal_ps.has_method("set_current_health"):
				var cur_h: float = float(heal_ps.get("current_health")) if "current_health" in heal_ps else 100.0
				var max_h: float = float(heal_ps.call("get_max_health")) if heal_ps.has_method("get_max_health") else 100.0
				heal_ps.set_current_health(minf(max_h, cur_h + 8.0), false)
			_show_feedback("Sunak arındırıldı. Küçük bir bereket hissediyorsun.")
			_resolved = true
		_:
			pass


func _merchant_supply_cost() -> int:
	return 8 + level


func _merchant_gamble_cost() -> int:
	return 5 + int(level / 2)


func _merchant_key_cost() -> int:
	return 12 + level * 2


func _grant_dungeon_key(key_id: String = "") -> bool:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs) or not drs.has_method("add_dungeon_key"):
		return false
	var id: String = key_id
	if id.is_empty() and "DEFAULT_DUNGEON_KEY_ID" in drs:
		id = String(drs.get("DEFAULT_DUNGEON_KEY_ID"))
	if id.is_empty():
		id = "dungeon_key"
	return bool(drs.call("add_dungeon_key", id))


func _cleanse_cost() -> int:
	return 10 + level


func _finish_event() -> void:
	_hint.visible = false
	if _sprite:
		_sprite.modulate = Color(0.55, 0.55, 0.58, 0.65)
	elif _placeholder:
		_placeholder.modulate = Color(0.55, 0.55, 0.58, 0.65)
	monitoring = false


func _show_feedback(message: String) -> void:
	print("[DungeonEvent] %s" % message)
	var hud: Node = get_tree().get_first_node_in_group("dungeon_hud")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", message)
		return
	_hint.text = message
	_hint.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(_hint) and _resolved:
			_hint.visible = false
	)


func _get_run_gold() -> int:
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd == null:
		return 0
	if gpd.has_method("uses_dungeon_loot_wallet") and gpd.uses_dungeon_loot_wallet():
		return int(gpd.get("dungeon_gold"))
	return int(gpd.get("gold"))


func _spend_run_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd == null:
		return false
	if gpd.has_method("uses_dungeon_loot_wallet") and gpd.uses_dungeon_loot_wallet():
		if int(gpd.get("dungeon_gold")) < amount:
			return false
		gpd.dungeon_gold = int(gpd.dungeon_gold) - amount
		if gpd.has_signal("dungeon_gold_changed"):
			gpd.dungeon_gold_changed.emit(gpd.dungeon_gold)
		return true
	if int(gpd.get("gold")) < amount:
		return false
	gpd.gold = int(gpd.gold) - amount
	return true


func _credit_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd and gpd.has_method("credit_run_loot_gold"):
		gpd.credit_run_loot_gold(amount, global_position)
	elif gpd and gpd.has_method("add_dungeon_gold"):
		gpd.add_dungeon_gold(amount)
