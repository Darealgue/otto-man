extends Button

var powerup_scene: PackedScene
var progress: float = 0.0

func setup(scene: PackedScene) -> void:
	powerup_scene = scene
	
	# Instance the powerup to get its name and description
	var powerup = scene.instantiate()
	
	# Check if it's a PowerupEffect or has the required properties
	if powerup is PowerupEffect:
		text = powerup.powerup_name + "\n" + powerup.description
	else:
		# For non-PowerupEffect powerups, use the script name as fallback
		var script_path = powerup.get_script().resource_path
		var script_name = script_path.get_file().get_basename()
		text = script_name.capitalize() + "\n" + "Activates " + script_name.capitalize()
	
	powerup.queue_free()

func set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	if progress > 0:
		var size = get_size()
		var radius = min(size.x, size.y) * 0.4
		var center = size * 0.5
		var angle_from = -PI/2
		var angle_to = angle_from + (PI * 2 * progress)
		
		draw_arc(center, radius, angle_from, angle_to, 32, Color(1, 1, 1, 0.5), 2.0)
