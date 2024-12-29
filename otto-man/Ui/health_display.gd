extends Control

@onready var health_label = $HealthLabel
var player: Node = null

func _ready() -> void:
	print("Health display initialized")
	call_deferred("connect_to_player")

func connect_to_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("Found player: ", player.name)
		if !player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
			print("Connected to player health signal")
			# Register player with PowerupManager
			PowerupManager.register_player(player)
			# Get initial health
			if "health" in player:
				print("Initial health: ", player.health)
				_on_player_health_changed(player.health)
			else:
				push_error("Player has no health variable!")
	else:
		push_error("No player found in scene!")

func _on_player_health_changed(new_health: int) -> void:
	if !is_instance_valid(player):
		return
		
	print("Health changed to: ", new_health)
	var max_health = player.current_max_health if "current_max_health" in player else 100
	health_label.text = "Health: %d / %d" % [new_health, max_health]
