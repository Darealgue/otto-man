extends "res://ui/minigames/MinigameBase.gd"

const ResourceType = preload("res://resources/resource_types.gd")
const StoneGauge = preload("res://ui/minigames/stone/StoneGauge.gd")
const StoneHurtbox = preload("res://ui/minigames/stone/StoneHurtbox.gd")
const ROCK_PIECE_SCENE := preload("res://ui/minigames/stone/rock_piece.tscn")
const ROCK_PIECE_TEXTURE := preload("res://ui/minigames/stone/rock_piece.png")
const ROCK_PIECE2_TEXTURE := preload("res://ui/minigames/stone/rock_piece2.png")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")

# Bar ayarları
@export var fill_speed_base: float = 1.2  # Bar dolum hızı (tier 1 için)
@export var fill_speed_per_tier: float = 0.2  # Her tier için hız artışı
@export var success_zone_threshold: float = 0.85  # Bar'ın en üst %15'lik kısmı (0.85-1.0 arası başarılı)
@export var speed_change_min: float = 0.8  # Her vuruştan sonra minimum hız çarpanı
@export var speed_change_max: float = 1.3  # Her vuruştan sonra maksimum hız çarpanı
@export var min_speed: float = 0.5  # Minimum hız sınırı
@export var max_speed: float = 2.5  # Maksimum hız sınırı

# Görsel ayarlar
@export var success_feedback_color: Color = Color(0.4, 0.9, 0.6, 1.0)
@export var fail_feedback_color: Color = Color(0.95, 0.35, 0.35, 1.0)
@export var anchor_offset_default: Vector2 = Vector2(0, 75)  # Bar aşağıda (taşı kapatmamak için)

# Oyun değişkenleri
var _required_hits: int = 3
var _base_reward: int = 1  # Normal ödül: 1 taş
var _perfect_bonus: int = 1  # Üstün başarı bonusu: +1 taş (toplam 2)
var _resource_type: String = ResourceType.STONE
var _tier: int = 1
var _current_hits: int = 0
var _current_progress: float = 0.0  # 0.0 - 1.0 arası
var _total_misses: int = 0  # Toplam miss sayısı (üstün başarı kontrolü için)
var _max_misses: int = 3  # Maksimum miss sayısı (bu kadar miss'ten sonra oyun sıfırlanır)
var _misses: int = 0  # Mevcut miss sayısı

# Bar durumu
var _fill_value: float = 0.0  # 0.0 = alt, 1.0 = üst
var _fill_speed: float = 1.2
var _fill_direction: float = 1.0  # 1.0 = doluyor, -1.0 = boşalıyor

# UI referansları
var _gauge: StoneGauge = null
var _anchor_path: NodePath = NodePath("")
var _anchor_offset: Vector2 = Vector2.ZERO
var _rock_node: Node2D = null
var _rock_path: NodePath = NodePath("")
var _hurtbox: StoneHurtbox = null
var _rng := RandomNumberGenerator.new()

func _on_minigame_ready() -> void:
	_rng.randomize()
	pause_game = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Context'ten değerleri al
	_required_hits = max(1, int(get_context_value("required_hits", 3)))
	_base_reward = int(get_context_value("resource_base", 1))  # Varsayılan 1
	_perfect_bonus = int(get_context_value("perfect_bonus", 1))  # Varsayılan 1
	_resource_type = String(get_context_value("resource_type", ResourceType.STONE))
	_tier = clampi(int(get_context_value("tier", 1)), 1, 5)
	_rock_path = _node_path_from_value(get_context_value("rock_path", NodePath("")))
	_anchor_offset = Vector2(get_context_value("anchor_offset", anchor_offset_default))
	_max_misses = int(get_context_value("max_misses", max(2, ceil(float(_required_hits) * 0.6))))
	
	# Hız ayarlarını tier'a göre ayarla
	_fill_speed = fill_speed_base + (fill_speed_per_tier * (_tier - 1))
	
	# Node'ları bul
	_setup_nodes()
	_setup_anchor()
	_setup_hurtbox()
	_reset_game_state()
	_reset_bar()
	_update_gauge_state()
	
	set_process(true)
	print("[StoneMinigame] Vertical bar minigame active (hits=%d, max_misses=%d, tier=%d, speed=%.2f, success_zone=%.2f-1.0)" % [_required_hits, _max_misses, _tier, _fill_speed, success_zone_threshold])

func _setup_nodes() -> void:
	# Taş node'unu bul
	if not _rock_path.is_empty():
		_rock_node = get_node_or_null(_rock_path)
		if _rock_node:
			print("[StoneMinigame] Rock node found: %s" % _rock_node.name)
		else:
			print("[StoneMinigame] Warning: Rock node not found at path: %s" % _rock_path)

func _setup_anchor() -> void:
	# Anchor node'unu bul (taşın üstünde bar göstermek için)
	if _rock_node:
		_anchor_path = _rock_node.get_path()
		var anchor_node := get_node_or_null(_anchor_path)
		if anchor_node:
			_create_gauge(anchor_node)
	else:
		# Anchor yoksa scene root'a ekle
		var scene_root := get_tree().current_scene
		if scene_root:
			_create_gauge(scene_root)

func _create_gauge(parent: Node) -> void:
	_gauge = StoneGauge.new()
	parent.add_child(_gauge)
	_gauge.z_index = 1000
	if _rock_node:
		_gauge.global_position = _rock_node.global_position + _anchor_offset
	else:
		_gauge.global_position = Vector2(960, 540)  # Ekran merkezi
	print("[StoneMinigame] Gauge created at position: %s" % _gauge.global_position)

func _setup_hurtbox() -> void:
	if not _rock_node:
		print("[StoneMinigame] Warning: Cannot create hurtbox, rock node not found")
		return
	
	# Taş node'una hurtbox ekle
	_hurtbox = StoneHurtbox.new()
	_rock_node.add_child(_hurtbox)
	_hurtbox.bind_minigame(self)
	
	# CollisionShape2D ekle
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(64, 96)  # Taş boyutu
	shape.shape = rect_shape
	shape.position = Vector2(0, -48)  # Taşın merkezine göre
	_hurtbox.add_child(shape)
	
	print("[StoneMinigame] Hurtbox created and bound to minigame")

func _process(delta: float) -> void:
	if is_finished():
		return
	
	# Bar dolum/boşalma animasyonu
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

func _on_stone_hurtbox_hit(hitbox: Area2D) -> void:
	if is_finished():
		return
	if not (hitbox is PlayerHitbox):
		return
	var player_hitbox := hitbox as PlayerHitbox
	if not _is_heavy_hit(player_hitbox):
		if _gauge:
			_gauge.set_feedback("Sadece heavy attack işe yarar!", fail_feedback_color, 0.9)
		return
	
	# Sadece heavy attack ile vuruş yapılabilir
	_attempt_hit()

func _is_heavy_hit(hitbox: PlayerHitbox) -> bool:
	if hitbox == null:
		return false
	var attack_name := String(hitbox.current_attack_name)
	return attack_name.find("heavy") != -1

func _attempt_hit() -> void:
	if is_finished():
		return
	
	# Bar'ın sağ tarafı (fill_value 1.0 = sağ)
	var bar_right: float = _fill_value
	
	# Bar'ın sağ tarafı en sağ %15'lik bölgede mi? (0.85-1.0 arası)
	if bar_right >= success_zone_threshold:
		# Bar'ın sağ tarafı başarılı bölgede
		_on_perfect_hit()
	else:
		# Bar henüz başarılı bölgeye ulaşmadı
		var distance: float = success_zone_threshold - bar_right
		_on_miss("Çok erken! (%.1f%% kaldı)" % (distance * 100.0))

func _on_perfect_hit() -> void:
	_current_hits += 1
	_current_progress = float(_current_hits) / float(_required_hits)
	
	# Feedback
	if _gauge:
		_gauge.set_feedback("PERFECT! (%d/%d)" % [_current_hits, _required_hits], success_feedback_color)
	
	# Taş hit animasyonu
	_play_rock_hit_animation()
	
	# Her başarılı vuruşta 1-2 rock piece fırlat
	var piece_count := _rng.randi_range(1, 2)
	for i in range(piece_count):
		_spawn_rock_piece_effect()
	
	# Taş çatlama efekti
	_apply_crack_visual(_current_progress)
	
	# Başarılı vuruş sayısı yeterli mi?
	if _current_hits >= _required_hits:
		_on_success()
	else:
		# Hızı rastgele değiştir
		_change_speed()
		# Yeni bar başlat
		_reset_bar()

func _on_miss(reason: String) -> void:
	_misses += 1
	_total_misses += 1  # Toplam miss sayısını artır (perfect bonus için)
	
	# Feedback
	if _gauge:
		_gauge.set_feedback("Iska! (%d/%d)" % [_misses, _max_misses], fail_feedback_color)
		_gauge.set_hits(_current_hits, _required_hits)
	
	# Yeni bar başlat
	_reset_bar()
	
	# Maksimum miss sayısına ulaşıldı mı?
	if _misses >= _max_misses:
		# İlerlemeyi sıfırla ve oyunu bitir
		_current_hits = 0
		_current_progress = 0.0
		_apply_crack_visual(0.0)
		emit_result(false, {
			"resource_type": _resource_type,
			"amount": 0,
			"hits": _current_hits,
			"misses": _misses,
		})

func _change_speed() -> void:
	# Hızı rastgele değiştir (çarpma faktörü ile)
	var speed_multiplier: float = _rng.randf_range(speed_change_min, speed_change_max)
	_fill_speed *= speed_multiplier
	# Hız sınırlarını kontrol et
	_fill_speed = clamp(_fill_speed, min_speed, max_speed)
	print("[StoneMinigame] Speed changed to: %.2f (multiplier: %.2f)" % [_fill_speed, speed_multiplier])

func _reset_bar() -> void:
	_fill_value = 0.0  # Bar'ı sıfırla
	_fill_direction = 1.0  # Dolmaya başla

func _reset_game_state() -> void:
	# Oyun başladığında veya yeni bir oyun başlatıldığında state'i sıfırla
	_current_hits = 0
	_current_progress = 0.0
	_total_misses = 0
	_misses = 0
	_fill_value = 0.0
	_fill_direction = 1.0

func _update_gauge_state() -> void:
	if _gauge:
		_gauge.set_fill_value(_fill_value)
		_gauge.set_success_zone_threshold(success_zone_threshold)
		_gauge.set_hits(_current_hits, _required_hits)

func _play_rock_hit_animation() -> void:
	# Taş hit animasyonu oynat
	if _rock_node and _rock_node.has_method("play_hit_animation"):
		_rock_node.play_hit_animation()

func _play_rock_break_animation() -> void:
	# Taş break animasyonu oynat
	if _rock_node and _rock_node.has_method("play_break_animation"):
		_rock_node.play_break_animation()

func _apply_crack_visual(progress: float) -> void:
	# Taş node'una çatlama efekti uygula
	if _rock_node and _rock_node.has_method("_apply_cracked_visual"):
		_rock_node._apply_cracked_visual(progress)
	elif _rock_node and _rock_node.has_node("Sprite2D"):
		var sprite := _rock_node.get_node("Sprite2D") as Sprite2D
		if sprite:
			var intensity := clampf(progress, 0.0, 1.0)
			sprite.modulate = Color(1.0, 1.0 - 0.4 * intensity, 1.0 - 0.4 * intensity, 1.0)

func _on_success() -> void:
	# Taş break animasyonu
	_play_rock_break_animation()
	
	# Taş parçalarını spawn et
	_spawn_rock_pieces()
	
	# Kaynak kazancı hesapla
	var total_reward := _base_reward
	# Üstün başarı: Hiç miss olmadan tüm vuruşları tamamlamak
	if _total_misses == 0:
		total_reward += _perfect_bonus
	
	# Floating text göster
	_show_resource_gain_text(total_reward)
	
	# Başarı mesajı
	if _gauge:
		_gauge.set_feedback("BAŞARILI! +%d Taş" % total_reward, success_feedback_color)
	
	# Minigame'i bitir
	emit_result(true, {
		"amount": total_reward,
		"resource_type": _resource_type,
		"progress": _current_progress
	})

func emit_result(success: bool, payload: Dictionary) -> void:
	if is_finished():
		return
	if _gauge:
		_cleanup_gauge()
	_release_hurtbox()
	finish(success, payload)

func _spawn_rock_pieces() -> void:
	# Taş kırıldığında taş parçaları fırlar
	var rock_count := _rng.randi_range(4, 6)
	for i in range(rock_count):
		_spawn_rock_piece_effect()

func _spawn_rock_piece_effect() -> void:
	var rock_piece := ROCK_PIECE_SCENE.instantiate() as Node2D
	if not rock_piece:
		print("[StoneMinigame] ERROR: Failed to instantiate rock piece scene")
		return

	# RigidBody2D'yi bul
	var rigid_body := rock_piece.get_node_or_null("RigidBody2D") as RigidBody2D
	if not rigid_body:
		print("[StoneMinigame] ERROR: RigidBody2D not found in rock piece scene")
		rock_piece.queue_free()
		return

	# Sprite'ı bul
	var sprite := rock_piece.get_node_or_null("RigidBody2D/Sprite2D") as Sprite2D
	if not sprite:
		print("[StoneMinigame] ERROR: Sprite2D not found in rock piece scene")
		rock_piece.queue_free()
		return

	# Taşın etrafında spawn pozisyonu
	var spawn_pos := Vector2.ZERO
	if _rock_node:
		var rock_pos := _rock_node.global_position
		# Taşın etrafına rastgele spawn
		spawn_pos = rock_pos + Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-80.0, -20.0))
	else:
		spawn_pos = Vector2(_rng.randf_range(-100.0, 100.0), _rng.randf_range(-100.0, -50.0))

	# Rock piece'i scene'e ekle - rock_node'un parent'ını kullan (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _rock_node and _rock_node.get_parent():
		spawn_parent = _rock_node.get_parent()
	else:
		spawn_parent = get_tree().current_scene

	if spawn_parent:
		rock_piece.global_position = spawn_pos
		rock_piece.z_index = 100000  # Çok yüksek z-index
		rock_piece.visible = true
		rock_piece.scale = Vector2.ONE

		# RigidBody2D ayarları - fırlama efekti için
		rigid_body.gravity_scale = 1.0
		rigid_body.linear_damp = 0.1  # Hava direnci
		rigid_body.angular_damp = 0.1

		# Güçlü fırlama hızı - rastgele yönlerde
		var horizontal_speed := _rng.randf_range(-200.0, 200.0)  # Sol-sağ
		var vertical_speed := _rng.randf_range(-400.0, -150.0)  # Yukarı (negatif = yukarı)
		# Bazıları daha dik fırlasın
		if _rng.randf() < 0.4:  # %40 şansla dik fırla
			vertical_speed = _rng.randf_range(-500.0, -350.0)  # Daha dik
		var velocity := Vector2(horizontal_speed, vertical_speed)

		rigid_body.linear_velocity = velocity

		# Çeşitli dönme hareketleri
		var angular_options := [-15.0, -8.0, -3.0, 3.0, 8.0, 15.0, 20.0, -20.0]
		var chosen_angular: float = angular_options[_rng.randi() % angular_options.size()]
		rigid_body.angular_velocity = chosen_angular

		# Sprite ayarları - rastgele rock_piece veya rock_piece2 kullan
		if sprite:
			var textures: Array[Texture2D] = [ROCK_PIECE_TEXTURE, ROCK_PIECE2_TEXTURE]
			var chosen_texture: Texture2D = textures[_rng.randi() % textures.size()]
			sprite.texture = chosen_texture
			sprite.visible = true

		spawn_parent.add_child(rock_piece)

func _show_resource_gain_text(amount: int) -> void:
	# Taşın tepesinde "+X" floating text göster
	if not _rock_node or not is_instance_valid(_rock_node):
		return
	
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	if not damage_number:
		return
	
	# Taşın tepesinde spawn pozisyonu
	var rock_pos := _rock_node.global_position
	var text_pos := Vector2(rock_pos.x, rock_pos.y - 100.0)  # Taşın tepesinde
	
	# Scene'e ekle (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _rock_node and _rock_node.get_parent():
		spawn_parent = _rock_node.get_parent()
	else:
		spawn_parent = get_tree().current_scene
	
	if spawn_parent:
		spawn_parent.add_child(damage_number)
		damage_number.global_position = text_pos
		damage_number.z_index = 200000  # Çok yüksek z-index
		
		# "+X" text'i göster (yeşil renk)
		var label := damage_number.get_node_or_null("Label") as Label
		if label:
			# setup() çağrısını yap (animasyon için gerekli)
			if damage_number.has_method("setup"):
				damage_number.setup(amount, false, false)
			# setup() text'i değiştirdi, tekrar "+" ekle
			label.text = "+" + str(amount)
			label.modulate = Color(0.2, 1.0, 0.2)  # Yeşil renk

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
