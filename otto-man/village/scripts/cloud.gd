extends Node2D

@export var speed_min: float = 10.0
@export var speed_max: float = 25.0
@export var fade_in_duration: float = 2.5
@export var fade_out_duration: float = 2.5

# If true, cloud moves from right to left (spawns on the right).
# If false, cloud moves from left to right (spawns on the left).
@export var move_left: bool = false 

var current_speed: float

# Fırtına/sağanakta bulut grileşmesi: hedef rengi yumuşak geçiş için cache
const NORMAL_CLOUD_COLOR: Vector3 = Vector3(2.0, 2.0, 2.0)  # Parlak beyaz (mevcut görünüm)
const STORM_CLOUD_COLOR: Vector3 = Vector3(0.48, 0.50, 0.55)  # Koyu gri (fırtına/sağanak)
const CLOUD_DARKEN_LERP: float = 0.004  # Çok yavaş geçiş; oyuncu zor fark eder

# Make sure you have a Sprite2D node named "CloudSprite" as a child of this node in your cloud.tscn
@onready var cloud_sprite: Sprite2D = $CloudSprite 
@onready var viewport_size: Vector2 = get_viewport_rect().size

func _ready() -> void:
	if not cloud_sprite:
		printerr("Cloud.gd: CloudSprite node not found in Cloud scene! Please add a Sprite2D named CloudSprite as a child.")
		queue_free() # Cannot operate without a sprite
		return

	if not cloud_sprite.texture:
		printerr("Cloud.gd: CloudSprite has no texture assigned in the Cloud scene. Please assign a default texture or the CloudManager should assign one.")
		# We can let it continue, as a CloudManager might assign a texture right after instancing.
		# For now, let it be, but visually it will be an empty moving node until texture is set.

	current_speed = randf_range(speed_min, speed_max)
	if move_left:
		current_speed = -abs(current_speed) # Ensure speed is negative
	else:
		current_speed = abs(current_speed)  # Ensure speed is positive

	# Başlangıç bulutları fade-in skip edebilir (meta ile kontrol)
	var skip_fade = has_meta("skip_fade_in") and get_meta("skip_fade_in") == true
	if skip_fade:
		cloud_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	else:
		# Initial state: invisible for fade-in. Preserve original color, only change alpha.
		cloud_sprite.modulate = Color(2.0, 2.0, 2.0, 0.0)
		var tween_fade_in = create_tween()
		tween_fade_in.tween_property(cloud_sprite, "modulate:a", 1.0, fade_in_duration).from(0.0)
		tween_fade_in.play()

func _process(delta: float) -> void:
	if not is_instance_valid(cloud_sprite) or not cloud_sprite.texture:
		return # Wait for texture or if sprite is somehow gone

	# Rüzgar güçlüyse bulut hızını artır (storm'da rüzgar hissi)
	var wind_multiplier: float = 1.0
	if WeatherManager:
		var wind_strength: float = WeatherManager.wind_strength
		wind_multiplier = 1.0 + wind_strength * 0.6  # Rüzgar güçlüyken %60'a kadar hızlanır
	
	position.x += current_speed * delta * wind_multiplier

	# Fırtına ve sağanak yağmurda bulutları grileştir
	if WeatherManager:
		var weather_darken: float = 0.0
		if WeatherManager.storm_active:
			weather_darken = 1.0
		elif WeatherManager.rain_intensity >= 0.65:
			weather_darken = 0.95  # Sağanak
		elif WeatherManager.rain_intensity >= 0.35:
			weather_darken = lerp(0.2, 0.8, (WeatherManager.rain_intensity - 0.35) / 0.3)  # Orta → yoğun
		var target_rgb: Vector3 = NORMAL_CLOUD_COLOR.lerp(STORM_CLOUD_COLOR, weather_darken)
		var current_rgb := Vector3(cloud_sprite.modulate.r, cloud_sprite.modulate.g, cloud_sprite.modulate.b)
		var new_rgb := current_rgb.lerp(target_rgb, CLOUD_DARKEN_LERP)
		var a: float = cloud_sprite.modulate.a
		cloud_sprite.modulate = Color(new_rgb.x, new_rgb.y, new_rgb.z, a)

	# Check for despawn when off-screen
	# The CloudManager will eventually handle spawning positions and more robust despawning.
	# This is a basic self-cleanup.
	
	# Use screen-space position for robust checking regardless of parallax/camera movement
	# global_position might be world space or canvas layer space depending on parent,
	# but get_global_transform_with_canvas().origin gives us the actual pixel position on screen.
	var screen_pos = get_global_transform_with_canvas().origin
	var screen_x = screen_pos.x
	
	var sprite_actual_width = cloud_sprite.texture.get_width() * max(cloud_sprite.scale.x, 1.0)
	var vp_size := get_viewport_rect().size
	var off_screen_buffer = sprite_actual_width + 100.0 

	if current_speed > 0: # Moving right
		# Check if left edge is past the right edge of viewport
		if screen_x - sprite_actual_width * 0.5 > vp_size.x + off_screen_buffer:
			# print("Cloud off-screen right (screen_x=", screen_x, "), removing: ", name)
			queue_free()
	elif current_speed < 0: # Moving left
		# Check if right edge is past the left edge of viewport
		if screen_x + sprite_actual_width * 0.5 < -off_screen_buffer:
			# print("Cloud off-screen left (screen_x=", screen_x, "), removing: ", name)
			queue_free()

# This function can be called by a CloudManager to gracefully remove the cloud
func initiate_fade_out_and_remove() -> void:
	if not is_instance_valid(cloud_sprite):
		queue_free() # Can't fade if no sprite
		return

	# If already transparent or nearly transparent, just remove
	if cloud_sprite.modulate.a < 0.01:
		queue_free()
		return

	var tween_fade_out = create_tween().set_parallel(false) # Ensure sequence
	tween_fade_out.tween_property(cloud_sprite, "modulate:a", 0.0, fade_out_duration)
	tween_fade_out.tween_callback(queue_free)
	tween_fade_out.play()

# The CloudManager will be responsible for setting the actual cloud texture
# from your 8 PNGs when it instances this scene.
# You can add a helper function here if needed, e.g.:
# func set_texture(new_texture: Texture2D) -> void:
#    if cloud_sprite:
#        cloud_sprite.texture = new_texture

func _exit_tree() -> void:
	# Clean up any running tweens if the node is removed prematurely
	# Godot's tweens are usually good about this, but explicit cleanup can be safe.
	var tweens = get_tree().get_nodes_in_group("tweens") # Default group for SceneTreeTween
	for t in tweens:
		if t is Tween and t.is_valid() and t.get_parent() == self: # Check if tween belongs to this node
			t.kill()
