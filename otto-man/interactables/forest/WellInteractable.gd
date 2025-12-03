class_name WellInteractable
extends BaseInteractable

const ResourceType = preload("res://resources/resource_types.gd")

# Sprite yolları
const WELL_IDLE_PATH := "res://ui/minigames/water/well_idle.png"
const WELL_IDLE_HIGHLIGHT_PATH := "res://ui/minigames/water/well_idle_highlight.png"
const WELL_HIT_PATH := "res://ui/minigames/water/well_hit.png"
const WELL_SUCCESS_PATH := "res://ui/minigames/water/well_success.png"
const WELL_FAIL_PATH := "res://ui/minigames/water/well_fail.png"
const WELL_HIT_FRAMES := 8
const WELL_SUCCESS_FRAMES := 28
const WELL_FAIL_FRAMES := 17
const WELL_HIT_FPS := 12.0
const WELL_SUCCESS_FPS := 12.0
const WELL_FAIL_FPS := 12.0

# Texture'ları yükle (conditional)
var WELL_IDLE_TEXTURE: Texture2D = null
var WELL_IDLE_HIGHLIGHT_TEXTURE: Texture2D = null
var WELL_HIT_TEXTURE: Texture2D = null
var WELL_SUCCESS_TEXTURE: Texture2D = null
var WELL_FAIL_TEXTURE: Texture2D = null

@export_range(1, 5, 1) var depth_level: int = 1
@export_range(4, 8, 1) var pulls_required: int = 5
@export_range(0.05, 0.3, 0.01) var sweet_spot_width: float = 0.12
@export var base_reward: int = 5
@export var perfect_bonus: int = 1
@export var placeholder_mode: bool = false

var _well_sprite: AnimatedSprite2D = null
var _highlight_sprite: Sprite2D = null

func _ready() -> void:
	minigame_kind = "forest_water"
	require_interact_press = true
	# Kuyu bir kere oynandıktan sonra bir daha oynanamaz (başarılı olsun ya da olmasın)
	auto_disable_on_success = true
	auto_disable_on_failure = true
	
	# Sprite'ları yükle
	_load_well_textures()
	
	_ensure_minimum_nodes()
	super._ready()
	_setup_idle_well_visual()
	# Placeholder görsel kaldırıldı

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["depth"] = depth_level
	ctx["hits_required"] = 3  # Artarda 3 vuruş gerekiyor
	ctx["sweet_spot"] = sweet_spot_width
	ctx["resource_type"] = ResourceType.WATER
	ctx["resource_base"] = base_reward
	ctx["perfect_bonus"] = perfect_bonus
	ctx["well_path"] = get_path()  # Well node path'i
	ctx["difficulty"] = depth_level  # Depth level = difficulty
	return ctx

func _load_well_textures() -> void:
	# Sprite'ları conditional olarak yükle
	if ResourceLoader.exists(WELL_IDLE_PATH):
		WELL_IDLE_TEXTURE = load(WELL_IDLE_PATH)
		print("[WellInteractable] Loaded well_idle texture: ", WELL_IDLE_TEXTURE != null)
	else:
		print("[WellInteractable] well_idle texture not found at: ", WELL_IDLE_PATH)
	if ResourceLoader.exists(WELL_IDLE_HIGHLIGHT_PATH):
		WELL_IDLE_HIGHLIGHT_TEXTURE = load(WELL_IDLE_HIGHLIGHT_PATH)
		print("[WellInteractable] Loaded well_idle_highlight texture: ", WELL_IDLE_HIGHLIGHT_TEXTURE != null)
	if ResourceLoader.exists(WELL_HIT_PATH):
		WELL_HIT_TEXTURE = load(WELL_HIT_PATH)
		print("[WellInteractable] Loaded well_hit texture: ", WELL_HIT_TEXTURE != null)
	if ResourceLoader.exists(WELL_SUCCESS_PATH):
		WELL_SUCCESS_TEXTURE = load(WELL_SUCCESS_PATH)
		print("[WellInteractable] Loaded well_success texture: ", WELL_SUCCESS_TEXTURE != null)
	if ResourceLoader.exists(WELL_FAIL_PATH):
		WELL_FAIL_TEXTURE = load(WELL_FAIL_PATH)
		print("[WellInteractable] Loaded well_fail texture: ", WELL_FAIL_TEXTURE != null)

func _on_player_enter(_player: Node) -> void:
	# Player yaklaştığında highlight'ı göster
	if _highlight_sprite:
		_highlight_sprite.visible = true

func _on_player_exit(_player: Node) -> void:
	# Player uzaklaştığında highlight'ı gizle
	if _highlight_sprite:
		_highlight_sprite.visible = false

func _on_minigame_started() -> void:
	# Minigame başladığında highlight'ı gizle
	if _highlight_sprite:
		_highlight_sprite.visible = false
	# Minigame başladığında hemen devre dışı bırak (bir daha oynanamaz)
	set_interactable_enabled(false)
	# Hit animasyonu sadece vuruş yapıldığında oynanmalı, burada değil

func _on_minigame_success(_payload: Dictionary) -> void:
	# Success animasyonunu oynat
	_play_success_animation()
	# Kuyu zaten _on_minigame_started'da devre dışı bırakıldı

func _on_minigame_failure(_payload: Dictionary) -> void:
	# Fail animasyonunu oynat
	_play_fail_animation()
	# Kuyu zaten _on_minigame_started'da devre dışı bırakıldı

func set_placeholder_mode(enabled: bool) -> void:
	placeholder_mode = enabled
	# Placeholder görsel kaldırıldı - artık sprite'lar kullanılıyor
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

func _ensure_minimum_nodes() -> void:
	if not has_node("CollisionShape2D"):
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(80, 80)
		cs.shape = rect
		cs.position = Vector2(0, -40)
		add_child(cs)
	if not has_node("WellIdleSprite"):
		var anim_sprite := AnimatedSprite2D.new()
		anim_sprite.name = "WellIdleSprite"
		anim_sprite.centered = false
		add_child(anim_sprite)
	if not has_node("WellHighlightSprite"):
		var highlight := Sprite2D.new()
		highlight.name = "WellHighlightSprite"
		highlight.centered = false
		highlight.visible = false
		add_child(highlight)
	if not has_node("Sprite2D"):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = false
		add_child(sprite)

func _setup_idle_well_visual() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		_well_sprite = get_node_or_null("WellIdleSprite") as AnimatedSprite2D
	if _well_sprite == null:
		print("[WellInteractable] ERROR: WellIdleSprite node not found!")
		return
	
	# Idle sprite'ı ayarla
	if WELL_IDLE_TEXTURE != null and is_instance_valid(WELL_IDLE_TEXTURE):
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 1.0)
		
		# Sprite sheet'ten frame'leri ayır
		var idle_size := WELL_IDLE_TEXTURE.get_size()
		var frame_width := idle_size.x  # 1 frame olduğu için tam genişlik
		var frame_height := idle_size.y
		
		# Sprite sheet'i frame'lere böl
		var atlas := AtlasTexture.new()
		atlas.atlas = WELL_IDLE_TEXTURE
		atlas.region = Rect2(0, 0, frame_width, frame_height)
		frames.add_frame("idle", atlas)
		
		_well_sprite.sprite_frames = frames
		_well_sprite.play("idle")
		
		# Pozisyonu ayarla
		var base_x := 0.0
		if has_node("CollisionShape2D"):
			base_x = $CollisionShape2D.position.x
		var sprite_pos := Vector2(base_x - frame_width * 0.5, -frame_height)
		_well_sprite.position = sprite_pos
		_well_sprite.centered = false
		_well_sprite.offset = Vector2.ZERO
		_well_sprite.visible = true
		print("[WellInteractable] Well idle sprite positioned at: ", sprite_pos, " size: ", idle_size)
	else:
		# Placeholder görsel
		print("[WellInteractable] Using placeholder - texture not loaded")
		_well_sprite.visible = false
	
	# Highlight sprite'ı ayarla
	_setup_highlight_sprite()

func _setup_highlight_sprite() -> void:
	if _highlight_sprite == null or not is_instance_valid(_highlight_sprite):
		_highlight_sprite = get_node_or_null("WellHighlightSprite") as Sprite2D
	if _highlight_sprite == null:
		return
	
	if WELL_IDLE_HIGHLIGHT_TEXTURE != null:
		_highlight_sprite.texture = WELL_IDLE_HIGHLIGHT_TEXTURE
		_highlight_sprite.centered = false
		
		# Well sprite ile aynı pozisyonda
		if _well_sprite:
			_highlight_sprite.position = _well_sprite.position
			_highlight_sprite.z_index = _well_sprite.z_index + 1
		
		_highlight_sprite.visible = false  # Başlangıçta gizli

func play_hit_animation() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		_well_sprite = get_node_or_null("WellIdleSprite") as AnimatedSprite2D
	if _well_sprite == null or WELL_HIT_TEXTURE == null:
		return
	
	var frames := SpriteFrames.new()
	frames.add_animation("hit")
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", WELL_HIT_FPS)
	
	# Sprite sheet'ten frame'leri ayır
	var hit_size := WELL_HIT_TEXTURE.get_size()
	var frame_width := hit_size.x / float(WELL_HIT_FRAMES)
	var frame_height := hit_size.y
	
	for i in range(WELL_HIT_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = WELL_HIT_TEXTURE
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("hit", atlas)
	
	_well_sprite.sprite_frames = frames
	_well_sprite.play("hit")
	
	# Animasyon bitince idle'e dön
	if not _well_sprite.animation_finished.is_connected(_on_well_animation_finished):
		_well_sprite.animation_finished.connect(_on_well_animation_finished)

func _play_success_animation() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		_well_sprite = get_node_or_null("WellIdleSprite") as AnimatedSprite2D
	if _well_sprite == null or WELL_SUCCESS_TEXTURE == null:
		return
	
	var frames := SpriteFrames.new()
	frames.add_animation("success")
	frames.set_animation_loop("success", false)  # Loop yok, bir kez oynat
	frames.set_animation_speed("success", WELL_SUCCESS_FPS)
	
	# Sprite sheet'ten frame'leri ayır
	var success_size := WELL_SUCCESS_TEXTURE.get_size()
	var frame_width := success_size.x / float(WELL_SUCCESS_FRAMES)
	var frame_height := success_size.y
	
	for i in range(WELL_SUCCESS_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = WELL_SUCCESS_TEXTURE
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("success", atlas)
	
	_well_sprite.sprite_frames = frames
	_well_sprite.play("success")
	
	# Animasyon bitince son frame'de kal
	if not _well_sprite.animation_finished.is_connected(_on_success_animation_finished):
		_well_sprite.animation_finished.connect(_on_success_animation_finished)

func _on_success_animation_finished() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		return
	# Success animasyonu bittiğinde son frame'de kal
	if _well_sprite.animation == "success":
		# Son frame'i göster (animasyonu durdur ama son frame'de kal)
		_well_sprite.stop()
		# Son frame'e git
		if _well_sprite.sprite_frames and _well_sprite.sprite_frames.has_animation("success"):
			var frame_count := _well_sprite.sprite_frames.get_frame_count("success")
			if frame_count > 0:
				_well_sprite.frame = frame_count - 1

func _play_fail_animation() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		_well_sprite = get_node_or_null("WellIdleSprite") as AnimatedSprite2D
	if _well_sprite == null or WELL_FAIL_TEXTURE == null:
		return
	
	var frames := SpriteFrames.new()
	frames.add_animation("fail")
	frames.set_animation_loop("fail", false)  # Loop yok, bir kez oynat
	frames.set_animation_speed("fail", WELL_FAIL_FPS)
	
	# Sprite sheet'ten frame'leri ayır
	var fail_size := WELL_FAIL_TEXTURE.get_size()
	var frame_width := fail_size.x / float(WELL_FAIL_FRAMES)
	var frame_height := fail_size.y
	
	for i in range(WELL_FAIL_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = WELL_FAIL_TEXTURE
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("fail", atlas)
	
	_well_sprite.sprite_frames = frames
	_well_sprite.play("fail")
	
	# Animasyon bitince son frame'de kal
	if not _well_sprite.animation_finished.is_connected(_on_fail_animation_finished):
		_well_sprite.animation_finished.connect(_on_fail_animation_finished)

func _on_fail_animation_finished() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		return
	# Fail animasyonu bittiğinde son frame'de kal
	if _well_sprite.animation == "fail":
		# Son frame'i göster (animasyonu durdur ama son frame'de kal)
		_well_sprite.stop()
		# Son frame'e git
		if _well_sprite.sprite_frames and _well_sprite.sprite_frames.has_animation("fail"):
			var frame_count := _well_sprite.sprite_frames.get_frame_count("fail")
			if frame_count > 0:
				_well_sprite.frame = frame_count - 1

func _on_well_animation_finished() -> void:
	if _well_sprite == null or not is_instance_valid(_well_sprite):
		return
	# Hit animasyonu bitince idle'e dön (eğer minigame hala devam ediyorsa)
	if _well_sprite.animation == "hit":
		_setup_idle_well_visual()

