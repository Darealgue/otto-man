extends CanvasLayer

signal completed(success: bool, payload: Dictionary)

## Kilidi Kır — köylü kurtarma minigame'i.
## İğne yeşil penceredeyken vurursan kilide sert bir yumruk iner (isabet); pencere
## dışında vurursan elini demire çarparsın (hata). Her köylünün kilidi
## HITS_PER_VILLAGER isabetle kırılır; TOPLAMDA MAX_FAILS hata hakkın vardır.
## Her kurtarılan köylüden sonra iğne hızlanır ve pencere daralır.
##
## Kilit ve yumruk görselleri şimdilik emoji placeholder: çizimler hazır olunca
## _lock_label / _fist_label yerine aynı konum ve tween'lerle Sprite2D koymak yeterli.

var context := {}

const HITS_PER_VILLAGER := 3
const MAX_FAILS := 3

const BAR_LEFT := 80.0
const BAR_RIGHT := 920.0
const BAR_TOP := 252.0
const BAR_BOTTOM := 302.0

const SPEED_UP_PER_RESCUE := 0.22      # kurtarılan köylü başına iğne hız artışı
const WINDOW_SHRINK_PER_RESCUE := 0.18 # kurtarılan köylü başına pencere daralması

const LOCK_HOME := Vector2(468.0, 92.0)
const FIST_HOME := Vector2(340.0, 128.0)

enum Phase { AIM, ANIM, DONE }

var _villager_total := 1
var _rescued := 0
var _hits := 0
var _fails_left := MAX_FAILS
var _base_speed := 1.1
var _speed := 1.1
var _base_window_half := 0.09
var _window_half := 0.09
var _window_center := 0.5
var _needle_t := 0.0
var _phase: int = Phase.AIM

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/Title
@onready var result_label: Label = $Panel/ResultLabel
@onready var hint_label: Label = $Panel/HintLabel
@onready var bar_bg: ColorRect = $Panel/BarBG

var _villager_row: RichTextLabel
var _fails_label: RichTextLabel
var _lock_label: Label
var _fist_label: Label
var _pips: Array = []
var _window_rect: ColorRect
var _needle: ColorRect


func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 100
	follow_viewport_enabled = false
	offset = Vector2.ZERO
	call_deferred("_recenter_panel")
	get_viewport().size_changed.connect(func(): call_deferred("_recenter_panel"))
	result_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint_label.add_theme_font_size_override("font_size", 13)
	_apply_context()
	_build_ui()
	_randomize_window()
	_refresh_status()
	_update_pips()
	hint_label.text = "İğne yeşil penceredeyken vur! (Zıpla / Onay)"


func _apply_context() -> void:
	var lvl := 1
	if typeof(context) == TYPE_DICTIONARY and context.has("level") and typeof(context.level) == TYPE_INT:
		lvl = max(1, int(context.level))
	if typeof(context) == TYPE_DICTIONARY:
		_villager_total = clampi(int(context.get("villager_count", 1)), 1, 5)
	_base_speed = clampf(1.35 + (lvl - 1) * 0.06, 1.35, 2.2)
	_base_window_half = clampf(0.062 - (lvl - 1) * 0.0025, 0.038, 0.062)
	var diff_mult := 1.0
	if typeof(context) == TYPE_DICTIONARY and context.has("difficulty_multiplier"):
		diff_mult = clampf(float(context.difficulty_multiplier), 0.5, 1.5)
	_base_speed *= diff_mult
	_update_difficulty()


func _update_difficulty() -> void:
	_speed = _base_speed * (1.0 + SPEED_UP_PER_RESCUE * _rescued)
	_window_half = maxf(0.03, _base_window_half * (1.0 - WINDOW_SHRINK_PER_RESCUE * _rescued))


func _process(delta):
	if _phase != Phase.AIM:
		return
	_needle_t += delta * _speed
	_update_needle_pos()
	if InputManager.is_jump_just_pressed() or InputManager.is_ui_accept_just_pressed():
		_resolve_press()


# --- Vuruş çözümleme ---

func _resolve_press() -> void:
	var v := pingpong(_needle_t, 1.0)
	if absf(v - _window_center) <= _window_half:
		_handle_hit()
	else:
		_handle_fail()


func _handle_hit() -> void:
	_phase = Phase.ANIM
	_hits += 1
	_update_pips()
	await _play_punch(true)
	if _hits >= HITS_PER_VILLAGER:
		_rescued += 1
		await _play_lock_break()
		_hits = 0
		_update_pips()
		_refresh_status()
		if _rescued >= _villager_total:
			_finish()
			return
		_update_difficulty()
		result_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
		result_label.text = "%d. köylü kurtarıldı! Sıradaki kilit daha sağlam..." % _rescued
	else:
		result_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
		result_label.text = "Sağlam vuruş!"
	_randomize_window()
	_phase = Phase.AIM


func _handle_fail() -> void:
	_phase = Phase.ANIM
	_fails_left -= 1
	_refresh_status()
	await _play_punch(false)
	if _fails_left <= 0:
		_finish()
		return
	result_label.add_theme_color_override("font_color", Color(0.92, 0.3, 0.25))
	result_label.text = "Elini demire çarptın! (%d hak kaldı)" % _fails_left
	_randomize_window()
	_phase = Phase.AIM


func _finish() -> void:
	_phase = Phase.DONE
	hint_label.text = ""
	var success := _rescued >= _villager_total
	if success:
		result_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.5))
		result_label.text = "Tüm köylüler kurtarıldı!"
	elif _rescued > 0:
		result_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
		result_label.text = "%d köylü kurtarıldı, %d hücrede kaldı..." % [_rescued, _villager_total - _rescued]
	else:
		result_label.add_theme_color_override("font_color", Color(0.92, 0.3, 0.25))
		result_label.text = "Kilit açılamadı..."
	await get_tree().create_timer(1.2).timeout
	emit_signal("completed", success, {"rescued_count": _rescued})


# --- Animasyonlar ---

## Yumruk kilide uzanır; isabette kilit sarsılır, hatada el geri seker ve kızarır.
func _play_punch(hit_ok: bool) -> void:
	var lunge := create_tween()
	lunge.tween_property(_fist_label, "position", LOCK_HOME + Vector2(-58.0, 26.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lunge.finished
	if hit_ok:
		_lock_label.modulate = Color(1.7, 1.6, 0.9)
		var shake := create_tween()
		shake.tween_property(_lock_label, "position", LOCK_HOME + Vector2(10, -2), 0.04)
		shake.tween_property(_lock_label, "position", LOCK_HOME + Vector2(-7, 3), 0.04)
		shake.tween_property(_lock_label, "position", LOCK_HOME, 0.05)
		await shake.finished
		_lock_label.modulate = Color(1, 1, 1)
	else:
		_fist_label.modulate = Color(1.9, 0.45, 0.4)
		var hurt := create_tween()
		hurt.tween_property(_fist_label, "position", LOCK_HOME + Vector2(-96.0, 44.0), 0.05)
		hurt.tween_property(_fist_label, "position", LOCK_HOME + Vector2(-86.0, 34.0), 0.05)
		hurt.tween_property(_fist_label, "position", LOCK_HOME + Vector2(-92.0, 40.0), 0.05)
		await hurt.finished
		_fist_label.modulate = Color(1, 1, 1)
	var back := create_tween()
	back.tween_property(_fist_label, "position", FIST_HOME, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished


func _play_lock_break() -> void:
	_lock_label.text = "🔓"
	_lock_label.modulate = Color(1.7, 1.6, 0.8)
	var tw := create_tween()
	tw.tween_property(_lock_label, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lock_label, "scale", Vector2.ONE, 0.15)
	await tw.finished
	await get_tree().create_timer(0.35).timeout
	_lock_label.text = "🔒"
	_lock_label.modulate = Color(1, 1, 1)


# --- UI kurulum / güncelleme ---

func _build_ui() -> void:
	_villager_row = RichTextLabel.new()
	_villager_row.bbcode_enabled = true
	_villager_row.scroll_active = false
	_villager_row.fit_content = true
	_villager_row.position = Vector2(40.0, 44.0)
	_villager_row.size = Vector2(600.0, 30.0)
	_villager_row.add_theme_font_size_override("normal_font_size", 18)
	panel.add_child(_villager_row)
	_fails_label = RichTextLabel.new()
	_fails_label.bbcode_enabled = true
	_fails_label.scroll_active = false
	_fails_label.fit_content = true
	_fails_label.position = Vector2(700.0, 44.0)
	_fails_label.size = Vector2(260.0, 30.0)
	_fails_label.add_theme_font_size_override("normal_font_size", 18)
	panel.add_child(_fails_label)
	_lock_label = Label.new()
	_lock_label.text = "🔒"
	_lock_label.add_theme_font_size_override("font_size", 72)
	_lock_label.position = LOCK_HOME
	_lock_label.size = Vector2(84.0, 92.0)
	_lock_label.pivot_offset = _lock_label.size * 0.5
	panel.add_child(_lock_label)
	_fist_label = Label.new()
	_fist_label.text = "👊"
	_fist_label.add_theme_font_size_override("font_size", 56)
	_fist_label.position = FIST_HOME
	_fist_label.size = Vector2(66.0, 72.0)
	_fist_label.pivot_offset = _fist_label.size * 0.5
	panel.add_child(_fist_label)
	for i in range(HITS_PER_VILLAGER):
		var pip := ColorRect.new()
		pip.position = Vector2(474.0 + i * 26.0, 196.0)
		pip.size = Vector2(18.0, 8.0)
		panel.add_child(pip)
		_pips.append(pip)
	_window_rect = ColorRect.new()
	_window_rect.color = Color(0.3, 0.8, 0.4, 0.7)
	panel.add_child(_window_rect)
	_needle = ColorRect.new()
	_needle.color = Color(1, 1, 1, 0.95)
	panel.add_child(_needle)
	_update_needle_pos()


func _refresh_status() -> void:
	title_label.text = "Kilidi Kır! (%d köylü)" % _villager_total
	var row := "[center]"
	for i in range(_villager_total):
		if i < _rescued:
			row += "[color=#5ee36b]✔ [/color]"
		elif i == _rescued:
			row += "[color=#ffd75e]◆ [/color]"
		else:
			row += "[color=#666666]◇ [/color]"
	row += "[/center]"
	_villager_row.text = row
	var hearts := "[right]Hak: "
	hearts += "[color=#e04840]" + "♥".repeat(_fails_left) + "[/color]"
	hearts += "[color=#555555]" + "♥".repeat(MAX_FAILS - _fails_left) + "[/color]"
	hearts += "[/right]"
	_fails_label.text = hearts


func _update_pips() -> void:
	for i in range(_pips.size()):
		var pip: ColorRect = _pips[i]
		pip.color = Color(1.0, 0.85, 0.3) if i < _hits else Color(0.25, 0.25, 0.28)


func _randomize_window() -> void:
	_window_center = randf_range(0.15 + _window_half, 0.85 - _window_half)
	var wl: float = lerp(BAR_LEFT, BAR_RIGHT, _window_center - _window_half)
	var wr: float = lerp(BAR_LEFT, BAR_RIGHT, _window_center + _window_half)
	_window_rect.position = Vector2(wl, BAR_TOP)
	_window_rect.size = Vector2(wr - wl, BAR_BOTTOM - BAR_TOP)


func _update_needle_pos() -> void:
	var v := pingpong(_needle_t, 1.0)
	var x: float = lerp(BAR_LEFT, BAR_RIGHT, v)
	_needle.position = Vector2(x - 3.0, BAR_TOP - 6.0)
	_needle.size = Vector2(6.0, BAR_BOTTOM - BAR_TOP + 12.0)


func _recenter_panel() -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.size = Vector2(1000, 420)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	panel.position = (vp_size - panel.size) * 0.5
