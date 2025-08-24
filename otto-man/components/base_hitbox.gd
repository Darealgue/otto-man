class_name BaseHitbox
extends Area2D

@export var damage: float = 0.0
@export var knockback_force: float = 0.0
@export var knockback_up_force: float = 0.0
@export var debug_enabled: bool = false

var is_active: bool = false

@onready var _shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready():
	# Ensure hitbox starts disabled
	disable()
	# Make collision shape visible in editor but hidden in game
	if get_node_or_null("CollisionShape2D"):
		get_node("CollisionShape2D").debug_color = Color(0.7, 0, 0, 0.4)

func enable():
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", false)
	is_active = true
	if debug_enabled:
		queue_redraw()

func disable():
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").set_deferred("disabled", true)
	is_active = false
	if debug_enabled:
		queue_redraw()

func is_enabled() -> bool:
	return is_active

func get_damage() -> float:
	return damage

func get_knockback_data() -> Dictionary:
	return {
		"force": knockback_force,
		"up_force": knockback_up_force
	} 

func _process(_delta: float) -> void:
	if debug_enabled:
		queue_redraw()

func _draw() -> void:
	if not debug_enabled:
		return
	if _shape_node == null or _shape_node.shape == null:
		return
	var fill_col := Color(1.0, 0.0, 0.0, 0.28) if is_active else Color(1.0, 0.0, 0.0, 0.12)
	var line_col := Color(1.0, 0.0, 0.0, 0.8)
	if _shape_node.shape is CircleShape2D:
		var circle := _shape_node.shape as CircleShape2D
		var center := _shape_node.position
		draw_circle(center, circle.radius, fill_col)
		draw_arc(center, circle.radius, 0.0, TAU, 24, line_col, 2.0, true)
	elif _shape_node.shape is RectangleShape2D:
		var rect := _shape_node.shape as RectangleShape2D
		var size := rect.size
		var top_left := _shape_node.position - size * 0.5
		draw_rect(Rect2(top_left, size), fill_col, true)
		draw_rect(Rect2(top_left, size), line_col, false, 2.0)
	elif _shape_node.shape is CapsuleShape2D:
		var cap := _shape_node.shape as CapsuleShape2D
		# Approximate capsule by a rectangle with two circles
		var r := cap.radius
		var h := cap.height
		var center_x := _shape_node.position.x
		var center_y := _shape_node.position.y
		var rect_top_left := Vector2(center_x - r, center_y - h * 0.5)
		var rect_size := Vector2(r * 2.0, h)
		draw_rect(Rect2(rect_top_left, rect_size), fill_col, true)
		draw_circle(Vector2(center_x, center_y - h * 0.5), r, fill_col)
		draw_circle(Vector2(center_x, center_y + h * 0.5), r, fill_col)
		draw_arc(Vector2(center_x, center_y - h * 0.5), r, 0.0, TAU, 24, line_col, 2.0, true)
		draw_arc(Vector2(center_x, center_y + h * 0.5), r, 0.0, TAU, 24, line_col, 2.0, true)
