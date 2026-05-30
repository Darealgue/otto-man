extends Node2D

const TEXTURE_PATHS: Array[String] = [
	"res://decoration/forest/fl1.png",
	"res://decoration/forest/fl2.png",
	"res://decoration/forest/fl3.png",
]
const FRAME_COUNT := 5
const REST_FRAME := 2
const BUMP_FRAME_SEC := 0.07
const BUMP_COOLDOWN_S := 0.5

const BUMP_FRAMES: Array[int] = [0, 1, 2, 3, 4, 3, 2, 1, 0]

@onready var _sprite: Sprite2D = $Sprite
@onready var _trigger: Area2D = $TriggerArea

var _bump_cooldown_s: float = 0.0
var _bump_playing: bool = false


func _ready() -> void:
	add_to_group("background_decor")
	add_to_group("forest_flower")
	_setup_sprite()
	_align_sprite_bottom()
	_setup_trigger()
	_show_rest_frame()


func _physics_process(delta: float) -> void:
	if _bump_cooldown_s > 0.0:
		_bump_cooldown_s = maxf(0.0, _bump_cooldown_s - delta)


func _pick_texture_path() -> String:
	return TEXTURE_PATHS[randi() % TEXTURE_PATHS.size()]


func _setup_sprite() -> void:
	if _sprite == null:
		return
	var path := _pick_texture_path()
	if not ResourceLoader.exists(path):
		path = TEXTURE_PATHS[0]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.hframes = FRAME_COUNT
	_sprite.vframes = 1
	_sprite.frame = REST_FRAME
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.flip_h = randf() >= 0.5
	set_meta("flower_variant", path.get_file())


func _show_rest_frame() -> void:
	if _sprite:
		_sprite.frame = REST_FRAME


func _align_sprite_bottom() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var fw := int(floor(float(_sprite.texture.get_width()) / float(FRAME_COUNT)))
	var fh := _sprite.texture.get_height()
	_sprite.position = Vector2(-fw * 0.5, -fh)


func _setup_trigger() -> void:
	if _trigger == null:
		return
	_trigger.collision_layer = CollisionLayers.NONE
	_trigger.collision_mask = CollisionLayers.PLAYER
	_trigger.monitoring = true
	_trigger.monitorable = false
	_trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if _bump_cooldown_s > 0.0 or _bump_playing:
		return
	if not _is_player(body):
		return
	_play_bump()


func _play_bump() -> void:
	if _sprite == null:
		return
	_bump_playing = true
	_bump_cooldown_s = BUMP_COOLDOWN_S
	for frame_idx in BUMP_FRAMES:
		if not is_instance_valid(_sprite):
			break
		_sprite.frame = frame_idx
		await get_tree().create_timer(BUMP_FRAME_SEC).timeout
	if is_instance_valid(_sprite):
		_show_rest_frame()
	_bump_playing = false


func _is_player(node: Node) -> bool:
	if node == null:
		return false
	for g in node.get_groups():
		if String(g).to_lower() == "player":
			return true
	if node.get_parent() != null:
		for g2 in node.get_parent().get_groups():
			if String(g2).to_lower() == "player":
				return true
	if node is CollisionObject2D:
		if ((node as CollisionObject2D).collision_layer & CollisionLayers.PLAYER) != 0:
			return true
	return false
