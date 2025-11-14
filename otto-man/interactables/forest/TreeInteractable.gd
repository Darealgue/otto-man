extends BaseInteractable
class_name TreeInteractable

const ResourceType = preload("res://resources/resource_types.gd")
const DEFAULT_SCENE_PATH := "res://interactables/forest/TreeInteractable.tscn"
const TREE_IDLE_TEXTURE := preload("res://ui/minigames/wood/woodcut_tree_idle.png")
const TREE_HIT_TEXTURE := preload("res://ui/minigames/wood/woodcut_tree.png")
const TREE_FALL_TEXTURE := preload("res://ui/minigames/wood/woodcut_tree_fall.png")
const TREE_HIT_FRAMES := 5
const TREE_FALL_FRAMES := 12
const TREE_HIT_FPS := 12.0
const TREE_FALL_FPS := 12.0

@export_range(1, 5, 1) var difficulty_level: int = 1
@export_enum("default", "syncopated", "rapid") var rhythm_pattern: String = "default"
@export var base_hits_required: int = 5
@export var base_reward: int = 1
@export var perfect_bonus: int = 0
@export var initial_tempo_bpm: float = 96.0
@export var placeholder_mode: bool = false
@export var scene_path: String = DEFAULT_SCENE_PATH
@export var gauge_offset: Vector2 = Vector2(0, -110)
@export var cancel_distance: float = 375.0

var _placeholder_sprite: ColorRect = null
var _placeholder_polygon: Polygon2D = null
var _active_player_path: NodePath = NodePath("")
var _tree_sprite: AnimatedSprite2D = null

func _ready() -> void:
	minigame_kind = "forest_woodcut"
	require_interact_press = true
	_ensure_minimum_nodes()
	super._ready()
	_setup_idle_tree_visual()
	if placeholder_mode:
		_apply_placeholder_visual()

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["difficulty"] = difficulty_level
	ctx["pattern"] = rhythm_pattern
	ctx["hits_required"] = base_hits_required
	ctx["resource_base"] = base_reward
	ctx["perfect_bonus"] = perfect_bonus
	ctx["resource_type"] = ResourceType.WOOD
	ctx["tempo"] = initial_tempo_bpm
	ctx["tree_path"] = get_path()
	ctx["anchor_offset"] = gauge_offset
	ctx["cancel_distance"] = cancel_distance
	if !_active_player_path.is_empty():
		ctx["player_path"] = _active_player_path
	ctx["max_misses"] = int(max(2, ceil(float(base_hits_required) * 0.6)))
	return ctx

func _on_player_enter(_player: Node) -> void:
	print("[TreeInteractable] Player entered area, ready for interaction (press interact key)")
	if _player and _player is Node:
		_active_player_path = (_player as Node).get_path()

func _on_minigame_started() -> void:
	print("[TreeInteractable] Minigame started!")
	if _placeholder_polygon and is_instance_valid(_placeholder_polygon):
		_placeholder_polygon.visible = false

func _on_minigame_failed_to_start() -> void:
	print("[TreeInteractable] ERROR: Failed to start minigame!")

func _on_minigame_failure(_payload: Dictionary) -> void:
	_mark_consumed_visual(false)

func _on_minigame_success(payload: Dictionary) -> void:
	_mark_consumed_visual(true)
	print("[TreeInteractable] Minigame completed successfully! Resources: ", payload.get("amount", 0))

func _mark_consumed_visual(success: bool) -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D
		if success:
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
		else:
			sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)

func set_placeholder_mode(enabled: bool) -> void:
	placeholder_mode = enabled
	if placeholder_mode:
		_apply_placeholder_visual()
	elif _placeholder_polygon:
		_placeholder_polygon.queue_free()
		_placeholder_polygon = null
		if _placeholder_sprite:
			_placeholder_sprite.queue_free()
			_placeholder_sprite = null
		_setup_idle_tree_visual()
	if has_node("Sprite2D"):
		$Sprite2D.visible = not placeholder_mode

func _apply_placeholder_visual() -> void:
	if _placeholder_polygon == null:
		_placeholder_polygon = Polygon2D.new()
		_placeholder_polygon.polygon = PackedVector2Array([
			Vector2(-32, 0),
			Vector2(32, 0),
			Vector2(32, -128),
			Vector2(-32, -128)
		])
		_placeholder_polygon.color = Color(0.6, 0.4, 0.2, 0.7)  # Kahverengi - odun rengi
		_placeholder_polygon.visible = false  # Placeholder görünmesin
		add_child(_placeholder_polygon)
	if _placeholder_sprite == null:
		_placeholder_sprite = ColorRect.new()
		_placeholder_sprite.size = Vector2.ZERO  # hidden; keep for backwards compat
		add_child(_placeholder_sprite)
	if has_node("Sprite2D"):
		$Sprite2D.visible = false
	if _tree_sprite and is_instance_valid(_tree_sprite):
		_tree_sprite.visible = true
	if has_node("CollisionShape2D"):
		var shape := $CollisionShape2D
		if shape.shape is RectangleShape2D:
			var rect := shape.shape as RectangleShape2D
			rect.size = Vector2(64, 128)
			shape.position = Vector2(0, -64)

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 128)
		cs.shape = rect
		cs.position = Vector2(0, -64)
		add_child(cs)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)
	_setup_idle_tree_visual()

func set_scene_path(path: String) -> void:
	scene_path = path
	var basename := path.get_file().get_basename().to_lower()
	if basename.find("tree") != -1:
		placeholder_mode = false
		_setup_idle_tree_visual()

func _trigger_interaction() -> void:
	if _tracked_players.size() > 0:
		var player := _tracked_players[0]
		if player and player is Node:
			_active_player_path = (player as Node).get_path()
	super._trigger_interaction()

func _setup_idle_tree_visual() -> void:
	if _tree_sprite == null or not is_instance_valid(_tree_sprite):
		_tree_sprite = get_node_or_null("TreeIdleSprite") as AnimatedSprite2D
	if _tree_sprite == null:
		return
	var frames := _build_idle_frames()
	_tree_sprite.sprite_frames = frames
	var sizes := frames.get_meta("tree_animation_sizes", {}) as Dictionary
	var max_height: float = 0.0
	var max_width: float = 0.0
	for anim_name in sizes:
		var size: Vector2 = sizes[anim_name]
		max_height = max(max_height, size.y)
		max_width = max(max_width, size.x)
	if max_height == 0.0:
		max_height = TREE_IDLE_TEXTURE.get_size().y
	if max_width == 0.0:
		max_width = TREE_IDLE_TEXTURE.get_size().x
	_tree_sprite.centered = false
	_tree_sprite.offset = Vector2.ZERO
	var base_x := 0.0
	if has_node("CollisionShape2D"):
		base_x = $CollisionShape2D.position.x
	_tree_sprite.position = Vector2(base_x - max_width * 0.5, -max_height)
	_tree_sprite.play("idle")
	_tree_sprite.visible = true

func _build_idle_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var sizes: Dictionary = {}
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", TREE_IDLE_TEXTURE)
	sizes["idle"] = TREE_IDLE_TEXTURE.get_size()
	var hit_size := _add_sheet_animation(frames, "hit", TREE_HIT_TEXTURE, TREE_HIT_FRAMES, TREE_HIT_FPS)
	if hit_size != Vector2.ZERO:
		sizes["hit"] = hit_size
	var fall_size := _add_sheet_animation(frames, "fall", TREE_FALL_TEXTURE, TREE_FALL_FRAMES, TREE_FALL_FPS)
	if fall_size != Vector2.ZERO:
		sizes["fall"] = fall_size
	frames.set_meta("tree_animation_sizes", sizes)
	return frames

func _add_sheet_animation(frames: SpriteFrames, name: String, texture: Texture2D, frame_count: int, fps: float, loop := false) -> Vector2:
	if texture == null or frame_count <= 0:
		return Vector2.ZERO
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	var size := texture.get_size()
	if size.x <= 0 or size.y <= 0:
		return Vector2.ZERO
	var frame_width := float(size.x) / float(frame_count)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_width * float(i), 0.0), Vector2(frame_width, float(size.y)))
		frames.add_frame(name, atlas)
	return Vector2(frame_width, float(size.y))
