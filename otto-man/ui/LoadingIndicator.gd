extends Control
## Yükleme / bekleme göstergesi. Varsayılan: dönen kum saati.
## İleride AnimatedSprite2D veya özel sahne ile değiştirilebilir.

enum VisualMode {
	TEXTURE,
	ANIMATED_SPRITE,
	CUSTOM_SCENE,
}

@export var spin_speed: float = 0.75
@export var visual_mode: VisualMode = VisualMode.TEXTURE
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var custom_visual_scene: PackedScene
@export var indicator_size: Vector2 = Vector2(112, 112)

@onready var _pivot: Control = %Pivot
@onready var _texture_rect: TextureRect = %TextureRect
@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _custom_slot: Control = %CustomSlot

var _spin_angle: float = 0.0
var _custom_instance: Node = null


func _ready() -> void:
	custom_minimum_size = indicator_size
	if texture == null:
		texture = load("res://assets/ui/loading_hourglass.svg") as Texture2D
	_refresh_visual()


func _process(delta: float) -> void:
	if visual_mode != VisualMode.TEXTURE:
		return
	if not is_visible_in_tree() or modulate.a <= 0.01:
		return
	_spin_angle += TAU * spin_speed * delta
	if is_instance_valid(_pivot):
		_pivot.rotation = _spin_angle


func set_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	texture = tex
	visual_mode = VisualMode.TEXTURE
	_refresh_visual()


func set_sprite_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return
	sprite_frames = frames
	visual_mode = VisualMode.ANIMATED_SPRITE
	_refresh_visual()


func set_custom_scene(scene: PackedScene) -> void:
	if scene == null:
		return
	custom_visual_scene = scene
	visual_mode = VisualMode.CUSTOM_SCENE
	_refresh_visual()


func _refresh_visual() -> void:
	_clear_custom_instance()
	if is_instance_valid(_texture_rect):
		_texture_rect.visible = false
	if is_instance_valid(_animated_sprite):
		_animated_sprite.visible = false

	match visual_mode:
		VisualMode.TEXTURE:
			_show_texture()
		VisualMode.ANIMATED_SPRITE:
			_show_animated_sprite()
		VisualMode.CUSTOM_SCENE:
			_show_custom_scene()


func _show_texture() -> void:
	if not is_instance_valid(_texture_rect) or texture == null:
		return
	_texture_rect.texture = texture
	_texture_rect.visible = true


func _show_animated_sprite() -> void:
	if not is_instance_valid(_animated_sprite) or sprite_frames == null:
		_show_texture()
		return
	_animated_sprite.sprite_frames = sprite_frames
	_animated_sprite.visible = true
	if _animated_sprite.sprite_frames.has_animation("default"):
		_animated_sprite.play("default")
	elif _animated_sprite.sprite_frames.get_animation_names().size() > 0:
		_animated_sprite.play(_animated_sprite.sprite_frames.get_animation_names()[0])


func _show_custom_scene() -> void:
	if custom_visual_scene == null or not is_instance_valid(_custom_slot):
		_show_texture()
		return
	_custom_instance = custom_visual_scene.instantiate()
	_custom_slot.add_child(_custom_instance)


func _clear_custom_instance() -> void:
	if is_instance_valid(_custom_instance):
		_custom_instance.queue_free()
	_custom_instance = null
