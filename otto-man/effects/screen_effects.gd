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
	print("[ScreenEffects] _ready() called")
	# Start with effects disabled
	time_slow_effect.visible = false
	Engine.time_scale = 1.0  # Ensure we start with normal time scale
	
	# Find camera for screen shake
	_find_camera()
	_setup_shake_layer()

func _find_camera():
	print("[ScreenEffects] _find_camera() called")
	# Try to find the camera in the scene
	var cameras = get_tree().get_nodes_in_group("camera")
	print("[ScreenEffects] Found cameras in 'camera' group: ", cameras.size())
	if cameras.size() > 0:
		camera = cameras[0] as Camera2D
		print("[ScreenEffects] Using camera from 'camera' group: ", camera)
	else:
		# Fallback: search for Camera2D nodes
		var all_cameras = []
		_find_camera2d_recursive(get_tree().current_scene, all_cameras)
		print("[ScreenEffects] Found cameras via recursive search: ", all_cameras.size())
		if all_cameras.size() > 0:
			camera = all_cameras[0]
			print("[ScreenEffects] Using camera from recursive search: ", camera)
	
	if camera:
		original_camera_position = camera.position
		print("[ScreenEffects] Camera found and set! Position: ", original_camera_position)
	else:
		print("[ScreenEffects] ERROR: No camera found!")

func _setup_shake_layer():
	# Create a CanvasLayer for screen shake that doesn't affect camera smoothing
	shake_layer = CanvasLayer.new()
	shake_layer.name = "ShakeLayer"
	shake_layer.layer = 1000  # High layer to be on top
	add_child(shake_layer)
	print("[ScreenEffects] Shake layer created")

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
	print("[ScreenEffects] shake() called - strength: ", strength, " duration: ", duration)
	print("[ScreenEffects] Current camera: ", camera)
	if not camera:
		print("[ScreenEffects] No camera found, trying to find again...")
		_find_camera()  # Try to find camera again if not found
		if not camera:
			print("[ScreenEffects] ERROR: Still no camera found for screen shake!")
			return  # No camera found, can't shake
	
	shake_duration = duration
	shake_strength = strength
	shake_timer = duration
	
	# Use CanvasLayer for shake - this doesn't affect camera smoothing at all
	print("[ScreenEffects] Screen shake started successfully! Strength: ", shake_strength, " Using CanvasLayer method")

func _process(delta: float):
	if shake_timer > 0:
		print("[ScreenEffects] _process: shake_timer=", shake_timer, " shake_strength=", shake_strength)
		shake_timer -= delta
		
		if shake_timer <= 0:
			# Shake finished, reset CanvasLayer offset
			if shake_layer:
				shake_layer.offset = Vector2.ZERO
				print("[ScreenEffects] Shake finished, reset CanvasLayer offset")
			shake_strength = 0.0
		else:
			# Apply shake using CanvasLayer offset
			if shake_layer:
				var shake_amount = shake_strength * (shake_timer / shake_duration)
				var shake_offset = Vector2(
					randf_range(-shake_amount, shake_amount),
					randf_range(-shake_amount, shake_amount)
				)
				shake_layer.offset = shake_offset
				print("[ScreenEffects] Applied shake: offset=", shake_offset)
