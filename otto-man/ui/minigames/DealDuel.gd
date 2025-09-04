extends CanvasLayer

signal completed(success: bool, payload: Dictionary)

var context := {}
var _timer := 0.0
var _speed := 2.2
var _window_center := 0.6
var _window_radius := 0.1
var _turn := 0
var _max_turns := 5
var _leverage: int = 0
var _leverage_win_threshold: int = 5
var _leverage_lose_threshold: int = -5
var _last_non_draw_result: int = 0 # 1: last win, -1: last lose, 0: none
var _win_streak: int = 0
var _pending_result: int = 0 # 1 win, -1 lose, 0 draw
var _enemy_persona: String = "balanced" # balanced | bully(pressure) | schemer(scheme) | appeaser(offer)
var _hint_turns: int = 2
var _perfect_half: float = 0.03
var _good_half: float = 0.08
var _sel := 0 # 0: offer, 1: pressure, 2: scheme
enum Phase { SELECT, REVEAL, ATTACK_QTE, DEFENSE_QTE, APPLY }
var _phase: int = Phase.SELECT
var _label_tween: Tween = null
var _qte_frozen: bool = false
var _frozen_v: float = 0.0

@onready var bar: TextureProgressBar = $Panel/ProgressBar
@onready var leverage_meter: Control = $Panel/LeverageMeter
@onready var label: Label = $Panel/Label
@onready var btn_offer: Button = $Panel/HBox/Offer
@onready var btn_pressure: Button = $Panel/HBox/Pressure
@onready var btn_scheme: Button = $Panel/HBox/Scheme
@onready var qte_window: ColorRect = $Panel/QTEWindow
@onready var qte_perfect: ColorRect = $Panel/QTEPerfect
@onready var qte_hit: ColorRect = $Panel/QTEHitMarker
@onready var needle: ColorRect = $Panel/Needle

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 100
	follow_viewport_enabled = false
	offset = Vector2.ZERO
	call_deferred("_recenter_panel")
	get_viewport().size_changed.connect(func(): call_deferred("_recenter_panel"))
	bar.min_value = 0
	bar.max_value = 1
	_update_leverage_ui()
	_apply_difficulty_from_context()
	_init_persona_from_context()
	_wire()
	_enable_gamepad_navigation()
	_next_turn()

func _wire():
	btn_offer.pressed.connect(func(): _attempt("offer"))
	btn_pressure.pressed.connect(func(): _attempt("pressure"))
	btn_scheme.pressed.connect(func(): _attempt("scheme"))

func _process(delta):
	if _phase == Phase.ATTACK_QTE or _phase == Phase.DEFENSE_QTE:
		if _qte_frozen:
			# keep bar/visuals at frozen position
			bar.value = _frozen_v
			return
	_timer += delta * _speed
	var v := fposmod(_timer, 1.0)
	bar.value = v
	_update_visuals(v)
	if _phase == Phase.SELECT:
		_handle_gamepad_input()
	elif _phase == Phase.ATTACK_QTE or _phase == Phase.DEFENSE_QTE:
		_handle_qte_input(v)

func _attempt(_kind: String):
	if _phase != Phase.SELECT:
		return
	# RPS reveal
	var player_pick := _kind
	var enemy_pick := _enemy_pick()
	var res := _rps_resolve(player_pick, enemy_pick)
	label.text = "You: %s    Opponent: %s\nResult: %s" % [player_pick.capitalize(), enemy_pick.capitalize(), res.to_upper()]
	if res == "win":
		_last_non_draw_result = 1
		_pending_result = 1
		_phase = Phase.ATTACK_QTE
	elif res == "lose":
		_last_non_draw_result = -1
		_pending_result = -1
		_phase = Phase.DEFENSE_QTE
	else:
		# draw: skip qte, apply nothing and go next turn
		_pending_result = 0
		_apply_and_next(0)
	_toggle_qte_visibility(_phase == Phase.ATTACK_QTE or _phase == Phase.DEFENSE_QTE)
	_qte_frozen = false
	_frozen_v = 0.0

func _next_turn():
	_turn += 1
	# no turn cap anymore
	_window_center = randf_range(0.2, 0.8)
	_window_radius = 0.08 + randf() * 0.06
	_phase = Phase.SELECT
	_toggle_qte_visibility(false)
	var hint := ""
	if _turn <= _hint_turns:
		hint = "\nHint: " + _persona_hint()
	# Ensure label is fully visible and default-colored at turn start
	label.visible = true
	label.modulate = Color(1, 1, 1, 1)
	if label.has_theme_color_override("font_color"):
		label.remove_theme_color_override("font_color")
	label.text = "Turn %d/%d\nLeverage: %s\nSelect: Offer / Pressure / Scheme%s" % [_turn, _max_turns, _format_leverage(), hint]

func _update_visuals(v: float) -> void:
	var left: float = 40.0
	var right: float = 960.0
	var top: float = 90.0
	var bottom: float = 170.0
	var w_left: float = lerp(left, right, _window_center - _window_radius)
	var w_right: float = lerp(left, right, _window_center + _window_radius)
	qte_window.offset_left = w_left
	qte_window.offset_right = w_right
	qte_window.offset_top = top
	qte_window.offset_bottom = bottom
	var p_left: float = lerp(left, right, _window_center - _perfect_half)
	var p_right: float = lerp(left, right, _window_center + _perfect_half)
	qte_perfect.offset_left = p_left
	qte_perfect.offset_right = p_right
	qte_perfect.offset_top = top + 5.0
	qte_perfect.offset_bottom = bottom - 5.0
	var n_x: float = lerp(left, right, v)
	needle.offset_left = n_x - 4.0
	needle.offset_right = n_x + 4.0
	needle.offset_top = top
	needle.offset_bottom = bottom

func _handle_qte_input(v: float) -> void:
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
		var d: float = abs(v - _window_center)
		var delta: int = 0
		# Freeze needle & show hit marker for ~1s at current position
		_show_hit_marker_at(v)
		await get_tree().create_timer(0.3).timeout
		if _phase == Phase.ATTACK_QTE:
			var delta_cap: int = 3
			if d <= _perfect_half:
				delta = 2
				label.text = "Attack QTE\nPERFECT (+2)"
			elif d <= _good_half:
				delta = 1
				label.text = "Attack QTE\nGOOD (+1)"
			else:
				delta = 0
				label.text = "Attack QTE\nMISS (+0)"
			# streak bonus on 2+ consecutive wins
			if _win_streak >= 1:
				delta += 1
				label.text += "\nSTREAK BONUS (+1)"
			if delta > delta_cap:
				delta = delta_cap
			# update streak for win and flash label briefly
			_win_streak += 1
			_flash_label(Color(0.2, 0.9, 0.4, 1.0))
		elif _phase == Phase.DEFENSE_QTE:
			if d <= _perfect_half:
				delta = 0  # perfect block → 0 kayıp
				label.text = "Defense QTE\nPERFECT (0 loss)"
			elif d <= _good_half:
				delta = -1  # good → -1
				label.text = "Defense QTE\nGOOD (-1)"
			else:
				delta = -2  # miss → -2
				label.text = "Defense QTE\nMISS (-2)"
			# reset streak on lose and flash label red
			_win_streak = 0
			_flash_label(Color(0.9, 0.25, 0.2, 1.0))
		_apply_and_next(delta)
		_toggle_qte_visibility(false)

func _apply_and_next(delta: int) -> void:
	_leverage += delta
	_update_leverage_ui()
	# Threshold check for instant finish
	if _leverage >= _leverage_win_threshold:
		_finish(true)
		return
	if _leverage <= _leverage_lose_threshold:
		_finish(false)
		return
	_phase = Phase.APPLY
	# küçük bekleme etkisi için timer yerine anında geçiş
	_next_turn()
	_qte_frozen = false
	_frozen_v = 0.0

func _enemy_pick() -> String:
	var choices := ["offer", "pressure", "scheme"]
	var weights: Array[float] = []
	match _enemy_persona:
		"bully":
			weights = [1.0, 2.5, 1.0]
		"schemer":
			weights = [1.0, 1.0, 2.5]
		"appeaser":
			weights = [2.5, 1.0, 1.0]
		_:
			weights = [1.0, 1.0, 1.0]
	var sum_w: float = 0.0
	for w in weights:
		sum_w += w
	var r := randf() * sum_w
	var acc := 0.0
	for i in range(choices.size()):
		acc += weights[i]
		if r <= acc:
			return choices[i]
	return choices.back()

func _rps_resolve(pick: String, enemy: String) -> String:
	if pick == enemy:
		return "draw"
	if pick == "offer" and enemy == "pressure":
		return "win"
	if pick == "pressure" and enemy == "scheme":
		return "win"
	if pick == "scheme" and enemy == "offer":
		return "win"
	return "lose"

func _finish(success: bool):
	emit_signal("completed", success, {"leverage": _leverage})

func _update_leverage_ui() -> void:
	if not is_instance_valid(leverage_meter):
		return
	# request a redraw via a custom property on meter
	leverage_meter.set_meta("leverage", _leverage)
	leverage_meter.queue_redraw()

func _format_leverage() -> String:
	if _leverage > 0:
		return "+%d" % _leverage
	elif _leverage < 0:
		return "%d" % _leverage
	return "0"

func _enable_gamepad_navigation() -> void:
	# Allow keyboard/gamepad focus
	for b in [btn_offer, btn_pressure, btn_scheme]:
		b.focus_mode = Control.FOCUS_ALL
	btn_offer.grab_focus()
	_set_selection(0)

func _handle_gamepad_input() -> void:
	if Input.is_action_just_pressed("ui_right"):
		_set_selection(min(_sel + 1, 2))
	elif Input.is_action_just_pressed("ui_left"):
		_set_selection(max(_sel - 1, 0))
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match _sel:
			0: _attempt("offer")
			1: _attempt("pressure")
			2: _attempt("scheme")

func _set_selection(i: int) -> void:
	_sel = i
	var mods = [btn_offer, btn_pressure, btn_scheme]
	for idx in range(mods.size()):
		var b: Button = mods[idx]
		b.modulate = Color(1, 1, 1, 1)
		if idx == _sel:
			b.modulate = Color(1, 1, 0.6, 1)
			b.grab_focus()

func _toggle_qte_visibility(v: bool) -> void:
	qte_window.visible = v
	qte_perfect.visible = v
	needle.visible = v
	if v:
		# reset needle visual when QTE starts
		needle.color = Color(0.95, 0.95, 0.2, 0.9)
	qte_hit.visible = false

func _recenter_panel() -> void:
	var panel: Control = $Panel
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.size = Vector2(1000, 360)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var pos := (vp_size - panel.size) * 0.5
	panel.position = pos
	print("[DealDuel] recenter panel: vp=", vp_size, " size=", panel.size, " pos=", pos)

func _flash_label(col: Color) -> void:
	if is_instance_valid(_label_tween):
		_label_tween.kill()
	label.visible = true
	label.add_theme_color_override("font_color", col)
	label.modulate = Color(1, 1, 1, 1)
	_label_tween = create_tween()
	_label_tween.tween_property(label, "modulate:a", 0.6, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_label_tween.tween_property(label, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _show_hit_marker_at(norm_v: float) -> void:
	# Position hit marker at normalized position along the dial; freeze needle.
	var left: float = 40.0
	var right: float = 960.0
	var n_x: float = lerp(left, right, norm_v)
	needle.offset_left = n_x - 4.0
	needle.offset_right = n_x + 4.0
	# turn needle white and flash
	needle.color = Color(1, 1, 1, 1)
	var ntw := create_tween()
	ntw.tween_property(needle, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ntw.tween_property(needle, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# freeze visuals after this point
	_qte_frozen = true
	_frozen_v = norm_v
	var marker_w: float = 2.0
	qte_hit.offset_left = n_x - marker_w
	qte_hit.offset_right = n_x + marker_w
	qte_hit.offset_top = 88.0
	qte_hit.offset_bottom = 172.0
	qte_hit.visible = true
	# Set hit marker color based on accuracy AND phase
	var d: float = abs(norm_v - _window_center)
	var marker_color: Color
	var is_perfect: bool = false
	if d <= _perfect_half:
		marker_color = Color(1, 1, 0.2, 1.0)  # Yellow for perfect (both phases)
		is_perfect = true
	elif d <= _good_half:
		if _phase == Phase.ATTACK_QTE:
			marker_color = Color(0.2, 0.9, 0.4, 1.0)  # Green for good attack
		else:  # DEFENSE_QTE
			marker_color = Color(0.9, 0.25, 0.2, 1.0)  # Red for failed defense
	else:
		if _phase == Phase.ATTACK_QTE:
			marker_color = Color(0.9, 0.25, 0.2, 1.0)  # Red for missed attack
		else:  # DEFENSE_QTE
			marker_color = Color(0.9, 0.25, 0.2, 1.0)  # Red for failed defense
	qte_hit.color = marker_color
	qte_hit.modulate = marker_color
	# Enhanced flash tween for perfect hits
	var tw := create_tween()
	if is_perfect and _phase == Phase.ATTACK_QTE:
		# More dramatic flash for perfect attacks
		tw.tween_property(qte_hit, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(qte_hit, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(qte_hit, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(qte_hit, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# Normal flash for other hits
		tw.tween_property(qte_hit, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _apply_difficulty_from_context() -> void:
	# Use context.level if provided to scale QTE speed and windows
	var lvl := 1
	if typeof(context) == TYPE_DICTIONARY and context.has("level") and typeof(context.level) == TYPE_INT:
		lvl = max(1, int(context.level))
	# Scale speed slightly with level, clamp to avoid impossible
	_speed = clamp(2.0 + (lvl - 1) * 0.12, 1.8, 4.0)
	# Scale window radius tighter with level for harder timing
	var base_min := 0.08
	var base_rand := 0.06
	var shrink: float = minf(0.04, (lvl - 1) * 0.005)
	_window_radius = base_min - shrink + randf() * maxf(0.02, base_rand - shrink)
	# tighten perfect/good windows with level
	_perfect_half = clamp(0.03 - (lvl - 1) * 0.0015, 0.02, 0.03)
	_good_half = clamp(0.08 - (lvl - 1) * 0.0020, 0.05, 0.08)

func _init_persona_from_context() -> void:
	if typeof(context) == TYPE_DICTIONARY and context.has("persona") and typeof(context.persona) == TYPE_STRING:
		_enemy_persona = String(context.persona)
		return
	# randomize with slight bias toward balanced
	var r: float = randf()
	if r < 0.5:
		_enemy_persona = "balanced"
	elif r < 0.7:
		_enemy_persona = "bully"
	elif r < 0.85:
		_enemy_persona = "schemer"
	else:
		_enemy_persona = "appeaser"

func _persona_hint() -> String:
	match _enemy_persona:
		"bully":
			return "favors Pressure"
		"schemer":
			return "favors Scheme"
		"appeaser":
			return "favors Offer"
		_:
			return "balanced"
