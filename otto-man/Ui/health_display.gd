extends Control

@onready var health_label = $HealthLabel

func _ready() -> void:
	print("Health display initialized")
	call_deferred("connect_to_player")

func connect_to_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Found player: ", player.name)
		if !player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
			print("Connected to player health signal")
			# Get initial health
			if "health" in player:
				print("Initial health: ", player.health)
				_on_player_health_changed(player.health)
			else:
				push_error("Player has no health variable!")
	else:
		push_error("No player found in scene!")

func _on_player_health_changed(new_health: int) -> void:
	print("Health changed to: ", new_health)
	health_label.text = "Health: %d / 100" % new_health
