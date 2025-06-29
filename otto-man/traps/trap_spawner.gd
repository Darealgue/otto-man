extends Node2D
class_name TrapSpawner

# Trap spawner configuration
@export var trap_category: TrapConfig.TrapCategory = TrapConfig.TrapCategory.GROUND
@export var auto_spawn: bool = true  # Whether to spawn automatically on ready
@export var spawn_on_level_start: bool = false  # Whether to wait for level start signal
@export var current_level: int = 1  # Current level number (will be set by level generator)
@export var chunk_type: String = "basic"  # Type of chunk this spawner is in
@export var spawn_chance: float = 0.8  # Increased from 0.3 for testing

# Optional configuration
@export var force_trap_type: String = ""  # If set, only spawns this type of trap
@export var spawn_offset: Vector2 = Vector2.ZERO  # Offset from spawner position

# Direction configuration for arrow shooters (only one should be true)
@export_group("Arrow Shooter Direction")
@export var shoot_right: bool = false  # Shoot to the right →
@export var shoot_left: bool = false   # Shoot to the left ←
@export var shoot_up: bool = false     # Shoot upward ↑
@export var shoot_down: bool = false   # Shoot downward ↓

# Internal variables
var _spawned_trap: BaseTrap = null
var _level_generator: Node = null
var _trap_config: TrapConfig
var _is_active: bool = false  # Whether this spawn point is active

# Visual marker for editor
@onready var spawn_marker: Node2D = $SpawnMarker

func _ready() -> void:
	# Load trap configuration
	_trap_config = TrapConfig.new()
	
	# Find level generator
	_level_generator = get_tree().get_first_node_in_group("level_generator")
	if _level_generator:
		current_level = _level_generator.current_level
		
	# Hide visual marker in game
	if spawn_marker:
		spawn_marker.visible = false
	
	print("[TrapSpawner] Initialized - Category: %s, Level: %d" % [TrapConfig.TrapCategory.keys()[trap_category], current_level])
	
	if auto_spawn and not spawn_on_level_start:
		# Don't spawn immediately, wait for activation
		pass
	elif spawn_on_level_start and _level_generator:
		if _level_generator.has_signal("level_started"):
			_level_generator.level_started.connect(_on_level_started)

func activate() -> bool:
	_is_active = true
	if auto_spawn:
		if randf() <= spawn_chance:
			_spawn_trap()
			print("[TrapSpawner] Activated")
			return true
		else:
			print("[TrapSpawner] Deactivated")
			_is_active = false
			return false
	print("[TrapSpawner] Activated")
	return true

func deactivate() -> void:
	_is_active = false
	clear_trap()
	print("[TrapSpawner] Deactivated")

func _on_level_started() -> void:
	if _is_active:
		_spawn_trap()

func _spawn_trap() -> bool:
	var trap_types = TrapConfig.get_traps_for_category(trap_category)
	if trap_types.is_empty():
		print("[TrapSpawner] No traps available for category: %s" % TrapConfig.TrapCategory.keys()[trap_category])
		return false
	
	# Select trap type (for now, random selection)
	var trap_type: String
	if not force_trap_type.is_empty() and force_trap_type in trap_types:
		trap_type = force_trap_type
	else:
		trap_type = trap_types[randi() % trap_types.size()]
	
	# Load appropriate scene based on trap type
	var trap_scene: PackedScene
	match trap_type:
		"spike_trap":
			trap_scene = preload("res://traps/ground/spike_trap.tscn")
		"fire_geyser":
			trap_scene = preload("res://traps/ground/fire_geyser.tscn")
		"arrow_shooter":
			trap_scene = preload("res://traps/wall/arrow_shooter.tscn")
		"cannon_trap":
			trap_scene = preload("res://traps/wall/cannon_trap.tscn")
		"rotating_saw":
			# Will implement later
			print("[TrapSpawner] Rotating saw not implemented yet")
			return false
		"pendulum_axe":
			trap_scene = preload("res://traps/ceiling/pendulum_axe.tscn")
		_:
			print("[TrapSpawner] Unknown trap type: %s" % trap_type)
			return false
	
	if not trap_scene:
		print("[TrapSpawner] Failed to load scene for trap type: %s" % trap_type)
		return false
	
	# Instantiate and setup trap
	var trap_instance = trap_scene.instantiate()
	if not trap_instance:
		print("[TrapSpawner] Failed to instantiate trap: %s" % trap_type)
		return false
	
	# Set direction properties for directional traps BEFORE adding to scene
	if trap_type == "arrow_shooter":
		print("[TrapSpawner] Setting arrow shooter directions: R=%s L=%s U=%s D=%s" % [shoot_right, shoot_left, shoot_up, shoot_down])
		trap_instance.shoot_right = shoot_right
		trap_instance.shoot_left = shoot_left
		trap_instance.shoot_up = shoot_up
		trap_instance.shoot_down = shoot_down
	elif trap_type == "cannon_trap":
		print("[TrapSpawner] Setting cannon trap directions: R=%s L=%s U=%s D=%s" % [shoot_right, shoot_left, shoot_up, shoot_down])
		trap_instance.shoot_right = shoot_right
		trap_instance.shoot_left = shoot_left
		trap_instance.shoot_up = shoot_up
		trap_instance.shoot_down = shoot_down
	
	# Add to scene
	get_parent().add_child(trap_instance)
	
	# Initialize trap
	var spawn_pos = global_position + spawn_offset
	trap_instance.initialize(current_level, spawn_pos)
	
	# Store reference
	_spawned_trap = trap_instance
	_is_active = true
	
	print("[TrapSpawner] Spawned %s at position %s" % [trap_type, spawn_pos])
	print("[TrapSpawner] Activated")
	
	return true

# Temporary method to create placeholder traps while we build the actual trap scenes
func _create_placeholder_trap(trap_type: String) -> void:
	# Create a simple placeholder BaseTrap
	var trap = preload("res://traps/base_trap.tscn").instantiate() if ResourceLoader.exists("res://traps/base_trap.tscn") else null
	
	if not trap:
		# Create a basic trap node if scene doesn't exist yet
		trap = BaseTrap.new()
		trap.name = "PlaceholderTrap_" + trap_type
		
		# Add basic visual indicator
		var sprite = Sprite2D.new()
		sprite.name = "Sprite"
		var texture = ImageTexture.new()
		var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
		
		# Different colors for different categories
		match trap_category:
			TrapConfig.TrapCategory.GROUND:
				image.fill(Color.RED)
			TrapConfig.TrapCategory.WALL:
				image.fill(Color.BLUE)
			TrapConfig.TrapCategory.CEILING:
				image.fill(Color.GREEN)
		
		texture.create_from_image(image)
		sprite.texture = texture
		trap.add_child(sprite)
		
		# Add basic collision areas
		var detection_area = Area2D.new()
		detection_area.name = "DetectionArea"
		var detection_shape = CollisionShape2D.new()
		detection_shape.shape = CircleShape2D.new()
		detection_shape.shape.radius = 100.0
		detection_area.add_child(detection_shape)
		trap.add_child(detection_area)
		
		var damage_area = Area2D.new()
		damage_area.name = "DamageArea"
		var damage_shape = CollisionShape2D.new()
		damage_shape.shape = CircleShape2D.new()
		damage_shape.shape.radius = 50.0
		damage_area.add_child(damage_shape)
		trap.add_child(damage_area)
		
		# Add timers
		var activation_timer = Timer.new()
		activation_timer.name = "ActivationTimer"
		trap.add_child(activation_timer)
		
		var cooldown_timer = Timer.new()
		cooldown_timer.name = "CooldownTimer"
		trap.add_child(cooldown_timer)
	
	# Add trap to scene
	get_parent().add_child(trap)
	
	# Initialize trap
	var spawn_position = global_position + spawn_offset
	trap.initialize(current_level, spawn_position)
	
	# Store reference
	_spawned_trap = trap
	
	print("[TrapSpawner] Created placeholder %s at position %s" % [trap_type, spawn_position])

func get_spawned_trap() -> BaseTrap:
	return _spawned_trap

func clear_trap() -> void:
	if _spawned_trap and is_instance_valid(_spawned_trap):
		_spawned_trap.queue_free()
		_spawned_trap = null

func set_level(level: int) -> void:
	current_level = level
	if _spawned_trap:
		_spawned_trap.set_level(level) 
 
 
