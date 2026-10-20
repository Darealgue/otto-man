class_name ResourceLossPopup
extends RefCounted

## Kaybedilen / harcanan kaynak için oyuncunun üstünde süzülen kırmızı "-N" + kaynak ikonu (yazısız).
## Toplama popup'ının (resource_piece.gd) ters ikizi; ormanda vurulunca kaybedilen kaynaklarda ve kediye yem harcarken kullanılır.

const ICON_PATHS := {
	"wood": "res://assets/Icons/wood_icon.png",
	"stone": "res://assets/Icons/stone_icon.png",
	"food": "res://assets/Icons/food_icon.png",
}
const LOSS_COLOR := Color(1.0, 0.25, 0.22, 1.0)


## resource_type: "wood" | "stone" | "food". delay: aynı anda birden çok kayıp için kademeli gösterim.
static func spawn(resource_type: String, amount: int, world_pos: Variant = null, delay: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null or amount <= 0:
		return
	var pos: Vector2
	if world_pos is Vector2:
		pos = world_pos
	else:
		var player := tree.get_first_node_in_group("player") as Node2D
		if player == null or not is_instance_valid(player):
			return
		pos = player.global_position + Vector2(0.0, -90.0)
	var popup := Node2D.new()
	popup.z_as_relative = false
	popup.z_index = 4096   # Godot'un üst sınırı; daha büyük değer sessizce reddedilir ve popup binaların arkasında kalır
	popup.modulate.a = 0.0
	tree.current_scene.add_child(popup)
	popup.global_position = pos

	var icon_path: String = String(ICON_PATHS.get(resource_type, ""))
	var label_x := -10.0
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.size = Vector2(18, 18)
		icon.position = Vector2(-2, -9)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(icon)
		label_x = -30.0

	var label := Label.new()
	label.text = "-%d" % amount
	label.position = Vector2(label_x, -13)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", LOSS_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	popup.add_child(label)

	var tween := popup.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(popup, "modulate:a", 1.0, 0.05)
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)
