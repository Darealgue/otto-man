extends "res://ui/minigames/MinigameBase.gd"

const ResourceType = preload("res://resources/resource_types.gd")
const WellGauge = preload("res://ui/minigames/water/WellGauge.gd")
const WellHurtbox = preload("res://ui/minigames/water/WellHurtbox.gd")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")

@export var base_indicator_speed: float = 0.65
@export var indicator_speed_variation: float = 0.45
@export var min_indicator_speed: float = 0.45
@export var sweet_width_easy: float = 0.28
@export var sweet_width_hard: float = 0.16
@export var anchor_offset_default: Vector2 = Vector2(0, 75)  # Bar aşağıda (kuyuyu kapatmamak için)
@export var success_feedback_color: Color = Color(0.4, 0.9, 0.6, 1.0)
@export var fail_feedback_color: Color = Color(0.95, 0.35, 0.35, 1.0)
@export var neutral_feedback_color: Color = Color(0.85, 0.85, 0.85, 1.0)

var _required_hits: int = 3  # Artarda 3 vuruş gerekiyor
var _base_reward: int = 1  # Su kaynağı
var _perfect_bonus: int = 0
var _resource_type: String = ResourceType.WATER
var _max_misses: int = 3  # 3 miss hakkı var
var _hits: int = 0
var _misses: int = 0
var _indicator_value: float = 0.5
var _indicator_speed: float = 0.6
var _indicator_direction: float = 1.0
var _sweet_center: float = 0.5
var _sweet_width: float = 0.22
var _anchor_path: NodePath = NodePath("")
var _anchor_offset: Vector2 = Vector2.ZERO
var _gauge: WellGauge = null
var _rng := RandomNumberGenerator.new()
var _well_path: NodePath = NodePath("")
var _well_node: Node2D = null
var _hurtbox: WellHurtbox = null

func _on_minigame_ready() -> void:
	_rng.randomize()
	pause_game = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_required_hits = max(1, int(get_context_value("hits_required", 3)))
	_base_reward = int(get_context_value("resource_base", 1))
	_perfect_bonus = int(get_context_value("perfect_bonus", 0))
	_resource_type = String(get_context_value("resource_type", ResourceType.WATER))
	var difficulty_level: int = clampi(int(get_context_value("difficulty", 1)), 1, 5)
	_anchor_offset = Vector2(get_context_value("anchor_offset", anchor_offset_default))
	_max_misses = int(get_context_value("max_misses", 3))  # 3 miss hakkı var
	_well_path = _node_path_from_value(get_context_value("well_path", NodePath("")))
	_ensure_nodes()
	_update_sweet_width(difficulty_level)
	_setup_anchor()
	_setup_hurtbox()
	_reset_indicator(true)
	_update_gauge_state()
	if _gauge:
		_gauge.set_feedback("Heavy Attack ile vur! (3 artarda)", neutral_feedback_color, 1.4)
	set_process(true)
	print("[WellRhythmMinigame] Water minigame active (hits=%d, max_misses=%d)" % [_required_hits, _max_misses])

func _process(delta: float) -> void:
	if is_finished():
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

func _on_well_hurtbox_hit(hitbox: Area2D) -> void:
	if is_finished():
		return
	if not (hitbox is PlayerHitbox):
		return
	var player_hitbox := hitbox as PlayerHitbox
	if not _is_heavy_hit(player_hitbox):
		if _gauge:
			_gauge.set_feedback("Sadece heavy attack işe yarar!", fail_feedback_color, 0.9)
		return
	_attempt_heavy_strike(player_hitbox)

func _is_heavy_hit(hitbox: PlayerHitbox) -> bool:
	if hitbox == null:
		return false
	var attack_name := String(hitbox.current_attack_name)
	return attack_name.find("heavy") != -1

func _attempt_heavy_strike(_hitbox: PlayerHitbox) -> void:
	if is_finished():
		return
	var distance: float = abs(_indicator_value - _sweet_center)
	var threshold: float = _sweet_width * 0.5
	if distance <= threshold:
		_hits += 1
		# Well hit animasyonunu oynat
		_play_well_hit_animation()
		if _gauge:
			_gauge.set_hits(_hits, _required_hits)
			_gauge.set_feedback("İsabet! (%d/%d)" % [_hits, _required_hits], success_feedback_color)
		_reset_indicator(true)
		if _hits >= _required_hits:
			# Başarılı: 3 artarda vuruş
			_cleanup_gauge()
			_show_resource_gain_text(_base_reward)
			emit_result(true, {
				"resource_type": _resource_type,
				"amount": _base_reward,
				"hits": _hits,
				"misses": _misses,
			})
	else:
		# Iska: Miss sayısını artır
		_misses += 1
		if _gauge:
			_gauge.set_hits(_hits, _required_hits)
			_gauge.set_feedback("Iska! (%d/%d)" % [_misses, _max_misses], fail_feedback_color)
			_gauge.flash_fail_region()
		_reset_indicator(false)
		if _misses >= _max_misses:
			# 3 miss oldu, oyun biter
			_cleanup_gauge()
			emit_result(false, {
				"resource_type": _resource_type,
				"amount": 0,
				"hits": _hits,
				"misses": _misses,
			})

func _play_well_hit_animation() -> void:
	if _well_node and is_instance_valid(_well_node):
		if _well_node.has_method("play_hit_animation"):
			_well_node.play_hit_animation()

func emit_result(success: bool, payload: Dictionary) -> void:
	if is_finished():
		return
	if _gauge:
		_cleanup_gauge()
	_release_hurtbox()
	finish(success, payload)

func _node_path_from_value(value) -> NodePath:
	if value is NodePath:
		return value
	if value is String:
		return NodePath(value)
	return NodePath("")

func _resolve_node2d(path: NodePath) -> Node2D:
	if path.is_empty():
		return null
	var node := get_node_or_null(path) as Node2D
	return node

func _ensure_nodes() -> void:
	if not _well_path.is_empty():
		_well_node = _resolve_node2d(_well_path)
		if _well_node:
			print("[WellRhythmMinigame] Well node found: %s" % _well_node.name)
		else:
			print("[WellRhythmMinigame] Warning: Well node not found at path: %s" % _well_path)

func _setup_anchor() -> void:
	_anchor_path = _well_path
	if _anchor_path.is_empty():
		_add_gauge_to_self()
		return
	var anchor_node: Node2D = _resolve_node2d(_anchor_path)
	if anchor_node:
		_well_node = anchor_node
		var gauge := WellGauge.new()
		anchor_node.add_child(gauge)
		gauge.position = _anchor_offset
		gauge.set_hits(_hits, _required_hits)
		gauge.set_sweet_spot(_sweet_center, _sweet_width)
		_gauge = gauge
	else:
		_add_gauge_to_self()

func _add_gauge_to_self() -> void:
	var gauge := WellGauge.new()
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
	if !_well_node or !is_instance_valid(_well_node):
		return
	var existing := _well_node.get_node_or_null("WellHurtbox")
	if existing and existing is WellHurtbox:
		_hurtbox = existing as WellHurtbox
	else:
		_hurtbox = WellHurtbox.new()
		_hurtbox.name = "WellHurtbox"
		_well_node.add_child(_hurtbox)
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
	var source_shape_node := _well_node.get_node_or_null("CollisionShape2D")
	if source_shape_node and source_shape_node is CollisionShape2D and source_shape_node.shape:
		hurt_shape.shape = source_shape_node.shape.duplicate(true)
		hurt_shape.position = source_shape_node.position
	elif hurt_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(80.0, 80.0)
		hurt_shape.shape = rect
		hurt_shape.position = Vector2(0.0, -40.0)

func _release_hurtbox() -> void:
	if _hurtbox and is_instance_valid(_hurtbox):
		_hurtbox.release_minigame(self)
		_hurtbox.queue_free()
	_hurtbox = null

func _update_sweet_width(difficulty: int) -> void:
	# Difficulty 1-5 arası, sweet width'i ayarla
	var t := float(difficulty - 1) / 4.0  # 0.0 (easy) to 1.0 (hard)
	_sweet_width = lerpf(sweet_width_easy, sweet_width_hard, t)
	_sweet_center = 0.5  # Ortada
	print("[WellRhythmMinigame] Sweet spot: center=%.2f width=%.2f (difficulty=%d)" % [_sweet_center, _sweet_width, difficulty])

func _reset_indicator(reset_after_hit: bool) -> void:
	if reset_after_hit:
		# Başarılı vuruştan sonra: rastgele pozisyon ve hız
		_indicator_value = _rng.randf_range(0.2, 0.8)
		_indicator_speed = _rng.randf_range(
			base_indicator_speed - indicator_speed_variation,
			base_indicator_speed + indicator_speed_variation
		)
		_indicator_speed = max(_indicator_speed, min_indicator_speed)
		_indicator_direction = 1.0 if _rng.randf() < 0.5 else -1.0
		# Sweet spot'u da rastgele değiştir
		_sweet_center = _rng.randf_range(_sweet_width * 0.5, 1.0 - _sweet_width * 0.5)
		if _gauge:
			_gauge.set_sweet_spot(_sweet_center, _sweet_width)
	else:
		# Iska'dan sonra: ortadan başla
		_indicator_value = 0.5
		_indicator_speed = base_indicator_speed
		_indicator_direction = 1.0
		_sweet_center = 0.5
		if _gauge:
			_gauge.set_sweet_spot(_sweet_center, _sweet_width)

func _update_gauge_state() -> void:
	if _gauge:
		_gauge.set_indicator(_indicator_value)
		_gauge.set_hits(_hits, _required_hits)
		_gauge.set_sweet_spot(_sweet_center, _sweet_width)

func _show_resource_gain_text(amount: int) -> void:
	# Kuyunun tepesinde "+X" floating text göster
	if not _well_node or not is_instance_valid(_well_node):
		return
	
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	if not damage_number:
		return
	
	# Kuyunun tepesinde spawn pozisyonu
	var well_pos := _well_node.global_position
	var text_pos := Vector2(well_pos.x, well_pos.y - 60.0)  # Kuyunun tepesinde
	
	# Scene'e ekle (chunk sistemine uygun)
	var spawn_parent: Node = null
	if _well_node and _well_node.get_parent():
		spawn_parent = _well_node.get_parent()
	else:
		spawn_parent = get_tree().current_scene
	
	if spawn_parent:
		spawn_parent.add_child(damage_number)
		damage_number.global_position = text_pos
		damage_number.z_index = 200000  # Çok yüksek z-index
		
		# "+X" text'i göster (mavi renk - su için)
		var label := damage_number.get_node_or_null("Label") as Label
		if label:
			if damage_number.has_method("setup"):
				damage_number.setup(amount, false, false)
			label.text = "+" + str(amount)
			label.modulate = Color(0.2, 0.6, 1.0)  # Mavi renk

