extends Node2D

func _ready() -> void:
	print("[Level] Scene tree check:")
	_print_scene_tree(self)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[Level] Found enemies:", enemies.size())
	for enemy in enemies:
		print("- Enemy position:", enemy.global_position)
		print("- Enemy visible:", enemy.visible)
		print("- Enemy parent:", enemy.get_parent().name if enemy.get_parent() else "None")

func _print_scene_tree(node: Node, indent: String = "") -> void:
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_scene_tree(child, indent + "  ") 