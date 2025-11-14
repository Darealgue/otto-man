extends "res://ui/minigames/MinigameBase.gd"

const ResourceType = preload("res://resources/resource_types.gd")
const WoodcutGauge = preload("res://ui/minigames/wood/WoodcutGauge.gd")
const WoodcutHurtbox = preload("res://ui/minigames/wood/WoodcutHurtbox.gd")
const FALLING_LEAF_SCENE := preload("res://ui/minigames/wood/falling_leaf.tscn")
const WOOD_PIECE_SCENE := preload("res://ui/minigames/wood/wood_piece.tscn")
const FALLING_LEAF_ANIMATOR_SCRIPT := preload("res://ui/minigames/wood/FallingLeafAnimator.gd")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")

@export var base_indicator_speed: float = 0.65
@export var indicator_speed_variation: float = 0.45
@export var min_indicator_speed: float = 0.45
@export var sweet_width_easy: float = 0.28
@export var sweet_width_hard: float = 0.16
@export var anchor_offset_default: Vector2 = Vector2(0, -110)
@export var success_feedback_color: Color = Color(0.4, 0.9, 0.6, 1.0)
@export var fail_feedback_color: Color = Color(0.95, 0.35, 0.35, 1.0)
@export var neutral_feedback_color: Color = Color(0.85, 0.85, 0.85, 1.0)

var _required_hits: int = 3
var _base_reward: int = 3
var _perfect_bonus: int = 1
var _resource_type: String = ResourceType.WOOD
var _max_misses: int = 3
var _hits: int = 0
var _misses: int = 0
var _indicator_value: float = 0.5
var _indicator_speed: float = 0.6
var _indicator_direction: float = 1.0
var _sweet_center: float = 0.5
var _sweet_width: float = 0.22
var _anchor_path: NodePath = NodePath("")
var _anchor_offset: Vector2 = Vector2.ZERO
var _gauge: WoodcutGauge = null
var _rng := RandomNumberGenerator.new()
var _tree_path: NodePath = NodePath("")
var _player_path: NodePath = NodePath("")
var _tree_node: Node2D = null
var _player_node: Node2D = null
var _cancel_distance: float = 375.0
var _hurtbox: WoodcutHurtbox = null
var _tree_sprite: AnimatedSprite2D = null
var _effect_root: Node2D = null
var _debug_sprite_logs_enabled: bool = true
# Yapraklar artık kendi scriptlerinde animasyon yapıyor, array'e gerek yok

func _on_minigame_ready() -> void:
	_rng.randomize()
	pause_game = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_required_hits = max(1, int(get_context_value("hits_required", 3)))
	_base_reward = int(get_context_value("resource_base", 3))
	_perfect_bonus = int(get_context_value("perfect_bonus", 1))
	_resource_type = String(get_context_value("resource_type", ResourceType.WOOD))
	var difficulty_level: int = clampi(int(get_context_value("difficulty", 1)), 1, 5)
	_anchor_offset = Vector2(get_context_value("anchor_offset", anchor_offset_default))
	_max_misses = int(get_context_value("max_misses", max(2, ceil(float(_required_hits) * 0.6))))
	_cancel_distance = float(get_context_value("cancel_distance", 375.0))
	_tree_path = _node_path_from_value(get_context_value("tree_path", NodePath("")))
	_player_path = _node_path_from_value(get_context_value("player_path", NodePath("")))
	_ensure_nodes()
	_update_sweet_width(difficulty_level)
	_setup_anchor()
	_setup_hurtbox()
	_setup_tree_visual()
	_reset_indicator(true)
	_update_gauge_state()
	if _gauge:
		_gauge.set_feedback("Heavy Attack ile vur!", neutral_feedback_color, 1.4)
	set_process(true)
	print("[WoodRhythmMinigame] Timing minigame active (hits=%d, max_misses=%d)" % [_required_hits, _max_misses])

func _process(delta: float) -> void:
	# Yapraklar artık kendi scriptlerinde animasyon yapıyor, burada güncellemeye gerek yok
	
	# Minigame logic'i (sadece minigame aktifken)
	if is_finished():
		return
	if _handle_distance_check():
		return
	_indicator_value += _indicator_direction * _indicator_speed * delta
	if _indicator_value <= 0.0:
		_indicator_value = 0.0
		_indicator_direction = 1.0
	elif _indicator_value >= 1.0:
		_indicator_value = 1.0
		_indicator_direction = -1.0
	if _gauge:
		_gauge.set_indicator(_indicator_value)

func _on_woodcut_hurtbox_hit(hitbox: Area2D) -> void:
	if is_finished():
		return
	if not (hitbox is PlayerHitbox):
		return
	var player_hitbox := hitbox as PlayerHitbox
	if not _is_heavy_hit(player_hitbox):
		if _gauge:
			_gauge.set_feedback("Sadece heavy attack işe yarar!", fail_feedback_color, 0.9)
		return

	# Sadece başarılı vuruşlarda yaprak dökülür (_attempt_heavy_strike içinde)
	_attempt_heavy_strike(player_hitbox)

func _attempt_heavy_strike(_hitbox: PlayerHitbox) -> void:
	if is_finished():
		return
	if _handle_distance_check():
		return
	var distance: float = abs(_indicator_value - _sweet_center)
	var threshold: float = _sweet_width * 0.5
	if distance <= threshold:
		_hits += 1
		_play_tree_hit_animation()
		_spawn_hit_effects()
		if _gauge:
			_gauge.set_hits(_hits, _required_hits)
			_gauge.set_feedback("İsabet!", success_feedback_color)
		_reset_indicator(true)
		if _hits >= _required_hits:
			# Perfect: 5'te 5 ve hiç ıskalamadan → 2 odun, diğer durumlarda → 1 odun
			var amount := 2 if (_misses == 0 and _hits >= _required_hits) else 1
			_cleanup_gauge()
			_play_tree_fall_animation()
			_spawn_wood_pieces()
			_show_resource_gain_text(amount)
			emit_result(true, {
				"resource_type": _resource_type,
				"amount": amount,
				"hits": _hits,
				"misses": _misses,
			})
	else:
		_misses += 1
		if _gauge:
			_gauge.set_hits(_hits, _required_hits)
			_gauge.set_feedback("Iska!", fail_feedback_color)
			_gauge.flash_fail_region()
		_reset_indicator(false)
		if _misses >= _max_misses:
			_reset_tree_visual()
			emit_result(false, {
				"resource_type": _resource_type,
				"amount": 0,
				"hits": _hits,
				"misses": _misses,
			})

func emit_result(success: bool, payload: Dictionary) -> void:
	if is_finished():
		return
	if _gauge:
		_cleanup_gauge()
	_release_hurtbox()
	if not success:
		_reset_tree_visual()
	# Yapraklar düşmeye devam etsin (tahta parçaları gibi)
	finish(success, payload)

func _setup_anchor() -> void:
	_anchor_path = _tree_path
	if _anchor_path.is_empty():
		_add_gauge_to_self()
		return
	var anchor_node: Node2D = _resolve_node2d(_anchor_path)
	if anchor_node:
		_tree_node = anchor_node
		var gauge := WoodcutGauge.new()
		anchor_node.add_child(gauge)
		gauge.position = _anchor_offset
		gauge.set_hits(_hits, _required_hits)
		gauge.set_sweet_spot(_sweet_center, _sweet_width)
		_gauge = gauge
	else:
		_add_gauge_to_self()

func _add_gauge_to_self() -> void:
	var gauge := WoodcutGauge.new()
	add_child(gauge)
	gauge.position = _anchor_offset
	gauge.set_hits(_hits, _required_hits)
	gauge.set_sweet_spot(_sweet_center, _sweet_width)
	_gauge = gauge

func _cleanup_gauge() -> void:
	if _gauge and is_instance_valid(_gauge):
		_gauge.queue_free()
	_gauge = null

func _setup_hurtbox() -> void:
	if !_tree_node or !is_instance_valid(_tree_node):
		return
	var existing := _tree_node.get_node_or_null("WoodcutHurtbox")
	if existing and existing is WoodcutHurtbox:
		_hurtbox = existing as WoodcutHurtbox
	else:
		_hurtbox = WoodcutHurtbox.new()
		_hurtbox.name = "WoodcutHurtbox"
		_tree_node.add_child(_hurtbox)
		_configure_hurtbox_shape()
	if _hurtbox:
		_hurtbox.bind_minigame(self)

func _configure_hurtbox_shape() -> void:
	if !_hurtbox:
		return
	var hurt_shape: CollisionShape2D = _hurtbox.get_node_or_null("CollisionShape2D")
	if hurt_shape == null:
		hurt_shape = CollisionShape2D.new()
		hurt_shape.name = "CollisionShape2D"
		_hurtbox.add_child(hurt_shape)
		hurt_shape.position = Vector2.ZERO
	var source_shape_node := _tree_node.get_node_or_null("CollisionShape2D")
	if source_shape_node and source_shape_node is CollisionShape2D and source_shape_node.shape:
		hurt_shape.shape = source_shape_node.shape.duplicate(true)
		hurt_shape.position = source_shape_node.position
	elif hurt_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(72.0, 128.0)
		hurt_shape.shape = rect
		hurt_shape.position = Vector2(0.0, -rect.size.y * 0.5)

func _release_hurtbox() -> void:
	if _hurtbox and is_instance_valid(_hurtbox):
		_hurtbox.release_minigame(self)
		_hurtbox.queue_free()
	_hurtbox = null

func _setup_tree_visual() -> void:
	if !_tree_node or !is_instance_valid(_tree_node):
		return
	var idle_sprite_node := _tree_node.get_node_or_null("TreeIdleSprite")
	if idle_sprite_node and idle_sprite_node is AnimatedSprite2D:
		_tree_sprite = idle_sprite_node as AnimatedSprite2D
		_tree_sprite.centered = false
		_tree_sprite.offset = Vector2.ZERO
	else:
		_tree_sprite = _tree_node.get_node_or_null("WoodcutTreeSprite") as AnimatedSprite2D
		if _tree_sprite == null:
			_tree_sprite = AnimatedSprite2D.new()
			_tree_sprite.name = "WoodcutTreeSprite"
			_tree_sprite.centered = false
			_tree_sprite.offset = Vector2.ZERO
			_tree_node.add_child(_tree_sprite)
	if _tree_sprite.sprite_frames and _tree_sprite.sprite_frames.has_animation("idle"):
		_align_sprite_to_bottom("idle")
		_tree_sprite.play("idle")
	_log_tree_sprite("setup_tree_visual")
	if not _tree_sprite.animation_finished.is_connected(Callable(self, "_on_tree_animation_finished")):
		_tree_sprite.animation_finished.connect(Callable(self, "_on_tree_animation_finished"))

func _align_sprite_to_bottom(animation: String) -> void:
	if !_tree_sprite or !_tree_sprite.sprite_frames:
		return
	var frames := _tree_sprite.sprite_frames
	if not frames.has_animation(animation):
		return
	var sizes := frames.get_meta("tree_animation_sizes", {}) as Dictionary
	var max_height: float = 0.0
	var max_width: float = 0.0
	for anim_name in sizes:
		var size: Vector2 = sizes[anim_name]
		max_height = max(max_height, size.y)
		max_width = max(max_width, size.x)
	if max_height == 0.0:
		return
	if max_width == 0.0:
		return
	var base_x := 0.0
	if _tree_node and _tree_node.has_node("CollisionShape2D"):
		var shape := _tree_node.get_node("CollisionShape2D") as CollisionShape2D
		if shape:
			base_x = shape.position.x
	var base_y := -max_height
	_tree_sprite.position = Vector2(base_x - max_width * 0.5, base_y)

func _play_tree_hit_animation() -> void:
	if !_tree_sprite or !_tree_sprite.sprite_frames or not _tree_sprite.sprite_frames.has_animation("hit"):
		return
	if _tree_sprite.animation == "fall":
		return
	_align_sprite_to_bottom("hit")
	_tree_sprite.play("hit")
	_log_tree_sprite("play_tree_hit_animation")

func _play_tree_fall_animation():
	if !_tree_sprite or !_tree_sprite.sprite_frames or not _tree_sprite.sprite_frames.has_animation("fall"):
		return
	_align_sprite_to_bottom("fall")
	_tree_sprite.play("fall")
	_log_tree_sprite("play_tree_fall_animation:start")
	await _tree_sprite.animation_finished
	_log_tree_sprite("play_tree_fall_animation:end")

func _spawn_hit_effects() -> void:
	# Başarılı saldırıda yapraklar dökülür
	print("[WoodRhythm] SPAWN DEBUG - Tree position check:")
	print("  - _tree_node exists: ", _tree_node != null)
	if _tree_node:
		print("  - tree_node.global_position: ", _tree_node.global_position)
		print("  - tree_node.is_inside_tree: ", _tree_node.is_inside_tree())
		print("  - tree_node.visible: ", _tree_node.visible)
	print("  - _tree_sprite exists: ", _tree_sprite != null)
	if _tree_sprite:
		print("  - tree_sprite.global_position: ", _tree_sprite.global_position)
		print("  - tree_sprite.position (local): ", _tree_sprite.position)

	var camera := get_viewport().get_camera_2d()
	if camera:
		print("  - camera.global_position: ", camera.global_position)

	var scene_root := get_tree().current_scene
	print("  - scene_root: ", scene_root)
	print("  - scene_root.is_inside_tree: ", scene_root.is_inside_tree() if scene_root else "null")

	var leaf_count := _rng.randi_range(2, 5)
	print("  - spawning ", leaf_count, " leaves")
	for i in range(leaf_count):
		_spawn_leaf_effect()

func _spawn_leaf_effect() -> void:
	# Basit yaprak spawn - ağacın tepesinde
	var leaf := FALLING_LEAF_SCENE.instantiate() as Node2D
	if !leaf:
		print("[WoodRhythm] ERROR: Failed to instantiate leaf scene")
		return

	# AnimatedSprite2D'yi bul
	var anim_sprite := leaf.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if !anim_sprite:
		print("[WoodRhythm] ERROR: AnimatedSprite2D not found in leaf scene")
		leaf.queue_free()
		return

	# Ağacın tepesinde spawn pozisyonu (yapraklı kısım) - doğru global pozisyon kullan
	var spawn_pos := Vector2.ZERO
	if _tree_node:
		var tree_pos := _tree_node.global_position  # tree_node'un gerçek global pozisyonu
		# Ağacın tepesinde spawn et - tree_node pozisyonuna göre
		var tree_top_y := tree_pos.y - 80.0  # Ağacın tepesinde
		spawn_pos = Vector2(tree_pos.x + _rng.randf_range(-30.0, 30.0), tree_top_y + _rng.randf_range(-20.0, 20.0))
	else:
		spawn_pos = Vector2(_rng.randf_range(-100.0, 100.0), _rng.randf_range(-200.0, -100.0))

	# Leaf'i scene'e ekle - tree_node'un parent'ını kullan (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _tree_node and _tree_node.get_parent():
		spawn_parent = _tree_node.get_parent()
	else:
		spawn_parent = get_tree().current_scene

	print("  - spawn_parent: ", spawn_parent, " (from tree_node parent)")

	if spawn_parent:
		leaf.global_position = spawn_pos
		leaf.z_index = 100000  # Çok yüksek z-index
		leaf.visible = true
		# Rastgele döndürme
		leaf.rotation_degrees = _rng.randf_range(-30.0, 30.0)
		# Boyut ayarını değiştirme - senin ayarladığın boyutu kullan
		leaf.scale = Vector2.ONE

			# AnimatedSprite2D ayarları
		anim_sprite.visible = true
		anim_sprite.play()  # Animasyonu başlat

		spawn_parent.add_child(leaf)

		# Yaprağa animasyon scripti ekle (minigame'den bağımsız çalışır) - await'ten ÖNCE
		leaf.set_script(FALLING_LEAF_ANIMATOR_SCRIPT)
		
		# Düşme animasyonu parametrelerini hesapla
		var fall_distance := _rng.randf_range(200.0, 300.0)
		var horizontal_drift := _rng.randf_range(-100.0, 100.0)
		var fall_time := _rng.randf_range(4.0, 6.0)
		var start_pos := spawn_pos  # spawn_pos kullan (leaf.global_position henüz doğru olmayabilir)
		var end_pos := start_pos + Vector2(horizontal_drift, fall_distance)
		var start_rotation := leaf.rotation_degrees
		var end_rotation := start_rotation + _rng.randf_range(-360.0, 360.0)
		var start_scale := leaf.scale
		var end_scale := start_scale * _rng.randf_range(0.8, 1.2)

		# Animasyonu hemen başlat (await'ten önce, minigame kapanmadan önce)
		if leaf.has_method("start_fall"):
			leaf.start_fall(start_pos, end_pos, start_rotation, end_rotation, start_scale, end_scale, fall_time)
			print("[WoodRhythm] Leaf animation started via script - from ", start_pos, " to ", end_pos, " in ", fall_time, " seconds")
		else:
			print("[WoodRhythm] ERROR: Leaf script not found, animation will not work!")

		# Spawn sonrası detaylı kontrol (await sonrası, ama animasyon zaten başladı)
		await get_tree().process_frame
		print("[WoodRhythm] LEAF SPAWNED - POST CHECK:")
		print("  - leaf.global_position: ", leaf.global_position)
		print("  - leaf.visible: ", leaf.visible)
		print("  - leaf.z_index: ", leaf.z_index)
		print("  - leaf.modulate: ", leaf.modulate)
		print("  - leaf.is_inside_tree: ", leaf.is_inside_tree())
		print("  - parent.name: ", spawn_parent.name if spawn_parent else "null")
		print("  - parent.visible: ", spawn_parent.visible if spawn_parent else "null")
		print("  - anim_sprite.playing: ", anim_sprite.is_playing())
		print("  - anim_sprite.visible: ", anim_sprite.visible)
		print("  - anim_sprite.z_index: ", anim_sprite.z_index)
		print("  - camera_pos: ", get_viewport().get_camera_2d().global_position if get_viewport().get_camera_2d() else "null")

		# Debug log
		print("[WoodRhythm] Leaf spawned at: ", spawn_pos, " tree_pos: ", _tree_sprite.global_position if _tree_sprite else "null", " anim_sprite.playing: ", anim_sprite.is_playing(), " leaf.visible: ", leaf.visible)

func _show_resource_gain_text(amount: int) -> void:
	# Ağacın tepesinde "+1" veya "+2" floating text göster
	if not _tree_node or not is_instance_valid(_tree_node):
		return
	
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	if not damage_number:
		return
	
	# Ağacın tepesinde spawn pozisyonu
	var tree_pos := _tree_node.global_position
	var text_pos := Vector2(tree_pos.x, tree_pos.y - 100.0)  # Ağacın tepesinde
	
	# Scene'e ekle (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _tree_node and _tree_node.get_parent():
		spawn_parent = _tree_node.get_parent()
	else:
		spawn_parent = get_tree().current_scene
	
	if spawn_parent:
		spawn_parent.add_child(damage_number)
		damage_number.global_position = text_pos
		damage_number.z_index = 200000  # Çok yüksek z-index
		
		# "+1" veya "+2" text'i göster (yeşil renk)
		var label := damage_number.get_node_or_null("Label") as Label
		if label:
			# setup() çağrısını yap (animasyon için gerekli)
			if damage_number.has_method("setup"):
				damage_number.setup(amount, false, false)
			# setup() text'i değiştirdi, tekrar "+" ekle
			label.text = "+" + str(amount)
			label.modulate = Color(0.2, 1.0, 0.2)  # Yeşil renk

func _spawn_wood_pieces() -> void:
	# Ağaç kesildiğinde tahta parçaları fırlar
	print("[WoodRhythm] WOOD PIECES SPAWN DEBUG - Tree position check:")
	print("  - _tree_node exists: ", _tree_node != null)
	if _tree_node:
		print("  - tree_node.global_position: ", _tree_node.global_position)
		print("  - tree_node.is_inside_tree: ", _tree_node.is_inside_tree())
		print("  - tree_node.visible: ", _tree_node.visible)
	print("  - _tree_sprite exists: ", _tree_sprite != null)
	if _tree_sprite:
		print("  - tree_sprite.global_position: ", _tree_sprite.global_position)
		print("  - tree_sprite.position (local): ", _tree_sprite.position)

	var camera := get_viewport().get_camera_2d()
	if camera:
		print("  - camera.global_position: ", camera.global_position)

	var scene_root := get_tree().current_scene
	print("  - scene_root: ", scene_root)
	print("  - scene_root.is_inside_tree: ", scene_root.is_inside_tree() if scene_root else "null")

	var wood_count := _rng.randi_range(4, 6)
	print("  - spawning ", wood_count, " wood pieces")
	for i in range(wood_count):
		_spawn_wood_piece_effect()

func _spawn_wood_piece_effect() -> void:
	# Basit tahta parçası spawn - ağacın etrafına
	var wood_piece := WOOD_PIECE_SCENE.instantiate() as Node2D
	if !wood_piece:
		print("[WoodRhythm] ERROR: Failed to instantiate wood piece scene")
		return

	# RigidBody2D'yi bul
	var rigid_body := wood_piece.get_node_or_null("RigidBody2D") as RigidBody2D
	if !rigid_body:
		print("[WoodRhythm] ERROR: RigidBody2D not found in wood piece scene")
		wood_piece.queue_free()
		return

	# Sprite'ı bul - artık RigidBody2D'nin içinde
	var sprite := wood_piece.get_node_or_null("RigidBody2D/Sprite2D") as Sprite2D
	if !sprite:
		print("[WoodRhythm] ERROR: Sprite2D not found in wood piece scene")
		wood_piece.queue_free()
		return

	# Ağacın etrafında spawn pozisyonu - doğru global pozisyon kullan
	var spawn_pos := Vector2.ZERO
	if _tree_node:
		var tree_pos := _tree_node.global_position  # tree_node'un gerçek global pozisyonu
		# Ağacın etrafına rastgele spawn - tree_node pozisyonuna göre
		spawn_pos = tree_pos + Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-80.0, -20.0))
	else:
		spawn_pos = Vector2(_rng.randf_range(-100.0, 100.0), _rng.randf_range(-100.0, -50.0))

	# Wood piece'i scene'e ekle - tree_node'un parent'ını kullan (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _tree_node and _tree_node.get_parent():
		spawn_parent = _tree_node.get_parent()
	else:
		spawn_parent = get_tree().current_scene

	print("  - spawn_parent: ", spawn_parent, " (from tree_node parent)")

	if spawn_parent:
		wood_piece.global_position = spawn_pos
		wood_piece.z_index = 100000  # Çok yüksek z-index
		wood_piece.visible = true
		# Boyut ayarını değiştirme - senin ayarladığın boyutu kullan
		wood_piece.scale = Vector2.ONE

		# RigidBody2D ayarları - fırlama efekti için
		rigid_body.gravity_scale = 1.0
		rigid_body.linear_damp = 0.1  # Hava direnci
		rigid_body.angular_damp = 0.1

		# Güçlü fırlama hızı - rastgele yönlerde
		# Bazıları daha dik (yukarı), bazıları daha yatay fırlasın
		var horizontal_speed := _rng.randf_range(-200.0, 200.0)  # Sol-sağ
		var vertical_speed := _rng.randf_range(-400.0, -150.0)  # Yukarı (negatif = yukarı)
		# Bazıları daha dik fırlasın (daha negatif y değeri)
		if _rng.randf() < 0.4:  # %40 şansla dik fırla
			vertical_speed = _rng.randf_range(-500.0, -350.0)  # Daha dik
		var velocity := Vector2(horizontal_speed, vertical_speed)

		rigid_body.linear_velocity = velocity

		# Çeşitli dönme hareketleri - bazıları hızlı, bazıları yavaş, bazıları ters yön
		var angular_options := [-15.0, -8.0, -3.0, 3.0, 8.0, 15.0, 20.0, -20.0]  # Farklı hız seçenekleri
		var chosen_angular: float = angular_options[_rng.randi() % angular_options.size()]
		rigid_body.angular_velocity = chosen_angular

		print("[WoodRhythm] Wood piece physics - velocity: ", velocity, " angular_velocity: ", rigid_body.angular_velocity)

		# Sprite ayarları
		sprite.visible = true

		spawn_parent.add_child(wood_piece)

		# Spawn sonrası detaylı kontrol
		await get_tree().process_frame
		print("[WoodRhythm] WOOD PIECE SPAWNED - POST CHECK:")
		print("  - wood_piece.global_position: ", wood_piece.global_position)
		print("  - wood_piece.visible: ", wood_piece.visible)
		print("  - wood_piece.z_index: ", wood_piece.z_index)
		print("  - wood_piece.modulate: ", wood_piece.modulate)
		print("  - wood_piece.is_inside_tree: ", wood_piece.is_inside_tree())
		print("  - rigid_body.gravity_scale: ", rigid_body.gravity_scale)
		print("  - rigid_body.linear_velocity: ", rigid_body.linear_velocity)
		print("  - rigid_body.angular_velocity: ", rigid_body.angular_velocity)
		print("  - parent.name: ", spawn_parent.name if spawn_parent else "null")
		print("  - parent.visible: ", spawn_parent.visible if spawn_parent else "null")
		print("  - sprite.visible: ", sprite.visible)
		print("  - sprite.z_index: ", sprite.z_index)
		print("  - camera_pos: ", get_viewport().get_camera_2d().global_position if get_viewport().get_camera_2d() else "null")

		# Bir süre sonra otomatik sil (performans için)
		var timer := wood_piece.get_tree().create_timer(10.0)
		timer.timeout.connect(func():
			if is_instance_valid(wood_piece):
				wood_piece.queue_free()
		)

		# Debug log
	print("[WoodRhythm] Wood piece spawned at: ", spawn_pos, " tree_pos: ", _tree_sprite.global_position if _tree_sprite else "null")

func _reset_tree_visual() -> void:
	if _tree_sprite and _tree_sprite.sprite_frames and _tree_sprite.sprite_frames.has_animation("idle") and _tree_sprite.animation != "fall":
		_align_sprite_to_bottom("idle")
		_tree_sprite.play("idle")
	var idle_sprite_node := _tree_node.get_node_or_null("TreeIdleSprite")
	if idle_sprite_node and idle_sprite_node is CanvasItem:
		var idle := idle_sprite_node as CanvasItem
		idle.visible = true
	_log_tree_sprite("reset_tree_visual")

func _on_tree_animation_finished() -> void:
	if not _tree_sprite or !_tree_sprite.sprite_frames:
		return
	if _tree_sprite.animation == "hit" and _tree_sprite.sprite_frames.has_animation("idle"):
		_align_sprite_to_bottom("idle")
		_tree_sprite.play("idle")
	_log_tree_sprite("animation_finished")

func _get_tree_sprite_offset() -> Vector2:
	if !_tree_node:
		return Vector2.ZERO
	var idle_node := _tree_node.get_node_or_null("TreeIdleSprite")
	if idle_node and idle_node is Node2D:
		return (idle_node as Node2D).position
	var shape_node := _tree_node.get_node_or_null("CollisionShape2D")
	if shape_node and shape_node is CollisionShape2D:
		var shape := shape_node as CollisionShape2D
		return shape.position
	return Vector2.ZERO

func _ensure_nodes() -> void:
	if !_tree_node or !is_instance_valid(_tree_node):
		_tree_node = _resolve_node2d(_tree_path)
	if !_player_node or !is_instance_valid(_player_node):
		_player_node = _resolve_node2d(_player_path)
		if _player_node == null:
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0 and players[0] is Node2D:
				_player_node = players[0] as Node2D

func _handle_distance_check() -> bool:
	_ensure_nodes()
	if !_tree_node or !is_instance_valid(_tree_node):
		emit_result(false, {"resource_type": _resource_type, "amount": 0, "hits": _hits, "misses": _misses, "tree_missing": true})
		return true
	if !_player_node or !is_instance_valid(_player_node):
		return false
	var distance: float = _tree_node.global_position.distance_to(_player_node.global_position)
	if distance > _cancel_distance:
		_reset_tree_visual()
		emit_result(false, {
			"resource_type": _resource_type,
			"amount": 0,
			"hits": _hits,
			"misses": _misses,
			"distance_cancelled": true,
			"distance": distance,
		})
		return true
	return false

func _is_heavy_hit(hitbox: PlayerHitbox) -> bool:
	if hitbox == null:
		return false
	var attack_name := String(hitbox.current_attack_name)
	return attack_name.find("heavy") != -1

func _log_tree_sprite(tag: String) -> void:
	if !_debug_sprite_logs_enabled:
		return
	if !_tree_sprite:
		print("[WoodRhythm][DEBUG]", tag, "tree_sprite=null")
		return
	var anim_name: String = _tree_sprite.animation if _tree_sprite.sprite_frames else "<none>"
	var playing: bool = _tree_sprite.is_playing()
	var global_pos: Vector2 = _tree_sprite.global_position
	var local_pos: Vector2 = _tree_sprite.position
	print("[WoodRhythm][DEBUG]", tag, "anim=", anim_name, "playing=", playing, "local=", local_pos, "global=", global_pos)

func _reset_indicator(success: bool) -> void:
	_indicator_direction = -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
	_indicator_speed = _compute_indicator_speed(success)
	_indicator_value = 0.0 if _indicator_direction > 0 else 1.0
	_randomize_sweet_spot(success)
	_update_gauge_state()

func _compute_indicator_speed(success: bool) -> float:
	var base: float = max(min_indicator_speed, base_indicator_speed)
	var variation: float = _rng.randf_range(0.0, indicator_speed_variation)
	var speed: float = base + variation
	if success:
		speed += float(_hits) * 0.05
	else:
		speed += float(max(_hits, 1)) * 0.02
	return max(min_indicator_speed, speed)

func _randomize_sweet_spot(success: bool) -> void:
	var center: float = _rng.randf_range(0.25, 0.75)
	if success:
		center = clamp(center + _rng.randf_range(-0.1, 0.1), 0.2, 0.8)
	_sweet_center = center
	if _gauge:
		_gauge.set_sweet_spot(_sweet_center, _sweet_width)

func _update_sweet_width(difficulty_level: int) -> void:
	var t: float = clamp(float(difficulty_level - 1) / 4.0, 0.0, 1.0)
	_sweet_width = lerp(sweet_width_easy, sweet_width_hard, t)

func _update_gauge_state() -> void:
	if _gauge:
		_gauge.set_indicator(_indicator_value)
		_gauge.set_hits(_hits, _required_hits)
		_gauge.set_sweet_spot(_sweet_center, _sweet_width)

func _resolve_node2d(path: NodePath) -> Node2D:
	if path.is_empty():
		return null
	var node := get_tree().get_root().get_node_or_null(path)
	if node and node is Node2D:
		return node as Node2D
	return null

func _node_path_from_value(value) -> NodePath:
	match typeof(value):
		TYPE_NODE_PATH:
			return value
		TYPE_STRING:
			if String(value) == "":
				return NodePath("")
			return NodePath(value)
		_:
			return NodePath("")


func _exit_tree() -> void:
	_cleanup_gauge()
