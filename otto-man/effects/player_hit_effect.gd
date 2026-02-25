extends Node2D

@onready var sprite = $Sprite2D

# Player hit efekti için player_hit1.png kullan
var player_hit_texture = preload("res://assets/effects/player fx/player_hit1.png")

func _ready() -> void:
	# Set z-index to appear above decorations but behind player
	z_index = 10
	
	# Sprite'ı merkeze hizala (centered = true yap)
	if sprite:
		sprite.centered = true
		sprite.texture = player_hit_texture
		
		# Sprite sheet ayarları (4 frame yatay varsayıyoruz)
		# Eğer player_hit1.png tek bir sprite ise, hframes = 1 yap
		# Eğer sprite sheet ise, hframes = 4 yap
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
	# 4 frame animasyonu oynat (eğer sprite sheet ise)
	# Eğer tek sprite ise, sadece fade out yap
	var tween = create_tween()
	
	# Sprite sheet varsa frame animasyonu yap
	if sprite.hframes > 1:
		for frame in range(sprite.hframes):
			tween.tween_callback(func(): sprite.frame = frame)
			tween.tween_interval(0.05)  # Her frame 0.05 saniye
	else:
		# Tek sprite ise fade out yap
		sprite.modulate.a = 1.0
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	
	# Animasyon bitince node'u sil
	tween.tween_callback(queue_free)

func setup(position_offset: Vector2 = Vector2.ZERO, scale_multiplier: float = 1.0, target_position: Vector2 = Vector2.ZERO) -> void:
	# Eğer target_position belirtilmişse, onu kullan (öncelikli)
	if target_position != Vector2.ZERO:
		global_position = target_position
	# Yoksa pozisyon offset'i ekle (eğer belirtilmişse)
	elif position_offset != Vector2.ZERO:
		global_position += position_offset
	
	# Scale multiplier'ı rastgele değişikliklerle birleştir
	scale = Vector2(scale_multiplier, scale_multiplier)
