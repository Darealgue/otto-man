class_name MentorCharacter
extends Node2D
## Mentor görseli: girişte SmokeFx (default) → ortada idle; çıkışta smoke_bomb → N. karede SmokeFx.

signal entrance_finished
signal departure_finished

## SmokeFx animasyon adı (Godot’ta genelde "default").
@export var smoke_fx_animation_name: StringName = &"default"
## Girişte body bu karede görünür (-1 = duman animasyonunun yarısı).
@export var entrance_body_reveal_frame: int = -1
## Çıkışta smoke_bomb bu karede (0’dan) duman FX başlar; 5 = 6. kare.
@export var departure_smoke_fx_at_throw_frame: int = 5

@onready var _body: AnimatedSprite2D = $Body
@onready var _smoke_fx: AnimatedSprite2D = $SmokeFx

var _playing_entrance: bool = false
var _entrance_revealed: bool = false
var _playing_departure: bool = false
var _departure_fx_started: bool = false


func _ready() -> void:
	_prepare_for_hidden_state()
	if _smoke_fx and not _smoke_fx.animation_finished.is_connected(_on_smoke_fx_animation_finished):
		_smoke_fx.animation_finished.connect(_on_smoke_fx_animation_finished)
	if _body and not _body.frame_changed.is_connected(_on_body_frame_changed):
		_body.frame_changed.connect(_on_body_frame_changed)
	if _body and not _body.animation_finished.is_connected(_on_body_animation_finished):
		_body.animation_finished.connect(_on_body_animation_finished)
	if _smoke_fx and not _smoke_fx.frame_changed.is_connected(_on_smoke_fx_frame_changed):
		_smoke_fx.frame_changed.connect(_on_smoke_fx_frame_changed)


func _prepare_for_hidden_state() -> void:
	if _body:
		_body.visible = false
	if _smoke_fx:
		_smoke_fx.visible = false


func play_idle() -> void:
	if _body and _body.sprite_frames and _body.sprite_frames.has_animation("idle"):
		_body.play("idle")


## Köy sahnesi: duman/giriş yok, doğrudan idle (yürüme/uyku vb. sonra eklenecek).
func show_village_idle() -> void:
	_playing_entrance = false
	_playing_departure = false
	_entrance_revealed = true
	_departure_fx_started = false
	if _smoke_fx:
		_smoke_fx.visible = false
		_smoke_fx.stop()
	if _body:
		_body.visible = true
	play_idle()


## Giriş: önce duman FX, ortasında mentor idle ile belirir.
func play_entrance_sequence() -> void:
	if _playing_entrance or _playing_departure:
		return
	var fx_anim := _resolve_smoke_fx_animation()
	if fx_anim.is_empty() or _smoke_fx == null:
		_reveal_body_idle()
		entrance_finished.emit()
		return
	_playing_entrance = true
	_entrance_revealed = false
	if _body:
		_body.visible = false
	_smoke_fx.visible = true
	_smoke_fx.play(fx_anim)
	await entrance_finished


## Çıkış: smoke_bomb → belirtilen karede duman FX → biter.
func play_departure_sequence() -> void:
	if _playing_entrance or _playing_departure:
		return
	if _body == null or _body.sprite_frames == null or not _body.sprite_frames.has_animation("smoke_bomb"):
		_finish_departure()
		return
	_playing_departure = true
	_departure_fx_started = false
	_body.visible = true
	_body.play("smoke_bomb")
	await departure_finished


func _resolve_smoke_fx_animation() -> StringName:
	if _smoke_fx == null or _smoke_fx.sprite_frames == null:
		return &""
	if _smoke_fx.sprite_frames.has_animation(smoke_fx_animation_name):
		return smoke_fx_animation_name
	if _smoke_fx.sprite_frames.has_animation(&"default"):
		return &"default"
	if _smoke_fx.sprite_frames.has_animation(&"smoke"):
		return &"smoke"
	var names := _smoke_fx.sprite_frames.get_animation_names()
	if not names.is_empty():
		return names[0]
	return &""


func _get_entrance_reveal_frame() -> int:
	if entrance_body_reveal_frame >= 0:
		return entrance_body_reveal_frame
	var anim := _resolve_smoke_fx_animation()
	if _smoke_fx and _smoke_fx.sprite_frames and not anim.is_empty():
		var n: int = _smoke_fx.sprite_frames.get_frame_count(anim)
		return maxi(0, n / 2)
	return 0


func _reveal_body_idle() -> void:
	_entrance_revealed = true
	if _body:
		_body.visible = true
	play_idle()


func _try_reveal_on_entrance_frame() -> void:
	if not _playing_entrance or _entrance_revealed or _smoke_fx == null:
		return
	if _smoke_fx.animation != _resolve_smoke_fx_animation():
		return
	if _smoke_fx.frame >= _get_entrance_reveal_frame():
		_reveal_body_idle()


func _on_smoke_fx_frame_changed() -> void:
	_try_reveal_on_entrance_frame()


func _on_smoke_fx_animation_finished() -> void:
	var fx_anim := _resolve_smoke_fx_animation()
	if fx_anim.is_empty():
		return
	if _playing_entrance and _smoke_fx.animation == fx_anim:
		_playing_entrance = false
		if not _entrance_revealed:
			_reveal_body_idle()
		if _smoke_fx:
			_smoke_fx.visible = false
		entrance_finished.emit()
		return
	if _playing_departure and _departure_fx_started and _smoke_fx.animation == fx_anim:
		_finish_departure()


func _on_body_frame_changed() -> void:
	if not _playing_departure or _departure_fx_started or _body == null:
		return
	if _body.animation != "smoke_bomb":
		return
	if _body.frame >= departure_smoke_fx_at_throw_frame:
		_trigger_departure_smoke_fx()


func _on_body_animation_finished() -> void:
	if not _playing_departure or _body == null:
		return
	if _body.animation != "smoke_bomb":
		return
	if not _departure_fx_started:
		_trigger_departure_smoke_fx()


func _trigger_departure_smoke_fx() -> void:
	if _departure_fx_started:
		return
	_departure_fx_started = true
	if _body:
		_body.visible = false
	var fx_anim := _resolve_smoke_fx_animation()
	if _smoke_fx == null or fx_anim.is_empty():
		_finish_departure()
		return
	_smoke_fx.visible = true
	_smoke_fx.play(fx_anim)


func _finish_departure() -> void:
	_playing_departure = false
	_departure_fx_started = false
	if _smoke_fx:
		_smoke_fx.visible = false
	if _body:
		_body.visible = false
		_body.stop()
	_prepare_for_hidden_state()
	departure_finished.emit()
