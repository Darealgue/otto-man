extends RefCounted
class_name ConcubinePortraitRenderer
## Cariye görünümünü SubViewport ile TextureRect'e bağlar (MissionCenter ile aynı mantık).

const _CONCUBINE_SCENE := preload("res://village/scenes/Concubine.tscn")
const _SPRITE_NAMES: Array[String] = [
	"BodySprite", "PantsSprite", "ClothingSprite", "MouthSprite", "EyesSprite", "HairSprite",
]


static func clear(portrait_rect: TextureRect) -> void:
	if portrait_rect == null or not is_instance_valid(portrait_rect):
		return
	if portrait_rect.has_meta("viewport_ref"):
		var vp: Variant = portrait_rect.get_meta("viewport_ref")
		if vp is SubViewport and is_instance_valid(vp):
			(vp as SubViewport).queue_free()
		portrait_rect.remove_meta("viewport_ref")
	portrait_rect.remove_meta("instance_ref")
	portrait_rect.texture = null


static func render(
	portrait_rect: TextureRect,
	cariye: Concubine,
	host: Node,
	is_stale: Callable
) -> void:
	clear(portrait_rect)
	if portrait_rect == null or not is_instance_valid(portrait_rect):
		return
	if cariye == null or cariye.appearance == null or host == null or not is_instance_valid(host):
		return
	if _CONCUBINE_SCENE == null:
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	host.add_child(viewport)

	var instance: Node = _CONCUBINE_SCENE.instantiate()
	viewport.add_child(instance)
	if not ("appearance" in instance):
		viewport.queue_free()
		return
	instance.set("appearance", cariye.appearance)
	if instance.has_method("update_visuals"):
		instance.call("update_visuals")
	instance.scale = Vector2(-1.0, 1.0)
	if instance.has_method("set_physics_process"):
		instance.set_physics_process(false)
	if "move_target_x" in instance:
		instance.set("move_target_x", 0.0)
	if "_target_global_y" in instance:
		instance.set("_target_global_y", 0.0)
	instance.position = Vector2.ZERO

	for sprite_name in _SPRITE_NAMES:
		var sprite: Node = instance.get_node_or_null(sprite_name)
		if sprite is Sprite2D:
			(sprite as Sprite2D).position = Vector2(0, -48)
			(sprite as Sprite2D).centered = true

	if instance.has_method("play_animation"):
		instance.call("play_animation", "idle")
	var anim_player: AnimationPlayer = instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if is_stale.call() or not is_instance_valid(portrait_rect):
		viewport.queue_free()
		return

	var camera := Camera2D.new()
	camera.zoom = Vector2(48.0, 48.0)
	camera.position = Vector2(0, -40)
	viewport.add_child(camera)
	camera.make_current()

	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if is_stale.call() or not is_instance_valid(portrait_rect):
		viewport.queue_free()
		return

	var viewport_texture: ViewportTexture = viewport.get_texture()
	if viewport_texture == null:
		viewport.queue_free()
		return

	portrait_rect.texture = viewport_texture
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_rect.visible = true
	portrait_rect.set_meta("viewport_ref", viewport)
	portrait_rect.set_meta("instance_ref", instance)
