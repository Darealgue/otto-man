class_name BushInteractable
extends BaseInteractable

const ResourceType = preload("res://resources/resource_types.gd")
# Sprite yolları
const BUSH_IDLE_PATH := "res://ui/minigames/food/berry_bush_idle.png"
const BUSH_IDLE_HIGHLIGHT_PATH := "res://ui/minigames/food/berry_bush_idle_highlight.png"
const BUSH_HIT_PATH := "res://ui/minigames/food/berry_bush_hit.png"
const BUSH_END_PATH := "res://ui/minigames/food/berry_bush_end.png"
const BUSH_HIT_FRAMES := 6  # Hit animasyonu frame sayısı
const BUSH_HIT_FPS := 12.0

# Texture'ları yükle (conditional)
var BUSH_IDLE_TEXTURE: Texture2D = null
var BUSH_IDLE_HIGHLIGHT_TEXTURE: Texture2D = null
var BUSH_HIT_TEXTURE: Texture2D = null
var BUSH_END_TEXTURE: Texture2D = null

@export_range(1, 5, 1) var tier: int = 1
@export_range(3, 5, 1) var fruits_to_spawn: int = 3
@export var base_reward: int = 1  # Her meyve için 1 yiyecek
@export var perfect_bonus: int = 0  # Bonus yok

var _bush_sprite: AnimatedSprite2D = null
var _highlight_sprite: Sprite2D = null

func _ready() -> void:
	print("[BushInteractable] _ready() called for: ", name, " at ", global_position)
	minigame_kind = "forest_food"
	require_interact_press = true
	# Çalı bir kere oynandıktan sonra bir daha oynanamaz (başarılı olsun ya da olmasın)
	auto_disable_on_success = true
	auto_disable_on_failure = true
	
	# Sprite'ları yükle
	_load_bush_textures()
	
	_ensure_minimum_nodes()
	super._ready()
	_setup_idle_bush_visual()
	print("[BushInteractable] _ready() completed. disabled=", _disabled, " monitoring=", monitoring, " monitorable=", monitorable)

func _load_bush_textures() -> void:
	# Sprite'ları conditional olarak yükle
	if ResourceLoader.exists(BUSH_IDLE_PATH):
		BUSH_IDLE_TEXTURE = load(BUSH_IDLE_PATH)
		print("[BushInteractable] Loaded bush_idle texture: ", BUSH_IDLE_TEXTURE != null)
	else:
		print("[BushInteractable] bush_idle texture not found at: ", BUSH_IDLE_PATH)
	if ResourceLoader.exists(BUSH_IDLE_HIGHLIGHT_PATH):
		BUSH_IDLE_HIGHLIGHT_TEXTURE = load(BUSH_IDLE_HIGHLIGHT_PATH)
		print("[BushInteractable] Loaded bush_idle_highlight texture: ", BUSH_IDLE_HIGHLIGHT_TEXTURE != null)
	if ResourceLoader.exists(BUSH_HIT_PATH):
		BUSH_HIT_TEXTURE = load(BUSH_HIT_PATH)
		print("[BushInteractable] Loaded bush_hit texture: ", BUSH_HIT_TEXTURE != null)
	if ResourceLoader.exists(BUSH_END_PATH):
		BUSH_END_TEXTURE = load(BUSH_END_PATH)
		print("[BushInteractable] Loaded bush_end texture: ", BUSH_END_TEXTURE != null)

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["tier"] = tier
	ctx["fruits_to_spawn"] = fruits_to_spawn
	ctx["resource_type"] = ResourceType.FOOD
	ctx["resource_base"] = base_reward
	ctx["perfect_bonus"] = perfect_bonus
	ctx["bush_path"] = get_path()
	ctx["max_misses"] = 3  # 3 miss'ten sonra oyun biter
	return ctx

func _on_minigame_started() -> void:
	print("[BushInteractable] _on_minigame_started() called for: ", name)
	# Minigame başladığında highlight'ı gizle
	if _highlight_sprite:
		_highlight_sprite.visible = false

func _on_minigame_success(payload: Dictionary) -> void:
	_apply_end_visual()
	# Çalı zaten _on_minigame_started'da devre dışı bırakıldı

func _on_minigame_failure(payload: Dictionary) -> void:
	# Uzaklaşma durumunda end visual'ı uygulama, idle sprite'ına geri dön
	if payload.get("distance_cancelled", false):
		_setup_idle_bush_visual()
		return
	_apply_end_visual()

func _apply_end_visual() -> void:
	# Minigame bitince bush_end sprite'ını göster
	if _bush_sprite == null or not is_instance_valid(_bush_sprite):
		_bush_sprite = get_node_or_null("BushIdleSprite") as AnimatedSprite2D
	if _bush_sprite == null:
		return
	
	if BUSH_END_TEXTURE != null:
		# End sprite'ını göster
		var frames := SpriteFrames.new()
		frames.add_animation("end")
		frames.set_animation_loop("end", true)
		frames.add_frame("end", BUSH_END_TEXTURE)
		_bush_sprite.sprite_frames = frames
		
		# End sprite pozisyonunu ayarla (idle ile aynı pozisyonda)
		var end_size := BUSH_END_TEXTURE.get_size()
		var base_x := 0.0
		if has_node("CollisionShape2D"):
			base_x = $CollisionShape2D.position.x
		var sprite_pos := Vector2(base_x - end_size.x * 0.5, -end_size.y)
		_bush_sprite.position = sprite_pos
		_bush_sprite.centered = false
		_bush_sprite.offset = Vector2.ZERO
		
		_bush_sprite.play("end")
		_bush_sprite.visible = true
		print("[BushInteractable] End sprite positioned at: ", sprite_pos, " size: ", end_size)

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 48)  # Çalı daha küçük
		cs.shape = rect
		cs.position = Vector2(0, -24)
		add_child(cs)
	if not has_node("BushIdleSprite"):
		var anim_sprite := AnimatedSprite2D.new()
		anim_sprite.name = "BushIdleSprite"
		anim_sprite.centered = false
		add_child(anim_sprite)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)

func _setup_idle_bush_visual() -> void:
	if _bush_sprite == null or not is_instance_valid(_bush_sprite):
		_bush_sprite = get_node_or_null("BushIdleSprite") as AnimatedSprite2D
	if _bush_sprite == null:
		print("[BushInteractable] ERROR: BushIdleSprite node not found!")
		return
	
	print("[BushInteractable] Setting up bush visual - BUSH_IDLE_TEXTURE: ", BUSH_IDLE_TEXTURE != null)
	
	# Placeholder görsel oluştur (assetler hazır olana kadar)
	if BUSH_IDLE_TEXTURE != null and is_instance_valid(BUSH_IDLE_TEXTURE):
		print("[BushInteractable] Building bush frames with texture")
		var frames := _build_bush_frames()
		_bush_sprite.sprite_frames = frames
		var sizes := frames.get_meta("bush_animation_sizes", {}) as Dictionary
		var max_height: float = 48.0
		var max_width: float = 64.0
		for anim_name in sizes:
			var size: Vector2 = sizes[anim_name]
			max_height = max(max_height, size.y)
			max_width = max(max_width, size.x)
		_bush_sprite.centered = false
		_bush_sprite.offset = Vector2.ZERO
		var base_x := 0.0
		if has_node("CollisionShape2D"):
			base_x = $CollisionShape2D.position.x
		var sprite_pos := Vector2(base_x - max_width * 0.5, -max_height)
		_bush_sprite.position = sprite_pos
		_bush_sprite.play("idle")
		_bush_sprite.visible = true
		print("[BushInteractable] Bush sprite visible: ", _bush_sprite.visible, " position: ", sprite_pos, " size: ", Vector2(max_width, max_height))
		_setup_highlight_sprite(max_width, max_height, base_x)
	else:
		print("[BushInteractable] Using placeholder - texture not loaded")
		# Placeholder: Basit renkli dikdörtgen
		var placeholder := ColorRect.new()
		placeholder.name = "BushPlaceholder"
		placeholder.color = Color(0.2, 0.6, 0.2, 0.8)  # Yeşil çalı rengi
		placeholder.size = Vector2(64, 48)
		placeholder.position = Vector2(-32, -48)
		add_child(placeholder)
		_setup_highlight_sprite(64.0, 48.0, 0.0)

func _build_bush_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var sizes: Dictionary = {}
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	# Assetler hazır olana kadar default size kullan
	var idle_texture = BUSH_IDLE_TEXTURE
	if idle_texture != null:
		frames.add_frame("idle", idle_texture)
		sizes["idle"] = idle_texture.get_size()
	else:
		# Placeholder için default size
		sizes["idle"] = Vector2(64, 48)
	var hit_size := _add_sheet_animation(frames, "hit", BUSH_HIT_TEXTURE, BUSH_HIT_FRAMES, BUSH_HIT_FPS)
	if hit_size != Vector2.ZERO:
		sizes["hit"] = hit_size
	frames.set_meta("bush_animation_sizes", sizes)
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
	if _bush_sprite == null or not is_instance_valid(_bush_sprite):
		_bush_sprite = get_node_or_null("BushIdleSprite") as AnimatedSprite2D
	if _bush_sprite == null or not _bush_sprite.sprite_frames:
		return
	if not _bush_sprite.sprite_frames.has_animation("hit"):
		return
	_align_sprite_to_bottom("hit")
	_bush_sprite.play("hit")

func _align_sprite_to_bottom(animation: String) -> void:
	if _bush_sprite == null or not _bush_sprite.sprite_frames:
		return
	var frames := _bush_sprite.sprite_frames
	if not frames.has_animation(animation):
		return
	var sizes := frames.get_meta("bush_animation_sizes", {}) as Dictionary
	var max_height: float = 48.0
	var max_width: float = 64.0
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
	_bush_sprite.position = Vector2(base_x - max_width * 0.5, base_y)

func _on_bush_animation_finished() -> void:
	# Hit animasyonu bittiğinde idle'e geri dön (eğer hala aktifse)
	if _bush_sprite and _bush_sprite.animation == "hit" and not _disabled:
		_align_sprite_to_bottom("idle")
		_bush_sprite.play("idle")

func _setup_highlight_sprite(width: float, height: float, base_x: float) -> void:
	if _highlight_sprite == null or not is_instance_valid(_highlight_sprite):
		_highlight_sprite = get_node_or_null("BushHighlightSprite") as Sprite2D
	if _highlight_sprite == null:
		# Highlight sprite yoksa oluştur
		_highlight_sprite = Sprite2D.new()
		_highlight_sprite.name = "BushHighlightSprite"
		add_child(_highlight_sprite)
	
	if BUSH_IDLE_HIGHLIGHT_TEXTURE:
		_highlight_sprite.texture = BUSH_IDLE_HIGHLIGHT_TEXTURE
		_highlight_sprite.centered = false
		_highlight_sprite.position = Vector2(base_x - width * 0.5, -height)
		_highlight_sprite.visible = false  # Başlangıçta gizli
		if _bush_sprite:
			_highlight_sprite.z_index = _bush_sprite.z_index + 1  # Bush sprite'ın üstünde

func _on_player_enter(_player: Node) -> void:
	# Oyuncu yakındayken highlight'ı göster
	if _highlight_sprite:
		_highlight_sprite.visible = true

func _on_player_exit(_player: Node) -> void:
	# Oyuncu uzaklaştığında highlight'ı gizle
	if _highlight_sprite:
		_highlight_sprite.visible = false
