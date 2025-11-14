class_name RockInteractable
extends BaseInteractable

const ResourceType = preload("res://resources/resource_types.gd")

@export_range(1, 5, 1) var tier: int = 1
@export_range(3, 7, 1) var perfect_hits_required: int = 3
@export_range(0.02, 0.2, 0.01) var tolerance: float = 0.1
@export var base_reward: int = 3
@export var perfect_bonus: int = 1
@export var placeholder_mode: bool = false

var _placeholder_polygon: Polygon2D = null

func _ready() -> void:
	minigame_kind = "forest_stone"
	require_interact_press = true
	_ensure_minimum_nodes()
	super._ready()
	if placeholder_mode:
		_apply_placeholder_visual()

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["tier"] = tier
	ctx["required_hits"] = perfect_hits_required
	ctx["tolerance"] = tolerance
	ctx["resource_type"] = ResourceType.STONE
	ctx["resource_base"] = base_reward
	ctx["perfect_bonus"] = perfect_bonus
	return ctx

func _on_minigame_success(payload: Dictionary) -> void:
	_apply_cracked_visual(payload.get("progress", 1.0))

func _on_minigame_failure(_payload: Dictionary) -> void:
	_apply_cracked_visual(0.0)

func _apply_cracked_visual(progress: float) -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D
		var intensity := clampf(progress, 0.0, 1.0)
		sprite.modulate = Color(1.0, 1.0 - 0.4 * intensity, 1.0 - 0.4 * intensity, 1.0)

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
			Vector2(-32, 0),
			Vector2(32, 0),
			Vector2(32, -96),
			Vector2(-32, -96)
		])
		_placeholder_polygon.color = Color(0.5, 0.5, 0.5, 0.7)  # Gri - taş rengi
		add_child(_placeholder_polygon)
	if has_node("Sprite2D"):
		$Sprite2D.visible = false
	if has_node("CollisionShape2D"):
		var shape := $CollisionShape2D
		if shape.shape is RectangleShape2D:
			var rect := shape.shape as RectangleShape2D
			rect.size = Vector2(64, 96)
			shape.position = Vector2(0, -48)

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 96)
		cs.shape = rect
		cs.position = Vector2(0, -48)
		add_child(cs)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)

