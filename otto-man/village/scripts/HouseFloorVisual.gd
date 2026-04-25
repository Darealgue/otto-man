extends Node2D

class_name HouseFloorVisual

@export var window_closed_texture: Texture2D
@export var window_open_texture: Texture2D

# Gece dolu pencerelere uygulanacak sıcak ışık tonu (modulate).
@export var night_lit_modulate: Color = Color(1.35, 1.12, 0.75, 1.0)
@export var day_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var _window_sprites: Array[Sprite2D] = []
var _last_open_flags: Array = []
var _last_is_night: bool = false

func _ready() -> void:
	_collect_window_sprites()
	apply_window_states([], false)

func _collect_window_sprites() -> void:
	_window_sprites.clear()
	for child in get_children():
		if child is Sprite2D and String(child.name).begins_with("WindowSlot"):
			_window_sprites.append(child)
	_window_sprites.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool:
		return String(a.name) < String(b.name))

func apply_window_states(open_flags: Array, is_night: bool = false) -> void:
	if _window_sprites.is_empty():
		_collect_window_sprites()
	_last_open_flags = open_flags.duplicate()
	_last_is_night = is_night
	for i in _window_sprites.size():
		var is_open: bool = i < open_flags.size() and bool(open_flags[i])
		var sprite: Sprite2D = _window_sprites[i]
		var tex: Texture2D = window_open_texture if is_open else window_closed_texture
		if tex != null:
			sprite.texture = tex
		# Modulate: gece + dolu pencere ise sıcak loş ışık, aksi halde normal.
		sprite.modulate = night_lit_modulate if (is_open and is_night) else day_modulate

# Sadece gece bayrağını güncellemek için kısa yol (pencere açık/kapalı durumu değişmeden saat değişince).
func set_night_mode(is_night: bool) -> void:
	if is_night == _last_is_night and not _window_sprites.is_empty():
		# Yine de modulate'i emniyete al
		pass
	apply_window_states(_last_open_flags, is_night)

func get_window_count() -> int:
	return _window_sprites.size()
