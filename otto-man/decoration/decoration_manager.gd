extends Node
class_name DecorationManager

var _decoration_config: DecorationConfig
var _decoration_spawners: Array[DecorationSpawner] = []
var _active_spawners: Array[DecorationSpawner] = []
var _chunk_type: String = "basic"
var _current_level: int = 1

func _ready() -> void:
	_decoration_config = DecorationConfig.new()
	add_to_group("decoration_manager")
	print("[DecorationManager] Initialized")
	
	# Tüm decoration spawner'ları topla
	_collect_decoration_spawners()

func _collect_decoration_spawners() -> void:
	# Parent (chunk) içindeki tüm DecorationSpawner'ları bul
	var parent = get_parent()
	if not parent:
		return
	
	_find_decoration_spawners_recursive(parent)
	print("[DecorationManager] Found %d decoration spawners" % _decoration_spawners.size())

func _find_decoration_spawners_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is DecorationSpawner:
			_decoration_spawners.append(child as DecorationSpawner)
			child.chunk_type = _chunk_type
			print("[DecorationManager] Added spawner: %s (Type: %s, Location: %s)" % [
				child.name, 
				DecorationConfig.DecorationType.keys()[child.decoration_type],
				DecorationConfig.SpawnLocation.keys()[child.spawn_location]
			])
		else:
			_find_decoration_spawners_recursive(child)

func initialize(chunk_type: String, level: int) -> void:
	_chunk_type = chunk_type
	_current_level = level
	
	print("[DecorationManager] Initializing with chunk type: %s, level: %d" % [chunk_type, level])
	
	# Tüm spawner'ları güncel ayarlarla güncelle
	for spawner in _decoration_spawners:
		spawner.chunk_type = chunk_type
		spawner.current_level = level
	
	# Hangi spawner'ların aktif olacağını seç
	_active_spawners = _select_decoration_spawners(_decoration_spawners, chunk_type, level)
	
	# Seçili spawner'ları aktif et
	for spawner in _decoration_spawners:
		if spawner in _active_spawners:
			spawner.activate()
		else:
			spawner.deactivate()
	
	print("[DecorationManager] Activated %d out of %d spawners" % [_active_spawners.size(), _decoration_spawners.size()])

func _select_decoration_spawners(available_spawners: Array[DecorationSpawner], chunk_type: String, level: int) -> Array[DecorationSpawner]:
	var selected: Array[DecorationSpawner] = []
	
	# Chunk tipi için density bilgilerini al
	var density = _decoration_config.get_decoration_density(chunk_type)
	
	# Tür bazında spawner'ları grupla
	var gold_spawners: Array[DecorationSpawner] = []
	var background_spawners: Array[DecorationSpawner] = []
	var platform_spawners: Array[DecorationSpawner] = []
	var breakable_spawners: Array[DecorationSpawner] = []
	
	for spawner in available_spawners:
		match spawner.decoration_type:
			DecorationConfig.DecorationType.GOLD:
				gold_spawners.append(spawner)
			DecorationConfig.DecorationType.BACKGROUND:
				background_spawners.append(spawner)
			DecorationConfig.DecorationType.PLATFORM:
				platform_spawners.append(spawner)
			DecorationConfig.DecorationType.BREAKABLE:
				breakable_spawners.append(spawner)
	
	# Her tür için belirlenen sayıda spawner seç
	selected.append_array(_select_spawners_by_type(gold_spawners, density.gold_spawns))
	selected.append_array(_select_spawners_by_type(background_spawners, density.background_decorations))
	selected.append_array(_select_spawners_by_type(platform_spawners, density.platform_decorations))
	selected.append_array(_select_spawners_by_type(breakable_spawners, density.breakable_decorations))
	
	return selected

func _select_spawners_by_type(spawners: Array[DecorationSpawner], count_range: Dictionary) -> Array[DecorationSpawner]:
	var selected: Array[DecorationSpawner] = []
	
	if spawners.is_empty():
		return selected
	
	# Min-max arasında rasgele sayı seç
	var target_count = randi_range(count_range.min, count_range.max)
	target_count = mini(target_count, spawners.size())
	
	# Shuffled array'den seç
	var shuffled_spawners = spawners.duplicate()
	shuffled_spawners.shuffle()
	
	# Minimum mesafe kontrolü ile seç
	var min_distance = 150.0
	
	for spawner in shuffled_spawners:
		var too_close = false
		for selected_spawner in selected:
			if spawner.global_position.distance_to(selected_spawner.global_position) < min_distance:
				too_close = true
				break
		
		if not too_close:
			selected.append(spawner)
			if selected.size() >= target_count:
				break
	
	return selected

func get_active_decoration_spawners() -> Array[DecorationSpawner]:
	return _active_spawners

func get_active_decorations() -> Array[Node2D]:
	var decorations: Array[Node2D] = []
	for spawner in _active_spawners:
		var decoration = spawner.get_spawned_decoration()
		if decoration:
			decorations.append(decoration)
	return decorations

func clear_all_decorations() -> void:
	for spawner in _decoration_spawners:
		spawner.clear_decoration()
	print("[DecorationManager] Cleared all decorations")

func set_level(level: int) -> void:
	_current_level = level
	initialize(_chunk_type, level)  # Yeni level ile yeniden initialize et

# Debug bilgisi
func get_debug_info() -> Dictionary:
	return {
		"total_spawners": _decoration_spawners.size(),
		"active_spawners": _active_spawners.size(),
		"chunk_type": _chunk_type,
		"current_level": _current_level,
		"spawner_type_counts": _get_spawner_type_counts()
	}

func _get_spawner_type_counts() -> Dictionary:
	var counts = {
		"gold": 0,
		"background": 0,
		"platform": 0,
		"breakable": 0
	}
	
	for spawner in _decoration_spawners:
		match spawner.decoration_type:
			DecorationConfig.DecorationType.GOLD:
				counts.gold += 1
			DecorationConfig.DecorationType.BACKGROUND:
				counts.background += 1
			DecorationConfig.DecorationType.PLATFORM:
				counts.platform += 1
			DecorationConfig.DecorationType.BREAKABLE:
				counts.breakable += 1
	
	return counts

# Breakable decoration damage handling
func handle_decoration_damage(decoration: Node2D, damage: int) -> void:
	if not decoration or not decoration.has_meta("decoration_type"):
		return
	
	if decoration.get_meta("decoration_type") != "breakable":
		return
	
	var current_hp = decoration.get_meta("hp", 0)
	current_hp -= damage
	decoration.set_meta("hp", current_hp)
	
	print("[DecorationManager] Decoration took %d damage, HP: %d" % [damage, current_hp])
	
	if current_hp <= 0:
		_break_decoration(decoration)

func _break_decoration(decoration: Node2D) -> void:
	print("[DecorationManager] Decoration broken!")
	
	# Altın drop et
	var gold_drop = decoration.get_meta("gold_drop", {})
	if not gold_drop.is_empty():
		var gold_amount = randi_range(gold_drop.min, gold_drop.max)
		_spawn_gold_drops(decoration.global_position, gold_amount)
	
	# Break efekti
	_create_break_effect(decoration.global_position)
	
	# Decoration'ı sil
	decoration.queue_free()

func _spawn_gold_drops(pos: Vector2, amount: int) -> void:
	# Kırılan objeden altın coinler çıkar
	for i in range(amount):
		var coin = Node2D.new()
		coin.name = "DroppedGold"
		
		# Basit altın sprite
		var sprite = Sprite2D.new()
		var texture = ImageTexture.new()
		var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
		image.fill(Color.YELLOW)
		texture.create_from_image(image)
		sprite.texture = texture
		coin.add_child(sprite)
		
		# Collection area
		var area = Area2D.new()
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 20.0
		collision.shape = shape
		area.add_child(collision)
		coin.add_child(area)
		
		# Rasgele konum
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		coin.global_position = pos + offset
		
		# Gold value
		coin.set_meta("gold_value", 1)
		
		# Collection signal
		area.body_entered.connect(_on_dropped_gold_collected.bind(coin))
		
		get_parent().add_child(coin)

func _on_dropped_gold_collected(coin: Node2D, body: Node2D) -> void:
	if body.is_in_group("player"):
		var gold_value = coin.get_meta("gold_value", 1)
		
		if GlobalPlayerData:
			GlobalPlayerData.add_gold(gold_value)
		
		print("[DecorationManager] Dropped gold collected: %d" % gold_value)
		coin.queue_free()

func _create_break_effect(pos: Vector2) -> void:
	# Basit kırılma efekti
	var effect = Node2D.new()
	effect.position = pos
	get_parent().add_child(effect)
	
	# Parçacık benzeri efekt (basit)
	for i in range(5):
		var particle = Node2D.new()
		var sprite = Sprite2D.new()
		var texture = ImageTexture.new()
		var image = Image.create(8, 8, false, Image.FORMAT_RGB8)
		image.fill(Color.BROWN)
		texture.create_from_image(image)
		sprite.texture = texture
		particle.add_child(sprite)
		effect.add_child(particle)
		
		# Rasgele hareket
		var tween = create_tween()
		var target_pos = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		tween.parallel().tween_property(particle, "position", target_pos, 0.5)
		tween.parallel().tween_property(particle, "modulate", Color.TRANSPARENT, 0.5)
	
	# Efekti temizle
	var cleanup_tween = create_tween()
	cleanup_tween.tween_delay(0.5)
	cleanup_tween.tween_callback(effect.queue_free) 