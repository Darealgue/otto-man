extends Node2D
## Orman çıkışı: yaklaşınca "Köye Dön" yazısı + yukarı ok ikonu belirir (uzaktayken gizli).
## Ayrıca ekranın kenarında, çıkış ekran dışındayken yönünü gösteren bir ok belirir;
## çıkış ekrandaysa ok gizlenir.

const NpcOverheadUi = preload("res://ui/npc_overhead_ui.gd")

const NEAR_FADE_START := 520.0
const NEAR_FADE_END := 260.0
const FADE_SPEED := 4.0
const EDGE_MARGIN := 42.0
const ARROW_SIZE := 26.0
const ARROW_COLOR := Color(0.95, 0.85, 0.45, 0.95)

var _info_label: Label
var _hint_icon: TextureRect
var _label_alpha := 0.0

var _arrow_layer: CanvasLayer
var _arrow: Control


func _ready() -> void:
	_info_label = get_node_or_null("Info")
	if _info_label:
		_info_label.modulate.a = 0.0

	_hint_icon = NpcOverheadUi.build_up_arrow_hint_icon()
	add_child(_hint_icon)
	if _info_label:
		_hint_icon.position = _info_label.position + Vector2(-_hint_icon.size.x - 6.0, -_hint_icon.size.y * 0.5 + 2.0)
	_hint_icon.modulate.a = 0.0

	_build_direction_arrow()
	set_process(true)


func _build_direction_arrow() -> void:
	_arrow_layer = CanvasLayer.new()
	_arrow_layer.name = "ForestExitArrowLayer"
	_arrow_layer.layer = 60
	add_child(_arrow_layer)

	_arrow = Control.new()
	_arrow.name = "ForestExitArrow"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
	_arrow.size = Vector2(ARROW_SIZE, ARROW_SIZE)
	_arrow.pivot_offset = Vector2(ARROW_SIZE * 0.5, ARROW_SIZE * 0.5)
	_arrow.visible = false
	_arrow.draw.connect(_draw_arrow.bind(_arrow))
	_arrow_layer.add_child(_arrow)


func _draw_arrow(node: Control) -> void:
	# Yukarıyı gösteren üçgen (varsayılan yön) — rotation ile hedefe döndürülür.
	var pts := PackedVector2Array([
		Vector2(ARROW_SIZE * 0.5, 0.0),
		Vector2(ARROW_SIZE, ARROW_SIZE),
		Vector2(ARROW_SIZE * 0.5, ARROW_SIZE * 0.72),
		Vector2(0.0, ARROW_SIZE),
	])
	node.draw_colored_polygon(pts, ARROW_COLOR)


func _process(delta: float) -> void:
	_update_proximity_hint(delta)
	_update_direction_arrow()


func _update_proximity_hint(delta: float) -> void:
	var player := _find_player()
	var target_alpha := 0.0
	if player:
		var dist := global_position.distance_to(player.global_position)
		if dist <= NEAR_FADE_END:
			target_alpha = 1.0
		elif dist < NEAR_FADE_START:
			target_alpha = 1.0 - (dist - NEAR_FADE_END) / (NEAR_FADE_START - NEAR_FADE_END)
	_label_alpha = move_toward(_label_alpha, target_alpha, FADE_SPEED * delta)
	if _info_label:
		_info_label.modulate.a = _label_alpha
	if _hint_icon:
		_hint_icon.modulate.a = _label_alpha


func _update_direction_arrow() -> void:
	if _arrow == null:
		return
	var vp := get_viewport()
	if vp == null:
		_arrow.visible = false
		return
	var cam := vp.get_camera_2d()
	if cam == null:
		_arrow.visible = false
		return
	var screen_size: Vector2 = vp.get_visible_rect().size
	var center: Vector2 = cam.get_screen_center_position()
	var screen_pos: Vector2 = (global_position - center) * cam.zoom + screen_size * 0.5

	if Rect2(Vector2.ZERO, screen_size).has_point(screen_pos):
		_arrow.visible = false
		return

	_arrow.visible = true
	var screen_center := screen_size * 0.5
	var dir: Vector2 = screen_pos - screen_center
	if dir.length() < 0.001:
		dir = Vector2.UP
	dir = dir.normalized()

	var half: Vector2 = screen_size * 0.5 - Vector2.ONE * EDGE_MARGIN
	var scale_x: float = (half.x / absf(dir.x)) if absf(dir.x) > 0.0001 else INF
	var scale_y: float = (half.y / absf(dir.y)) if absf(dir.y) > 0.0001 else INF
	var t: float = minf(scale_x, scale_y)
	var clamped: Vector2 = screen_center + dir * t

	_arrow.position = clamped - _arrow.size * 0.5
	_arrow.rotation = dir.angle() + PI * 0.5
	_arrow.queue_redraw()


func _find_player() -> Node2D:
	for n in get_tree().get_nodes_in_group(&"player"):
		if is_instance_valid(n) and n is Node2D:
			return n
	return null
