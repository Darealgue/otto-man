extends RefCounted
class_name HudLayout
## Oyuncu HUD — yuz sol ust koseye oturur, can/stamina saginda ust uste.

const FRAME_TEXTURE_SIZE := Vector2(480.0, 180.0)
const FRAME_INNER_HOLE_SIZE := 110.0
const FRAME_INNER_TOP_LEFT := Vector2(45.0, 35.0)
## Dis halka bbox (otto_frame2 analizi) — kesilmemesi icin buna gore hizala.
const FRAME_RING_OUTER_TOP_LEFT := Vector2(31.0, 21.0)
const PORTRAIT_PIXEL_SIZE := 110

const HUD_ORIGIN := Vector2(10.0, 10.0)

const BAR_GAP_FROM_PORTRAIT := 8.0
const BAR_HEIGHT := 20.0
const BAR_STACK_GAP := 4.0

const STAMINA_SIZE := Vector2(200.0, 25.0)
const VILLAGE_RESOURCE_PANEL_GAP := 12.0

## Cerceve dis halkasi (0,0)'da; yuz deligi buna gore ofsetli.
static func get_frame_draw_offset() -> Vector2:
	return -FRAME_RING_OUTER_TOP_LEFT


static func get_face_rect_local() -> Rect2:
	var pos: Vector2 = FRAME_INNER_TOP_LEFT - FRAME_RING_OUTER_TOP_LEFT
	return Rect2(pos, Vector2(FRAME_INNER_HOLE_SIZE, FRAME_INNER_HOLE_SIZE))


static func get_hud_clip_size() -> Vector2:
	var face: Rect2 = get_face_rect_local()
	return Vector2(
		face.position.x + face.size.x + BAR_GAP_FROM_PORTRAIT + 200.0 + 8.0,
		FRAME_TEXTURE_SIZE.y + get_frame_draw_offset().y
	)


static func get_bar_left() -> float:
	var face: Rect2 = get_face_rect_local()
	return face.position.x + face.size.x + BAR_GAP_FROM_PORTRAIT


static func get_bar_width() -> float:
	return 200.0


static func get_bar_top() -> float:
	var face: Rect2 = get_face_rect_local()
	return face.position.y + (face.size.y - BAR_HEIGHT) * 0.5


static func get_health_display_size() -> Vector2:
	return get_hud_clip_size()


static func get_bar_rect() -> Rect2:
	return Rect2(get_bar_left(), get_bar_top(), get_bar_width(), BAR_HEIGHT)


static func get_stamina_rect(health_origin: Vector2 = HUD_ORIGIN) -> Rect2:
	var bar: Rect2 = get_bar_rect()
	var top: float = health_origin.y + bar.position.y + bar.size.y + BAR_STACK_GAP
	return Rect2(health_origin.x + bar.position.x, top, bar.size.x, STAMINA_SIZE.y)


static func get_hud_block_bottom(health_origin: Vector2 = HUD_ORIGIN) -> float:
	var bar: Rect2 = get_bar_rect()
	var stamina: Rect2 = get_stamina_rect(health_origin)
	var frame_bottom: float = health_origin.y + FRAME_TEXTURE_SIZE.y + get_frame_draw_offset().y
	return maxf(frame_bottom, stamina.position.y + stamina.size.y)


static func get_village_resource_panel_top(health_origin: Vector2 = HUD_ORIGIN) -> float:
	return get_hud_block_bottom(health_origin) + VILLAGE_RESOURCE_PANEL_GAP


static func get_portrait_hole_rect_local() -> Rect2:
	return get_face_rect_local()


static func apply_health_display(health: Control, origin: Vector2 = HUD_ORIGIN) -> void:
	if health == null:
		return
	var size: Vector2 = get_health_display_size()
	health.set_anchors_preset(Control.PRESET_TOP_LEFT)
	health.offset_left = origin.x
	health.offset_top = origin.y
	health.offset_right = origin.x + size.x
	health.offset_bottom = origin.y + size.y
	health.scale = Vector2.ONE
	var bar: Control = health.get_node_or_null("BarContainer") as Control
	if bar:
		var rect: Rect2 = get_bar_rect()
		bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bar.offset_left = rect.position.x
		bar.offset_top = rect.position.y
		bar.offset_right = rect.position.x + rect.size.x
		bar.offset_bottom = rect.position.y + rect.size.y
	var portrait: Control = health.get_node_or_null("Portrait") as Control
	if portrait:
		portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
		portrait.offset_left = 0.0
		portrait.offset_top = 0.0
		portrait.offset_right = size.x
		portrait.offset_bottom = get_frame_draw_offset().y + FRAME_TEXTURE_SIZE.y
		portrait.clip_contents = false


static func apply_stamina_bar(stamina: Control, health_origin: Vector2 = HUD_ORIGIN) -> void:
	if stamina == null:
		return
	var rect: Rect2 = get_stamina_rect(health_origin)
	stamina.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stamina.offset_left = rect.position.x
	stamina.offset_top = rect.position.y
	stamina.offset_right = rect.position.x + rect.size.x
	stamina.offset_bottom = rect.position.y + rect.size.y
	stamina.scale = Vector2.ONE


static func apply_game_hud_container(container: Control) -> void:
	if container == null:
		return
	apply_health_display(container.get_node_or_null("HealthDisplay") as Control, HUD_ORIGIN)
	apply_stamina_bar(container.get_node_or_null("StaminaBar") as Control, HUD_ORIGIN)


static func describe_node(node: Control, label: String) -> String:
	if node == null:
		return "%s: <null>" % label
	return (
		"%s pos=(%.0f,%.0f) size=%.0fx%.0f scale=%s"
		% [label, node.position.x, node.position.y, node.size.x, node.size.y, node.scale]
	)
