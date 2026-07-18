extends Node2D

class_name HouseFloorVisual

const NUM_WINDOW_STATES: int = 3  # 0=kapalı, 1=yarı kapalı, 2=açık

@export var window_closed_texture: Texture2D
@export var window_half_closed_texture: Texture2D
@export var window_open_texture: Texture2D

# Çeşitlilik için: doluysa rastgele bu varyantlardan biri seçilir (boşsa mevcut texture korunur).
@export var body_texture_variants: Array[Texture2D] = []
@export var gate_texture_variants: Array[Texture2D] = []
@export var allow_horizontal_flip: bool = true

# Gece dolu pencerelere uygulanacak sıcak ışık tonu (modulate).
@export var night_lit_modulate: Color = Color(1.35, 1.12, 0.75, 1.0)
@export var day_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var _window_sprites: Array[Sprite2D] = []
var _last_window_states: Array = []
var _last_is_night: bool = false

func _ready() -> void:
	_collect_window_sprites()
	_apply_random_variants()
	apply_window_states([], false)

func _collect_window_sprites() -> void:
	_window_sprites.clear()
	for child in get_children():
		if child is Sprite2D and String(child.name).begins_with("WindowSlot"):
			_window_sprites.append(child)
	_window_sprites.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool:
		return String(a.name) < String(b.name))

# Zemin/kapı görselinde rastgele çeşitlilik (varyant + flip).
# NOT: Pencereler flip edilmez — pencere state'leri (kapalı/yarı/açık) sabit bir
# köşeden (menteşe) büyüyen, centered=false yerleşimli sprite'lardır; WindowSlot'un
# flip_h değeri hangi kenardan (sol/sağ) büyüdüğünü belirler ve rastgele değiştirilirse
# pencere olması gereken yerden tamamen kayar.
func _apply_random_variants() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body != null:
		if body_texture_variants.size() > 0:
			body.texture = body_texture_variants[randi() % body_texture_variants.size()]
		if allow_horizontal_flip:
			body.flip_h = randf() < 0.5
	var gate := get_node_or_null("Gate") as Sprite2D
	if gate != null:
		if gate_texture_variants.size() > 0:
			gate.texture = gate_texture_variants[randi() % gate_texture_variants.size()]
		if allow_horizontal_flip:
			gate.flip_h = randf() < 0.5

# window_states: her pencere yuvası için 0 (kapalı) / 1 (yarı kapalı) / 2 (açık) değerleri.
func apply_window_states(window_states: Array, is_night: bool = false) -> void:
	if _window_sprites.is_empty():
		_collect_window_sprites()
	_last_window_states = window_states.duplicate()
	_last_is_night = is_night
	for i in _window_sprites.size():
		var state: int = clamp(int(window_states[i]) if i < window_states.size() else 0, 0, NUM_WINDOW_STATES - 1)
		var sprite: Sprite2D = _window_sprites[i]
		var tex: Texture2D
		match state:
			1:
				tex = window_half_closed_texture
			2:
				tex = window_open_texture
			_:
				tex = window_closed_texture
		if tex != null:
			sprite.texture = tex
			# Pencere durumları (kapalı/yarı/açık) farklı genişlikte ve sabit bir
			# menteşe kenarından büyüyor. flip_h=false ise menteşe sol kenarda ve
			# sprite.position'dan sağa doğru büyür (offset.x=0 yeterli).
			# flip_h=true ise menteşe sağ kenarda; flip_h çizim alanını KAYDIRMAZ,
			# sadece içeriği aynalar, bu yüzden sprite'ın sağ kenarı sabit kalsın diye
			# offset.x'i -genişlik yapıp sola doğru büyümesini sağlıyoruz.
			sprite.offset.x = -tex.get_width() if sprite.flip_h else 0
		# Modulate: gece + dolu pencere (yarı veya tam açık) ise sıcak loş ışık, aksi halde normal.
		sprite.modulate = night_lit_modulate if (state > 0 and is_night) else day_modulate

# Sadece gece bayrağını güncellemek için kısa yol (pencere durumu değişmeden saat değişince).
func set_night_mode(is_night: bool) -> void:
	apply_window_states(_last_window_states, is_night)

func get_window_count() -> int:
	return _window_sprites.size()
