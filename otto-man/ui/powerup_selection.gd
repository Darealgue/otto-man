extends CanvasLayer

@onready var powerup_container = $Control/CenterContainer/VBoxContainer/PowerupContainer

const PowerupButton = preload("res://ui/powerup_button.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Make sure UI works while game is paused
	show_ui(false)  # Start hidden

func setup_powerups(powerups: Array) -> void:
	# Clear existing buttons
	for child in powerup_container.get_children():
		child.queue_free()
	
	# Create new buttons
	for powerup in powerups:
		var button = PowerupButton.instantiate()
		powerup_container.add_child(button)
		button.setup(powerup)
		button.pressed.connect(func(): _on_powerup_selected(powerup))
	
	show_ui(true)

func _print_node_hierarchy(node: Node, indent: String = "") -> void:
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_node_hierarchy(child, indent + "  ")

func _on_powerup_selected(powerup: PowerupResource) -> void:
	PowerupManager.apply_powerup(powerup)
	show_ui(false)

func show_ui(should_show: bool) -> void:
	visible = should_show
	$Control.visible = should_show
