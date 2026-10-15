extends Node
class_name DirectedMissionController
## Dünya haritasında "cariyeyi göreve yolla" seçim modu.
##
## Köydeki cariye penceresi haritayı payload ile açar (`select_mission_concubine_id`).
## WorldMapScene bu denetleyiciyi yaratır ve girdiyi / çizimi / onayı ona devreder:
##   1. İmleç bir hex'e gelince alttaki balon "burada ne yapılabilir"i gösterir.
##   2. Onay -> TEK küçük panel: görev (birden çoksa), asker, mal/hediye miktarı satırları.
##      Yukarı/aşağı satır seçer, sol/sağ değeri değiştirir (basılı tutunca tekrarlar),
##      Onay doğrudan yollar, İptal geri döner.
##   3. Gönder -> MissionManager.create_player_directed_mission, harita kapanıp köye dönülür.
## Mouse yok; tüm gezinme ui_up/down/left/right/accept/cancel ile.
## Bkz. docs/CONCUBINE_MAP_MISSIONS_PLAN.md.

const _MEDIEVAL_THEME := preload("res://resources/medieval_theme.tres")
const LAYER := 130
const TITLE_FONT := 24
const BODY_FONT := 20

enum Stage { NONE, PREP }

signal dispatched(mission_id: String)

var _map: Node2D = null
var _cid: int = -1
var _cariye: Concubine = null
var _mm: Node = null
var _layer: CanvasLayer = null
var _root: Control = null
var _banner_label: Label = null
var _hover_panel: PanelContainer = null
var _hover_label: RichTextLabel = null
var _modal_panel: PanelContainer = null
var _modal_label: RichTextLabel = null
var _stage: int = Stage.NONE
var _target_q: int = 0
var _target_r: int = 0
var _info: Dictionary = {}
var _opt_idx: int = 0
var _row: int = 0
var _soldiers: int = 0
var _gift: int = 0
var _hover_q: int = -99999
var _hover_r: int = -99999
var _hover_ok: bool = false
var _hover_accum: float = 0.0
var _error_text: String = ""


func setup(map: Node2D, concubine_id: int) -> bool:
	_map = map
	_cid = concubine_id
	_mm = get_node_or_null("/root/MissionManager")
	if _mm == null or not ("concubines" in _mm) or not _mm.concubines.has(concubine_id):
		return false
	_cariye = _mm.concubines[concubine_id]
	_build_ui()
	_refresh_hover(true)
	return true


func is_panel_open() -> bool:
	return _stage != Stage.NONE


func get_concubine_id() -> int:
	return _cid


## Seçenek başlığı/açıklaması: katalog seçenekleri çeviri anahtarı, eski görevler düz metin taşır.
func _opt_title(o: Dictionary) -> String:
	if o.has("title_text"):
		return String(o["title_text"])
	return tr(String(o.get("title_key", "")))


func _opt_desc(o: Dictionary) -> String:
	if o.has("desc_text"):
		return String(o["desc_text"])
	return tr(String(o.get("desc_key", "")))


## Seçim modunda rota önizlemesinin rengi (cariyenin rol rengi).
func route_color() -> Color:
	return _role_color() if _cariye != null else Color(1, 1, 1, 0.95)


# ─── UI ───────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.name = "DirectedMissionLayer"
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _MEDIEVAL_THEME
	_layer.add_child(_root)

	# Üst şerit: kimi yolluyoruz.
	var banner := PanelContainer.new()
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -420
	banner.offset_right = 420
	banner.offset_top = 14
	banner.offset_bottom = 74
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.06, 0.04, 0.82)))
	_root.add_child(banner)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", TITLE_FONT)
	_banner_label.text = tr("dm.banner") % [_cariye.name, _cariye.get_role_name()]
	banner.add_child(_banner_label)

	# Alt balon: imlecin olduğu hex'e ne yapılabilir (kısa liste).
	_hover_panel = PanelContainer.new()
	_hover_panel.anchor_left = 0.5
	_hover_panel.anchor_right = 0.5
	_hover_panel.anchor_top = 1.0
	_hover_panel.anchor_bottom = 1.0
	_hover_panel.offset_left = -300
	_hover_panel.offset_right = 300
	_hover_panel.offset_top = -190
	_hover_panel.offset_bottom = -70
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.06, 0.04, 0.8)))
	_root.add_child(_hover_panel)
	_hover_label = _make_rich_label(false)
	_hover_panel.add_child(_hover_label)

	# Gönderme paneli: içeriğe göre boylanan, ortada küçük kutu.
	_modal_panel = PanelContainer.new()
	_modal_panel.anchor_left = 0.5
	_modal_panel.anchor_right = 0.5
	_modal_panel.anchor_top = 0.5
	_modal_panel.anchor_bottom = 0.5
	_modal_panel.offset_left = -320
	_modal_panel.offset_right = 320
	_modal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_modal_panel.visible = false
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.1, 0.07, 0.97)))
	_root.add_child(_modal_panel)
	_modal_label = _make_rich_label(true)
	_modal_panel.add_child(_modal_label)


func _panel_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.78, 0.62, 0.32, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	return sb


func _make_rich_label(fit: bool) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = fit
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", BODY_FONT)
	l.add_theme_font_size_override("bold_font_size", BODY_FONT)
	return l


func _role_color() -> Color:
	return DirectedMissionCatalog.role_color(int(_cariye.role), Color(0.9, 0.9, 0.9))


# ─── Hex üzerinde bilgi (imleç gezinirken) ────────────────────────────────────

func _process(delta: float) -> void:
	if _map == null or _stage != Stage.NONE:
		return
	_hover_accum += delta
	var cq: int = int(_map.get("_cursor_q"))
	var cr: int = int(_map.get("_cursor_r"))
	if cq != _hover_q or cr != _hover_r or _hover_accum >= 0.6:
		_hover_accum = 0.0
		_refresh_hover(false)


func _refresh_hover(_force: bool) -> void:
	if _map == null or _mm == null:
		return
	_hover_q = int(_map.get("_cursor_q"))
	_hover_r = int(_map.get("_cursor_r"))
	var info: Dictionary = _mm.get_directed_mission_options(_cid, _hover_q, _hover_r)
	_hover_ok = bool(info.get("ok", false))
	var lines: PackedStringArray = PackedStringArray()
	var kind: String = String(info.get("kind", ""))
	if not kind.is_empty():
		lines.append("[b]%s[/b]" % tr("dm.kind." + kind))
	if _hover_ok:
		for o in info["options"]:
			lines.append("• %s" % _opt_title(o))
	else:
		lines.append("[color=#e08a7a]%s[/color]" % String(info.get("reason", "")))
	_hover_label.text = "\n".join(lines)


# ─── Girdi ────────────────────────────────────────────────────────────────────

## WorldMapScene._unhandled_input en başta çağırır; true dönerse olay tüketilmiştir.
func handle_input(event: InputEvent) -> bool:
	if _stage == Stage.NONE:
		return false
	var consume := func() -> void:
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		_close_panel()
		consume.call()
		return true
	if event.is_action_pressed("ui_accept"):
		_send()
		consume.call()
		return true
	if event.is_action_pressed("ui_down"):
		_move_row(1)
		consume.call()
		return true
	if event.is_action_pressed("ui_up"):
		_move_row(-1)
		consume.call()
		return true
	# Sol/sağ basılı tutulunca tekrarlar (miktar hızlı değişsin).
	if event.is_action_pressed("ui_left", true):
		_adjust(-1)
		consume.call()
		return true
	if event.is_action_pressed("ui_right", true):
		_adjust(1)
		consume.call()
		return true
	# Panel açıkken harita başka hiçbir girdiyi (zoom, rota, pause) işlemesin.
	if event is InputEventKey or event is InputEventJoypadButton:
		consume.call()
		return true
	return false


## Seçim modundayken onay tuşu: imlecin üstündeki hex için gönderme panelini aç.
func on_confirm(q: int, r: int) -> void:
	if _stage != Stage.NONE:
		return
	var info: Dictionary = _mm.get_directed_mission_options(_cid, q, r)
	if not bool(info.get("ok", false)):
		_hover_label.text = "[color=#e08a7a]%s[/color]" % String(info.get("reason", ""))
		return
	_target_q = q
	_target_r = r
	_info = info
	_opt_idx = 0
	_row = 0
	_error_text = ""
	_apply_defaults()
	_stage = Stage.PREP
	_modal_panel.visible = true
	_hover_panel.visible = false
	_render_modal()


func _close_panel() -> void:
	_stage = Stage.NONE
	_error_text = ""
	_modal_panel.visible = false
	_hover_panel.visible = true
	_refresh_hover(true)
	_map.queue_redraw()


func _options() -> Array:
	return _info.get("options", [])


func _current_option() -> Dictionary:
	var opts: Array = _options()
	if opts.is_empty():
		return {}
	return opts[clampi(_opt_idx, 0, opts.size() - 1)]


## Seçenek değişince asker ve miktar makul bir başlangıç değerine döner (onay direkt yollasın).
func _apply_defaults() -> void:
	var o: Dictionary = _current_option()
	var avail: int = int(_info.get("available_soldiers", 0))
	var scfg: Dictionary = o.get("soldiers", {})
	_soldiers = 0
	if not scfg.is_empty():
		_soldiers = clampi(int(scfg.get("rec", scfg.get("min", 1))), int(scfg.get("min", 0)), avail)
	var gcfg: Dictionary = o.get("gift", {})
	_gift = 0
	if not gcfg.is_empty():
		var step: int = int(gcfg.get("step", 5))
		var mult: int = 4 if o.has("sell_value") else (1 if o.has("recruit_gold_per") else 2)
		_gift = mini(_gift_cap(gcfg), step * mult)


## Görünen satırlar: görev (birden çok seçenek varsa), asker, miktar.
func _rows() -> Array[String]:
	var rows: Array[String] = []
	var o: Dictionary = _current_option()
	if _options().size() > 1:
		rows.append("option")
	if not (o.get("soldiers", {}) as Dictionary).is_empty():
		rows.append("soldiers")
	if not (o.get("gift", {}) as Dictionary).is_empty():
		rows.append("gift")
	return rows


func _move_row(dir: int) -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	_row = wrapi(_row + dir, 0, rows.size())
	_render_modal()


func _adjust(dir: int) -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	var row: String = rows[clampi(_row, 0, rows.size() - 1)]
	var o: Dictionary = _current_option()
	_error_text = ""
	if row == "option":
		var n: int = _options().size()
		_opt_idx = wrapi(_opt_idx + dir, 0, n)
		_apply_defaults()
		# Yeni seçenekte satır sayısı değişmiş olabilir: seçili satırı koru ama sınırla.
		_row = mini(_row, maxi(0, _rows().size() - 1))
	elif row == "soldiers":
		var cfg: Dictionary = o["soldiers"]
		var avail: int = int(_info.get("available_soldiers", 0))
		_soldiers = clampi(_soldiers + dir, int(cfg.get("min", 0)), avail)
	elif row == "gift":
		var gcfg: Dictionary = o["gift"]
		var step: int = int(gcfg.get("step", 5))
		_gift = clampi(_gift + dir * step, 0, _gift_cap(gcfg))
	_render_modal()


## Miktar tavanı: katalogdaki üst sınır ile elde olan stoğun küçüğü.
func _gift_cap(gcfg: Dictionary) -> int:
	var res: String = String(gcfg.get("res", "gold"))
	var have: int = 0
	if res == "gold":
		var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
		have = int(gpd.gold) if gpd != null and "gold" in gpd else 0
	else:
		var vm: Node = get_node_or_null("/root/VillageManager")
		if vm != null and vm.has_method("get_available_resource_level"):
			have = int(vm.call("get_available_resource_level", res))
	return mini(int(gcfg.get("max", 0)), have)


func _send() -> void:
	var o: Dictionary = _current_option()
	if o.is_empty():
		return
	var res: Dictionary = _mm.create_player_directed_mission(_cid, _target_q, _target_r, String(o.get("id", "")), _soldiers, _gift)
	if not bool(res.get("ok", false)):
		_error_text = String(res.get("reason", ""))
		_render_modal()
		return
	dispatched.emit(String(res.get("mission_id", "")))
	_stage = Stage.NONE
	_modal_panel.visible = false
	if _map != null and _map.has_method("_try_close_overlay_or_go_to_village"):
		_map.call("_try_close_overlay_or_go_to_village")


# ─── Çizim (WorldMapScene._draw içinden) ──────────────────────────────────────

func draw_overlay(canvas: CanvasItem, to_px: Callable, hex_pts: Callable) -> void:
	if _map == null:
		return
	var cq: int = int(_map.get("_cursor_q"))
	var cr: int = int(_map.get("_cursor_r"))
	var center: Vector2 = to_px.call(cq, cr)
	var col: Color = _role_color() if _hover_ok else Color(0.9, 0.3, 0.25, 0.9)
	var pts: PackedVector2Array = hex_pts.call(center, 36.0, 15.0)
	canvas.draw_polyline(pts, Color(0.05, 0.04, 0.03, 0.8), 6.0, true)
	canvas.draw_polyline(pts, col, 3.4, true)
	if _stage != Stage.NONE:
		var tc: Vector2 = to_px.call(_target_q, _target_r)
		canvas.draw_circle(tc, 7.0, Color(col.r, col.g, col.b, 0.35))


# ─── Panel içeriği ────────────────────────────────────────────────────────────

func _value_text(text: String, selected: bool) -> String:
	if selected:
		return "[b]◀  %s  ▶[/b]" % text
	return "[b]%s[/b]" % text


func _render_modal() -> void:
	var o: Dictionary = _current_option()
	var rows := _rows()
	var lines: PackedStringArray = PackedStringArray()
	var col_hex: String = _role_color().to_html(false)
	lines.append("[font_size=%d][b][color=#%s]%s[/color][/b][/font_size]" % [
		TITLE_FONT, col_hex, tr("dm.modal.title") % [_cariye.name, _cariye.get_role_name()]])
	lines.append("[color=#b9a67a]%s · %s[/color]" % [
		tr("dm.kind." + String(_info.get("kind", ""))),
		tr("dm.distance") % int(_info.get("distance", 0))])
	lines.append("")
	# Görev adı (tek seçenekse başlık olarak, çoksa seçilebilir satır olarak)
	if rows.has("option"):
		var sel_o: bool = rows[clampi(_row, 0, rows.size() - 1)] == "option"
		var label_val: String = _opt_title(o)
		if o.has("sell_value"):
			label_val = tr("dm.res." + String((o.get("gift", {}) as Dictionary).get("res", "gold")))
		var c0: String = "#ffe9a8" if sel_o else "#d8cdb0"
		var name_key: String = "dm.prep.good" if o.has("sell_value") else "dm.prep.task"
		lines.append("[color=%s]%s:  %s[/color]" % [c0, tr(name_key), _value_text(label_val, sel_o)])
	else:
		lines.append("[b]%s[/b]" % _opt_title(o))
	# Asker / miktar satırları
	for i in range(rows.size()):
		var row: String = rows[i]
		if row == "option":
			continue
		var sel: bool = i == clampi(_row, 0, rows.size() - 1)
		var c: String = "#ffe9a8" if sel else "#d8cdb0"
		if row == "soldiers":
			lines.append("[color=%s]%s:  %s / %d[/color]" % [
				c, tr("dm.prep.soldiers"), _value_text(str(_soldiers), sel), int(_info.get("available_soldiers", 0))])
		elif row == "gift":
			var gc: Dictionary = o["gift"]
			var gname: String = tr("dm.prep.amount") if o.has("sell_value") else tr("dm.res." + String(gc.get("res", "gold")))
			lines.append("[color=%s]%s:  %s / %d[/color]" % [c, gname, _value_text(str(_gift), sel), _gift_cap(gc)])
	lines.append("")
	lines.append("[color=#b9a67a]%s[/color]" % _opt_desc(o))
	lines.append("")
	# Özet: kazanç ve süre/şans tek bakışta
	var chance: float = float(o.get("chance", 0.0))
	var gcfg: Dictionary = o.get("gift", {})
	if not gcfg.is_empty() and int(gcfg.get("max", 0)) > 0:
		chance = clampf(chance + _mm.DIRECTED_GIFT_CHANCE_BONUS * clampf(float(_gift) / float(gcfg.get("max", 1)), 0.0, 1.0), 0.05, 0.98)
	var shown_rewards: Dictionary = (o.get("rewards", {}) as Dictionary).duplicate(true)
	var loot: float = _mm.directed_loot_factor(o, _soldiers)
	if loot != 1.0:
		for rk in shown_rewards.keys():
			if String(rk) != "reputation":
				shown_rewards[rk] = maxi(1, int(round(float(shown_rewards[rk]) * loot)))
	if _gift > 0 and o.has("sell_rate"):
		shown_rewards["gold"] = int(shown_rewards.get("gold", 0)) + int(round(float(_gift) * float(o["sell_rate"])))
	var recruit_heads: int = 0
	if _gift > 0 and o.has("recruit_gold_per"):
		recruit_heads = int(floor(float(_gift) / maxf(1.0, float(o["recruit_gold_per"]))))
		if recruit_heads > 0:
			shown_rewards["villager"] = recruit_heads
	if _gift > 0 and o.has("buy_item"):
		var bought: int = int(floor(float(_gift) / maxf(0.1, float(o.get("buy_price", 3.0)))))
		if bought > 0:
			var bi: String = String(o["buy_item"])
			shown_rewards[bi] = int(shown_rewards.get(bi, 0)) + bought
	var reward_text: String = _format_effects(shown_rewards)
	if not reward_text.is_empty():
		lines.append("[color=#8fd08a]%s: %s[/color]" % [tr("dm.prep.rewards"), reward_text])
	lines.append("%s %s   ·   %s %d%%" % [
		tr("dm.prep.duration"), _format_minutes(float(o.get("duration", 0.0))),
		tr("dm.prep.chance"), int(round(chance * 100.0))])
	var pen_text: String = _format_effects(o.get("penalties", {}))
	# Yağma gibi görevler köyle ilişkiyi bozar: etkiyi risk satırında göster.
	if String(o.get("effect", "")).contains("relation:-"):
		pen_text = (pen_text + ", " if not pen_text.is_empty() else "") + tr("dm.pen.relation")
	if recruit_heads > 0:
		pen_text = (pen_text + ", " if not pen_text.is_empty() else "") + (tr("dm.pen.recruit_relation") % (3 * recruit_heads))
	var locked: String = String(o.get("locked_reason", ""))
	if not locked.is_empty():
		lines.append("[color=#ff7a6a]%s[/color]" % locked)
	if not pen_text.is_empty():
		lines.append("[color=#e08a7a]%s: %s[/color]" % [tr("dm.prep.risks"), pen_text])
	if not _error_text.is_empty():
		lines.append("")
		lines.append("[color=#ff7a6a]%s[/color]" % _error_text)
	lines.append("")
	lines.append("[color=#8fd08a]%s[/color]" % tr("dm.hint.prep2"))
	_modal_label.text = "\n".join(lines)


func _format_effects(d: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in d.keys():
		var key: String = String(k)
		var v = d[k]
		match key:
			"cariye_injured":
				parts.append(tr("dm.pen.injured"))
			"army_losses":
				parts.append("%s" % tr("dm.pen.army_losses"))
			_:
				var amt: int = int(v)
				if amt == 0:
					continue
				var sign_str: String = "+" if amt > 0 else ""
				parts.append("%s%d %s" % [sign_str, amt, tr("dm.res." + key)])
	return ", ".join(parts)


func _format_minutes(minutes: float) -> String:
	var total: int = int(round(minutes))
	return tr("dm.time.hm") % [int(total / 60), total % 60]
