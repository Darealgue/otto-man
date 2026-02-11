extends Node2D
## Tek yaprak: dünya koordinatında rüzgar yönünde hareket (kameradan bağımsız).

var leaf_sprite: AnimatedSprite2D = null

var _velocity: Vector2 = Vector2.ZERO
var _rotation_speed: float = 0.0
var _lifetime: float = 30.0  # Çok uzun süre ekranda kalsın
var _age: float = 0.0
var _pending_sprite_frames: SpriteFrames = null
var _pending_anim_name: String = ""
var _pending_scale: float = 1.0

func _ready() -> void:
	leaf_sprite = get_node_or_null("LeafSprite") as AnimatedSprite2D
	if not leaf_sprite:
		queue_free()
		return
	# Görünürlüğü garantile
	leaf_sprite.visible = true
	leaf_sprite.modulate = Color(1, 1, 1, 1)  # Tam opak, beyaz
	leaf_sprite.z_index = 50  # Sprite'ın da z_index'i - NPC ve oyuncunun üstünde
	# Z-index'i garantile
	z_index = 50
	# Görünürlüğü tekrar kontrol et
	if not leaf_sprite.visible:
		leaf_sprite.visible = true
	
	# Bekleyen animation data varsa uygula
	if _pending_sprite_frames and _pending_anim_name != "":
		leaf_sprite.sprite_frames = _pending_sprite_frames
		leaf_sprite.animation = _pending_anim_name
		leaf_sprite.scale = Vector2(_pending_scale, _pending_scale)
		# Animasyonu başlat
		if leaf_sprite.sprite_frames:
			leaf_sprite.play()
		_pending_sprite_frames = null
		_pending_anim_name = ""


var _wind_angle: float = 90.0  # Varsayılan dikey açı

func init_leaf(velocity: Vector2, rotation_speed: float = 2.0) -> void:
	_velocity = velocity
	_rotation_speed = rotation_speed * randf_range(0.8, 1.5)  # Rastgele rotasyon hızı
	# Daha doğal hareket için rastgele titreşimler ekle
	_velocity += Vector2(randf_range(-15, 15), randf_range(-10, 10))
	
	# Rüzgar açısına göre başlangıç rotasyonu ayarla
	# Güçlü rüzgarda yapraklar daha yatay olmalı
	rotation = deg_to_rad(_wind_angle) + randf_range(-0.3, 0.3)

func set_wind_angle(angle_deg: float) -> void:
	_wind_angle = angle_deg
	
	# _ready() çağrılmışsa animasyonu başlat
	if leaf_sprite:
		if leaf_sprite.sprite_frames:
			leaf_sprite.play()


func set_animation_data(sprite_frames: SpriteFrames, anim_name: String) -> void:
	if not sprite_frames or anim_name not in sprite_frames.get_animation_names():
		return
	
	if leaf_sprite:
		# _ready() çağrılmış, direkt ayarla
		leaf_sprite.sprite_frames = sprite_frames
		leaf_sprite.animation = anim_name
	else:
		# _ready() henüz çağrılmamış, bekle
		_pending_sprite_frames = sprite_frames
		_pending_anim_name = anim_name


func set_scale_size(scale_factor: float) -> void:
	_pending_scale = scale_factor
	if leaf_sprite:
		leaf_sprite.scale = Vector2(scale_factor, scale_factor)


func _process(delta: float) -> void:
	# Pause'da durdur
	if is_instance_valid(GameState) and GameState.is_paused:
		return
	
	if not is_instance_valid(leaf_sprite):
		return
	_age += delta
	if _age > _lifetime:
		queue_free()
		return
	
	# Rüzgar şiddetine göre yerçekimi etkisi
	# Güçlü rüzgarda yerçekimi azalır (daha yatay hareket)
	var wind_strength: float = 0.01
	var storm_active: bool = false
	if WeatherManager:
		wind_strength = WeatherManager.wind_strength
		storm_active = WeatherManager.storm_active
	
	# Storm'da ve güçlü rüzgarda yerçekimi daha da azalır
	var gravity_factor: float = 1.0 - (wind_strength * 0.8)
	if storm_active and wind_strength > 0.5:
		gravity_factor *= 0.5  # Storm'da yerçekimi çok az
	
	_velocity.y += 10.0 * gravity_factor * delta
	
	# Rüzgar etkisiyle rastgele titreşimler (daha doğal görünüm, daha yavaş)
	var turbulence: float = sin(_age * 2.0) * 3.0
	_velocity.x += turbulence * delta
	_velocity.y += cos(_age * 1.8) * 2.0 * delta
	
	# Hızı sınırla (daha yavaş maksimum hız)
	_velocity.x = clamp(_velocity.x, -180.0, 180.0)
	_velocity.y = clamp(_velocity.y, -150.0, 150.0)
	
	position += _velocity * delta
	rotation += _rotation_speed * delta
	# Ekran dışına çıkınca sil (dünya koordinatında olduğumuz için ekran pozisyonuna çevirip bakıyoruz)
	var vp := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var cam_pos: Vector2 = cam.global_position
	var margin := 500.0  # Çok büyük margin - yapraklar ekrandan çok uzaklaşınca silinsin
	var cam_left: float = cam_pos.x - vp.x * 0.5 - margin
	var cam_right: float = cam_pos.x + vp.x * 0.5 + margin
	var cam_top: float = cam_pos.y - vp.y * 0.5 - margin
	var cam_bottom: float = cam_pos.y + vp.y * 0.5 + margin
	
	if global_position.x < cam_left or global_position.x > cam_right or global_position.y < cam_top or global_position.y > cam_bottom:
		queue_free()
