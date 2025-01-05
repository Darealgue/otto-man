extends Node2D

func _ready() -> void:
	_print_scene_tree(self)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	

func _print_scene_tree(node: Node, indent: String = "") -> void:
	for child in node.get_children():
		_print_scene_tree(child, indent + "  ") 
