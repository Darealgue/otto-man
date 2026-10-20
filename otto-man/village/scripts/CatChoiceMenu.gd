extends CanvasLayer

## Eşlikçi olabilecek bir kediyle etkileşimde açılan küçük seçim menüsü: Okşa / Yanıma al (ya da Evde bırak) / Vazgeç.
## Kedinin adı, bağ seviyesi ve özelliği (adı + kısa açıklaması) gösterilir. Klavye/oyun kolu ile seçilir (ok tuşları + onay, Esc = vazgeç).
## Metinler çeviri anahtarlarındandır (cat.menu.*, cat.bond.*, cat.trait.*).

signal chosen(choice: String)        # "pet" | "take" | "leave" | "close"

var cat_id: String = ""
var can_pet: bool = true

var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 112
	process_mode = Node.PROCESS_MODE_ALWAYS
	var roster := get_node_or_null("/root/CatRoster")
	if roster == null:
		_close("close")
		return
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	style.border_color = Color(0.55, 0.5, 0.4, 1.0)
	style.set_border_width_all(2)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	# Yukarıda dursun: menü açıkken kedi ve oyuncu (ekranın ortasında) görünsün.
	panel.anchor_top = 0.2
	panel.anchor_bottom = 0.2
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var level: int = int(roster.get_level(cat_id))
	box.add_child(_label("%s  (%s)" % [roster.get_cat_name(cat_id), tr("cat.menu.bond") % tr("cat.bond.%d" % level)], 22, Color(1.0, 0.92, 0.7)))
	var trait_id: String = String(roster.get_trait(cat_id))
	if not trait_id.is_empty():
		box.add_child(_label(tr("cat.trait.%s.name" % trait_id), 19, Color(0.7, 0.9, 0.75)))
		box.add_child(_label(tr("cat.trait.%s.desc" % trait_id), 16, Color(0.85, 0.85, 0.85)))
	var perk_id: String = String(roster.get_perk(cat_id))
	if not perk_id.is_empty():
		var perk_info: Dictionary = MetaUpgradeConfig.get_level_bonus(perk_id)
		box.add_child(_label(tr("cat.perk.%s" % perk_id) % (1 if perk_id == "item" else int(perk_info["amount"])), 17, Color(1.0, 0.85, 0.5)))
	var rest: int = int(roster.get_rest_runs(cat_id))
	if rest > 0:
		box.add_child(_label(tr("cat.menu.resting") % rest, 16, Color(0.95, 0.7, 0.55)))
	elif roster.is_companion(cat_id):
		box.add_child(_label(tr("cat.menu.with_you"), 16, Color(0.7, 0.85, 1.0)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var pet_btn := _button(tr("cat.menu.pet"), "pet", row)
	pet_btn.disabled = not can_pet
	var companion_key: String = "leave" if roster.is_companion(cat_id) else "take"
	_button(tr("cat.menu.%s" % companion_key), companion_key, row)
	_button(tr("cat.menu.close"), "close", row)
	# İlk odak: Okşa'ya basılamıyorsa bir sonraki düğmeye.
	for b in _buttons:
		if not b.disabled:
			b.grab_focus()
			break


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(380, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, choice: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(120, 38)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(_close.bind(choice))
	parent.add_child(b)
	_buttons.append(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close("close")


func _close(choice: String) -> void:
	chosen.emit(choice)
	queue_free()
