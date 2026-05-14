extends Area2D

# Meyve havada fırlayacak ve oyuncu üzerine gelerek toplayacak
const CollisionLayers = preload("res://resources/CollisionLayers.gd")

# Sprite yolları
const BERRY_PATH := "res://ui/minigames/food/berry.png"
const BERRY_DROP_PATH := "res://ui/minigames/food/berry_drop.png"

## Toplama yarıçapı (world space). Çap 2x için 12 → 24.
const FRUIT_PICKUP_RADIUS: float = 24.0

# Texture'ları yükle (conditional)
var BERRY_TEXTURE: Texture2D = null
var BERRY_DROP_TEXTURE: Texture2D = null

var _berry_sprite: Sprite2D = null

var _initial_velocity: Vector2 = Vector2.ZERO
# Minigame: 980’den hafif düşük — iniş çok sert olmasın; çok alçak kalmaması için 720’den yukarı tutuldu.
var _gravity: float = 750.0
var _air_time: float = 0.0
var _max_air_time: float = 3.0  # Maksimum havada kalma süresi
var _is_collected: bool = false
var _bush_position: Vector2 = Vector2.ZERO
var _minigame_ref: Node = null  # Minigame referansı (toplama için)
var _spawn_time: float = 0.0  # Spawn zamanı
var _collision_delay: float = 1.0  # İlk 1 saniye collision kapalı (dallardan geçmek için)
## Çarpışma (monitoring) açıldıktan sonra bu kadar saniye daha toplanamaz — spawn anında sayaç bug'ını önler.
var _pickup_cooldown_after_collision: float = 0.22
var _hit_ground: bool = false  # Yere değdi mi?
var _ground_hit_time: float = 0.0  # Yere değme zamanı
var _ground_fade_duration: float = 5.0  # Yere değdikten sonra kaybolma süresi (5 saniye)
var _ground_hit_position: Vector2 = Vector2.ZERO  # Yere değdiği pozisyon
var _rotation_speed: float = 0.0  # Dönme hızı (rad/saniye)

# Bar seviyesine göre fırlatma parametreleri
# fill_value: 0.0-1.0 arası (bar doluluk oranı)
## arc_index: 0..N-1 meyve sırası; farklı tepe yüksekliği için dikey ölçek (negatif = eski davranış, rastgele sadece açı).
func launch_from_bush(bush_pos: Vector2, fill_value: float, rng: RandomNumberGenerator, arc_index: int = -1) -> void:
	_bush_position = bush_pos
	_is_collected = false
	_air_time = 0.0
	_spawn_time = 0.0  # Spawn zamanını sıfırla
	
	# Bar seviyesine göre fırlatma gücü hesapla
	# fill_value ne kadar yüksekse o kadar yükseğe fırla
	var base_speed: float = 410.0
	var max_speed: float = 640.0
	var speed: float = lerp(base_speed, max_speed, fill_value)
	
	# Açı: 0° = tam yukarı; dar yelpaze (±60 genişti, havada yakalama için dar tutuldu).
	var angle_degrees: float = rng.randf_range(-22.0, 22.0)
	var angle: float = deg_to_rad(angle_degrees)
	
	var horizontal_speed: float = sin(angle) * speed
	var vertical_speed: float = -cos(angle) * speed  # Negatif = yukarı
	
	vertical_speed *= lerpf(1.12, 1.82, fill_value)
	# Aynı bar açısında bile meyveler farklı tepeye çıksın (sıraya göre alçak / orta / yüksek).
	if arc_index >= 0:
		const ARC_VERTICAL_SCALE := [0.74, 1.0, 1.22]
		vertical_speed *= ARC_VERTICAL_SCALE[arc_index % ARC_VERTICAL_SCALE.size()]
	horizontal_speed *= 1.08
	
	_initial_velocity = Vector2(horizontal_speed, vertical_speed)
	# Hafif yatay ofset (geniş ofset ayrıca yelpazeyi şişiriyordu)
	global_position = bush_pos + Vector2(rng.randf_range(-18.0, 18.0), -30.0)
	
	# Rastgele dönme hızı (farklı yönlerde ve hızlarda)
	# -360° ile +360° arası (saniyede 1 tam tur = 360° = 2π rad)
	var rotation_speed_degrees: float = rng.randf_range(-360.0, 360.0)  # Saniyede dönme açısı
	_rotation_speed = deg_to_rad(rotation_speed_degrees)
	
	# Başlangıç rotasyonu da rastgele
	rotation = deg_to_rad(rng.randf_range(0.0, 360.0))
	
	# Maksimum havada kalma süresi bar seviyesine göre ayarla
	_max_air_time = lerp(3.0, 5.0, fill_value)  # Daha uzun havada kalma
	
	var col_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape == null:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = FRUIT_PICKUP_RADIUS
		col_shape.shape = circle
		add_child(col_shape)
	elif col_shape.shape is CircleShape2D:
		(col_shape.shape as CircleShape2D).radius = FRUIT_PICKUP_RADIUS
	
	# Area2D ayarları - Player body ile etkileşim için
	collision_layer = 0  # Hiçbir layer'da değil
	collision_mask = CollisionLayers.PLAYER  # Player body'yi algıla
	monitoring = false  # İlk 1 saniye collision kapalı (dallardan geçmek için)
	monitorable = false  # Diğerleri bizi algılamasın
	
	# Yere değme durumunu sıfırla
	_hit_ground = false
	_ground_hit_time = 0.0
	
	# 1 saniye sonra collision'ı aç
	call_deferred("_enable_collision_after_delay")
	
	print("[Fruit] launch_from_bush() - collision_mask=", collision_mask, " monitoring=", monitoring, " monitorable=", monitorable)
	
	# Area2D signal'larını bağla - body_entered kullan (CharacterBody2D için)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("[Fruit] body_entered signal connected")
	else:
		print("[Fruit] body_entered signal already connected")
	
	# Sprite'ları yükle ve göster
	_load_berry_textures()
	_setup_berry_sprite()
	
	set_process(true)

func _load_berry_textures() -> void:
	# Sprite'ları conditional olarak yükle
	if ResourceLoader.exists(BERRY_PATH):
		BERRY_TEXTURE = load(BERRY_PATH)
	if ResourceLoader.exists(BERRY_DROP_PATH):
		BERRY_DROP_TEXTURE = load(BERRY_DROP_PATH)

func _setup_berry_sprite() -> void:
	# Berry sprite'ını oluştur veya bul
	if _berry_sprite == null or not is_instance_valid(_berry_sprite):
		_berry_sprite = get_node_or_null("BerrySprite") as Sprite2D
		if _berry_sprite == null:
			_berry_sprite = Sprite2D.new()
			_berry_sprite.name = "BerrySprite"
			_berry_sprite.centered = true  # Havadayken merkezden
			add_child(_berry_sprite)
	
	# Placeholder ColorRect'i gizle
	var color_rect := get_node_or_null("ColorRect") as ColorRect
	if color_rect:
		color_rect.visible = false
	
	# Berry sprite'ını göster
	if BERRY_TEXTURE != null:
		_berry_sprite.texture = BERRY_TEXTURE
		_berry_sprite.visible = true
	else:
		# Placeholder göster
		if color_rect:
			color_rect.visible = true

func set_minigame_ref(minigame: Node) -> void:
	_minigame_ref = minigame

func _enable_collision_after_delay() -> void:
	# 1 saniye sonra collision'ı aç
	await get_tree().create_timer(_collision_delay).timeout
	if not _hit_ground and not _is_collected:
		monitoring = true
		print("[Fruit] Collision enabled after delay")

func _on_body_entered(body: Node2D) -> void:
	print("[Fruit] _on_body_entered() called - body=", body.name, " class=", body.get_class())
	
	# Yere değdiyse artık toplanamaz
	if _hit_ground:
		print("[Fruit] ❌ Fruit hit ground, cannot collect")
		return
	
	if not can_be_collected():
		return
	
	# Oyuncu meyvenin üzerine geldi mi?
	if body.is_in_group("player"):
		print("[Fruit] ✅ Player detected! Calling collect()")
		# Minigame referansının hala geçerli olduğunu kontrol et
		if _minigame_ref != null and is_instance_valid(_minigame_ref) and _minigame_ref.has_method("_on_fruit_hit"):
			print("[Fruit] Calling minigame._on_fruit_hit()")
			_minigame_ref._on_fruit_hit(self)
		else:
			print("[Fruit] Minigame ref invalid, calling collect() directly")
			# Fallback: direkt topla
			collect()
	else:
		print("[Fruit] ❌ Not a player - body class: ", body.get_class())

func _process(delta: float) -> void:
	if _is_collected:
		return
	
	_air_time += delta
	_spawn_time += delta  # Spawn zamanını güncelle
	
	# Yere değdiyse fade out animasyonu
	if _hit_ground:
		_ground_hit_time += delta
		# Fade out efekti
		var fade_progress: float = _ground_hit_time / _ground_fade_duration
		modulate.a = lerp(1.0, 0.0, fade_progress)
		# Kırmızımsı renk (bozulmuş meyve)
		modulate = Color(0.7, 0.3, 0.3, modulate.a)
		
		# Süre doldu mu?
		if _ground_hit_time >= _ground_fade_duration:
			queue_free()
			return
		return  # Yere değdiyse hareket etme
	
	# Yerçekimi uygula
	_initial_velocity.y += _gravity * delta
	
	# Yatay sürtünmeyi kaldırdık: sabit 0.982/kare (delta'sız) yatay hızı çok hızlı eritiyordu;
	# meyve bir süre sonra düz dikey gidiyor, havada yakalama sıkıcı oluyordu. Saf balistik parabol.
	
	# Pozisyonu güncelle
	global_position += _initial_velocity * delta
	
	# Dönme animasyonu (havadayken)
	rotation += _rotation_speed * delta
	
	# Yere değdi mi kontrol et (raycast ile)
	_check_ground_collision()
	
	# Maksimum havada kalma süresi doldu mu?
	if _air_time >= _max_air_time:
		_on_ground_hit()
		return

func _check_ground_collision() -> void:
	# Collision delay süresi dolmadan önce yere değme kontrolü yapma
	if _spawn_time < _collision_delay:
		return
	
	# Raycast ile yere değip değmediğini kontrol et
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 20)  # 20 piksel aşağıya bak
	)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	
	var result := space_state.intersect_ray(query)
	if result:
		# Yere değdi!
		var distance: float = global_position.distance_to(result.position)
		if distance < 15.0:  # 15 piksel içindeyse yere değmiş say
			_ground_hit_position = result.position  # Yere değdiği pozisyonu kaydet
			_on_ground_hit()

func _on_ground_hit() -> void:
	if _hit_ground:
		return  # Zaten yere değmiş
	
	_hit_ground = true
	_ground_hit_time = 0.0
	
	# Collision'ı kapat - artık toplanamaz
	monitoring = false
	
	# Hızı sıfırla (yere yapışsın)
	_initial_velocity = Vector2.ZERO
	
	# Dönmeyi durdur (yere değdiğinde)
	_rotation_speed = 0.0
	
	# Yere değdiği pozisyonu kullan (eğer raycast sonucu varsa)
	if _ground_hit_position != Vector2.ZERO:
		# Berry'yi yere değdiği noktaya yerleştir (sprite'ın alt kısmı yere değsin)
		if _berry_sprite and BERRY_DROP_TEXTURE != null:
			var drop_size := BERRY_DROP_TEXTURE.get_size()
			# Sprite'ı bottom-center pivot'a çevir (alt kısmı yere otursun)
			_berry_sprite.centered = false
			# Offset: sprite'ın sol üst köşesinden merkeze kadar olan mesafe
			# Alt kısmının yere oturması için: offset.y = drop_size.y (sprite'ın alt kısmı node'un pozisyonunda olsun)
			# 25 piksel yukarı almak için offset.y'yi azaltıyoruz
			_berry_sprite.offset = Vector2(drop_size.x * 0.5, drop_size.y - 25.0)
			# Node pozisyonunu yere değdiği noktaya yerleştir (offset sayesinde sprite'ın alt kısmı burada olacak)
			global_position = _ground_hit_position
		else:
			global_position = _ground_hit_position
	else:
		# Raycast sonucu yoksa mevcut pozisyonu kullan
		if _berry_sprite and BERRY_DROP_TEXTURE != null:
			var drop_size := BERRY_DROP_TEXTURE.get_size()
			# Mevcut pozisyonu kullan ama sprite'ı yere oturt (25 piksel yukarı)
			_berry_sprite.centered = false
			_berry_sprite.offset = Vector2(drop_size.x * 0.5, drop_size.y - 25.0)
	
	# Berry drop sprite'ını göster
	if _berry_sprite and BERRY_DROP_TEXTURE != null:
		_berry_sprite.texture = BERRY_DROP_TEXTURE
		# Rotasyonu sıfırla (yere düşünce düzgün otursun)
		rotation = 0.0
		print("[Fruit] Berry drop sprite set, position: ", global_position, " offset: ", _berry_sprite.offset, " size: ", BERRY_DROP_TEXTURE.get_size())
	
	print("[Fruit] Fruit hit ground, disabling collection")
	
	# Minigame'e bildir - yere düşen meyve artık aktif değil
	if _minigame_ref != null and is_instance_valid(_minigame_ref) and _minigame_ref.has_method("_on_fruit_grounded"):
		_minigame_ref._on_fruit_grounded(self)

func collect() -> void:
	if _is_collected:
		return
	
	# Yere değdiyse toplanamaz
	if _hit_ground:
		return
	
	if not can_be_collected():
		return
	
	_is_collected = true
	
	# Altın toplama efektine benzer çizgi efekti
	_create_collection_effect(global_position)
	
	# Toplama efekti (küçük patlama veya fade out)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
	
	# Scale animasyonu
	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", scale * 1.5, 0.2)
	scale_tween.tween_property(self, "scale", Vector2.ZERO, 0.1)

func _create_collection_effect(pos: Vector2) -> void:
	# Altın toplama efektine benzer: 4 yöne açılan çizgi-parlama (yeşil tonları)
	var parent: Node = get_tree().current_scene
	if not parent:
		return
	
	var lines := []
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	# Berry için yeşil tonları
	var colors := [Color(0.6, 1.0, 0.6, 1), Color(0.6, 1.0, 0.6, 1), Color(0.8, 1.0, 0.8, 1), Color(0.8, 1.0, 0.8, 1)]
	
	for i in range(4):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = colors[i]
		# Ensure effect renders in front of player sprites
		line.z_as_relative = false
		line.z_index = 1000
		line.add_point(pos)
		line.add_point(pos)  # başlangıçta sıfır uzunluk
		parent.add_child(line)
		lines.append({"node": line, "dir": dirs[i]})
	
	var duration := 0.22
	for entry in lines:
		var line: Line2D = entry.node
		var dir: Vector2 = entry.dir
		# Tween'i parent'ta oluştur (Fruit silinince tween iptal olmasın)
		var tween := parent.create_tween()
		tween.tween_method(func(t: float):
			if not is_instance_valid(line):
				return
			var end_pos: Vector2 = pos + dir * (t * 24.0)
			line.set_point_position(0, pos)
			line.set_point_position(1, end_pos)
			line.modulate.a = 1.0 - t
		, 0.0, 1.0, duration)
		tween.tween_callback(line.queue_free)

func is_collected() -> bool:
	return _is_collected


func can_be_collected() -> bool:
	if _is_collected or _hit_ground:
		return false
	return _spawn_time >= _collision_delay + _pickup_cooldown_after_collision


func has_hit_ground() -> bool:
	return _hit_ground
