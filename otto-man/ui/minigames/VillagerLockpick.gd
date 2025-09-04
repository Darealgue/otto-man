extends CanvasLayer

signal completed(success: bool, payload: Dictionary)

var context := {}
var _timer := 0.0
var _speed := 2.0
var _window_center := 0.5
var _window_radius := 0.12
var _hits := 0
var _required := 3
var _attempts := 5

@onready var dial: Control = $Panel/Dial
@onready var window_rect: ColorRect = $Panel/Dial/Window
@onready var needle_rect: ColorRect = $Panel/Dial/Needle
@onready var hit_marker: ColorRect = $Panel/Dial/HitMarker
@onready var label: Label = $Panel/Label

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 100
	follow_viewport_enabled = false
	offset = Vector2.ZERO
	# Center panel regardless of camera
	var panel: Control = $Panel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -120
	panel.offset_bottom = 120
	_randomize_window()
	_apply_difficulty_from_context()
	_update_visuals(0.0)

func _process(delta):
	_timer += delta * _speed
	var v = fposmod(_timer, 1.0)
	_update_visuals(v)
	if Input.is_action_just_pressed("jump"):
		var d = abs(v - _window_center)
		if d <= _window_radius:
			_hits += 1
			label.text = "Hit %d/%d" % [_hits, _required]
			# colored hit marker based on accuracy
			hit_marker.visible = true
			var hit_accuracy: float = 1.0 - (d / _window_radius)
			var marker_color: Color
			if hit_accuracy > 0.7:
				marker_color = Color(0.2, 0.9, 0.4, 1.0)  # Green for perfect
			else:
				marker_color = Color(0.2, 0.9, 0.4, 1.0)  # Green for good (not red!)
			hit_marker.color = marker_color
			hit_marker.modulate = marker_color
			# Update hit marker position to current needle position
			var n_x: float = lerp(40.0, 800.0, v)
			hit_marker.offset_left = n_x - 4.0
			hit_marker.offset_right = n_x + 4.0
			hit_marker.offset_top = 24.0
			hit_marker.offset_bottom = 184.0
			var htw := create_tween()
			htw.tween_property(hit_marker, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			htw.tween_callback(func(): hit_marker.visible = false)
			# Safe label flash
			_flash_label(Color(0.2, 0.9, 0.4, 1.0))
			_randomize_window()
			if _hits >= _required:
				_finish(true)
		else:
			_attempts -= 1
			label.text = "Miss! Attempts left: %d" % _attempts
			# Show red hit marker for miss
			hit_marker.visible = true
			hit_marker.color = Color(0.9, 0.25, 0.2, 1.0)
			hit_marker.modulate = Color(0.9, 0.25, 0.2, 1.0)
			var n_x: float = lerp(40.0, 800.0, v)
			hit_marker.offset_left = n_x - 4.0
			hit_marker.offset_right = n_x + 4.0
			hit_marker.offset_top = 24.0
			hit_marker.offset_bottom = 184.0
			var htw := create_tween()
			htw.tween_property(hit_marker, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			htw.tween_callback(func(): hit_marker.visible = false)
			# Safe label flash
			_flash_label(Color(0.9, 0.25, 0.2, 1.0))
			if _attempts <= 0:
				_finish(false)

func _randomize_window():
	_window_center = randf_range(0.2, 0.8)
	_window_radius = 0.10 + randf() * 0.05

func _update_visuals(v: float) -> void:
	var left: float = 40.0
	var right: float = 800.0
	var top: float = 24.0
	var bottom: float = 184.0
	var w_left: float = lerp(left, right, _window_center - _window_radius)
	var w_right: float = lerp(left, right, _window_center + _window_radius)
	window_rect.offset_left = w_left
	window_rect.offset_right = w_right
	window_rect.offset_top = top + 16.0
	window_rect.offset_bottom = bottom - 16.0
	var n_x: float = lerp(left, right, v)
	needle_rect.offset_left = n_x - 4.0
	needle_rect.offset_right = n_x + 4.0
	needle_rect.offset_top = top
	needle_rect.offset_bottom = bottom

func _finish(success: bool):
	emit_signal("completed", success, {"perfect": _hits == _required})

func _flash_label(col: Color) -> void:
	# Safe label flash that doesn't conflict with other tweens
	label.visible = true
	label.add_theme_color_override("font_color", col)
	label.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.6, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _apply_difficulty_from_context() -> void:
	var lvl := 1
	if typeof(context) == TYPE_DICTIONARY and context.has("level") and typeof(context.level) == TYPE_INT:
		lvl = max(1, int(context.level))
	_speed = clamp(2.0 + (lvl - 1) * 0.12, 1.8, 4.2)
	_required = clamp(3 + int((lvl - 1) / 3), 3, 6)
	_attempts = max(_required + 2, 5)
