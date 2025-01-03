extends Control

@onready var health_label = $HealthLabel
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	if !health_label:
		push_error("HealthLabel node not found! Make sure there is a Label node named 'HealthLabel' as a child of this Control node.")
		return
		
	if !player:
		push_error("Player not found! Make sure the player is in the 'player' group.")
		return
		
	player.health_changed.connect(_on_player_health_changed)
	update_health_display(player.health)

func _on_player_health_changed(new_health: float):
	update_health_display(new_health)

func update_health_display(current_health: float):
	if health_label:
		health_label.text = "Health: %d / %d" % [current_health, player.max_health]
