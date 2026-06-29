class_name NpcAmbientBubble
extends RefCounted
## Köylü kafasında kısa ambient konuşma balonu (kod ile oluşturulur).

const BUBBLE_NAME := "AmbientSpeechBubble"


static func show_on_npc(npc: Node2D, text: String, duration: float = 3.5) -> void:
	if not is_instance_valid(npc) or text.strip_edges().is_empty():
		return
	clear_on_npc(npc)
	var bubble := _build_bubble(text)
	bubble.name = BUBBLE_NAME
	npc.add_child(bubble)
	bubble.position = Vector2(-72.0, -78.0)
	bubble.z_index = 20
	if npc.scale.x < 0.0:
		bubble.scale.x = -1.0
	var tween := npc.create_tween()
	tween.tween_property(bubble, "modulate:a", 0.0, 0.35).set_delay(maxf(0.5, duration - 0.35))
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(bubble):
			bubble.queue_free()
	)


static func clear_on_npc(npc: Node2D) -> void:
	if not is_instance_valid(npc):
		return
	var existing := npc.get_node_or_null(BUBBLE_NAME)
	if is_instance_valid(existing):
		existing.queue_free()


static func has_active_bubble(npc: Node) -> bool:
	return is_instance_valid(npc) and npc.get_node_or_null(BUBBLE_NAME) != null


static func _build_bubble(text: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(144.0, 0.0)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(144.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.82)
	style.border_color = Color(0.55, 0.48, 0.35, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(132.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NpcOverheadUi.apply_nameplate_text_style(label)
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	return root
