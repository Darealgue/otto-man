extends "res://ui/minigames/MinigameBase.gd"

const ResourceType = preload("res://resources/resource_types.gd")
const FoodGauge = preload("res://ui/minigames/food/FoodGauge.gd")
const FoodHurtbox = preload("res://ui/minigames/food/FoodHurtbox.gd")
const FRUIT_SCENE := preload("res://ui/minigames/food/Fruit.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")

# Bar ayarları
@export var fill_speed_base: float = 1.2  # Bar dolum hızı
@export var success_zone_threshold: float = 0.85  # Bar'ın en üst %15'lik kısmı (0.85-1.0 arası başarılı)
@export var speed_change_min: float = 0.8  # Her vuruştan sonra minimum hız çarpanı
@export var speed_change_max: float = 1.3  # Her vuruştan sonra maksimum hız çarpanı
@export var min_speed: float = 0.5  # Minimum hız sınırı
@export var max_speed: float = 2.5  # Maksimum hız sınırı

# Görsel ayarlar
@export var success_feedback_color: Color = Color(0.4, 0.9, 0.6, 1.0)
@export var fail_feedback_color: Color = Color(0.95, 0.35, 0.35, 1.0)
@export var anchor_offset_default: Vector2 = Vector2(0, 75)  # Bar aşağıda (çalıyı kapatmamak için)

# Oyun değişkenleri
var _fruits_to_spawn: int = 3
var _base_reward: int = 1  # Her meyve için 1 yiyecek
var _perfect_bonus: int = 0  # Bonus yok, her meyve = +1
var _resource_type: String = ResourceType.FOOD
var _fruits_collected: int = 0
var _fruits_spawned: int = 0
var _max_misses: int = 3  # Maksimum miss sayısı
var _misses: int = 0

# Bar durumu
var _fill_value: float = 0.0  # 0.0 = alt, 1.0 = üst
var _fill_speed: float = 1.2
var _fill_direction: float = 1.0  # 1.0 = doluyor, -1.0 = boşalıyor

# UI referansları
var _gauge: FoodGauge = null
var _anchor_path: NodePath = NodePath("")
var _anchor_offset: Vector2 = Vector2.ZERO
var _bush_node: Node2D = null
var _bush_path: NodePath = NodePath("")
var _player_path: NodePath = NodePath("")
var _player_node: Node2D = null
var _cancel_distance: float = 375.0
var _hurtbox: FoodHurtbox = null
var _rng := RandomNumberGenerator.new()

# Meyve takibi
var _active_fruits: Array[Node2D] = []  # Havada olan meyveler
var _game_started: bool = false
var _waiting_for_fruits: bool = false  # Meyveler havada mı?
var _fruits_already_spawned: bool = false  # Meyveler bir kez spawn oldu mu?
var _fruits_spawning: bool = false  # Meyveler şu anda spawn oluyor mu? (delay sırasında)
var _camera_zoom_tween: Tween = null  # Kamera zoom animasyonu için
var _default_camera_zoom: Vector2 = Vector2(1.5, 1.5)  # Başlangıç zoom değeri
var _parallax_original_scales: Dictionary = {}  # Parallax sprite'ların orijinal scale'leri
var _parallax_original_mirroring: Dictionary = {}  # Parallax layer'ların orijinal motion_mirroring değerleri

func _on_minigame_ready() -> void:
	_rng.randomize()
	pause_game = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Context'ten değerleri al
	_fruits_to_spawn = max(3, int(get_context_value("fruits_to_spawn", 5)))
	_base_reward = int(get_context_value("resource_base", 1))
	_perfect_bonus = int(get_context_value("perfect_bonus", 2))
	_resource_type = String(get_context_value("resource_type", ResourceType.FOOD))
	_bush_path = _node_path_from_value(get_context_value("bush_path", NodePath("")))
	_player_path = _node_path_from_value(get_context_value("player_path", NodePath("")))
	_anchor_offset = Vector2(get_context_value("anchor_offset", anchor_offset_default))
	_max_misses = int(get_context_value("max_misses", 3))
	_cancel_distance = float(get_context_value("cancel_distance", 375.0))
	
	# Node'ları bul
	_setup_nodes()
	_setup_anchor()
	_setup_hurtbox()
	_reset_game_state()
	_reset_bar()
	_update_gauge_state()
	
	# Default kamera zoom değerini kaydet
	_save_default_camera_zoom()
	
	# Parallax orijinal scale'lerini kaydet
	_save_parallax_original_scales()
	
	set_process(true)
	print("[FoodMinigame] Food minigame active (fruits=%d, max_misses=%d)" % [_fruits_to_spawn, _max_misses])

func _setup_nodes() -> void:
	# Çalı node'unu bul
	if not _bush_path.is_empty():
		_bush_node = get_node_or_null(_bush_path)
		if _bush_node:
			print("[FoodMinigame] Bush node found: %s" % _bush_node.name)
		else:
			print("[FoodMinigame] Warning: Bush node not found at path: %s" % _bush_path)
	# Oyuncu node'unu bul
	if not _player_path.is_empty():
		_player_node = get_node_or_null(_player_path)
	if _player_node == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0] is Node2D:
			_player_node = players[0] as Node2D

func _setup_anchor() -> void:
	# Anchor node'unu bul (çalının üstünde bar göstermek için)
	if _bush_node:
		_anchor_path = _bush_node.get_path()
		var anchor_node := get_node_or_null(_anchor_path)
		if anchor_node:
			_create_gauge(anchor_node)
	else:
		# Anchor yoksa scene root'a ekle
		var scene_root := get_tree().current_scene
		if scene_root:
			_create_gauge(scene_root)

func _create_gauge(parent: Node) -> void:
	_gauge = FoodGauge.new()
	parent.add_child(_gauge)
	_gauge.z_index = 1000
	if _bush_node:
		_gauge.global_position = _bush_node.global_position + _anchor_offset
	else:
		_gauge.global_position = Vector2(960, 540)  # Ekran merkezi
	print("[FoodMinigame] Gauge created at position: %s" % _gauge.global_position)

func _setup_hurtbox() -> void:
	if not _bush_node:
		print("[FoodMinigame] Warning: Cannot create hurtbox, bush node not found")
		return
	
	# Çalı node'una hurtbox ekle
	_hurtbox = FoodHurtbox.new()
	_bush_node.add_child(_hurtbox)
	_hurtbox.bind_minigame(self)
	
	# CollisionShape2D ekle
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(64, 48)  # Çalı boyutu
	shape.shape = rect_shape
	shape.position = Vector2(0, -24)  # Çalının merkezine göre
	_hurtbox.add_child(shape)
	
	print("[FoodMinigame] Hurtbox created and bound to minigame")

func _process(delta: float) -> void:
	if is_finished():
		return
	if _handle_distance_check():
		return
	
	# Bar dolum/boşalma animasyonu (sadece meyveler havada değilken)
	if not _waiting_for_fruits:
		_fill_value += _fill_direction * _fill_speed * delta
		
		# Bar sınırlarını kontrol et
		if _fill_value >= 1.0:
			_fill_value = 1.0
			_fill_direction = -1.0  # Geri boşalmaya başla
		elif _fill_value <= 0.0:
			_fill_value = 0.0
			_fill_direction = 1.0  # Tekrar dolmaya başla
		
		# Gauge'i güncelle
		_update_gauge_state()
	
	# Havadaki meyveleri kontrol et
	_check_active_fruits()

func _on_food_hurtbox_hit(hitbox: Area2D) -> void:
	print("[FoodMinigame] _on_food_hurtbox_hit() called - is_finished=", is_finished(), " fruits_already_spawned=", _fruits_already_spawned)
	if is_finished():
		print("[FoodMinigame] BLOCKED: Minigame already finished")
		return
	if not (hitbox is PlayerHitbox):
		print("[FoodMinigame] BLOCKED: Not a PlayerHitbox")
		return
	var player_hitbox := hitbox as PlayerHitbox
	if not _is_heavy_hit(player_hitbox):
		if _gauge:
			_gauge.set_feedback("Sadece heavy attack işe yarar!", fail_feedback_color, 0.9)
		print("[FoodMinigame] BLOCKED: Not a heavy hit")
		return
	
	# Eğer meyveler zaten spawn olduysa, bir daha vuruş yapma ve bar'ı kapat
	if _fruits_already_spawned:
		print("[FoodMinigame] BLOCKED: Fruits already spawned, ignoring hit")
		# Bar'ı kapat
		if _gauge:
			_cleanup_gauge()
		return
	
	# Sadece heavy attack ile vuruş yapılabilir
	print("[FoodMinigame] Proceeding with _attempt_hit()")
	_attempt_hit()

func _is_heavy_hit(hitbox: PlayerHitbox) -> bool:
	if hitbox == null:
		return false
	var attack_name := String(hitbox.current_attack_name)
	return attack_name.find("heavy") != -1

func _handle_distance_check() -> bool:
	_setup_nodes()
	if !_bush_node or !is_instance_valid(_bush_node):
		emit_result(false, {"resource_type": _resource_type, "amount": 0, "fruits_collected": _fruits_collected, "misses": _misses, "bush_missing": true})
		return true
	if !_player_node or !is_instance_valid(_player_node):
		return false
	var distance: float = _bush_node.global_position.distance_to(_player_node.global_position)
	if distance > _cancel_distance:
		if _gauge:
			_cleanup_gauge()
		_reset_camera_zoom()
		emit_result(false, {
			"resource_type": _resource_type,
			"amount": 0,
			"fruits_collected": _fruits_collected,
			"misses": _misses,
			"distance_cancelled": true,
			"distance": distance,
		})
		return true
	return false

func _attempt_hit() -> void:
	if is_finished():
		return
	if _handle_distance_check():
		return
	
	# Eğer meyveler hala havadaysa, yeni vuruş yapma
	if _waiting_for_fruits:
		if _gauge:
			_gauge.set_feedback("Meyveleri topla!", fail_feedback_color, 0.9)
		return
	
	# Bar'ın sağ tarafı (fill_value 1.0 = sağ)
	var bar_right: float = _fill_value
	
	# Bar'ın sağ tarafı en sağ %15'lik bölgede mi? (0.85-1.0 arası)
	if bar_right >= success_zone_threshold:
		# Bar'ın sağ tarafı başarılı bölgede - meyveleri fırlat
		_on_perfect_hit()
	else:
		# Bar henüz başarılı bölgeye ulaşmadı
		var distance: float = success_zone_threshold - bar_right
		_on_miss("Çok erken! (%.1f%% kaldı)" % (distance * 100.0))

func _on_perfect_hit() -> void:
	# Eğer meyveler zaten spawn olduysa, bir daha spawn etme
	if _fruits_already_spawned:
		print("[FoodMinigame] BLOCKED: Fruits already spawned, ignoring hit")
		return
	
	print("[FoodMinigame] _on_perfect_hit() called - spawning fruits")
	# Çalı hit animasyonu
	_play_bush_hit_animation()
	
	# Kamerayı zoom out yap (meyveleri görmek için)
	_zoom_camera_out()
	
	# Bar seviyesine göre meyveleri fırlat (0.3 saniye gecikme ile animasyona uyum için)
	_fruits_already_spawned = true
	
	# Bar'ı hemen kapat (başarılı vuruştan sonra)
	if _gauge:
		_cleanup_gauge()
	
	# Meyveler havada, bekle
	_waiting_for_fruits = true
	_fruits_spawned = _fruits_to_spawn
	
	# 0.3 saniye gecikme ile meyveleri spawn et (async olarak başlat)
	_fruits_spawning = true
	_spawn_fruits_delayed(_fill_value)

func _spawn_fruits_delayed(fill_value: float) -> void:
	# 0.3 saniye bekle (çalı animasyonuna uyum için)
	print("[FoodMinigame] _spawn_fruits_delayed() called - waiting 0.3 seconds...")
	await get_tree().create_timer(0.3).timeout
	print("[FoodMinigame] Timer finished, calling _spawn_fruits()")
	_fruits_spawning = false
	_spawn_fruits(fill_value)

func _on_miss(reason: String) -> void:
	_misses += 1
	
	# Feedback
	if _gauge:
		_gauge.set_feedback("Iska! (%d/%d)" % [_misses, _max_misses], fail_feedback_color)
		_gauge.set_fruits_collected(_fruits_collected, _fruits_to_spawn)
	
	# Yeni bar başlat
	_reset_bar()
	
	# Maksimum miss sayısına ulaşıldı mı?
	if _misses >= _max_misses:
		# İlerlemeyi sıfırla ve oyunu bitir
		_fruits_collected = 0
		emit_result(false, {
			"resource_type": _resource_type,
			"amount": 0,
			"fruits_collected": _fruits_collected,
			"misses": _misses,
		})

func _spawn_fruits(bar_level: float) -> void:
	# Bar seviyesine göre meyveleri fırlat
	print("[FoodMinigame] _spawn_fruits() called with bar_level=", bar_level, " fruits_to_spawn=", _fruits_to_spawn)
	if not _bush_node:
		print("[FoodMinigame] ERROR: _bush_node is null!")
		return
	
	var bush_pos := _bush_node.global_position
	print("[FoodMinigame] Bush position: ", bush_pos)
	
	var spawned_count := 0
	for i in range(_fruits_to_spawn):
		var fruit := FRUIT_SCENE.instantiate() as Node2D
		if not fruit:
			print("[FoodMinigame] ERROR: Failed to instantiate fruit ", i)
			continue
		
		# Scene'e ekle
		var spawn_parent: Node = null
		if _bush_node and _bush_node.get_parent():
			spawn_parent = _bush_node.get_parent()
		else:
			spawn_parent = get_tree().current_scene
		
		if spawn_parent:
			spawn_parent.add_child(fruit)
			
			# Meyveyi fırlat
			if fruit.has_method("launch_from_bush"):
				fruit.launch_from_bush(bush_pos, bar_level, _rng)
			else:
				print("[FoodMinigame] ERROR: Fruit does not have launch_from_bush method")
			
			# Meyve toplama için minigame referansı ver
			if fruit.has_method("set_minigame_ref"):
				fruit.set_minigame_ref(self)
			
			_active_fruits.append(fruit)
			spawned_count += 1
			print("[FoodMinigame] Fruit spawned: %d/%d" % [i+1, _fruits_to_spawn])
		else:
			print("[FoodMinigame] ERROR: spawn_parent is null!")
	
	print("[FoodMinigame] Total fruits spawned: %d/%d" % [spawned_count, _fruits_to_spawn])

func _on_fruit_hit(fruit: Node2D) -> void:
	# Oyuncu meyveye vurdu
	_collect_fruit(fruit)

func _collect_fruit(fruit: Node2D) -> void:
	if not fruit or not fruit in _active_fruits:
		return
	
	if fruit.has_method("is_collected") and fruit.is_collected():
		return
	
	# Meyveyi topla
	_fruits_collected += 1
	print("[FoodMinigame] _collect_fruit() - fruits_collected=", _fruits_collected, " active_fruits=", _active_fruits.size())
	
	# Feedback
	if _gauge:
		_gauge.set_fruits_collected(_fruits_collected, _fruits_to_spawn)
		_gauge.set_feedback("Meyve toplandı! (%d/%d)" % [_fruits_collected, _fruits_to_spawn], success_feedback_color, 0.8)
	
	# Meyveyi kaldır
	if fruit.has_method("collect"):
		fruit.collect()
	else:
		fruit.queue_free()
	
	_active_fruits.erase(fruit)
	print("[FoodMinigame] After erase - active_fruits=", _active_fruits.size(), " waiting_for_fruits=", _waiting_for_fruits)
	
	# Tüm meyveler toplandı mı veya yere düştü mü?
	# Eğer tüm meyveler toplandıysa veya yere düştüyse kontrol et
	if _waiting_for_fruits:
		if _active_fruits.is_empty():
			print("[FoodMinigame] All fruits collected/dropped, calling _check_fruit_collection_complete()")
			_check_fruit_collection_complete()
		else:
			print("[FoodMinigame] Still waiting for ", _active_fruits.size(), " fruits")

func _check_active_fruits() -> void:
	# Eğer meyveler şu anda spawn oluyorsa (delay sırasında) kontrol etme
	if _fruits_spawning:
		return
	
	# Havadaki meyveleri kontrol et, yere düşenleri kaldır
	var fruits_to_remove: Array[Node2D] = []
	
	for fruit in _active_fruits:
		if not is_instance_valid(fruit):
			fruits_to_remove.append(fruit)
			continue
		
		# Yere düştü mü kontrol et (bush pozisyonunun altında mı veya has_hit_ground() true mu?)
		if fruit.has_method("has_hit_ground") and fruit.has_hit_ground():
			fruits_to_remove.append(fruit)
			continue
		
		# Yere düştü mü kontrol et (bush pozisyonunun altında mı?)
		if _bush_node and fruit.global_position.y > _bush_node.global_position.y + 50.0:
			fruits_to_remove.append(fruit)
			continue
	
	# Kaldırılan meyveleri temizle
	for fruit in fruits_to_remove:
		if is_instance_valid(fruit):
			# Yere düşen meyveleri hemen kaldırma, sadece listeden çıkar
			# (Fruit kendi fade out animasyonunu yapacak)
			pass
		_active_fruits.erase(fruit)
	
	# Tüm meyveler toplandı/yere düştü mü?
	# Sadece meyveler spawn olduktan sonra kontrol et
	# (_fruits_already_spawned true ve _active_fruits boşsa, meyveler spawn olmuş ama hepsi toplanmış/düşmüş demektir)
	if _waiting_for_fruits and _active_fruits.is_empty() and _fruits_already_spawned:
		print("[FoodMinigame] All fruits collected/dropped (from _check_active_fruits), calling _check_fruit_collection_complete()")
		_check_fruit_collection_complete()

func _on_fruit_grounded(fruit: Node2D) -> void:
	# Yere düşen meyveyi aktif listeden kaldır
	print("[FoodMinigame] _on_fruit_grounded() called - removing from active_fruits")
	if fruit in _active_fruits:
		_active_fruits.erase(fruit)
		print("[FoodMinigame] Fruit removed from active_fruits, remaining: ", _active_fruits.size())
	
	# Tüm meyveler toplandı/yere düştü mü?
	if _waiting_for_fruits and _active_fruits.is_empty():
		print("[FoodMinigame] All fruits collected/dropped (from _on_fruit_grounded), calling _check_fruit_collection_complete()")
		_check_fruit_collection_complete()

func _check_fruit_collection_complete() -> void:
	if not _waiting_for_fruits:
		return
	
	# Tüm meyveler toplandı veya yere düştü
	_waiting_for_fruits = false
	
	# Kamerayı eski haline döndür
	_reset_camera_zoom()
	
	# Ödül hesapla
	var reward := _calculate_reward()
	
	print("[FoodMinigame] _check_fruit_collection_complete() - reward=", reward, " fruits_collected=", _fruits_collected)
	
	if reward > 0:
		# Başarılı!
		print("[FoodMinigame] Showing resource gain text: +", reward)
		_show_resource_gain_text(reward)
		if _gauge:
			_gauge.set_feedback("BAŞARILI! +%d Yiyecek" % reward, success_feedback_color)
		
		emit_result(true, {
			"resource_type": _resource_type,
			"amount": reward,
			"fruits_collected": _fruits_collected,
			"misses": _misses,
		})
	else:
		# Hiç meyve toplanamadı
		print("[FoodMinigame] No reward - fruits_collected=", _fruits_collected)
		if _gauge:
			_gauge.set_feedback("Meyve toplanamadı!", fail_feedback_color)
		
		_misses += 1
		# Tüm meyveler yere düştüyse minigame'i bitir (başarısız)
		emit_result(false, {
			"resource_type": _resource_type,
			"amount": 0,
			"fruits_collected": _fruits_collected,
			"misses": _misses,
		})

func _calculate_reward() -> int:
	# Her meyve = +1 yiyecek
	return _fruits_collected

func _change_speed() -> void:
	# Hızı rastgele değiştir (çarpma faktörü ile)
	var speed_multiplier: float = _rng.randf_range(speed_change_min, speed_change_max)
	_fill_speed *= speed_multiplier
	# Hız sınırlarını kontrol et
	_fill_speed = clamp(_fill_speed, min_speed, max_speed)
	print("[FoodMinigame] Speed changed to: %.2f (multiplier: %.2f)" % [_fill_speed, speed_multiplier])

func _reset_bar() -> void:
	_fill_value = 0.0  # Bar'ı sıfırla
	_fill_direction = 1.0  # Dolmaya başla

func _reset_game_state() -> void:
	# Oyun başladığında veya yeni bir oyun başlatıldığında state'i sıfırla
	_fruits_collected = 0
	_fruits_spawned = 0
	_misses = 0
	_fill_value = 0.0
	_fill_direction = 1.0
	_waiting_for_fruits = false
	_fruits_already_spawned = false
	_fruits_spawning = false
	_active_fruits.clear()

func _update_gauge_state() -> void:
	if _gauge:
		_gauge.set_fill_value(_fill_value)
		_gauge.set_success_zone_threshold(success_zone_threshold)
		_gauge.set_fruits_collected(_fruits_collected, _fruits_to_spawn)

func _play_bush_hit_animation() -> void:
	# Çalı hit animasyonu oynat
	print("[FoodMinigame] _play_bush_hit_animation() called - _bush_node: ", _bush_node)
	if _bush_node and is_instance_valid(_bush_node):
		if _bush_node.has_method("play_hit_animation"):
			print("[FoodMinigame] Calling play_hit_animation() on bush")
			_bush_node.play_hit_animation()
		else:
			print("[FoodMinigame] ERROR: Bush node does not have play_hit_animation method")
	else:
		print("[FoodMinigame] ERROR: _bush_node is null or invalid")

func _zoom_camera_out() -> void:
	# Kamerayı bul ve zoom out yap
	var camera: Camera2D = _find_player_camera()
	if not camera:
		print("[FoodMinigame] ERROR: Could not find player camera for zoom")
		return
	
	print("[FoodMinigame] Zooming camera out - current zoom: ", camera.zoom)
	
	# Target zoom hesapla (default zoom'un 0.7 katı)
	var target_zoom := _default_camera_zoom * 0.7
	
	# Parallax viewport'u güncelle (zoom değişikliği için)
	_update_parallax_for_zoom(target_zoom)
	
	# Eğer kamera zoom fonksiyonları varsa kullan
	if camera.has_method("zoom_to_factor"):
		# 0.7 faktörü ile zoom out (daha geniş görüş)
		camera.zoom_to_factor(0.7, 0.4)
		print("[FoodMinigame] Camera zoom out to factor 0.7")
	elif camera.has_method("zoom_to_vector"):
		camera.zoom_to_vector(target_zoom, 0.4)
		print("[FoodMinigame] Camera zoom out to: ", target_zoom)
	else:
		# Manuel zoom animasyonu
		if _camera_zoom_tween and _camera_zoom_tween.is_running():
			_camera_zoom_tween.kill()
		_camera_zoom_tween = create_tween()
		_camera_zoom_tween.tween_property(camera, "zoom", target_zoom, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		print("[FoodMinigame] Camera zoom out (manual) to: ", target_zoom)

func _update_parallax_for_zoom(zoom_level: Vector2) -> void:
	# ParallaxBackground'ı bul
	var parallax_bg: ParallaxBackground = null
	var scene_root := get_tree().current_scene
	if scene_root:
		parallax_bg = scene_root.get_node_or_null("ParallaxBackground") as ParallaxBackground
		if not parallax_bg:
			# Alternatif: ForestLevelGenerator içinde olabilir
			var forest_gen := scene_root.get_node_or_null("ForestLevelGenerator")
			if forest_gen:
				parallax_bg = forest_gen.get_node_or_null("ParallaxBackground") as ParallaxBackground
	
	if not parallax_bg:
		print("[FoodMinigame] WARNING: ParallaxBackground not found, cannot update for zoom")
		return
	
	# Parallax sprite'ların scale'lerini zoom'a göre ayarla
	_adjust_parallax_scales(parallax_bg, zoom_level)
	
	# ParallaxBackground'ı force update et (deferred olarak)
	call_deferred("_force_parallax_update", parallax_bg, zoom_level)
	
	print("[FoodMinigame] Scheduled parallax update for zoom: ", zoom_level)

func _save_parallax_original_scales() -> void:
	# ParallaxBackground'ı bul
	var parallax_bg: ParallaxBackground = null
	var scene_root := get_tree().current_scene
	if scene_root:
		parallax_bg = scene_root.get_node_or_null("ParallaxBackground") as ParallaxBackground
		if not parallax_bg:
			var forest_gen := scene_root.get_node_or_null("ForestLevelGenerator")
			if forest_gen:
				parallax_bg = forest_gen.get_node_or_null("ParallaxBackground") as ParallaxBackground
	
	if not parallax_bg:
		return
	
	# Tüm parallax layer'ları bul ve orijinal scale'leri kaydet
	for child in parallax_bg.get_children():
		if child is ParallaxLayer:
			var layer := child as ParallaxLayer
			# Motion mirroring'i kaydet
			var layer_path := layer.get_path()
			if not _parallax_original_mirroring.has(layer_path):
				_parallax_original_mirroring[layer_path] = layer.motion_mirroring
				print("[FoodMinigame] Saved original motion_mirroring for ", layer_path, ": ", layer.motion_mirroring)
			
			# Sprite scale'lerini kaydet
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					var spr := sprite as Sprite2D
					var sprite_path := spr.get_path()
					if not _parallax_original_scales.has(sprite_path):
						_parallax_original_scales[sprite_path] = spr.scale
						print("[FoodMinigame] Saved original parallax scale for ", sprite_path, ": ", spr.scale)

func _adjust_parallax_scales(parallax_bg: ParallaxBackground, zoom_level: Vector2) -> void:
	# Zoom faktörü (zoom out = daha küçük zoom değeri = daha büyük görüş alanı)
	# Örnek: zoom 1.5 -> 0.7 (zoom out), scale 1.0 -> 1.5/0.7 = ~2.14 katı
	var default_zoom := _default_camera_zoom.x
	var current_zoom := zoom_level.x
	var scale_multiplier := default_zoom / current_zoom  # Zoom out yapıldığında scale artmalı
	
	print("[FoodMinigame] Adjusting parallax scales - default zoom: ", default_zoom, " current zoom: ", current_zoom, " multiplier: ", scale_multiplier)
	
	# Tüm parallax layer'ları bul ve sprite scale'lerini ayarla
	for child in parallax_bg.get_children():
		if child is ParallaxLayer:
			var layer := child as ParallaxLayer
			# Sprite'ları bul
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					var spr := sprite as Sprite2D
					# Orijinal scale'i kaydet (ilk seferinde)
					var sprite_path := spr.get_path()
					if not _parallax_original_scales.has(sprite_path):
						_parallax_original_scales[sprite_path] = spr.scale
						print("[FoodMinigame] Saved original scale for ", sprite_path, ": ", spr.scale)
					
					# Yeni scale hesapla
					var original_scale: Vector2 = _parallax_original_scales[sprite_path]
					var new_scale := original_scale * scale_multiplier
					spr.scale = new_scale
					
			# Motion mirroring'i de güncelle (eğer layer'da varsa)
			var layer_path := layer.get_path()
			if _parallax_original_mirroring.has(layer_path):
				var original_mirroring: Vector2 = _parallax_original_mirroring[layer_path]
				if original_mirroring != Vector2.ZERO:
					# Motion mirroring'i zoom'a göre ölçekle
					# Zoom out yapıldığında, daha fazla alan görünür, bu yüzden mirroring artmalı
					var new_mirroring := original_mirroring * scale_multiplier
					layer.motion_mirroring = new_mirroring
					print("[FoodMinigame] Adjusted motion_mirroring for layer ", layer.name, " from ", original_mirroring, " to ", new_mirroring)
			
			# Sprite'ları bul ve scale'lerini ayarla
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					var spr := sprite as Sprite2D
					# Orijinal scale'i kaydet (ilk seferinde)
					var sprite_path := spr.get_path()
					if not _parallax_original_scales.has(sprite_path):
						_parallax_original_scales[sprite_path] = spr.scale
						print("[FoodMinigame] Saved original scale for ", sprite_path, ": ", spr.scale)
					
					# Yeni scale hesapla
					var original_scale: Vector2 = _parallax_original_scales[sprite_path]
					var new_scale := original_scale * scale_multiplier
					spr.scale = new_scale
					print("[FoodMinigame] Adjusted parallax sprite scale: ", sprite.name, " from ", original_scale, " to ", new_scale)

func _reset_parallax_scales() -> void:
	# ParallaxBackground'ı bul
	var parallax_bg: ParallaxBackground = null
	var scene_root := get_tree().current_scene
	if scene_root:
		parallax_bg = scene_root.get_node_or_null("ParallaxBackground") as ParallaxBackground
		if not parallax_bg:
			var forest_gen := scene_root.get_node_or_null("ForestLevelGenerator")
			if forest_gen:
				parallax_bg = forest_gen.get_node_or_null("ParallaxBackground") as ParallaxBackground
	
	if not parallax_bg:
		return
	
	# Tüm parallax layer'ları bul ve orijinal scale'lere döndür
	for child in parallax_bg.get_children():
		if child is ParallaxLayer:
			var layer := child as ParallaxLayer
			# Motion mirroring'i orijinal değerine döndür
			var layer_path := layer.get_path()
			if _parallax_original_mirroring.has(layer_path):
				layer.motion_mirroring = _parallax_original_mirroring[layer_path]
				print("[FoodMinigame] Reset motion_mirroring for layer ", layer.name, " to ", layer.motion_mirroring)
			
			# Sprite scale'lerini orijinal değerlerine döndür
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					var spr := sprite as Sprite2D
					var sprite_path := spr.get_path()
					if _parallax_original_scales.has(sprite_path):
						spr.scale = _parallax_original_scales[sprite_path]
						print("[FoodMinigame] Reset parallax sprite scale: ", sprite.name, " to ", spr.scale)

func _force_parallax_update(parallax_bg: ParallaxBackground, zoom_level: Vector2) -> void:
	# ParallaxBackground'ı force update et
	if not parallax_bg or not is_instance_valid(parallax_bg):
		return
	
	# Birkaç frame bekle (parallax'in güncellenmesi için)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Viewport size'ını al ve zoom'a göre hesapla
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom_factor := zoom_level.x
	
	# ParallaxBackground'ın scroll_offset'ini güncelle
	# Zoom değiştiğinde, parallax'in görünür alanı değişir
	# Bu yüzden scroll_offset'i sıfırlayıp parallax'in yeniden hesaplanmasını sağla
	parallax_bg.scroll_offset = Vector2(0.01, 0.01)
	await get_tree().process_frame
	parallax_bg.scroll_offset = Vector2.ZERO
	
	# Tüm parallax layer'ları zorla güncelle
	for child in parallax_bg.get_children():
		if child is ParallaxLayer:
			var layer := child as ParallaxLayer
			# Layer'ı force update et
			layer.set_process(true)
			
			# Motion mirroring'i zoom'a göre ayarla (eğer varsa)
			if layer.motion_mirroring != Vector2.ZERO:
				# Zoom out yapıldığında, daha fazla alan görünür
				# Motion mirroring'i zoom faktörüne göre ölçekle
				var original_mirroring := layer.motion_mirroring
				# Zoom out için mirroring'i artır (daha fazla texture repeat gerekir)
				# Ama bu çok agresif olabilir, bu yüzden sadece scroll_offset güncellemesi yeterli olabilir
			
			# Sprite'ları bul ve force update et
			for sprite in layer.get_children():
				if sprite is Sprite2D:
					var spr := sprite as Sprite2D
					# Sprite'ı force update et
					spr.queue_redraw()
					# Texture repeat aktifse, sprite'ın scale'ini kontrol et
					if spr.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED:
						# Texture repeat için sprite'ın görünür alanını artırmak gerekebilir
						# Ama bu genellikle otomatik olarak yapılır
						pass
	
	print("[FoodMinigame] Force updated parallax background for zoom: ", zoom_level, " viewport: ", viewport_size)

func _save_default_camera_zoom() -> void:
	# Başlangıç zoom değerini kaydet
	var camera: Camera2D = _find_player_camera()
	if not camera:
		print("[FoodMinigame] WARNING: Could not find camera to save default zoom")
		return
	
	# ÖNCE mevcut zoom değerini kaydet (bu gerçek başlangıç zoom'u)
	_default_camera_zoom = camera.zoom
	print("[FoodMinigame] Saved CURRENT camera zoom as default: ", _default_camera_zoom)
	
	# Eğer kamera script'inde _default_zoom varsa ve mevcut zoom'dan farklıysa, script'teki değeri kullan
	# Ama genellikle mevcut zoom doğru değerdir
	if camera.has_method("get"):
		var script_default = camera.get("_default_zoom")
		if script_default != null and script_default != Vector2.ZERO:
			# Script'teki default zoom'u kontrol et, ama mevcut zoom'u tercih et
			print("[FoodMinigame] Camera script has _default_zoom: ", script_default, " but using current: ", _default_camera_zoom)
	
	# Eğer hala Vector2.ZERO veya geçersiz bir değerse, varsayılan değer kullan
	if _default_camera_zoom == Vector2.ZERO or _default_camera_zoom.x <= 0 or _default_camera_zoom.y <= 0:
		_default_camera_zoom = Vector2(1.5, 1.5)  # Player camera default
		print("[FoodMinigame] Using fallback default zoom: ", _default_camera_zoom)

func _reset_camera_zoom() -> void:
	# Kamerayı eski haline döndür
	var camera: Camera2D = _find_player_camera()
	if not camera:
		print("[FoodMinigame] ERROR: Could not find player camera for reset zoom")
		return
	
	print("[FoodMinigame] Resetting camera zoom - current zoom: ", camera.zoom, " target: ", _default_camera_zoom)
	
	# Parallax'i orijinal scale'lerine döndür
	_reset_parallax_scales()
	
	# Parallax viewport'u güncelle (zoom değişikliği için)
	_update_parallax_for_zoom(_default_camera_zoom)
	
	# Kamera'nın _default_zoom'unu bizim kaydettiğimiz değerle güncelle
	if camera.has_method("set"):
		camera.set("_default_zoom", _default_camera_zoom)
		print("[FoodMinigame] Updated camera script _default_zoom to: ", _default_camera_zoom)
	
	# Önce kamera'nın kendi reset_zoom metodunu dene
	if camera.has_method("reset_zoom"):
		camera.reset_zoom(0.6)  # Yavaşça dön (0.6 saniye)
		print("[FoodMinigame] Camera reset zoom via reset_zoom() method")
		# Callback ile kontrol et
		await get_tree().create_timer(0.7).timeout
		print("[FoodMinigame] Camera zoom after reset: ", camera.zoom)
		# Eğer hala doğru değere dönmediyse, manuel olarak ayarla
		if camera.zoom.distance_to(_default_camera_zoom) > 0.1:
			print("[FoodMinigame] WARNING: Camera did not reset correctly, forcing manual reset")
			camera.zoom = _default_camera_zoom
		return
	
	# Eğer reset_zoom yoksa, manuel olarak zoom_to_vector veya tween kullan
	if camera.has_method("zoom_to_vector"):
		camera.zoom_to_vector(_default_camera_zoom, 0.6)
		print("[FoodMinigame] Camera reset zoom to: ", _default_camera_zoom)
	else:
		# Manuel zoom animasyonu - kesin çalışır
		if _camera_zoom_tween and _camera_zoom_tween.is_running():
			_camera_zoom_tween.kill()
		_camera_zoom_tween = create_tween()
		_camera_zoom_tween.tween_property(camera, "zoom", _default_camera_zoom, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_camera_zoom_tween.tween_callback(func(): print("[FoodMinigame] Camera zoom reset complete - final zoom: ", camera.zoom))
		print("[FoodMinigame] Camera reset zoom (manual tween) to: ", _default_camera_zoom)

func _find_player_camera() -> Camera2D:
	# Player'ı bul ve kamerasını döndür
	var player_list := get_tree().get_nodes_in_group("player")
	if player_list.is_empty():
		return null
	
	var player := player_list[0] as Node2D
	if not player:
		return null
	
	# Player'ın Camera2D'sini bul
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		return camera
	
	# Alternatif: Viewport'tan aktif kamerayı al
	var viewport_camera := get_viewport().get_camera_2d()
	if viewport_camera:
		return viewport_camera
	
	return null

func _show_resource_gain_text(amount: int) -> void:
	# Çalının tepesinde "+X" floating text göster
	print("[FoodMinigame] _show_resource_gain_text() called with amount=", amount)
	
	if not _bush_node or not is_instance_valid(_bush_node):
		print("[FoodMinigame] ERROR: _bush_node is null or invalid!")
		return
	
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	if not damage_number:
		print("[FoodMinigame] ERROR: Failed to instantiate DAMAGE_NUMBER_SCENE")
		return
	
	# Çalının tepesinde spawn pozisyonu
	var bush_pos := _bush_node.global_position
	var text_pos := Vector2(bush_pos.x, bush_pos.y - 60.0)  # Çalının tepesinde
	
	print("[FoodMinigame] Bush position: ", bush_pos, " Text position: ", text_pos)
	
	# Scene'e ekle (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _bush_node and _bush_node.get_parent():
		spawn_parent = _bush_node.get_parent()
		print("[FoodMinigame] Using bush parent as spawn_parent: ", spawn_parent.name)
	else:
		spawn_parent = get_tree().current_scene
		print("[FoodMinigame] Using scene root as spawn_parent: ", spawn_parent.name)
	
	if spawn_parent:
		spawn_parent.add_child(damage_number)
		damage_number.global_position = text_pos
		damage_number.z_index = 200000  # Çok yüksek z-index
		
		print("[FoodMinigame] Damage number added to scene at position: ", damage_number.global_position)
		
		# "+X" text'i göster (yeşil renk)
		var label := damage_number.get_node_or_null("Label") as Label
		if label:
			# setup() çağrısını yap (animasyon için gerekli)
			if damage_number.has_method("setup"):
				damage_number.setup(amount, false, false)
			# setup() text'i değiştirdi, tekrar "+" ekle
			label.text = "+" + str(amount)
			label.modulate = Color(0.2, 1.0, 0.2)  # Yeşil renk
			print("[FoodMinigame] Label text set to: ", label.text)
		else:
			print("[FoodMinigame] ERROR: Label node not found in damage_number!")
	else:
		print("[FoodMinigame] ERROR: spawn_parent is null!")

func emit_result(success: bool, payload: Dictionary) -> void:
	if is_finished():
		return
	if _gauge:
		_cleanup_gauge()
	_release_hurtbox()
	# Havadaki meyveleri temizle
	for fruit in _active_fruits:
		if is_instance_valid(fruit):
			fruit.queue_free()
	_active_fruits.clear()
	finish(success, payload)

func _cleanup_gauge() -> void:
	if _gauge and is_instance_valid(_gauge):
		_gauge.queue_free()
		_gauge = null

func _release_hurtbox() -> void:
	if _hurtbox and is_instance_valid(_hurtbox):
		_hurtbox.release_minigame(self)
		_hurtbox.queue_free()
		_hurtbox = null

func _node_path_from_value(value) -> NodePath:
	if value is NodePath:
		return value
	if value is String:
		return NodePath(value)
	return NodePath("")


