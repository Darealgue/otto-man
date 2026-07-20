extends Area2D
## Kamp çeşmesi: etkileşimle oyuncu canı doldurur.
## Görsel: fountain.png (11 kare) — ilk 3 kare akan su döngüsü olarak loop eder;
## çeşme kullanılınca kalan 8 kare (4-11) kuruma animasyonu olarak bir kez oynar
## ve son kare (11) kalıcı "kurumuş" hali olarak ekranda kalır.
const PLAYER_GROUP: StringName = &"player"

@export var heal_amount: float = 30.0
@export var heal_fraction_of_max: float = 0.0
@export var one_use_per_camp: bool = true

var _player_in_range: bool = false
var _used: bool = false

@onready var _prompt_label: Label = $PromptLabel if has_node("PromptLabel") else null
var _anim_sprite: AnimatedSprite2D = null

const FOUNTAIN_SHEET_PATH := "res://assets/objects/dungeon/fountain.png"
const FOUNTAIN_FRAME_COUNT := 11
const FOUNTAIN_IDLE_FRAME_COUNT := 3
const FOUNTAIN_IDLE_FPS := 6.0
const FOUNTAIN_DRY_FPS := 8.0

## fountain.png bulunamazsa (yüklenmediyse) eski placeholder yedekleri.
const FOUNTAIN_FALLBACK_TEXTURE_PATHS: Array[String] = [
	"res://village/buildings/sprite/well2.png",
	"res://village/buildings/sprite/well1.png",
	"res://assets/decorations/crystal_1.png",
	"res://assets/decorations/pillar_1.png",
]


func _ready() -> void:
	_setup_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt_label:
		_prompt_label.visible = false


func _setup_visual() -> void:
	var placeholder: Node = get_node_or_null("Placeholder")
	if ResourceLoader.exists(FOUNTAIN_SHEET_PATH):
		if placeholder is CanvasItem:
			(placeholder as CanvasItem).visible = false
		_setup_animated_fountain()
		return
	var hide_list: Array = []
	if placeholder:
		hide_list.append(placeholder)
	InteractableVisualHelper.attach_centered_sprite(
		self,
		FOUNTAIN_FALLBACK_TEXTURE_PATHS,
		Vector2(0.0, -40.0),
		Vector2(72.0, 80.0),
		hide_list
	)


func _setup_animated_fountain() -> void:
	var tex: Texture2D = load(FOUNTAIN_SHEET_PATH) as Texture2D
	if tex == null:
		return
	var frame_w: int = int(floor(float(tex.get_width()) / float(FOUNTAIN_FRAME_COUNT)))
	var frame_h: int = tex.get_height()
	if frame_w <= 0 or frame_h <= 0:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", FOUNTAIN_IDLE_FPS)
	frames.add_animation("drying")
	frames.set_animation_loop("drying", false)
	frames.set_animation_speed("drying", FOUNTAIN_DRY_FPS)
	for i in range(FOUNTAIN_FRAME_COUNT):
		var at := AtlasTexture.new()
		at.atlas = tex
		var w: int = frame_w if i < FOUNTAIN_FRAME_COUNT - 1 else (tex.get_width() - i * frame_w)
		at.region = Rect2(i * frame_w, 0, w, frame_h)
		at.filter_clip = true
		if i < FOUNTAIN_IDLE_FRAME_COUNT:
			frames.add_frame("idle", at)
		else:
			frames.add_frame("drying", at)
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.name = "FountainAnim"
	_anim_sprite.sprite_frames = frames
	_anim_sprite.centered = false
	_anim_sprite.position = Vector2(-frame_w * 0.5, -frame_h)
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_anim_sprite)
	move_child(_anim_sprite, 0)
	_anim_sprite.play("idle")


func _play_dry_animation() -> void:
	if _anim_sprite and _anim_sprite.sprite_frames and _anim_sprite.sprite_frames.has_animation("drying"):
		_anim_sprite.play("drying")


func _segment_allows_heal() -> bool:
	var drs := get_node_or_null("/root/DungeonRunState")
	if drs and drs.has_method("has_segment_modifier") and drs.has_segment_modifier("no_heal"):
		return false
	return true


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if one_use_per_camp and _used:
		if _prompt_label:
			_prompt_label.visible = false
		return
	if not _segment_allows_heal():
		if _prompt_label:
			_prompt_label.text = "Bu bölümde iyileşme kapalı"
			_prompt_label.visible = true
		return
	if InputManager.is_interact_just_pressed() or InputManager.is_portal_enter_just_pressed():
		_try_heal()


func _is_player(body: Node2D) -> bool:
	return body.is_in_group(PLAYER_GROUP) or (body.get_parent() and body.get_parent().is_in_group(PLAYER_GROUP))


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in_range = true
		if _prompt_label and not (one_use_per_camp and _used):
			if not _segment_allows_heal():
				_prompt_label.text = "Bu bölümde iyileşme kapalı"
			else:
				_prompt_label.text = "E veya Yukarı - Su iç (can)"
			_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in_range = false
		if _prompt_label:
			_prompt_label.visible = false


func _try_heal() -> void:
	if one_use_per_camp and _used:
		return
	if not _segment_allows_heal():
		return
	var ps = get_node_or_null("/root/PlayerStats")
	if not ps or not ps.has_method("get_current_health") or not ps.has_method("set_current_health"):
		return
	var current: float = ps.get_current_health()
	var max_h: float = ps.get_max_health() if ps.has_method("get_max_health") else 100.0
	if current >= max_h:
		return
	var add: float = heal_amount
	if heal_fraction_of_max > 0.0:
		add = max_h * heal_fraction_of_max
	var new_health: float = minf(current + add, max_h)
	ps.set_current_health(new_health, false)
	_used = true
	_play_dry_animation()
	if _prompt_label:
		_prompt_label.text = "Kullanıldı"
		_prompt_label.visible = true
	print("[CampFountain] Healed player to %.1f" % new_health)
