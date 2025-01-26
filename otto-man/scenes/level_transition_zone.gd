extends Area2D

@export var zone_type: String = "Start"  # Can be "Start" or "Finish"

signal player_entered(zone_type: String)

func _ready() -> void:
	# Set up collision layer and mask for player detection
	collision_layer = 0  # Zone doesn't need a collision layer
	collision_mask = 2   # Layer 2 is typically for player
	monitoring = true    # Ensure monitoring is enabled
	monitorable = true  # Allow the area to be monitored
	
	# Connect to area entered signal
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)  # Also connect to body_entered
	print("Level transition zone ready: ", zone_type, " - collision_mask: ", collision_mask, " - monitoring: ", monitoring)

func _on_area_entered(area: Area2D) -> void:
	print("Area entered transition zone: ", area.name)  # Debug print
	print("Area parent: ", area.get_parent().name if area.get_parent() else "No parent")
	# Check if the entering area is the player's hitbox
	if area.get_parent().name == "Player":
		print("Player detected, emitting signal for zone type: ", zone_type)  # Debug print
		player_entered.emit(zone_type)

func _on_body_entered(body: Node2D) -> void:
	print("Body entered transition zone: ", body.name)
	# Check if the entering body is the player
	if body.name == "Player" or (body.get_parent() and body.get_parent().name == "Player"):
		print("Player body detected, emitting signal for zone type: ", zone_type)
		player_entered.emit(zone_type) 