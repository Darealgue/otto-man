extends Node2D

func _ready() -> void:
	# Create UI layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GameUI"
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	# Create container
	var container = Control.new()
	container.name = "Container"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(container)
	
	# Create health display
	var health_display = preload("res://ui/health_display.tscn").instantiate()
	health_display.name = "HealthDisplay"
	health_display.position = Vector2(20, 20)
	container.add_child(health_display)
	
	# Create stamina bar
	var stamina_bar = preload("res://ui/stamina_bar.tscn").instantiate()
	stamina_bar.name = "StaminaBar"
	stamina_bar.position = Vector2(20, 65)
	container.add_child(stamina_bar)
	
	print("[Level] Initializing level...")
	_print_scene_tree(self)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		print("[Level] Found enemy:", enemy.name)

func _print_scene_tree(node: Node, indent: String = "") -> void:
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_scene_tree(child, indent + "  ")
