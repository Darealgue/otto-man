extends Node2D

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer

var hit_effect_textures = [
	preload("res://assets/effects/player fx/hit1.png"),
	preload("res://assets/effects/player fx/hit2.png"),
	preload("res://assets/effects/player fx/hit3.png")
]

func _ready() -> void:
	# Set z-index to appear above decorations but behind player
	z_index = 10
	
	# Sprite'ı merkeze hizala (centered = true yap)
	if sprite:
		sprite.centered = true
	
	# Rastgele bir hit efekt seç
	var random_effect = hit_effect_textures[randi() % hit_effect_textures.size()]
	sprite.texture = random_effect
	
	# Sprite sheet ayarları (4 frame yatay)
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.frame = 0
	
	# Rastgele yön ve ölçek değişiklikleri
	_apply_random_variations()
	
	# Animasyonu başlat
	_play_hit_animation()

func _apply_random_variations() -> void:
	# Rastgele rotasyon (-45° ile +45° arası)
	var random_rotation = randf_range(-45.0, 45.0)
	rotation_degrees = random_rotation
	
	# Rastgele X ekseni flip (bazen ters çevir)
	if randf() < 0.5:
		sprite.flip_h = true
	
	# Rastgele Y ekseni flip (bazen ters çevir)
	if randf() < 0.3:
		sprite.flip_v = true
	
	# Rastgele hafif ölçek değişikliği (0.8x ile 1.2x arası)
	var random_scale = randf_range(0.8, 1.2)
	scale *= random_scale

func _play_hit_animation() -> void:
	# 4 frame animasyonu oynat
	var tween = create_tween()
	
	# Her frame için kısa bir süre beklet
	for frame in range(4):
		tween.tween_callback(func(): sprite.frame = frame)
		tween.tween_interval(0.05)  # Her frame 0.05 saniye
	
	# Animasyon bitince node'u sil
	tween.tween_callback(queue_free)

func setup(position_offset: Vector2 = Vector2.ZERO, scale_multiplier: float = 1.0, effect_type: int = -1, target_position: Vector2 = Vector2.ZERO) -> void:
	# Eğer target_position belirtilmişse, onu kullan (öncelikli)
	if target_position != Vector2.ZERO:
		global_position = target_position
	# Yoksa pozisyon offset'i ekle (eğer belirtilmişse)
	elif position_offset != Vector2.ZERO:
		global_position += position_offset
	
	# Belirli bir efekt türü seçilmişse onu kullan
	if effect_type >= 0 and effect_type < hit_effect_textures.size():
		sprite.texture = hit_effect_textures[effect_type]
		sprite.hframes = 4
		sprite.vframes = 1
		sprite.frame = 0
	
	# Scale multiplier'ı rastgele değişikliklerle birleştir
	scale = Vector2(scale_multiplier, scale_multiplier)

func _adjust_position_to_center(target_position: Vector2) -> void:
	# Sprite artık centered = true olduğu için, direkt pozisyonu kullan
	global_position = target_position
