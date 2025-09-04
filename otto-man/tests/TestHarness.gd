extends Node2D

func _ready():
	# Ensure MinigameRouter exists
	if not Engine.is_editor_hint():
		pass
	# Attach camera to player and move to chunk center
	var center := _get_chunk_center()
	var player := get_node_or_null("Player")
	if player:
		if not player.is_in_group("player"):
			player.add_to_group("player")
		if not player.has_node("Camera2D"):
			var pcam := Camera2D.new()
			player.add_child(pcam)
			pcam.make_current()
		player.global_position = center
	else:
		if not has_node("Camera2D"):
			var cam := Camera2D.new()
			add_child(cam)
			cam.make_current()
			cam.global_position = center

func _get_chunk_center() -> Vector2:
	var chunk := get_node_or_null("Chunk")
	if chunk and chunk is Node2D:
		return (chunk as Node2D).global_position + Vector2(960, 544)
	return Vector2.ZERO
