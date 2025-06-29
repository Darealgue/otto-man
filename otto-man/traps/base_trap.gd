extends Node2D
class_name BaseTrap

# Trap configuration
@export var trap_category: TrapConfig.TrapCategory = TrapConfig.TrapCategory.GROUND
@export var activation_type: TrapConfig.ActivationType = TrapConfig.ActivationType.PROXIMITY
@export var damage_type: TrapConfig.DamageType = TrapConfig.DamageType.PHYSICAL

# Trap stats (will be set by spawner based on level)
@export var base_damage: float = 25.0
@export var activation_range: float = 100.0
@export var activation_delay: float = 0.5  # Delay before trap activates
@export var cooldown_time: float = 2.0     # Time before trap can activate again

# Internal state
var current_level: int = 1
var is_active: bool = true
var is_on_cooldown: bool = false
var players_in_range: Array[Node] = []

# Node references
@onready var detection_area: Area2D = $DetectionArea
@onready var damage_area: Area2D = $DamageArea
@onready var sprite: Node2D = $Sprite
@onready var activation_timer: Timer = $ActivationTimer
@onready var cooldown_timer: Timer = $CooldownTimer

# Signals
signal trap_triggered(trap: BaseTrap)
signal player_damaged(player: Node, damage: float)

func _ready() -> void:
	add_to_group("traps")
	print("[BaseTrap] Initialized: ", name)
	
	# Setup detection area
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)
		# Set detection range
		var collision_shape = detection_area.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = activation_range
	
	# Setup damage area
	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_entered)
		damage_area.monitoring = false  # Start disabled
	
	# Setup timers
	if activation_timer:
		activation_timer.wait_time = activation_delay
		activation_timer.one_shot = true
		activation_timer.timeout.connect(_on_activation_timer_timeout)
	
	if cooldown_timer:
		cooldown_timer.wait_time = cooldown_time
		cooldown_timer.one_shot = true
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)

# Called by TrapSpawner to initialize trap
func initialize(level: int, spawner_position: Vector2) -> void:
	current_level = level
	global_position = spawner_position
	
	# Scale damage based on level
	var scaled_damage = base_damage * (1.0 + (level - 1) * 0.3)  # 30% increase per level
	base_damage = scaled_damage
	
	print("[BaseTrap] Initialized at level %d with damage %.1f" % [level, base_damage])

# Detection area events
func _on_detection_area_entered(body: Node2D) -> void:
	if not is_active or is_on_cooldown:
		print("[BaseTrap] Player detected but trap not active or on cooldown")
		return
		
	if body.is_in_group("player"):
		players_in_range.append(body)
		print("[BaseTrap] Player entered detection range - Player name: %s" % body.name)
		
		# Start activation timer
		if activation_timer and players_in_range.size() == 1:  # First player
			print("[BaseTrap] Starting activation timer - delay: %.1f seconds" % activation_delay)
			activation_timer.start()

func _on_detection_area_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body in players_in_range:
		players_in_range.erase(body)
		print("[BaseTrap] Player left detection range - Player name: %s" % body.name)
		
		# Stop activation if no players left
		if players_in_range.is_empty() and activation_timer:
			print("[BaseTrap] No players in range, stopping activation timer")
			activation_timer.stop()

# Activation timer timeout
func _on_activation_timer_timeout() -> void:
	if not players_in_range.is_empty():
		print("[BaseTrap] Activation timer finished, triggering trap")
		trigger_trap()
	else:
		print("[BaseTrap] Activation timer finished but no players in range")

# Main trap activation
func trigger_trap() -> void:
	if not is_active or is_on_cooldown:
		print("[BaseTrap] Cannot trigger - active: %s, on_cooldown: %s" % [is_active, is_on_cooldown])
		return
	
	print("[BaseTrap] Trap triggered!")
	trap_triggered.emit(self)
	
	# Enable damage area temporarily
	if damage_area:
		damage_area.monitoring = true
		print("[BaseTrap] Damage area enabled")
	
	# Start cooldown
	start_cooldown()
	
	# Call specific trap behavior (override in child classes)
	_execute_trap_behavior()
	
	# Disable damage area after a short time
	await get_tree().create_timer(0.2).timeout
	if damage_area:
		damage_area.monitoring = false
		print("[BaseTrap] Damage area disabled")

# Override this in specific trap classes
func _execute_trap_behavior() -> void:
	# Base implementation - just visual feedback
	if sprite:
		# Simple scale animation as feedback
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

# Damage area events
func _on_damage_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[BaseTrap] Player entered damage area - dealing damage")
		deal_damage_to_player(body)
		
# Deal damage to player
func deal_damage_to_player(player: Node) -> void:
	if player.has_method("take_damage"):
		player.take_damage(base_damage)
		player_damaged.emit(player, base_damage)
		print("[BaseTrap] Dealt %.1f damage to player %s" % [base_damage, player.name])
	else:
		print("[BaseTrap] Player %s has no take_damage method!" % player.name)

# Cooldown management
func start_cooldown() -> void:
	is_on_cooldown = true
	print("[BaseTrap] Started cooldown - duration: %.1f seconds" % cooldown_time)
	if cooldown_timer:
		cooldown_timer.start()

func _on_cooldown_timer_timeout() -> void:
	is_on_cooldown = false
	print("[BaseTrap] Cooldown finished, trap ready")

# Public methods
func activate() -> void:
	is_active = true
	print("[BaseTrap] Trap activated")

func deactivate() -> void:
	is_active = false
	if activation_timer:
		activation_timer.stop()
	if damage_area:
		damage_area.monitoring = false
	print("[BaseTrap] Trap deactivated")

func set_level(level: int) -> void:
	current_level = level
	# Rescale damage
	var scaled_damage = base_damage * (1.0 + (level - 1) * 0.3)
	base_damage = scaled_damage 
