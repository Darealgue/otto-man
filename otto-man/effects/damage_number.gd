extends Node2D

const FLOAT_SPEED = 100.0
const FADE_SPEED = 0.8
const SPREAD_RANGE = 30.0
const CRIT_SCALE = 1.2
const FONT_OUTLINE_SIZE := 6
const COLOR_CRIT := Color(1.0, 0.25, 0.2, 1.0)
const COLOR_PLAYER := Color(1.0, 0.25, 0.2, 1.0)
const COLOR_NORMAL := Color(1.0, 0.92, 0.25, 1.0)

@onready var label = $Label

var initial_position: Vector2
var direction: Vector2
var lifetime: float = 1.0

func _ready() -> void:
	initial_position = position
	# Set high z-index to appear above everything
	z_index = 1000
	
	# Random spread
	direction = Vector2(
		randf_range(-1, 1),  # Random X direction
		-1  # Always float up
	).normalized()
	
	# Initial scale animation
	scale = Vector2(0, 0)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.2)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_ELASTIC)

func _process(delta: float) -> void:
	# Move up and fade out
	position += direction * FLOAT_SPEED * delta
	modulate.a -= FADE_SPEED * delta
	
	# Remove when fully transparent
	if modulate.a <= 0:
		queue_free()

func _apply_label_style(fill: Color) -> void:
	label.modulate = Color.WHITE
	label.add_theme_color_override("font_color", fill)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", FONT_OUTLINE_SIZE)


func setup(damage: int, is_crit: bool = false, is_player_damage: bool = false) -> void:
	label.text = str(damage)
	if is_crit:
		scale = Vector2(CRIT_SCALE, CRIT_SCALE)
		_apply_label_style(COLOR_CRIT)
	elif is_player_damage:
		_apply_label_style(COLOR_PLAYER)
	else:
		_apply_label_style(COLOR_NORMAL)