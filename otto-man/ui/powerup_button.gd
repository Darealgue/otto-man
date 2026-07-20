extends Button

var powerup_scene: PackedScene
var progress: float = 0.0

func setup(scene: PackedScene) -> void:
	powerup_scene = scene

	# Instance the powerup to get its name and description
	var powerup = scene.instantiate()

	# Check if it's a PowerupEffect or has the required properties
	if powerup is PowerupEffect:
		var powerup_name = powerup.powerup_name
		var description = powerup.description
		var tree_name = powerup.tree_name

		# Tree bilgisi artık isme karışmıyor, ayrı küçük bir rozet olarak gösteriliyor
		var tree_info = ""
		var tree_color: Color = Color(0.6, 0.6, 0.6)
		if tree_name != "":
			var powerup_manager = get_node("/root/PowerupManager")
			if powerup_manager and powerup_manager.TREE_DEFINITIONS.has(tree_name):
				var tree_def = powerup_manager.TREE_DEFINITIONS[tree_name]
				tree_color = tree_def.get("color", Color.WHITE)
				tree_info = String(tree_def.get("name", tree_name.capitalize()))
		_apply_card_tint(tree_color)

		_set_card_text(powerup_name, description, tree_info, tree_color)
	else:
		# For non-PowerupEffect powerups, use the script name as fallback
		var script_path = powerup.get_script().resource_path
		var script_name = script_path.get_file().get_basename()
		_set_card_text(script_name.capitalize(), "Activates " + script_name.capitalize(), "", Color.WHITE)

	powerup.queue_free()

## İsim büyük punto bölgesine, açıklama altına, tree bilgisi ise küçük bir rozet olarak sol üst
## köşeye yazılır. get_node ile doğrudan çekiyoruz — @onready, setup() çağrıldığı anda (buton
## henüz ağaca eklenmeden) çalıştığı için henüz doldurulmamış oluyordu (yazılar kayboluyordu).
func _set_card_text(card_name: String, description: String, tag_text: String = "", tag_color: Color = Color.WHITE) -> void:
	var name_label := get_node_or_null("NameLabel") as Label
	var desc_label := get_node_or_null("DescLabel") as Label
	var tag_label := get_node_or_null("RarityLabel") as Label
	if name_label:
		name_label.text = card_name
	if desc_label:
		desc_label.text = description
	if tag_label:
		tag_label.text = tag_text
		tag_label.add_theme_color_override("font_color", tag_color)

## Şablon kart çizimini (card_template.png) sınıf rengine göre boyayıp buton arka planına basar.
func _apply_card_tint(tint: Color) -> void:
	var sb := CardVisualUtil.build_tinted_card_stylebox(tint)
	if sb == null:
		return
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)

func set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	if progress > 0:
		var size = get_size()
		# Kartın altında, küçük ve kalın bir dolum halkası (eskisi kart ortasında dev ve incecikti)
		var radius = (min(size.x, size.y) * 0.4) / 5.0
		var center = Vector2(size.x * 0.5, size.y + radius + 20.0)
		var angle_from = -PI/2
		var angle_to = angle_from + (PI * 2 * progress)

		draw_arc(center, radius, angle_from, angle_to, 32, Color(1, 1, 1, 0.9), 6.0)
