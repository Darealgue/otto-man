class_name RockInteractable
extends BaseInteractable

const ResourceType = preload("res://resources/resource_types.gd")
const ROCK_IDLE_TEXTURE := preload("res://ui/minigames/stone/rockmine_idle.png")
const ROCK_IDLE_HIGHLIGHT_TEXTURE := preload("res://ui/minigames/stone/rockmine_idle_highlight.png")
const ROCK_HIT_TEXTURE := preload("res://ui/minigames/stone/rockmine_hit.png")
const ROCK_BREAK_TEXTURE := preload("res://ui/minigames/stone/rockmine_break.png")
const ROCK_HIT_FRAMES := 4  # Hit animasyonu frame sayısı
const ROCK_BREAK_FRAMES := 11  # Break animasyonu frame sayısı
const ROCK_HIT_FPS := 12.0
const ROCK_BREAK_FPS := 12.0

@export_range(1, 5, 1) var tier: int = 1
@export_range(3, 7, 1) var perfect_hits_required: int = 3
@export_range(0.02, 0.2, 0.01) var tolerance: float = 0.1
@export var base_reward: int = 1  # Normal ödül: 1 taş
@export var perfect_bonus: int = 1  # Üstün başarı bonusu: +1 taş (toplam 2)

var _rock_sprite: AnimatedSprite2D = null
var _highlight_sprite: Sprite2D = null

func _ready() -> void:
	minigame_kind = "forest_stone"
	require_interact_press = true
	_ensure_minimum_nodes()
	super._ready()
	_setup_idle_rock_visual()

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["tier"] = tier
	ctx["required_hits"] = perfect_hits_required
	ctx["tolerance"] = tolerance
	ctx["resource_type"] = ResourceType.STONE
	ctx["resource_base"] = base_reward
	ctx["perfect_bonus"] = perfect_bonus
	ctx["rock_path"] = get_path()
	ctx["max_misses"] = int(max(2, ceil(float(perfect_hits_required) * 0.6)))
	return ctx

func _on_minigame_started() -> void:
	# Minigame başladığında highlight'ı gizle
	if _highlight_sprite:
		_highlight_sprite.visible = false

func _on_minigame_success(payload: Dictionary) -> void:
	_apply_cracked_visual(payload.get("progress", 1.0))

func _on_minigame_failure(_payload: Dictionary) -> void:
	_apply_cracked_visual(0.0)

func _apply_cracked_visual(progress: float) -> void:
	if has_node("Sprite2D"):
		var sprite := $Sprite2D
		var intensity := clampf(progress, 0.0, 1.0)
		sprite.modulate = Color(1.0, 1.0 - 0.4 * intensity, 1.0 - 0.4 * intensity, 1.0)

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 96)
		cs.shape = rect
		cs.position = Vector2(0, -48)
		add_child(cs)
	if not has_node("RockIdleSprite"):
		var anim_sprite := AnimatedSprite2D.new()
		anim_sprite.name = "RockIdleSprite"
		anim_sprite.centered = false
		add_child(anim_sprite)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)

func _setup_idle_rock_visual() -> void:
	if _rock_sprite == null or not is_instance_valid(_rock_sprite):
		_rock_sprite = get_node_or_null("RockIdleSprite") as AnimatedSprite2D
	if _rock_sprite == null:
		return
	var frames := _build_rock_frames()
	_rock_sprite.sprite_frames = frames
	var sizes := frames.get_meta("rock_animation_sizes", {}) as Dictionary
	var max_height: float = 0.0
	var max_width: float = 0.0
	for anim_name in sizes:
		var size: Vector2 = sizes[anim_name]
		max_height = max(max_height, size.y)
		max_width = max(max_width, size.x)
	if max_height == 0.0:
		max_height = ROCK_IDLE_TEXTURE.get_size().y if ROCK_IDLE_TEXTURE else 200.0
	if max_width == 0.0:
		max_width = ROCK_IDLE_TEXTURE.get_size().x if ROCK_IDLE_TEXTURE else 200.0
	_rock_sprite.centered = false
	_rock_sprite.offset = Vector2.ZERO
	var base_x := 0.0
	if has_node("CollisionShape2D"):
		base_x = $CollisionShape2D.position.x
	_rock_sprite.position = Vector2(base_x - max_width * 0.5, -max_height)
	_rock_sprite.play("idle")
	_rock_sprite.visible = true
	# Animation finished signal'ını bağla
	if not _rock_sprite.animation_finished.is_connected(_on_rock_animation_finished):
		_rock_sprite.animation_finished.connect(_on_rock_animation_finished)
	
	# Highlight sprite'ı oluştur ve ayarla
	_setup_highlight_sprite(max_width, max_height, base_x)

func _build_rock_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var sizes: Dictionary = {}
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	if ROCK_IDLE_TEXTURE:
		frames.add_frame("idle", ROCK_IDLE_TEXTURE)
		sizes["idle"] = ROCK_IDLE_TEXTURE.get_size()
	var hit_size := _add_sheet_animation(frames, "hit", ROCK_HIT_TEXTURE, ROCK_HIT_FRAMES, ROCK_HIT_FPS)
	if hit_size != Vector2.ZERO:
		sizes["hit"] = hit_size
	var break_size := _add_sheet_animation(frames, "break", ROCK_BREAK_TEXTURE, ROCK_BREAK_FRAMES, ROCK_BREAK_FPS)
	if break_size != Vector2.ZERO:
		sizes["break"] = break_size
	frames.set_meta("rock_animation_sizes", sizes)
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

func play_hit_animation() -> void:
	if _rock_sprite == null or not is_instance_valid(_rock_sprite):
		_rock_sprite = get_node_or_null("RockIdleSprite") as AnimatedSprite2D
	if _rock_sprite == null or not _rock_sprite.sprite_frames:
		return
	if not _rock_sprite.sprite_frames.has_animation("hit"):
		return
	if _rock_sprite.animation == "break":
		return
	_align_sprite_to_bottom("hit")
	_rock_sprite.play("hit")

func play_break_animation() -> void:
	if _rock_sprite == null or not is_instance_valid(_rock_sprite):
		_rock_sprite = get_node_or_null("RockIdleSprite") as AnimatedSprite2D
	if _rock_sprite == null or not _rock_sprite.sprite_frames:
		return
	if not _rock_sprite.sprite_frames.has_animation("break"):
		return
	_align_sprite_to_bottom("break")
	_rock_sprite.play("break")

func _align_sprite_to_bottom(animation: String) -> void:
	if _rock_sprite == null or not _rock_sprite.sprite_frames:
		return
	var frames := _rock_sprite.sprite_frames
	if not frames.has_animation(animation):
		return
	var sizes := frames.get_meta("rock_animation_sizes", {}) as Dictionary
	var max_height: float = 0.0
	var max_width: float = 0.0
	for anim_name in sizes:
		var size: Vector2 = sizes[anim_name]
		max_height = max(max_height, size.y)
		max_width = max(max_width, size.x)
	if max_height == 0.0 or max_width == 0.0:
		return
	var base_x := 0.0
	if has_node("CollisionShape2D"):
		var shape := $CollisionShape2D as CollisionShape2D
		if shape:
			base_x = shape.position.x
	var base_y := -max_height
	_rock_sprite.position = Vector2(base_x - max_width * 0.5, base_y)

func _on_rock_animation_finished() -> void:
	# Hit animasyonu bittiğinde idle'e geri dön
	if _rock_sprite and _rock_sprite.animation == "hit":
		_align_sprite_to_bottom("idle")
		_rock_sprite.play("idle")

func _setup_highlight_sprite(width: float, height: float, base_x: float) -> void:
	if _highlight_sprite == null or not is_instance_valid(_highlight_sprite):
		_highlight_sprite = get_node_or_null("RockHighlightSprite") as Sprite2D
	if _highlight_sprite == null:
		# Highlight sprite yoksa oluştur
		_highlight_sprite = Sprite2D.new()
		_highlight_sprite.name = "RockHighlightSprite"
		add_child(_highlight_sprite)
	
	if ROCK_IDLE_HIGHLIGHT_TEXTURE:
		_highlight_sprite.texture = ROCK_IDLE_HIGHLIGHT_TEXTURE
		_highlight_sprite.centered = false
		_highlight_sprite.position = Vector2(base_x - width * 0.5, -height)
		_highlight_sprite.visible = false  # Başlangıçta gizli
		if _rock_sprite:
			_highlight_sprite.z_index = _rock_sprite.z_index + 1  # Rock sprite'ın üstünde

func _on_player_enter(_player: Node) -> void:
	# Oyuncu yakındayken highlight'ı göster
	if _highlight_sprite:
		_highlight_sprite.visible = true

func _on_player_exit(_player: Node) -> void:
	# Oyuncu uzaklaştığında highlight'ı gizle
	if _highlight_sprite:
		_highlight_sprite.visible = false

