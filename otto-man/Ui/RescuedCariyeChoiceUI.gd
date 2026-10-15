extends CanvasLayer
class_name RescuedCariyeChoiceUI
## Zindanda bir cariye kurtarılınca açılır: özelliklerini gösterir ve "köye al / yoluna gitsin"
## diye sorar. Karar verilene kadar oyun durur. Yoluna gönderilirse cariye teşekkür eder,
## küçük bir ödül bırakır (çağıran taraf verir). Klavye/kontrolcü: sol/sağ seç, onay karar.

signal decided(accept: bool)

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const _VillagerAppearance := preload("res://village/scripts/VillagerAppearance.gd")
const _PortraitRenderer := preload("res://ui/ConcubinePortraitRenderer.gd")
const LAYER := 140

var _accept_btn: Button
var _decline_btn: Button
var _done: bool = false
var _reward_gold: int = 0


## cariye_data: { isim, id (rezerve edilmiş cariye kimliği), appearance (Dictionary) }
func setup(cariye_data: Dictionary, reward_gold: int) -> void:
	_reward_gold = reward_gold
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preview := Concubine.new()
	preview.id = int(cariye_data.get("id", 0))
	preview.name = String(cariye_data.get("isim", "?"))
	var app_raw: Variant = cariye_data.get("appearance", null)
	if app_raw is Dictionary and (app_raw as Dictionary).size() > 0:
		var app = _VillagerAppearance.new()
		app.from_dict(app_raw)
		preview.appearance = app
	_build(preview)
	get_tree().paused = true
	call_deferred("_focus_default")


func _build(c: Concubine) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = _MEDIEVAL_THEME
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.01, 0.7)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -400
	panel.offset_right = 400
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.07, 0.98)
	sb.border_color = Color(0.78, 0.62, 0.32)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	var title := Label.new()
	title.text = tr("rescue.choice.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	outer.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	outer.add_child(body)

	# Portre
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(190, 190)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(portrait)

	# Ad + özellikler
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("normal_font_size", 20)
	info.add_theme_font_size_override("bold_font_size", 20)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[font_size=26][b]%s[/b][/font_size]" % c.name)
	lines.append("")
	lines.append("[b]%s[/b]" % tr("cm_popup.traits_title"))
	var traits: Array[String] = c.get_traits()
	if traits.is_empty():
		lines.append("[color=#b9a67a]%s[/color]" % tr("cm_popup.traits_none"))
	for t in traits:
		var kind: String = String(Concubine.TRAIT_KINDS.get(t, "good"))
		var col: String = "#8fd08a"
		if kind == "bad":
			col = "#e08a7a"
		elif kind == "mixed":
			col = "#e8c46a"
		lines.append("[color=%s][b]%s[/b][/color]  [color=#b9a67a]%s[/color]" % [
			col, tr("concubine.trait.%s.name" % t), tr("concubine.trait.%s.desc" % t)])
	info.text = "\n".join(lines)
	body.add_child(info)

	var q := Label.new()
	q.text = tr("rescue.choice.question") % c.name
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 20)
	outer.add_child(q)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	outer.add_child(row)
	_accept_btn = _make_button(tr("rescue.choice.accept"))
	_accept_btn.pressed.connect(_finish.bind(true))
	row.add_child(_accept_btn)
	_decline_btn = _make_button(tr("rescue.choice.decline") % _reward_gold)
	_decline_btn.pressed.connect(_finish.bind(false))
	row.add_child(_decline_btn)

	# Portre asenkron çizilir (SubViewport).
	if c.appearance != null:
		_PortraitRenderer.render(portrait, c, self, func() -> bool: return _done)


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 20)
	return b


func _focus_default() -> void:
	if is_instance_valid(_accept_btn):
		_accept_btn.grab_focus()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		var cur := get_viewport().gui_get_focus_owner()
		if cur == _accept_btn:
			_decline_btn.grab_focus()
		else:
			_accept_btn.grab_focus()
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var owner := get_viewport().gui_get_focus_owner()
		if owner == _decline_btn:
			_finish(false)
		else:
			_finish(true)
		return
	# Karar verilmeden başka girdi akmasın.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _finish(accept: bool) -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	decided.emit(accept)
	queue_free()
