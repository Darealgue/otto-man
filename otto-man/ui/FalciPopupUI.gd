extends Control
class_name FalciPopupUI
## Gezgin falcı: tam ekran deste yönetimi (bkz. docs/FALCI_REWORK.md).
## Düzen (Hearthstone koleksiyonu gibi): solda element şeridi, ortada 5x2 sayfalı kart ızgarası,
## sağda hizmet paneli (satış, takas sepeti, falcı yükseltme), altta seçili kartın açıklaması.
## İşlemler (Güçlendir / Arşivle / Takas) seçili kartın ÜSTÜNDE çıkar. İş mantığı ve fiyatlar ItemManager'da;
## burası yalnızca altın tahsil eder ve çağırır (önce can_*, sonra harca, sonra işlem).
## Oyunu durdurmaz (process_mode ALWAYS).

signal closed

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const GOLD_ICON := preload("res://assets/Icons/gold_icon.png")

const TAB_ALL := "all"
const TAB_ARCHIVE := "archive"
const THEME_TABS: Array[String] = ["ates", "buz", "zehir", "firtina", "barut", "golge", "notr"]

const SORT_CHRONO := 0
const SORT_ELEMENT := 1
const SORT_CATEGORY := 2

const COLUMNS := 5
const ROWS := 2
const PAGE_SIZE := COLUMNS * ROWS
const MARGIN := 40

var _is_open := false
var _tab: String = TAB_ALL
var _sort: int = SORT_CHRONO
var _page: int = 0
var _page_count: int = 1
var _selected_id: String = ""
var _selected_closed := false
var _selected_sale := false
var _swap_sel: Array[String] = []
var _meta_cache: Dictionary = {}
var _card_holder: Dictionary = {}    # item_id -> Control (kartın dış kutusu)
var _card_main: Dictionary = {}      # item_id -> Button
var _rail_buttons: Dictionary = {}   # sekme anahtarı -> Button
const _KeyChip := preload("res://ui/KeyChip.gd")
const CLOTH_TEXTURE_PATH := "res://assets/NPC/Fortune_teller/Falcı_arayüz_el.png"
const _CurtainScript := preload("res://ui/ClothCurtain.gd")
var _bg: ColorRect
var _curtain: Control
var _content: Control
var _intro_active := false
var _closing := false
var _open_id: String = ""            # işlem düğmeleri açık olan kart (tıklanınca açılır)
var _actions_layer: Control          # düğmeler en üstte çizilsin diye ayrı katman

var _gold_label: Label
var _deck_label: Label
var _level_label: Label
var _rail: VBoxContainer
var _sort_opt: OptionButton
var _grid: GridContainer
var _pager_label: Label
var _side: VBoxContainer
var _detail_name: Label
var _detail_desc: Label
var _detail_hint: Label
var _info_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _MEDIEVAL_THEME
	UiFontFloor.attach(self)
	_build_ui()
	visible = false
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _im() -> Node:
	return get_node_or_null("/root/ItemManager")


# ----------------------------------------------------------------------------- build

func _build_ui() -> void:
	# Zemin: örtü animasyonu bitince tam siyah zemin devreye girer (animasyon sırasında köy görünür kalır)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.gui_input.connect(_on_bg_gui_input)
	add_child(_bg)

	# Örtü: 3840x1080 çizim; sağdan girer, sola kadar gider ve son hâliyle arayüzün arka planı olur
	_curtain = _CurtainScript.new()
	_curtain.setup(CLOTH_TEXTURE_PATH)
	_curtain.covered.connect(_finish_intro)
	_curtain.uncovered.connect(_finish_close)
	add_child(_curtain)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	add_child(margin)
	_content = margin

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# --- üst bar ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 26)
	root.add_child(top)

	var title := Label.new()
	title.text = tr("falci.title")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	top.add_child(title)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 19)
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_level_label)

	_deck_label = Label.new()
	_deck_label.add_theme_font_size_override("font_size", 19)
	_deck_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_deck_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var gold_icon := TextureRect.new()
	gold_icon.texture = GOLD_ICON
	gold_icon.custom_minimum_size = Vector2(32, 32)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(gold_icon)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 28)
	_gold_label.modulate = Color(1, 0.9, 0.45)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_gold_label)

	root.add_child(_make_divider())

	# --- gövde: sol şerit | kart ızgarası | sağ panel ---
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	_rail = VBoxContainer.new()
	_rail.custom_minimum_size = Vector2(190, 0)
	_rail.add_theme_constant_override("separation", 6)
	body.add_child(_rail)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	body.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.gui_input.connect(_on_grid_gui_input)
	center.add_child(_grid)

	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 20)
	center.add_child(pager)
	# Tuş rozetleri oyuncunun kullandığı cihaza göre değişir (klavye Q/E, gamepad L2/R2)
	var chip_l: PanelContainer = _KeyChip.new()
	chip_l.setup("Q", "L2")
	pager.add_child(chip_l)
	_pager_label = Label.new()
	_pager_label.add_theme_font_size_override("font_size", 20)
	_pager_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pager.add_child(_pager_label)
	var chip_r: PanelContainer = _KeyChip.new()
	chip_r.setup("E", "R2")
	pager.add_child(chip_r)

	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(300, 0)
	_side.add_theme_constant_override("separation", 12)
	body.add_child(_side)

	root.add_child(_make_divider())

	# --- seçili kartın açıklaması (her zaman görünür) ---
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(0, 148)
	root.add_child(detail)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 26)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 19)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(_detail_desc)

	# Açıklama ile işlem ipuçları arasında iki satırlık boşluk; ipuçları sola dayalı kalır
	var hint_gap := Control.new()
	hint_gap.custom_minimum_size = Vector2(0, 36)
	hint_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(hint_gap)

	_detail_hint = Label.new()
	_detail_hint.add_theme_font_size_override("font_size", 15)
	_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_hint.modulate = Color(1, 0.9, 0.6, 0.65)
	detail.add_child(_detail_hint)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_info_label)

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	close_row.add_theme_constant_override("separation", 10)
	root.add_child(close_row)
	var hint := Label.new()
	hint.text = tr("falci.v2.close_label")
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_row.add_child(hint)
	var close_chip: PanelContainer = _KeyChip.new()
	close_chip.setup("Esc", "B", 16)
	close_row.add_child(close_chip)

	TextOutline.apply_to_tree(self)

	# İşlem düğmeleri kartın içinde değil, her şeyin üstünde bu katmanda çizilir (komşu kartların arkasında kalmasın)
	_actions_layer = Control.new()
	_actions_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_actions_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions_layer.z_index = 100
	add_child(_actions_layer)


func _make_divider() -> Control:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.6, 0.47, 0.28, 0.85)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


# ----------------------------------------------------------------------------- open / close

func show_popup() -> void:
	_reapply_full_rect()
	_curtain.reset()
	_closing = false
	_is_open = true
	_meta_cache.clear()
	_swap_sel.clear()
	_selected_id = ""
	_selected_sale = false
	_tab = TAB_ALL
	_open_id = ""
	_page = 0
	_info_label.text = ""
	var im := _im()
	if im and not im.is_connected("falci_deck_changed", _on_deck_changed):
		im.connect("falci_deck_changed", _on_deck_changed)
	_refresh()
	visible = true
	_play_intro()


## Açılış: örtüyü seren el sağdan girip sola kadar gider; kalan siyah örtü arayüzün zemini olur.
func _play_intro() -> void:
	_closing = false
	_bg.visible = false
	_content.visible = false
	if not _curtain.has_cloth():
		_finish_intro()
		return
	_intro_active = true
	_curtain.play_in()


func _finish_intro() -> void:
	_intro_active = false
	_bg.visible = true
	_content.visible = true
	_content.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_content, "modulate:a", 1.0, 0.25)
	call_deferred("_grab_initial_focus")


## Kapanış: açılışın tersi, hızlı. İçerik hemen gizlenir, siyah zemin kalkar, örtü sağa çekilirken köy görünür.
func hide_popup() -> void:
	if _closing:
		return
	if _anim_active:
		_anim_can_dismiss = true
		_anim_done.emit()
	_close_actions()
	_intro_active = false
	if not _curtain.has_cloth():
		_finish_close()
		return
	_closing = true
	_content.visible = false
	_bg.visible = false
	_curtain.play_out()


func _finish_close() -> void:
	_closing = false
	_is_open = false
	visible = false
	closed.emit()


func _on_deck_changed() -> void:
	if _is_open:
		_refresh()


# ----------------------------------------------------------------------------- data helpers

func _current_gold() -> int:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	return int(gpd.gold) if gpd else 0


func _spend_gold(amount: int) -> bool:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	if gpd == null or int(gpd.gold) < amount:
		return false
	gpd.gold = int(gpd.gold) - amount
	return true


func _refund_gold(amount: int) -> void:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	if gpd:
		gpd.gold = int(gpd.gold) + amount


func _meta(item_id: String) -> Dictionary:
	if not _meta_cache.has(item_id):
		var im := _im()
		_meta_cache[item_id] = im.call("get_item_meta", item_id) if im else {}
	return _meta_cache[item_id]


func _item_name(item_id: String) -> String:
	return String(_meta(item_id).get("name", item_id))


func _theme_title(theme: String) -> String:
	return tr("falci.v2.theme." + theme)


func _theme_of(item_id: String) -> String:
	var im := _im()
	return String(im.call("get_item_theme", item_id)) if im else "notr"


func _reason_text(reason: String) -> String:
	return tr("falci.v2.reason." + reason)


func _compact(text: String) -> String:
	# "Güçlendir (150)" -> iki satır: dar kart düğmelerine sığsın
	return text.replace(" (", "\n(")


# ----------------------------------------------------------------------------- refresh

func _refresh() -> void:
	var im := _im()
	if im == null:
		return
	_close_actions()
	_gold_label.text = str(_current_gold())
	var level: int = int(im.get("falci_level"))
	var boosted: int = (im.get("boosted_item_ids") as Array).size()
	_level_label.text = tr("falci.v2.level") % [level, int(im.FALCI_MAX_LEVEL)] + "     " + tr("falci.v2.boost_slots") % [boosted, level]
	_deck_label.text = tr("falci.v2.deck") % [(im.call("get_deck_ids") as Array).size(), int(im.call("get_deck_floor"))]
	_rebuild_rail()
	_rebuild_grid()
	_rebuild_side()
	_refresh_detail()
	# Yeniden kurulan düğümler odağı kaybettirir: ilk karta (yoksa sekmeye) dön
	call_deferred("_grab_initial_focus")


func _rebuild_rail() -> void:
	for child in _rail.get_children():
		_rail.remove_child(child)
		child.queue_free()
	_rail_buttons.clear()
	var im := _im()
	var deck: Array = im.call("get_deck_ids")
	var counts: Dictionary = {}
	for id in deck:
		var t: String = _theme_of(String(id))
		counts[t] = int(counts.get(t, 0)) + 1
	var order: Array[String] = [TAB_ALL]
	order.append_array(THEME_TABS)
	for key in order:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = key == _tab
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(0, 46)
		var n: int = deck.size() if key == TAB_ALL else int(counts.get(key, 0))
		var label: String = tr("falci.v2.tab.all") if key == TAB_ALL else _theme_title(key)
		btn.text = "%s  (%d)" % [label, n]
		if key != TAB_ALL:
			var col: Color = im.call("get_theme_color", key)
			btn.add_theme_color_override("font_color", col.lightened(0.3))
			btn.add_theme_color_override("font_pressed_color", col.lightened(0.5))
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.darkened(0.7)
			sb.border_width_left = 6
			sb.border_color = col
			sb.set_corner_radius_all(6)
			sb.set_content_margin_all(8)
			btn.add_theme_stylebox_override("normal", sb)
			var sbp: StyleBoxFlat = sb.duplicate()
			sbp.bg_color = col.darkened(0.45)
			btn.add_theme_stylebox_override("pressed", sbp)
			btn.add_theme_stylebox_override("hover", sbp)
		btn.pressed.connect(_on_tab_pressed.bind(key))
		_style_focus(btn)
		_rail.add_child(btn)
		_rail_buttons[key] = btn

	var arch := Button.new()
	arch.toggle_mode = true
	arch.button_pressed = _tab == TAB_ARCHIVE
	arch.alignment = HORIZONTAL_ALIGNMENT_LEFT
	arch.add_theme_font_size_override("font_size", 20)
	arch.custom_minimum_size = Vector2(0, 46)
	arch.text = "%s  (%d)" % [tr("falci.v2.tab.archive"), (im.get("archived_item_ids") as Array).size()]
	arch.pressed.connect(_on_tab_pressed.bind(TAB_ARCHIVE))
	_style_focus(arch)
	_rail.add_child(arch)
	_rail_buttons[TAB_ARCHIVE] = arch

	var sort_lbl := Label.new()
	sort_lbl.text = tr("falci.v2.sort.label")
	sort_lbl.add_theme_font_size_override("font_size", 16)
	sort_lbl.modulate = Color(1, 1, 1, 0.7)
	_rail.add_child(sort_lbl)

	_sort_opt = OptionButton.new()
	_sort_opt.add_theme_font_size_override("font_size", 17)
	_sort_opt.add_item(tr("falci.v2.sort.chrono"), SORT_CHRONO)
	_sort_opt.add_item(tr("falci.v2.sort.element"), SORT_ELEMENT)
	_sort_opt.add_item(tr("falci.v2.sort.category"), SORT_CATEGORY)
	_sort_opt.select(_sort)
	_sort_opt.item_selected.connect(_on_sort_selected)
	_style_focus(_sort_opt)
	_rail.add_child(_sort_opt)


## Sekmede gösterilecek kartlar: [{id, closed}]
func _tab_entries() -> Array:
	var im := _im()
	var out: Array = []
	var ids: Array[String] = []
	if _tab == TAB_ARCHIVE:
		for id in (im.get("archived_item_ids") as Array):
			ids.append(String(id))
	else:
		ids = im.call("get_deck_ids")
	# Kronolojik: en son açılan başta. unlocked_item_ids açılış sırasıyla tutulur.
	var chrono: Array[String] = []
	var unlocked: Array = im.get("unlocked_item_ids")
	for i in range(unlocked.size() - 1, -1, -1):
		var uid: String = String(unlocked[i])
		if uid in ids:
			chrono.append(uid)
	var filtered: Array[String] = []
	for id in chrono:
		if _tab in THEME_TABS and _theme_of(id) != _tab:
			continue
		filtered.append(id)
	filtered = _apply_sort(filtered)
	for id in filtered:
		out.append({"id": id, "closed": false})
	# Tema sekmelerinde henüz açılmamışlar silüet olarak sonda görünür (koleksiyon ilerlemesi)
	if _tab in THEME_TABS and _tab != "notr":
		var pool: Array[String] = []
		pool.append_array(im.call("_theme_pool", _tab, ""))
		pool.append_array(im.call("_child_ids_for", _tab, ""))
		var seen: Array[String] = []
		for id in pool:
			if id in seen or im.call("is_unlocked", id) or id in im.EXCLUDED_ITEM_IDS:
				continue
			seen.append(id)
			out.append({"id": id, "closed": true})
	return out


func _apply_sort(ids: Array[String]) -> Array[String]:
	if _sort == SORT_CHRONO:
		return ids
	var keyed: Array = []
	for i in range(ids.size()):
		var id: String = ids[i]
		var k: int
		if _sort == SORT_ELEMENT:
			k = THEME_TABS.find(_theme_of(id))
		else:
			k = int(_meta(id).get("category", 0))
		keyed.append([k, i, id])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[String] = []
	for entry in keyed:
		out.append(String(entry[2]))
	return out


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_card_holder.clear()
	_card_main.clear()
	var entries: Array = _tab_entries()
	_page_count = maxi(1, int(ceil(float(entries.size()) / float(PAGE_SIZE))))
	_page = clampi(_page, 0, _page_count - 1)
	var start: int = _page * PAGE_SIZE
	for i in range(start, mini(entries.size(), start + PAGE_SIZE)):
		_grid.add_child(_make_card(String(entries[i]["id"]), bool(entries[i]["closed"])))
	if entries.is_empty():
		var empty := Label.new()
		empty.text = tr("falci.v2.grid.empty")
		empty.add_theme_font_size_override("font_size", 22)
		empty.modulate = Color(1, 1, 1, 0.6)
		_grid.add_child(empty)
	_pager_label.text = tr("falci.v2.page") % [_page + 1, _page_count]
	# Seçili kart bu sayfada değilse ilk kartı seç
	if _selected_id.is_empty() or not _card_main.has(_selected_id):
		if _selected_sale:
			pass
		elif not entries.is_empty():
			var first: Dictionary = entries[start]
			_selected_id = String(first["id"])
			_selected_closed = bool(first["closed"])
			_selected_sale = false


func _make_card(item_id: String, closed: bool) -> Control:
	var im := _im()
	var col: Color = im.call("get_theme_color", _theme_of(item_id))
	var boosted: bool = bool(im.call("is_boosted", item_id))
	var archived: bool = bool(im.call("is_archived", item_id))
	var swap_picked: bool = item_id in _swap_sel

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 150)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 23)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.62) if not closed else Color(0.12, 0.11, 0.10)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	var border_w := 3
	var border_col: Color = col if not closed else Color(0.3, 0.28, 0.25)
	if boosted:
		border_w = 6
		border_col = Color(1.0, 0.85, 0.3)
	if swap_picked:
		border_w = 6
		border_col = Color(1, 1, 1)
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	# Fare üstüne gelince vurgu YOK: yalnızca seçilen (tıklanan/odaklanan) kart vurgulanır
	for state in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat = sb.duplicate()
		if state == "pressed" or state == "focus":
			s.bg_color = s.bg_color.lightened(0.16)
			s.border_color = Color(1.0, 0.95, 0.7)
		btn.add_theme_stylebox_override(state, s)

	var line2: String = ""
	var card_text: String
	if closed:
		card_text = "???\n" + tr("falci.v2.closed.hint")
		btn.modulate = Color(1, 1, 1, 0.55)
	else:
		if swap_picked:
			line2 = tr("falci.v2.state.swap")
		elif boosted:
			line2 = tr("falci.v2.state.boosted")
		elif archived:
			line2 = tr("falci.v2.state.archived")
		card_text = _item_name(item_id) + ("\n" + line2 if not line2.is_empty() else "")
	holder.add_child(btn)

	# İsim kartın alt kısmında durur: üst bölge sonradan gelecek çizimlere ayrıldı
	var name_lbl := Label.new()
	name_lbl.text = card_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 23)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.anchor_left = 0.0
	name_lbl.anchor_right = 1.0
	name_lbl.anchor_top = 0.0
	name_lbl.anchor_bottom = 1.0
	name_lbl.offset_left = 10
	name_lbl.offset_right = -10
	name_lbl.offset_top = 10
	name_lbl.offset_bottom = -14
	if closed:
		name_lbl.modulate = Color(1, 1, 1, 0.55)
	holder.add_child(name_lbl)
	_card_main[item_id] = btn
	_card_holder[item_id] = holder

	# Seçim yalnızca odak/tıklama ile değişir (fare üstüne gelmek vurgu ve açıklama değiştirmez)
	btn.focus_entered.connect(_select.bind(item_id, closed, false))
	if not closed:
		btn.pressed.connect(_on_card_pressed.bind(item_id))
	return holder


## Kart tıklanınca (ya da gamepad'de basılınca) kartın alt kenarında işlem düğmeleri açılır.
func _open_actions(item_id: String) -> void:
	_close_actions()
	var holder: Control = _card_holder.get(item_id)
	if holder == null or not is_instance_valid(holder):
		return
	var im := _im()
	var archived: bool = bool(im.call("is_archived", item_id))
	var boosted: bool = bool(im.call("is_boosted", item_id))
	var swap_picked: bool = item_id in _swap_sel

	var rect: Rect2 = holder.get_global_rect()
	var bar := HBoxContainer.new()
	bar.name = "ActionBar"
	bar.add_theme_constant_override("separation", 6)
	bar.size = Vector2(rect.size.x - 16.0, 62.0)
	bar.global_position = Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y - 70.0)
	_actions_layer.add_child(bar)

	if archived:
		_add_card_action(bar, tr("falci.v2.act.restore") % int(im.FALCI_RESTORE_COST), _on_restore_pressed.bind(item_id))
	else:
		if boosted:
			_add_card_action(bar, tr("falci.v2.act.unboost"), _on_unboost_pressed.bind(item_id))
		else:
			_add_card_action(bar, tr("falci.v2.act.boost") % int(im.call("get_boost_cost")), _on_boost_pressed.bind(item_id))
		_add_card_action(bar, tr("falci.v2.act.archive") % int(im.call("get_archive_cost")), _on_archive_pressed.bind(item_id))
		_add_card_action(bar, tr("falci.v2.act.swap_remove") if swap_picked else tr("falci.v2.act.swap_add"), _on_swap_toggle_pressed.bind(item_id))
	_open_id = item_id


func _close_actions() -> void:
	_open_id = ""
	if _actions_layer == null:
		return
	for child in _actions_layer.get_children():
		_actions_layer.remove_child(child)
		child.queue_free()


func _add_card_action(parent: Control, text: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = _compact(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.15, 0.09, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.85, 0.7, 0.35)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(0.4, 0.3, 0.12, 1.0)
	hov.border_color = Color(1.0, 0.9, 0.5)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	_style_focus(b)
	b.pressed.connect(handler)
	parent.add_child(b)


# ----------------------------------------------------------------------------- sağ panel

func _rebuild_side() -> void:
	for child in _side.get_children():
		_side.remove_child(child)
		child.queue_free()
	var im := _im()
	var gold: int = _current_gold()

	# Falcı yükseltme
	var up_cost: int = int(im.call("get_falci_upgrade_cost"))
	var up := Button.new()
	up.add_theme_font_size_override("font_size", 19)
	up.custom_minimum_size = Vector2(0, 48)
	if up_cost < 0:
		up.text = tr("falci.v2.upgrade_max")
		up.disabled = true
	else:
		up.text = tr("falci.v2.upgrade") % up_cost
	up.pressed.connect(_on_upgrade_pressed)
	_style_focus(up)
	_side.add_child(up)

	# Bu ziyaretin satışı
	_side.add_child(_section_title(tr("falci.v2.sale.title")))
	var stock: Array = im.call("get_falci_sale_stock")
	if stock.is_empty():
		var none := Label.new()
		none.text = tr("falci.v2.sale.empty")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 15)
		none.modulate = Color(1, 1, 1, 0.6)
		_side.add_child(none)
	else:
		for raw in stock:
			var sid: String = String(raw)
			var col: Color = im.call("get_item_color", sid)
			var row := Button.new()
			row.text = "%s  -  %d" % [_item_name(sid), int(im.FALCI_SALE_PRICE)]
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_theme_font_size_override("font_size", 18)
			row.custom_minimum_size = Vector2(0, 44)
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.darkened(0.65)
			sb.border_width_left = 6
			sb.border_color = col
			sb.set_corner_radius_all(6)
			sb.set_content_margin_all(8)
			row.add_theme_stylebox_override("normal", sb)
			var sbh: StyleBoxFlat = sb.duplicate()
			sbh.bg_color = col.darkened(0.4)
			row.add_theme_stylebox_override("hover", sbh)
			row.add_theme_stylebox_override("pressed", sbh)
			if gold < int(im.FALCI_SALE_PRICE):
				row.modulate = Color(1, 1, 1, 0.75)
			row.mouse_entered.connect(_select.bind(sid, false, true))
			row.focus_entered.connect(_select.bind(sid, false, true))
			row.pressed.connect(_on_buy_pressed.bind(sid))
			_style_focus(row)
			_side.add_child(row)
		var sale_hint := Label.new()
		sale_hint.text = tr("falci.v2.sale.hint")
		sale_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sale_hint.add_theme_font_size_override("font_size", 14)
		sale_hint.modulate = Color(1, 0.9, 0.6, 0.65)
		_side.add_child(sale_hint)

	# Takas sepeti
	_side.add_child(_section_title(tr("falci.v2.trade.title") + "  %d/%d" % [_swap_sel.size(), int(im.FALCI_SWAP_SACRIFICE_COUNT)]))
	for i in range(int(im.FALCI_SWAP_SACRIFICE_COUNT)):
		var slot := Button.new()
		slot.add_theme_font_size_override("font_size", 18)
		slot.custom_minimum_size = Vector2(0, 40)
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i < _swap_sel.size():
			slot.text = "%s   x" % _item_name(_swap_sel[i])
			slot.pressed.connect(_on_swap_toggle_pressed.bind(_swap_sel[i]))
		else:
			slot.text = tr("falci.v2.trade.empty")
			slot.disabled = true
		_style_focus(slot)
		_side.add_child(slot)
	var swap_cost: int = int(im.FALCI_SWAP_COST)
	var go := Button.new()
	go.text = tr("falci.v2.swap.go") % swap_cost
	go.add_theme_font_size_override("font_size", 19)
	go.custom_minimum_size = Vector2(0, 46)
	go.disabled = _swap_sel.size() != int(im.FALCI_SWAP_SACRIFICE_COUNT)
	go.pressed.connect(_on_swap_pressed)
	_style_focus(go)
	_side.add_child(go)
	var trade_hint := Label.new()
	trade_hint.text = tr("falci.v2.trade.hint")
	trade_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_hint.add_theme_font_size_override("font_size", 14)
	trade_hint.modulate = Color(1, 0.9, 0.6, 0.65)
	_side.add_child(trade_hint)


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	return l


# ----------------------------------------------------------------------------- seçim / açıklama

func _select(item_id: String, closed: bool, sale: bool) -> void:
	if _selected_id == item_id and _selected_closed == closed and _selected_sale == sale:
		return
	_selected_id = item_id
	_selected_closed = closed
	_selected_sale = sale
	# Başka karta geçince açık işlem düğmeleri kapanır (düğmelerin üstündeyken karta ait kalır)
	if _open_id != "" and _open_id != item_id:
		_close_actions()
	_refresh_detail()


func _on_card_pressed(item_id: String) -> void:
	_select(item_id, false, false)
	if _open_id == item_id:
		_close_actions()
		return
	_open_actions(item_id)
	# Gamepad/klavye: karta basınca işlem düğmelerine geç
	if _actions_layer.get_child_count() > 0:
		var bar: Node = _actions_layer.get_child(0)
		for child in bar.get_children():
			if child is Button:
				(child as Button).call_deferred("grab_focus")
				return


func _refresh_detail() -> void:
	var im := _im()
	if im == null or _selected_id.is_empty():
		_detail_name.text = ""
		_detail_desc.text = tr("falci.v2.detail.none")
		_detail_hint.text = ""
		return
	if _selected_closed:
		_detail_name.text = "???"
		_detail_name.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_detail_desc.text = tr("falci.v2.closed.hint") + " (%s)" % _theme_title(_theme_of(_selected_id))
		_detail_hint.text = ""
		return
	var theme: String = _theme_of(_selected_id)
	_detail_name.text = "%s   (%s)" % [_item_name(_selected_id), _theme_title(theme)]
	_detail_name.add_theme_color_override("font_color", im.call("get_theme_color", theme).lightened(0.4))
	_detail_desc.text = String(_meta(_selected_id).get("description", ""))
	if _selected_sale:
		_detail_hint.text = tr("falci.v2.hint.sale")
	elif bool(im.call("is_archived", _selected_id)):
		_detail_hint.text = tr("falci.v2.hint.archived")
	else:
		_detail_hint.text = tr("falci.v2.hint.actions")


# ----------------------------------------------------------------------------- sayfa / sekme

func _change_page(delta: int) -> void:
	var np: int = clampi(_page + delta, 0, _page_count - 1)
	if np == _page:
		return
	_page = np
	_selected_id = ""
	_close_actions()
	_rebuild_grid()
	_refresh_detail()
	call_deferred("_grab_initial_focus")


func _on_grid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_page(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_page(1)


func _on_tab_pressed(key: String) -> void:
	_tab = key
	_page = 0
	_selected_id = ""
	_selected_sale = false
	_info_label.text = ""
	_refresh()
	# Sekme düğmeleri yeniden kuruldu: odak sekmede kalsın (boş sekmede de gamepad takılmasın)
	call_deferred("_focus_tab", key)


func _focus_tab(key: String) -> void:
	var b: Button = _rail_buttons.get(key)
	if b and is_instance_valid(b):
		b.grab_focus()


func _on_sort_selected(index: int) -> void:
	_sort = _sort_opt.get_item_id(index)
	_page = 0
	_selected_id = ""
	_refresh()
	call_deferred("_focus_sort")


func _focus_sort() -> void:
	if _sort_opt and is_instance_valid(_sort_opt):
		_sort_opt.grab_focus()


# ----------------------------------------------------------------------------- işlemler

func _on_upgrade_pressed() -> void:
	var im := _im()
	if im == null:
		return
	var cost: int = int(im.call("get_falci_upgrade_cost"))
	if cost < 0:
		return
	if not _spend_gold(cost):
		_show_info(tr("falci.info.no_gold"), false)
		return
	im.call("upgrade_falci")
	_show_info(tr("falci.v2.info.upgraded") % int(im.get("falci_level")), true)
	_refresh()


func _on_boost_pressed(item_id: String) -> void:
	var im := _im()
	if im == null:
		return
	var check: Dictionary = im.call("can_boost_item", item_id)
	if not bool(check.get("ok", false)):
		_show_info(_reason_text(String(check.get("reason", ""))), false)
		return
	var cost: int = int(im.call("get_boost_cost"))
	if not _spend_gold(cost):
		_show_info(tr("falci.info.no_gold"), false)
		return
	im.call("boost_item", item_id)
	_show_info(tr("falci.v2.info.boosted") % _item_name(item_id), true)
	_refresh()


func _on_unboost_pressed(item_id: String) -> void:
	var im := _im()
	if im == null:
		return
	im.call("unboost_item", item_id)
	_show_info(tr("falci.v2.info.unboosted") % _item_name(item_id), true)
	_refresh()


func _on_archive_pressed(item_id: String) -> void:
	var im := _im()
	if im == null:
		return
	var check: Dictionary = im.call("can_archive_item", item_id)
	if not bool(check.get("ok", false)):
		_show_info(_reason_text(String(check.get("reason", ""))), false)
		return
	var cost: int = int(im.call("get_archive_cost"))
	if not _spend_gold(cost):
		_show_info(tr("falci.info.no_gold"), false)
		return
	_swap_sel.erase(item_id)
	im.call("archive_item", item_id)
	_show_info(tr("falci.v2.info.archived") % _item_name(item_id), true)
	_selected_id = ""
	_refresh()


func _on_restore_pressed(item_id: String) -> void:
	var im := _im()
	if im == null:
		return
	var cost: int = int(im.FALCI_RESTORE_COST)
	if not _spend_gold(cost):
		_show_info(tr("falci.info.no_gold"), false)
		return
	im.call("restore_item", item_id)
	_show_info(tr("falci.v2.info.restored") % _item_name(item_id), true)
	_selected_id = ""
	_refresh()


func _on_swap_toggle_pressed(item_id: String) -> void:
	var im := _im()
	if im == null:
		return
	if item_id in _swap_sel:
		_swap_sel.erase(item_id)
	else:
		if _swap_sel.size() >= int(im.FALCI_SWAP_SACRIFICE_COUNT):
			_show_info(_reason_text("count"), false)
			return
		_swap_sel.append(item_id)
	_info_label.text = ""
	_refresh()


func _on_swap_pressed() -> void:
	var im := _im()
	if im == null:
		return
	var check: Dictionary = im.call("can_swap_items", _swap_sel)
	if not bool(check.get("ok", false)):
		_show_info(_reason_text(String(check.get("reason", ""))), false)
		return
	var cost: int = int(im.FALCI_SWAP_COST)
	if not _spend_gold(cost):
		_show_info(tr("falci.info.no_gold"), false)
		return
	var gone: Array[String] = []
	for id in _swap_sel:
		gone.append(_item_name(id))
	var replacement: String = String(im.call("swap_items", _swap_sel))
	if replacement.is_empty():
		_refund_gold(cost)
		_show_info(tr("falci.v2.info.swap_failed"), false)
		_refresh()
		return
	var sacrificed: Array = _swap_sel.duplicate()
	_swap_sel.clear()
	_selected_id = ""
	_refresh()
	await _play_swap_animation(sacrificed, replacement)
	_show_info(tr("falci.v2.info.swapped") % [", ".join(gone), _item_name(replacement)], true)


func _on_buy_pressed(item_id: String) -> void:
	var im := _im()
	if im == null:
		return
	if not bool(im.call("can_buy_falci_sale", item_id)):
		_show_info(_reason_text("not_in_deck"), false)
		return
	var cost: int = int(im.FALCI_SALE_PRICE)
	if not _spend_gold(cost):
		_show_info(tr("falci.info.no_gold"), false)
		return
	if not bool(im.call("buy_falci_sale", item_id)):
		_refund_gold(cost)
		_show_info(tr("falci.v2.info.swap_failed"), false)
		_refresh()
		return
	_show_info(tr("falci.v2.info.bought") % _item_name(item_id), true)
	_selected_id = ""
	_selected_sale = false
	_refresh()


# ----------------------------------------------------------------------------- takas animasyonu

signal _anim_done

var _anim_active := false
var _anim_can_dismiss := false


func _anim_card(item_id: String, card_size: Vector2, font_size: int, with_desc: bool) -> PanelContainer:
	var im := _im()
	var col: Color = im.call("get_item_color", item_id)
	var p := PanelContainer.new()
	p.custom_minimum_size = card_size
	p.size = card_size
	p.pivot_offset = card_size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.55)
	sb.set_border_width_all(5)
	sb.border_color = col.lightened(0.25)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	var name_lbl := Label.new()
	name_lbl.text = _item_name(item_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", font_size)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_lbl.add_theme_constant_override("outline_size", 5)
	box.add_child(name_lbl)
	if with_desc:
		var d := Label.new()
		d.text = String(_meta(item_id).get("description", ""))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 18)
		d.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		d.add_theme_constant_override("outline_size", 4)
		box.add_child(d)
	return p


## Feda edilen kartlar ortada birleşir, parlama olur, yeni kart büyüyerek çıkar. Basınca kapanır.
func _play_swap_animation(sacrificed: Array, new_id: String) -> void:
	_anim_active = true
	_anim_can_dismiss = false
	_close_actions()

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 200
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.focus_mode = Control.FOCUS_ALL
	layer.gui_input.connect(_on_anim_gui_input)
	add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	layer.grab_focus()

	var center: Vector2 = size * 0.5
	var card_size := Vector2(240, 140)
	var focus_pos: Vector2 = center - card_size * 0.5 + Vector2(0, -30)
	var cards: Array[Control] = []
	for i in range(sacrificed.size()):
		var c: PanelContainer = _anim_card(String(sacrificed[i]), card_size, 24, false)
		c.position = focus_pos + Vector2((i - 1) * 330.0, 0)
		c.modulate.a = 0.0
		layer.add_child(c)
		cards.append(c)

	var t1 := create_tween().set_parallel(true)
	t1.tween_property(dim, "color:a", 0.85, 0.3)
	for c in cards:
		t1.tween_property(c, "modulate:a", 1.0, 0.3)
	await t1.finished
	await get_tree().create_timer(0.4).timeout

	var t2 := create_tween().set_parallel(true)
	for c in cards:
		t2.tween_property(c, "position", focus_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t2.tween_property(c, "scale", Vector2(0.75, 0.75), 0.6)
	await t2.finished

	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.95, 0.75, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var t3 := create_tween()
	t3.tween_property(flash, "color:a", 0.95, 0.15)
	await t3.finished
	for c in cards:
		c.queue_free()

	var new_size := Vector2(380, 240)
	var new_card: PanelContainer = _anim_card(new_id, new_size, 32, true)
	new_card.position = center - new_size * 0.5 + Vector2(0, 10)
	new_card.scale = Vector2(0.3, 0.3)
	layer.add_child(new_card)

	var title := Label.new()
	title.text = tr("falci.v2.anim.new")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(new_size.x, 48)
	title.position = Vector2(new_card.position.x, new_card.position.y - 70)
	title.modulate.a = 0.0
	layer.add_child(title)

	var t4 := create_tween().set_parallel(true)
	t4.tween_property(flash, "color:a", 0.0, 0.55)
	t4.tween_property(new_card, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t4.tween_property(title, "modulate:a", 1.0, 0.4)
	await t4.finished

	var cont := Label.new()
	cont.text = tr("falci.v2.anim.continue")
	cont.add_theme_font_size_override("font_size", 18)
	cont.modulate = Color(1, 1, 1, 0.7)
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cont.size = Vector2(new_size.x, 28)
	cont.position = Vector2(new_card.position.x, new_card.position.y + new_size.y + 22)
	layer.add_child(cont)

	_anim_can_dismiss = true
	await _anim_done
	_anim_active = false
	_anim_can_dismiss = false
	if is_instance_valid(layer):
		layer.queue_free()
	call_deferred("_grab_initial_focus")


func _on_anim_gui_input(event: InputEvent) -> void:
	if not _anim_can_dismiss:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_anim_done.emit()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_anim_done.emit()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_anim_done.emit()


func _show_info(text: String, good: bool) -> void:
	_info_label.text = text
	_info_label.modulate = Color(0.6, 1.0, 0.6) if good else Color(1, 0.55, 0.5)


# ----------------------------------------------------------------------------- odak / girdi

func _style_focus(control: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	sb.set_corner_radius_all(6)
	control.add_theme_stylebox_override("focus", sb)


func _grab_initial_focus() -> void:
	if not visible and not _is_open:
		return
	var main: Button = _card_main.get(_selected_id)
	if main and is_instance_valid(main):
		main.grab_focus()
		return
	for id in _card_main:
		var b: Button = _card_main[id]
		if is_instance_valid(b):
			b.grab_focus()
			return
	# Kart yoksa (boş arşiv/sekme) odak sekme şeridine gitsin
	_focus_tab(_tab)


func _on_bg_gui_input(_event: InputEvent) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if _intro_active:
		# Örtü serilirken Escape pencereyi hemen kapatır, başka girdi yutulur
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
			hide_popup()
		return
	if _anim_active:
		# Animasyon sürerken hiçbir şey pencereyi kapatmasın; bitince basış animasyonu kapatır
		get_viewport().set_input_as_handled()
		if _anim_can_dismiss and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back")):
			_anim_done.emit()
		return
	if event.is_action_pressed("ui_page_left") or event.is_action_pressed("l2_trigger"):
		get_viewport().set_input_as_handled()
		_change_page(-1)
		return
	if event.is_action_pressed("ui_page_right") or event.is_action_pressed("r2_trigger"):
		get_viewport().set_input_as_handled()
		_change_page(1)
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		get_viewport().set_input_as_handled()
		# Açık işlem düğmeleri varsa önce onları kapat ve karta dön, sonra pencereyi kapat
		if _open_id != "":
			var back_to: String = _open_id
			_close_actions()
			var main: Button = _card_main.get(back_to)
			if main and is_instance_valid(main):
				main.grab_focus()
			return
		hide_popup()
