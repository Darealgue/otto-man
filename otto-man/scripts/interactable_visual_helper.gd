class_name InteractableVisualHelper
extends RefCounted
## Etkileşimli objeler için texture yükleme ve Sprite2D montajı (placeholder yedek).


static func load_first_texture(paths: Array) -> Texture2D:
	for raw in paths:
		var path: String = String(raw)
		if path.is_empty():
			continue
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			return tex
	return null


static func attach_centered_sprite(
	parent: Node,
	texture_paths: Array,
	position: Vector2 = Vector2.ZERO,
	max_size: Vector2 = Vector2(72.0, 72.0),
	hide_fallback_nodes: Array = []
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "VisualSprite"
	sprite.centered = true
	sprite.position = position
	var tex: Texture2D = load_first_texture(texture_paths)
	if tex:
		sprite.texture = tex
		sprite.scale = fit_texture_scale(tex, max_size)
		for node in hide_fallback_nodes:
			if node is CanvasItem:
				(node as CanvasItem).visible = false
	else:
		sprite.visible = false
	if parent:
		parent.add_child(sprite)
		parent.move_child(sprite, 0)
	return sprite


static func fit_texture_scale(tex: Texture2D, max_size: Vector2) -> Vector2:
	if tex == null:
		return Vector2.ONE
	var sz: Vector2 = tex.get_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Vector2.ONE
	return Vector2(
		minf(1.0, max_size.x / sz.x),
		minf(1.0, max_size.y / sz.y)
	)
