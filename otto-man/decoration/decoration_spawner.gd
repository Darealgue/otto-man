extends Node2D
class_name DecorationSpawner

# Dekorasyon spawner konfigürasyonu
@export var decoration_type: DecorationConfig.DecorationType = DecorationConfig.DecorationType.GOLD
@export var spawn_location: DecorationConfig.SpawnLocation = DecorationConfig.SpawnLocation.FLOOR_CENTER
@export var auto_spawn: bool = true
@export var spawn_chance: float = 0.8
@export var current_level: int = 1
@export var chunk_type: String = "basic"

# Opsiyonel konfigürasyon
@export var force_decoration_type: String = ""  # Eğer set edilirse, sadece bu tür dekorasyon spawn eder
@export var spawn_offset: Vector2 = Vector2.ZERO

# Internal variables
var _spawned_decoration: Node2D = null
var _decoration_config: DecorationConfig
var _is_active: bool = false

# Visual marker for editor
@onready var spawn_marker: Node2D

func _ready() -> void:
	# DecorationConfig'i yükle
	_decoration_config = DecorationConfig.new()
	
	# Spawn marker'ı gizle (oyun içinde)
	spawn_marker = get_node_or_null("SpawnMarker")
	if spawn_marker:
		spawn_marker.visible = false
	
	print("[DecorationSpawner] Initialized - Type: %s, Location: %s" % [
		DecorationConfig.DecorationType.keys()[decoration_type], 
		DecorationConfig.SpawnLocation.keys()[spawn_location]
	])

func activate() -> bool:
	_is_active = true
	if auto_spawn:
		if randf() <= spawn_chance:
			_spawn_decoration()
			print("[DecorationSpawner] Activated and spawned")
			return true
		else:
			print("[DecorationSpawner] Activated but failed chance roll")
			_is_active = false
			return false
	print("[DecorationSpawner] Activated")
	return true

func deactivate() -> void:
	_is_active = false
	clear_decoration()
	print("[DecorationSpawner] Deactivated")

func _spawn_decoration() -> bool:
	# Bu lokasyon için uygun dekorasyonları al
	var available_decorations = _decoration_config.get_decorations_for_location(decoration_type, spawn_location)
	
	if available_decorations.is_empty():
		print("[DecorationSpawner] No decorations available for type: %s, location: %s" % [
			DecorationConfig.DecorationType.keys()[decoration_type],
			DecorationConfig.SpawnLocation.keys()[spawn_location]
		])
		return false
	
	# Dekorasyon türünü seç
	var decoration_name: String
	if not force_decoration_type.is_empty() and force_decoration_type in available_decorations:
		decoration_name = force_decoration_type
	else:
		decoration_name = _decoration_config.select_random_decoration(available_decorations, decoration_type)
	
	if decoration_name.is_empty():
		print("[DecorationSpawner] Failed to select decoration")
		return false
	
	# Dekorasyon instance'ını oluştur
	var decoration_instance = _create_decoration_instance(decoration_name)
	if not decoration_instance:
		print("[DecorationSpawner] Failed to create decoration instance: %s" % decoration_name)
		return false
	
	# Sahneye ekle
	get_parent().add_child(decoration_instance)
	
	# Konumunu ayarla
	var spawn_pos = global_position + spawn_offset
	decoration_instance.global_position = spawn_pos
	
	# Referansı sakla
	_spawned_decoration = decoration_instance
	_is_active = true
	
	print("[DecorationSpawner] Spawned %s at position %s" % [decoration_name, spawn_pos])
	return true

func _create_decoration_instance(decoration_name: String) -> Node2D:
	var decoration_data = _decoration_config.get_decorations_for_type(decoration_type)[decoration_name]
	
	# Temel node oluştur
	var decoration_node = Node2D.new()
	decoration_node.name = decoration_name
	
	# Sprite ekle
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	
	# Rasgele sprite seç
	var sprites = decoration_data.sprites
	var sprite_path = sprites[randi() % sprites.size()]
	
	# Sprite yükle (şimdilik placeholder)
	var texture = _create_placeholder_texture(decoration_name)
	sprite.texture = texture
	
	decoration_node.add_child(sprite)
	
	# Tip özel ayarları
	match decoration_type:
		DecorationConfig.DecorationType.GOLD:
			_setup_gold_decoration(decoration_node, decoration_data)
		DecorationConfig.DecorationType.PLATFORM:
			_setup_platform_decoration(decoration_node, decoration_data)
		DecorationConfig.DecorationType.BREAKABLE:
			_setup_breakable_decoration(decoration_node, decoration_data)
		DecorationConfig.DecorationType.BACKGROUND:
			_setup_background_decoration(decoration_node, decoration_data)
	
	return decoration_node

func _setup_gold_decoration(node: Node2D, data: Dictionary) -> void:
	# Altın toplama area'sı
	var area = Area2D.new()
	area.name = "CollectionArea"
	
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0  # Toplama mesafesi
	collision_shape.shape = shape
	
	area.add_child(collision_shape)
	node.add_child(area)
	
	# Altın değerini node'a ekle
	node.set_meta("gold_value", data.gold_value)
	node.set_meta("decoration_type", "gold")
	
	# Player detection
	area.body_entered.connect(_on_gold_collected.bind(node, data.gold_value))

func _setup_platform_decoration(node: Node2D, data: Dictionary) -> void:
	# Platform collision
	var static_body = StaticBody2D.new()
	static_body.name = "PlatformBody"
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = data.collision_size
	collision_shape.shape = shape
	
	static_body.add_child(collision_shape)
	node.add_child(static_body)
	
	node.set_meta("decoration_type", "platform")

func _setup_breakable_decoration(node: Node2D, data: Dictionary) -> void:
	# Breakable body
	var rigid_body = RigidBody2D.new()
	rigid_body.name = "BreakableBody"
	rigid_body.freeze = true  # Sabit ama kırılabilir
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = data.collision_size
	collision_shape.shape = shape
	
	rigid_body.add_child(collision_shape)
	node.add_child(rigid_body)
	
	# HP sistemi
	node.set_meta("hp", data.hp)
	node.set_meta("max_hp", data.hp)
	node.set_meta("gold_drop", data.gold_drop)
	node.set_meta("decoration_type", "breakable")
	
	# Damage detection
	var area = Area2D.new()
	area.name = "DamageArea"
	var damage_collision = CollisionShape2D.new()
	damage_collision.shape = shape
	area.add_child(damage_collision)
	node.add_child(area)
	
	# Breakable group'a ekle
	node.add_to_group("breakable_decorations")

func _setup_background_decoration(node: Node2D, data: Dictionary) -> void:
	# Sadece görsel, collision yok
	node.set_meta("decoration_type", "background")
	
	# Z-index ayarla (arka planda kalsın)
	node.z_index = -1

func _create_placeholder_texture(decoration_name: String) -> ImageTexture:
	# Placeholder texture oluştur
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	
	# Tip göre renk
	match decoration_type:
		DecorationConfig.DecorationType.GOLD:
			image.fill(Color.YELLOW)
		DecorationConfig.DecorationType.PLATFORM:
			image.fill(Color.GRAY)
		DecorationConfig.DecorationType.BREAKABLE:
			image.fill(Color.BROWN)
		DecorationConfig.DecorationType.BACKGROUND:
			image.fill(Color.DIM_GRAY)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func _on_gold_collected(node: Node2D, gold_value: int, body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[DecorationSpawner] Gold collected: %d" % gold_value)
		
		# PlayerData'ya altın ekle (varsa)
		if GlobalPlayerData:
			GlobalPlayerData.add_gold(gold_value)
		
		# Altın toplama efekti
		_create_collection_effect(node.global_position)
		
		# Node'u sil
		node.queue_free()
		_spawned_decoration = null

func _create_collection_effect(pos: Vector2) -> void:
	# Basit toplama efekti
	var effect = Node2D.new()
	effect.position = pos
	get_parent().add_child(effect)
	
	# Fade out tween
	var tween = create_tween()
	tween.tween_property(effect, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(effect.queue_free)

func get_spawned_decoration() -> Node2D:
	return _spawned_decoration

func clear_decoration() -> void:
	if _spawned_decoration and is_instance_valid(_spawned_decoration):
		_spawned_decoration.queue_free()
		_spawned_decoration = null

func set_level(level: int) -> void:
	current_level = level 