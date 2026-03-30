extends Area2D

signal door_selected(door: Node)

@export var label_text: String = ""
## True ise sadece dekoratif giriş kapısı: açık frame, etkileşim yok
@export var entrance_only: bool = false

const PLAYER_GROUP: StringName = &"player"

var _player_in_range: bool = false
var _hold_timer: float = 0.0
var _opening: bool = false

@export var hold_time_required: float = 0.4

@onready var _label: RichTextLabel = $Label
@onready var _sprite: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	if _label:
		_label.text = label_text
	if _sprite:
		if entrance_only:
			# Giriş kapısı: animasyon bitmiş açık halde, etkileşim yok
			_sprite.play(&"open")
			_sprite.pause()
			_sprite.frame = _sprite.sprite_frames.get_frame_count(&"open") - 1
			_sprite.frame_progress = 1.0
			if _label:
				_label.visible = false
			set_process(false)
		else:
			_sprite.play(&"open")
			_sprite.pause()
			_sprite.frame = 0
			_sprite.frame_progress = 0.0
			_sprite.animation_finished.connect(_on_animation_finished)

func set_label_text(text: String) -> void:
	label_text = text
	if _label:
		_label.text = label_text

func _process(_delta: float) -> void:
	if entrance_only:
		return
	if not _player_in_range or _opening:
		_hold_timer = 0.0
		return
	# Oyuncu yukarı / portal tuşuna BASILI tutuyor mu?
	if InputManager.is_portal_enter_pressed():
		_hold_timer += _delta
		if _hold_timer >= hold_time_required:
			_start_open()
	else:
		_hold_timer = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_player_in_range = false
		_hold_timer = 0.0

func _start_open() -> void:
	_opening = true
	_hold_timer = 0.0
	if _sprite:
		_sprite.play(&"open")

func _on_animation_finished() -> void:
	if not _opening:
		return
	_opening = false
	door_selected.emit(self)

