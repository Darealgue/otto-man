extends Button

@onready var name_label = $VBoxContainer/Name
@onready var description_label = $VBoxContainer/Description

func setup(powerup: PowerupResource) -> void:
	name_label.text = powerup.name
	description_label.text = powerup.description
	
	# Add hover effect
	mouse_entered.connect(func(): modulate = Color(1.2, 1.2, 1.2))
	mouse_exited.connect(func(): modulate = Color.WHITE)
	focus_entered.connect(func(): modulate = Color(1.2, 1.2, 1.2))
	focus_exited.connect(func(): modulate = Color.WHITE) 