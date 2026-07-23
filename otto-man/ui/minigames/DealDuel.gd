extends CanvasLayer

signal completed(success: bool, payload: Dictionary)

## İkna Düellosu — cariye ile karşılıklı söz dalaşı.
## Cariye her tur bir söz hamlesi yapar (renkli konuşma satırı). Oyuncu, iğne AYNI
## renkteki karşı-cevap bölgesinin üstündeyken tuşa basarsa metre oyuncuya doğru
## kayar; yanlış bölge veya boşluk cariyeye puan yazar. Metre +5'e ulaşırsa cariye
## ikna olur (kurtarma başarılı), -5'e düşerse sözü cariye kazanır (başarısız).

var context := {}

const ConcubineScene := preload("res://village/scenes/Concubine.tscn")
const PLAYER_IDLE_TEX := preload("res://resources/player_normalmap resources/idle_normal.tres")
const PLAYER_IDLE_FRAMES := 36
const PLAYER_IDLE_FPS := 15.0
const CHAR_SCALE := 2.6
const CHAR_GROUND_Y := 345.0     # iki karakterin ayak hizası (panel koordinatı)
const CARIYE_FEET_OFFSET := 2.5  # Concubine node origin'i ayaklara çok yakın (ekran ölçümü)

const LEV_WIN := 5
const LEV_LOSE := -5

const BAR_LEFT := 180.0
const BAR_RIGHT := 940.0
const BAR_TOP := 218.0
const BAR_BOTTOM := 278.0

const WINDUP_TIME := 0.55       # cariyenin hamlesini gösterme süresi (input kapalı)
const AIM_TIMEOUT := 3.5        # bu süre içinde basılmazsa cariye sabırsızlanır (-1)
const RESOLVE_TIME := 0.8       # sonucun ekranda kalma süresi
const PERFECT_FRAC := 0.28      # bölge ortasındaki perfect bandın orana göre yarısı
const RESIST_PER_LEV := 0.09    # cariye köşeye sıkıştıkça direnir: +leverage başına iğne hız artışı

const STANCES := {
	"duygu": {
		"stance": "Duygu Sömürüsü",
		"counter": "Güven Ver",
		"color": Color(0.92, 0.45, 0.62),
		"quotes": ["Beni burada bırakacaksın, değil mi...?", "Kimsem yok benim...", "Sana nasıl güveneyim?"],
	},
	"pazarlik": {
		"stance": "Pazarlık",
		"counter": "Cazip Teklif",
		"color": Color(0.95, 0.78, 0.30),
		"quotes": ["Gelirim ama şartlarım var.", "Bana ne vereceksin?", "Bedava iş yok bu dünyada."],
	},
	"naz": {
		"stance": "Naz",
		"counter": "Blöfü Gör",
		"color": Color(0.66, 0.50, 0.95),
		"quotes": ["Belki de burada kalmak istiyorum.", "Neden seninle geleyim ki?", "Beni etkilemen gerek."],
	},
}

enum Phase { WINDUP, AIM, RESOLVE, DONE }

var _phase: int = Phase.WINDUP
var _phase_timer := 0.0
var _leverage := 0
var _turn := 0
var _cariye_name := "Cariye"

var _speed := 1.25           # iğnenin bar boyu geçiş hızı (tur/sn, pingpong)
var _zone_half := 0.048      # bölge yarı genişliği (bar oranı, 0..1)
var _bluff_chance := 0.25
var _persona := "dengeli"    # kirilgan | cikarci | oyuncu | dengeli

var _needle_t := 0.0
var _stance_key := "duygu"
var _zone_order: Array = []      # stance key'lerinin bar üzerindeki soldan sağa sırası
var _zone_centers: Array = []    # normalized bölge merkezleri
var _bluff_at := -1.0            # AIM başladıktan kaç sn sonra blöf (negatif = yok)
var _bluffed := false

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var name_left: Label = $Panel/NameLeft
@onready var name_right: Label = $Panel/NameRight
@onready var leverage_meter: Control = $Panel/LeverageMeter
@onready var stance_label: Label = $Panel/StanceLabel
@onready var quote_label: Label = $Panel/QuoteLabel
@onready var result_label: Label = $Panel/ResultLabel
@onready var hint_label: Label = $Panel/HintLabel
@onready var bar_bg: ColorRect = $Panel/BarBG

var _zone_rects: Array = []
var _perfect_rects: Array = []
var _zone_labels: Array = []
var _needle: ColorRect
var _hit_marker: ColorRect
var _cariye_vis: Node2D
var _player_vis: Sprite2D
var _anim_t := 0.0
var _perfect_label: Label
var _flash_rect: ColorRect
var _timer_bg: ColorRect
var _timer_fill: ColorRect


func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 100
	follow_viewport_enabled = false
	offset = Vector2.ZERO
	call_deferred("_recenter_panel")
	get_viewport().size_changed.connect(func(): call_deferred("_recenter_panel"))
	_apply_difficulty_from_context()
	_init_persona_from_context()
	if typeof(context) == TYPE_DICTIONARY and context.has("cariye_name"):
		var n := String(context.cariye_name)
		if n != "":
			_cariye_name = n
	title_label.text = "%s ile İkna Düellosu" % _cariye_name
	name_left.text = "Sen"
	name_left.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
	name_right.text = _cariye_name
	name_right.add_theme_color_override("font_color", Color(0.92, 0.45, 0.62))
	# Oyuncu solda durduğu için metre oyuncu lehine SOLA dolar
	leverage_meter.set_meta("flip", true)
	quote_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	quote_label.add_theme_font_size_override("font_size", 14)
	stance_label.add_theme_font_size_override("font_size", 22)
	result_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint_label.add_theme_font_size_override("font_size", 13)
	_build_bar_nodes()
	_spawn_duel_characters()
	_update_meter()
	_next_turn()


func _process(delta):
	_phase_timer += delta
	_anim_t += delta
	if is_instance_valid(_player_vis):
		_player_vis.frame = int(_anim_t * PLAYER_IDLE_FPS) % PLAYER_IDLE_FRAMES
	match _phase:
		Phase.WINDUP:
			_advance_needle(delta)
			if _phase_timer >= WINDUP_TIME:
				_phase = Phase.AIM
				_phase_timer = 0.0
		Phase.AIM:
			_advance_needle(delta)
			_update_timer_bar()
			if _bluff_at > 0.0 and not _bluffed and _phase_timer >= _bluff_at:
				_do_bluff()
			if _phase_timer >= AIM_TIMEOUT:
				_resolve(-1, "%s sabırsızlandı! (-1)" % _cariye_name, _current_v())
			elif InputManager.is_jump_just_pressed() or InputManager.is_ui_accept_just_pressed():
				_resolve_press()
		Phase.RESOLVE:
			if _phase_timer >= RESOLVE_TIME:
				_after_resolve()
		Phase.DONE:
			pass


func _current_v() -> float:
	return pingpong(_needle_t, 1.0)


func _update_timer_bar() -> void:
	var remain := clampf(1.0 - _phase_timer / AIM_TIMEOUT, 0.0, 1.0)
	_timer_bg.visible = true
	_timer_fill.visible = true
	_timer_fill.size.x = (BAR_RIGHT - BAR_LEFT) * remain
	# Dolu = beyaz, azaldıkça kırmızı
	_timer_fill.color = Color(0.9, 0.25, 0.2).lerp(Color(0.9, 0.9, 0.9), remain)


func _hide_timer_bar() -> void:
	if _timer_bg:
		_timer_bg.visible = false
	if _timer_fill:
		_timer_fill.visible = false


func _advance_needle(delta: float) -> void:
	# Kazanmaya yaklaştıkça cariye direnir: iğne hızlanır (rubber band)
	var resist := 1.0 + maxf(0.0, float(_leverage)) * RESIST_PER_LEV
	_needle_t += delta * _speed * resist
	_update_needle_pos(_current_v())


# --- Tur akışı ---

func _next_turn():
	_turn += 1
	_stance_key = _pick_stance()
	_layout_zones()
	_bluffed = false
	_bluff_at = -1.0
	if randf() < _bluff_chance:
		_bluff_at = randf_range(0.3, AIM_TIMEOUT * 0.65)
	_phase = Phase.WINDUP
	_phase_timer = 0.0
	_hit_marker.visible = false
	result_label.text = ""
	if _turn <= 2:
		hint_label.text = "Cariyenin hamlesiyle AYNI renkteki bölgede tuşa bas! (Zıpla / Onay)"
	else:
		hint_label.text = ""
	_show_stance(false)


func _show_stance(is_bluff: bool) -> void:
	var info: Dictionary = STANCES[_stance_key]
	var prefix := "Fikrini değiştirdi! " if is_bluff else ""
	stance_label.text = "%s%s: %s" % [prefix, _cariye_name, info.stance]
	stance_label.add_theme_color_override("font_color", info.color)
	var quotes: Array = info.quotes
	quote_label.text = "\"%s\"" % quotes[randi() % quotes.size()]


func _do_bluff() -> void:
	_bluffed = true
	var keys := STANCES.keys()
	keys.erase(_stance_key)
	_stance_key = keys[randi() % keys.size()]
	_show_stance(true)


func _resolve_press() -> void:
	var v := _current_v()
	var idx := _zone_index_at(v)
	var correct := _zone_order.find(_stance_key)
	if idx == correct and idx != -1:
		var d: float = abs(v - _zone_centers[idx])
		if d <= _zone_half * PERFECT_FRAC:
			_resolve(2, "Tam yerine oturdu! (+2)", v)
		else:
			_resolve(1, "Etkili söz. (+1)", v)
	else:
		_resolve(-1, "%s lafı gediğine koydu! (-1)" % _cariye_name, v)


func _resolve(delta_lev: int, msg: String, v: float) -> void:
	_hide_timer_bar()
	_leverage += delta_lev
	_update_meter()
	_show_hit_marker(v, delta_lev)
	if delta_lev >= 2:
		_play_perfect_fx()
	result_label.text = msg
	var col := Color(1, 1, 1)
	if delta_lev > 0:
		col = Color(0.35, 0.9, 0.5) if delta_lev < 2 else Color(1.0, 0.9, 0.3)
	elif delta_lev < 0:
		col = Color(0.92, 0.3, 0.25)
	result_label.add_theme_color_override("font_color", col)
	_phase = Phase.RESOLVE
	_phase_timer = 0.0


func _after_resolve() -> void:
	if _leverage >= LEV_WIN:
		_finish(true)
	elif _leverage <= LEV_LOSE:
		_finish(false)
	else:
		_next_turn()


func _finish(success: bool) -> void:
	_phase = Phase.DONE
	_hide_timer_bar()
	hint_label.text = ""
	if success:
		stance_label.text = "%s ikna oldu!" % _cariye_name
		stance_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
		quote_label.text = "\"Peki... Seninle geliyorum.\""
	else:
		stance_label.text = "%s sözü kazandı." % _cariye_name
		stance_label.add_theme_color_override("font_color", Color(0.92, 0.3, 0.25))
		quote_label.text = "\"Ben burada kalıyorum. Git başımdan.\""
	await get_tree().create_timer(1.2).timeout
	emit_signal("completed", success, {"leverage": _leverage})


# --- Bölgeler / iğne ---

func _layout_zones() -> void:
	_zone_order = STANCES.keys()
	_zone_order.shuffle()
	_zone_centers = []
	for i in range(3):
		var base := (2.0 * i + 1.0) / 6.0
		_zone_centers.append(base + randf_range(-0.04, 0.04))
	_update_zone_rects()


func _zone_index_at(v: float) -> int:
	for i in range(_zone_centers.size()):
		if abs(v - _zone_centers[i]) <= _zone_half:
			return i
	return -1


func _build_bar_nodes() -> void:
	for i in range(3):
		var z := ColorRect.new()
		panel.add_child(z)
		_zone_rects.append(z)
		var p := ColorRect.new()
		panel.add_child(p)
		_perfect_rects.append(p)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		panel.add_child(l)
		_zone_labels.append(l)
	_needle = ColorRect.new()
	_needle.color = Color(1, 1, 1, 0.95)
	panel.add_child(_needle)
	_hit_marker = ColorRect.new()
	_hit_marker.visible = false
	panel.add_child(_hit_marker)
	# Karar süresi barı: AIM sırasında dolu başlar, azaldıkça kırmızılaşır
	_timer_bg = ColorRect.new()
	_timer_bg.color = Color(0.05, 0.05, 0.06, 0.9)
	_timer_bg.position = Vector2(BAR_LEFT, BAR_TOP - 16.0)
	_timer_bg.size = Vector2(BAR_RIGHT - BAR_LEFT, 6.0)
	_timer_bg.visible = false
	panel.add_child(_timer_bg)
	_timer_fill = ColorRect.new()
	_timer_fill.color = Color(0.9, 0.9, 0.9)
	_timer_fill.position = Vector2(BAR_LEFT, BAR_TOP - 16.0)
	_timer_fill.size = Vector2(BAR_RIGHT - BAR_LEFT, 6.0)
	_timer_fill.visible = false
	panel.add_child(_timer_fill)
	# Perfect vuruş şovu: tüm paneli kaplayan altın parlama + büyük yazı
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 0.9, 0.3, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.visible = false
	panel.add_child(_flash_rect)
	_perfect_label = Label.new()
	_perfect_label.text = "TAM İSABET!"
	_perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perfect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_perfect_label.add_theme_font_size_override("font_size", 44)
	_perfect_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_perfect_label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	_perfect_label.add_theme_constant_override("outline_size", 8)
	_perfect_label.size = Vector2(500, 70)
	_perfect_label.position = Vector2((1120.0 - 500.0) * 0.5, 160.0)
	_perfect_label.pivot_offset = _perfect_label.size * 0.5
	_perfect_label.visible = false
	panel.add_child(_perfect_label)


## Perfect vuruşta kısa şov: parlama, büyüyen yazı, panel sarsıntısı.
func _play_perfect_fx() -> void:
	_flash_rect.visible = true
	_flash_rect.color.a = 0.32
	var ftw := create_tween()
	ftw.tween_property(_flash_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ftw.tween_callback(func(): _flash_rect.visible = false)
	_perfect_label.visible = true
	_perfect_label.modulate = Color(1, 1, 1, 1)
	_perfect_label.scale = Vector2(0.4, 0.4)
	var ltw := create_tween()
	ltw.tween_property(_perfect_label, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ltw.tween_property(_perfect_label, "scale", Vector2(1.0, 1.0), 0.1)
	ltw.tween_interval(0.25)
	ltw.tween_property(_perfect_label, "modulate:a", 0.0, 0.25)
	ltw.tween_callback(func(): _perfect_label.visible = false)
	var base_pos := panel.position
	var stw := create_tween()
	stw.tween_property(panel, "position", base_pos + Vector2(5, -3), 0.04)
	stw.tween_property(panel, "position", base_pos + Vector2(-4, 3), 0.04)
	stw.tween_property(panel, "position", base_pos + Vector2(3, -2), 0.04)
	stw.tween_property(panel, "position", base_pos, 0.04)


func _update_zone_rects() -> void:
	for i in range(3):
		var key: String = _zone_order[i]
		var info: Dictionary = STANCES[key]
		var c: float = _zone_centers[i]
		var zl: float = lerp(BAR_LEFT, BAR_RIGHT, c - _zone_half)
		var zr: float = lerp(BAR_LEFT, BAR_RIGHT, c + _zone_half)
		var z: ColorRect = _zone_rects[i]
		z.color = Color(info.color.r, info.color.g, info.color.b, 0.55)
		z.position = Vector2(zl, BAR_TOP)
		z.size = Vector2(zr - zl, BAR_BOTTOM - BAR_TOP)
		var ph: float = _zone_half * PERFECT_FRAC
		var pl: float = lerp(BAR_LEFT, BAR_RIGHT, c - ph)
		var pr: float = lerp(BAR_LEFT, BAR_RIGHT, c + ph)
		var p: ColorRect = _perfect_rects[i]
		p.color = Color(info.color.r, info.color.g, info.color.b, 1.0)
		p.position = Vector2(pl, BAR_TOP + 6.0)
		p.size = Vector2(pr - pl, BAR_BOTTOM - BAR_TOP - 12.0)
		var l: Label = _zone_labels[i]
		l.text = info.counter
		l.add_theme_color_override("font_color", info.color)
		l.position = Vector2(lerp(BAR_LEFT, BAR_RIGHT, c) - 80.0, BAR_BOTTOM + 4.0)
		l.size = Vector2(160.0, 18.0)


## Solda oyuncunun idle'ı, sağda cariye (gerçek zindan görünümüyle) — karşı karşıya,
## ayakları CHAR_GROUND_Y hizasında.
func _spawn_duel_characters() -> void:
	# Oyuncu: idle spritesheet'i, sağa (cariyeye) dönük
	var pv := Sprite2D.new()
	pv.texture = PLAYER_IDLE_TEX
	pv.hframes = PLAYER_IDLE_FRAMES
	var frame_h := 64.0
	if pv.texture:
		frame_h = float(pv.texture.get_height())
	# Sprite origin'i kare merkezinde: ayaklar merkezin frame_h/2 altında
	pv.position = Vector2(100.0, CHAR_GROUND_Y - frame_h * 0.5 * CHAR_SCALE)
	pv.scale = Vector2(CHAR_SCALE, CHAR_SCALE)
	panel.add_child(pv)
	_player_vis = pv
	# Cariye: Concubine sahnesi düz Node2D'dir (fizik gövdesi yok) ama dungeon-prisoner
	# modunda script yerçekimi/AI uygular; UI içinde düşmesin diye physics kapatılır.
	var cv = ConcubineScene.instantiate()
	cv.is_dungeon_prisoner = true
	cv.display_name = _cariye_name
	if typeof(context) == TYPE_DICTIONARY and context.get("cariye_appearance") != null:
		cv.appearance = context.cariye_appearance
	panel.add_child(cv)
	cv.set_physics_process(false)
	cv.set_process(false)
	var plate = cv.get_node_or_null("NamePlateContainer")
	if plate:
		plate.visible = false
	cv.position = Vector2(1020.0, CHAR_GROUND_Y - CARIYE_FEET_OFFSET * CHAR_SCALE)
	# X'i negatif ölçekleyerek sola (oyuncuya) dönük aynala
	cv.scale = Vector2(-CHAR_SCALE, CHAR_SCALE)
	if cv.has_method("play_animation"):
		cv.play_animation("idle")
	_cariye_vis = cv


func _update_needle_pos(v: float) -> void:
	var x: float = lerp(BAR_LEFT, BAR_RIGHT, v)
	_needle.position = Vector2(x - 3.0, BAR_TOP - 6.0)
	_needle.size = Vector2(6.0, BAR_BOTTOM - BAR_TOP + 12.0)


func _show_hit_marker(v: float, delta_lev: int) -> void:
	var x: float = lerp(BAR_LEFT, BAR_RIGHT, v)
	_hit_marker.position = Vector2(x - 2.0, BAR_TOP - 8.0)
	_hit_marker.size = Vector2(4.0, BAR_BOTTOM - BAR_TOP + 16.0)
	var col := Color(0.92, 0.3, 0.25)
	if delta_lev >= 2:
		col = Color(1.0, 0.9, 0.3)
	elif delta_lev == 1:
		col = Color(0.35, 0.9, 0.5)
	_hit_marker.color = col
	_hit_marker.modulate = Color(1, 1, 1, 1)
	_hit_marker.visible = true
	var tw := create_tween()
	tw.tween_property(_hit_marker, "modulate:a", 0.0, RESOLVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- Cariye karakteri / zorluk ---

func _pick_stance() -> String:
	var choices := ["duygu", "pazarlik", "naz"]
	var weights: Array[float] = [1.0, 1.0, 1.0]
	match _persona:
		"kirilgan":
			weights = [2.5, 1.0, 1.0]
		"cikarci":
			weights = [1.0, 2.5, 1.0]
		"oyuncu":
			weights = [1.0, 1.0, 2.5]
	var sum_w := 0.0
	for w in weights:
		sum_w += w
	var r := randf() * sum_w
	var acc := 0.0
	for i in range(choices.size()):
		acc += weights[i]
		if r <= acc:
			return choices[i]
	return choices.back()


func _init_persona_from_context() -> void:
	var raw := ""
	if typeof(context) == TYPE_DICTIONARY and context.has("persona") and typeof(context.persona) == TYPE_STRING:
		raw = String(context.persona)
	match raw:
		"appeaser", "kirilgan":
			_persona = "kirilgan"
		"bully", "cikarci":
			_persona = "cikarci"
		"schemer", "oyuncu":
			_persona = "oyuncu"
		"balanced", "dengeli":
			_persona = "dengeli"
		_:
			var r := randf()
			if r < 0.4:
				_persona = "dengeli"
			elif r < 0.6:
				_persona = "kirilgan"
			elif r < 0.8:
				_persona = "cikarci"
			else:
				_persona = "oyuncu"
	var bluff_base := 0.45 if _persona == "oyuncu" else 0.22
	_bluff_chance = clampf(bluff_base + _level_from_context() * 0.02, 0.0, 0.6)


func _level_from_context() -> int:
	if typeof(context) == TYPE_DICTIONARY and context.has("level") and typeof(context.level) == TYPE_INT:
		return max(0, int(context.level) - 1)
	return 0


func _apply_difficulty_from_context() -> void:
	var lvl := _level_from_context()
	_speed = clampf(1.25 + lvl * 0.07, 1.25, 2.1)
	_zone_half = clampf(0.048 - lvl * 0.0025, 0.03, 0.048)
	var diff_mult := 1.0
	if typeof(context) == TYPE_DICTIONARY and context.has("difficulty_multiplier"):
		diff_mult = clampf(float(context.difficulty_multiplier), 0.5, 1.5)
	_speed *= diff_mult


# --- Yardımcılar ---

func _update_meter() -> void:
	if not is_instance_valid(leverage_meter):
		return
	leverage_meter.set_meta("leverage", _leverage)
	leverage_meter.queue_redraw()


func _recenter_panel() -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.size = Vector2(1120, 420)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	panel.position = (vp_size - panel.size) * 0.5
