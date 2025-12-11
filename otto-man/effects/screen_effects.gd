extends Node

@onready var time_slow_effect = $CanvasLayer/TimeSlowEffect

# Screen shake variables
var camera: Camera2D
var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_camera_position: Vector2
var original_camera_offset: Vector2
var shake_layer: CanvasLayer

func _ready():
	# print("[ScreenEffects] _ready() called")
	# Start with effects disabled
	time_slow_effect.visible = false
	Engine.time_scale = 1.0  # Ensure we start with normal time scale
	
	# Find camera for screen shake
	_find_camera()
	_setup_shake_layer()

func _find_camera():
	# Try to find the camera in the scene
	# First check "camera" group
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		camera = cameras[0] as Camera2D
	else:
		# Check "Camera Groups" group (used by player camera)
		var camera_groups = get_tree().get_nodes_in_group("Camera Groups")
		if camera_groups.size() > 0:
			camera = camera_groups[0] as Camera2D
		else:
			# Fallback: search for Camera2D nodes recursively
			var all_cameras = []
			_find_camera2d_recursive(get_tree().current_scene, all_cameras)
			if all_cameras.size() > 0:
				camera = all_cameras[0]
	
	if camera:
		original_camera_position = camera.position
		original_camera_offset = camera.offset

func _setup_shake_layer():
	# Create a CanvasLayer for screen shake that doesn't affect camera smoothing
	shake_layer = CanvasLayer.new()
	shake_layer.name = "ShakeLayer"
	shake_layer.layer = 1000  # High layer to be on top
	add_child(shake_layer)
	# print("[ScreenEffects] Shake layer created")

func _find_camera2d_recursive(node: Node, camera_list: Array):
	if node is Camera2D:
		camera_list.append(node)
	for child in node.get_children():
		_find_camera2d_recursive(child, camera_list)

func slow_time(scale: float = 0.2, duration: float = 1.0) -> void:
	
	# Immediately set time scale
	Engine.time_scale = scale
	
	time_slow_effect.visible = true
	
	# Create tween to fade in effect
	var effect_tween = create_tween()
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.7, 0.1)
	effect_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.6, 0.1)
	
	# Create timer to restore time scale after duration
	var timer = get_tree().create_timer(duration)  # Don't adjust for slowed time
	await timer.timeout
	
	
	# Fade out effect
	var fade_tween = create_tween()
	fade_tween.tween_property(time_slow_effect.material, "shader_parameter/vignette_opacity", 0.0, 0.2)
	fade_tween.tween_property(time_slow_effect.material, "shader_parameter/desaturation", 0.0, 0.2)
	fade_tween.tween_callback(func(): 
		time_slow_effect.visible = false
	)
	
	# Restore time scale
	Engine.time_scale = 1.0

func apply_time_slow_effect():
	slow_time(0.2, 1.0)  # Use standard values for testing

# Screen shake functions
func shake(duration: float, strength: float):
	if not camera:
		_find_camera()  # Try to find camera again if not found
		if not camera:
			return  # No camera found, can't shake
	
	shake_duration = duration
	shake_strength = strength
	shake_timer = duration
	
	# Store original offset if not already stored
	if original_camera_offset == Vector2.ZERO and camera:
		original_camera_offset = camera.offset

func _process(delta: float):
	if shake_timer > 0:
		shake_timer -= delta
		
		if not camera:
			_find_camera()
			if not camera:
				shake_timer = 0
				return
		
		if shake_timer <= 0:
			# Shake finished, reset camera offset
			if camera:
				camera.offset = original_camera_offset
			shake_strength = 0.0
		else:
			# Apply shake using camera offset (more visible than CanvasLayer)
			if camera:
				var shake_amount = shake_strength * (shake_timer / shake_duration)
				var shake_offset = Vector2(
					randf_range(-shake_amount, shake_amount),
					randf_range(-shake_amount, shake_amount)
				)
				camera.offset = original_camera_offset + shake_offset
