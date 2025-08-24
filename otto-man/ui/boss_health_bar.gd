extends Control

@onready var bar := $Bar as ColorRect
@onready var delayed := $Delayed as ColorRect
@onready var label := $Label as Label

var max_health: float = 100.0
var current_health: float = 100.0
var delayed_health: float = 100.0
var visible_tweening: bool = false
var defer_reveal: bool = false

func _ready() -> void:
	# Center pivot for nicer scale pop
	pivot_offset = size * 0.5

func _process(delta: float) -> void:
	if delayed_health > current_health:
		delayed_health = move_toward(delayed_health, current_health, max_health * 0.8 * delta)
		_update_bars()

func setup(initial_max: float) -> void:
	max_health = max(1.0, initial_max)
	current_health = max_health
	delayed_health = max_health
	_update_bars()
	if not defer_reveal:
		_show_bar()

func setup_silent(initial_max: float) -> void:
	max_health = max(1.0, initial_max)
	current_health = max_health
	delayed_health = max_health
	_update_bars()
	hide()
	modulate.a = 0.0
	scale = Vector2.ONE

func update_health(h: float, max_h: float) -> void:
	max_health = max(1.0, max_h)
	current_health = clamp(h, 0.0, max_health)
	_update_bars()
	if not defer_reveal:
		_show_bar()

func _update_bars() -> void:
	var ratio := current_health / max_health
	var delayed_ratio := delayed_health / max_health
	bar.scale.x = clamp(ratio, 0.0, 1.0)
	delayed.scale.x = clamp(delayed_ratio, 0.0, 1.0)
	label.text = "%d / %d" % [int(current_health), int(max_health)]

func _show_bar() -> void:
	if visible_tweening:
		return
	visible_tweening = true
	modulate.a = 0.0
	show()
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.finished.connect(func(): visible_tweening = false)

func reveal() -> void:
	if visible_tweening:
		return
	defer_reveal = false
	visible_tweening = true
	show()
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	var t = create_tween()
	# Fade in and scale up slightly
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.18)
	# Ease back to 1.0 scale
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	t.finished.connect(func(): visible_tweening = false)

func conceal() -> void:
	if visible_tweening:
		return
	defer_reveal = true
	visible_tweening = true
	var t = create_tween()
	# Quick fade-out and slight scale down
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.parallel().tween_property(self, "scale", Vector2(0.98, 0.98), 0.15)
	t.finished.connect(func():
		visible_tweening = false
		hide()
		scale = Vector2(1.0, 1.0)
	)


