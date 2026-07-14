class_name VillageResourceDeliveryFx
extends Node2D

const RESOURCE_ICONS: Dictionary = {
	"wood": preload("res://assets/Icons/wood_icon.png"),
	"stone": preload("res://assets/Icons/stone_icon.png"),
	"food": preload("res://assets/Icons/food_icon.png"),
}

const FLOAT_OFFSET := Vector2(0.0, -72.0)
const DURATION := 1.15
const ICON_SCALE := Vector2(0.42, 0.42)


static func spawn(parent: Node, world_position: Vector2, resource_type: String, amount: int) -> void:
	if parent == null or amount <= 0:
		return
	var fx := VillageResourceDeliveryFx.new()
	parent.add_child(fx)
	fx.global_position = world_position
	fx._play(resource_type, amount)


func _play(resource_type: String, amount: int) -> void:
	z_index = 85
	modulate = Color(1, 1, 1, 1)

	var icon_tex: Texture2D = RESOURCE_ICONS.get(resource_type, null) as Texture2D
	if icon_tex:
		var icon := Sprite2D.new()
		icon.texture = icon_tex
		icon.scale = ICON_SCALE
		icon.position = Vector2(-14, -8)
		add_child(icon)

	var label := Label.new()
	label.text = "+%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-28, -36)
	label.size = Vector2(56, 28)
	label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)

	scale = Vector2(0.35, 0.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "global_position", global_position + FLOAT_OFFSET, DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, DURATION)\
		.set_delay(0.35)
	tween.chain().tween_callback(queue_free)
