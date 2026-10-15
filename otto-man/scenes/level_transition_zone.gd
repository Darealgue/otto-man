extends Area2D

@export var zone_type: String = "Start"  # Can be "Start" or "Finish"
@export var cooldown_time: float = 1.0  # Cooldown in seconds

signal player_entered(zone_type: String)

var is_on_cooldown: bool = false

func _ready() -> void:
	# Set up collision layer and mask for player detection
	collision_layer = CollisionLayers.NONE  # Zone doesn't need a collision layer
	collision_mask = CollisionLayers.PLAYER   # Detect player by named layer
	monitoring = true    # Ensure monitoring is enabled
	monitorable = true  # Allow the area to be monitored
	
	# Connect to area entered signal
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)  # Also connect to body_entered

func start_cooldown() -> void:
	is_on_cooldown = true
	var timer = get_tree().create_timer(cooldown_time)
	timer.timeout.connect(func(): is_on_cooldown = false)

func _on_area_entered(area: Area2D) -> void:
	if is_on_cooldown:
		return
		
	# Check if the entering area is the player's hitbox
	if area.get_parent().name == "Player":
		player_entered.emit(zone_type)
		start_cooldown()

func _on_body_entered(body: Node2D) -> void:
	if is_on_cooldown:
		return
		
	# Check if the entering body is the player
	if body.name == "Player" or (body.get_parent() and body.get_parent().name == "Player"):
		player_entered.emit(zone_type)
		start_cooldown()
