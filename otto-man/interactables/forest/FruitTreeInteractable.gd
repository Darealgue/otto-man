class_name FruitTreeInteractable
extends BaseInteractable

const ResourceType = preload("res://resources/resource_types.gd")

@export_range(3, 7, 1) var fruit_count: int = 4
@export_enum("burst", "spiral", "arc") var launch_pattern: String = "burst"
@export var combo_target: int = 3
@export var base_reward: int = 4
@export var combo_bonus: int = 2
@export var placeholder_mode: bool = false

var _placeholder_polygon: Polygon2D = null

func _ready() -> void:
	minigame_kind = "forest_fruit"
	require_interact_press = true
	_ensure_minimum_nodes()
	super._ready()
	if placeholder_mode:
		_apply_placeholder_visual()

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["fruit_count"] = fruit_count
	ctx["pattern"] = launch_pattern
	ctx["combo_target"] = combo_target
	ctx["resource_type"] = ResourceType.FOOD
	ctx["resource_base"] = base_reward
	ctx["combo_bonus"] = combo_bonus
	return ctx

func _on_minigame_success(_payload: Dictionary) -> void:
	_mark_harvested(true)

func _on_minigame_failure(_payload: Dictionary) -> void:
	_mark_harvested(false)

func _mark_harvested(success: bool) -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D
		if success:
			sprite.modulate = Color(0.7, 1.0, 0.7, 1.0)
		else:
			sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)

func set_placeholder_mode(enabled: bool) -> void:
	placeholder_mode = enabled
	if placeholder_mode:
		_apply_placeholder_visual()
	elif _placeholder_polygon:
		_placeholder_polygon.queue_free()
		_placeholder_polygon = null
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

func _apply_placeholder_visual() -> void:
	if _placeholder_polygon == null:
		_placeholder_polygon = Polygon2D.new()
		_placeholder_polygon.polygon = PackedVector2Array([
			Vector2(-32, 0),
			Vector2(32, 0),
			Vector2(32, -128),
			Vector2(-32, -128)
		])
		_placeholder_polygon.color = Color(0.8, 0.5, 0.2, 0.7)  # Turuncu/kahverengi - meyve rengi
		add_child(_placeholder_polygon)
	if has_node("Sprite2D"):
		$Sprite2D.visible = false
	if has_node("CollisionShape2D"):
		var shape := $CollisionShape2D
		if shape.shape is RectangleShape2D:
			var rect := shape.shape as RectangleShape2D
			rect.size = Vector2(64, 128)
			shape.position = Vector2(0, -64)

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 128)
		cs.shape = rect
		cs.position = Vector2(0, -64)
		add_child(cs)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)

