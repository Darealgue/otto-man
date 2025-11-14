class_name WellInteractable
extends BaseInteractable

const ResourceType = preload("res://resources/resource_types.gd")

@export_range(1, 5, 1) var depth_level: int = 1
@export_range(4, 8, 1) var pulls_required: int = 5
@export_range(0.05, 0.3, 0.01) var sweet_spot_width: float = 0.12
@export var base_reward: int = 5
@export var perfect_bonus: int = 1
@export var placeholder_mode: bool = false

var _placeholder_polygon: Polygon2D = null

func _ready() -> void:
	minigame_kind = "forest_water"
	require_interact_press = true
	_ensure_minimum_nodes()
	super._ready()
	if placeholder_mode:
		_apply_placeholder_visual()

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["depth"] = depth_level
	ctx["pulls_required"] = pulls_required
	ctx["sweet_spot"] = sweet_spot_width
	ctx["resource_type"] = ResourceType.WATER
	ctx["resource_base"] = base_reward
	ctx["perfect_bonus"] = perfect_bonus
	return ctx

func _on_minigame_success(_payload: Dictionary) -> void:
	_fade_visual(Color(0.6, 0.8, 1.0))

func _on_minigame_failure(_payload: Dictionary) -> void:
	_fade_visual(Color(1.0, 0.5, 0.5))

func _fade_visual(color: Color) -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D
		sprite.modulate = color

func set_placeholder_mode(enabled: bool) -> void:
	placeholder_mode = enabled
	if placeholder_mode:
		_apply_placeholder_visual()
	elif _placeholder_polygon:
		_placeholder_polygon.queue_free()
		_placeholder_polygon = null
	if has_node("Sprite2D"):
		$Sprite2D.visible = not placeholder_mode

func _apply_placeholder_visual() -> void:
	if _placeholder_polygon == null:
		_placeholder_polygon = Polygon2D.new()
		_placeholder_polygon.polygon = PackedVector2Array([
			Vector2(-40, 0),
			Vector2(40, 0),
			Vector2(40, -80),
			Vector2(-40, -80)
		])
		_placeholder_polygon.color = Color(0.3, 0.6, 0.9, 0.7)  # Açık mavi - su rengi
		add_child(_placeholder_polygon)
	if has_node("Sprite2D"):
		$Sprite2D.visible = false
	if has_node("CollisionShape2D"):
		var shape := $CollisionShape2D
		if shape.shape is RectangleShape2D:
			var rect := shape.shape as RectangleShape2D
			rect.size = Vector2(80, 80)
			shape.position = Vector2(0, -40)

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(80, 80)
		cs.shape = rect
		cs.position = Vector2(0, -40)
		add_child(cs)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)

