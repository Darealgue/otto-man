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


## hframes > 1 verilirse texture bir sprite sheet olarak ele alınır: yalnızca `frame`
## gösterilir ve ölçek tam texture'a değil KARE boyutuna göre hesaplanır.
## (Zindan kapısı door_1.png 8 kareli; tam texture ölçeğiyle 8 kapı yan yana görünürdü.)
static func attach_centered_sprite(
	parent: Node,
	texture_paths: Array,
	position: Vector2 = Vector2.ZERO,
	max_size: Vector2 = Vector2(72.0, 72.0),
	hide_fallback_nodes: Array = [],
	hframes: int = 1,
	frame: int = 0
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "VisualSprite"
	sprite.centered = true
	sprite.position = position
	var tex: Texture2D = load_first_texture(texture_paths)
	if tex:
		sprite.texture = tex
		sprite.hframes = maxi(1, hframes)
		sprite.frame = clampi(frame, 0, sprite.hframes - 1)
		sprite.scale = fit_texture_scale(tex, max_size, sprite.hframes)
		for node in hide_fallback_nodes:
			if node is CanvasItem:
				(node as CanvasItem).visible = false
	else:
		sprite.visible = false
	if parent:
		parent.add_child(sprite)
		parent.move_child(sprite, 0)
	return sprite


## max_size bileşeni <= 0 ise o eksende sınır yok demektir (texture kendi boyutunda kalır).
## Vector2.ZERO geçilirse hiç küçültülmez — eskiden ölçek 0 çıkıp sprite görünmez oluyordu.
static func fit_texture_scale(tex: Texture2D, max_size: Vector2, hframes: int = 1) -> Vector2:
	if tex == null:
		return Vector2.ONE
	var sz: Vector2 = tex.get_size()
	sz.x /= float(maxi(1, hframes))
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Vector2.ONE
	if max_size.x <= 0.0 and max_size.y <= 0.0:
		return Vector2.ONE
	if max_size.x <= 0.0:
		return Vector2.ONE * minf(1.0, max_size.y / sz.y)
	if max_size.y <= 0.0:
		return Vector2.ONE * minf(1.0, max_size.x / sz.x)
	return Vector2(
		minf(1.0, max_size.x / sz.x),
		minf(1.0, max_size.y / sz.y)
	)
