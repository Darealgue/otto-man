extends Node2D

var expansion_duration: float = 0.5
var fade_duration: float = 0.4
var ring_count: int = 3
var ring_delay: float = 0.1

func _ready():
	# Create multiple shockwave rings with delays
	for i in range(ring_count):
		var delay = i * ring_delay
		get_tree().create_timer(delay).timeout.connect(_create_shockwave_ring.bind(i))

func _create_shockwave_ring(ring_index: int):
	var ring = Sprite2D.new()
	ring.name = "ShockwaveRing" + str(ring_index)
	add_child(ring)
	
	# Create ring texture
	_create_ring_texture(ring, ring_index)
	
	# Initial state
	ring.scale = Vector2(0.1, 0.1)
	ring.modulate.a = 0.8 - (ring_index * 0.2)  # Each ring slightly more transparent
	
	# Animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale animation - each ring expands to different size
	var final_scale = 2.5 + (ring_index * 0.5)
	tween.tween_property(ring, "scale", Vector2(final_scale, final_scale), expansion_duration)
	
	# Fade animation
	tween.tween_property(ring, "modulate:a", 0.0, fade_duration)
	
	# Cleanup
	tween.tween_callback(ring.queue_free).set_delay(expansion_duration)

func _create_ring_texture(sprite: Sprite2D, ring_index: int):
	var size = 80
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(size/2, size/2)
	var outer_radius = (size/2 - 2) - (ring_index * 2)  # Each ring slightly smaller
	var inner_radius = outer_radius - 6  # Ring thickness
	
	# Different colors for each ring
	var colors = [
		Color(1.0, 0.9, 0.4, 1.0),  # Yellow-orange
		Color(1.0, 0.6, 0.2, 1.0),  # Orange
		Color(1.0, 0.3, 0.1, 1.0)   # Red-orange
	]
	var ring_color = colors[ring_index % colors.size()]
	
	# Draw ring
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			
			if distance <= outer_radius and distance >= inner_radius:
				var alpha = 1.0 - abs(distance - (inner_radius + outer_radius) / 2.0) / 3.0
				alpha = clamp(alpha, 0.4, 1.0)
				var pixel_color = ring_color
				pixel_color.a = alpha
				image.set_pixel(x, y, pixel_color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	sprite.texture = texture

func set_explosion_radius(radius: float):
	# This will be called when the effect is created
	# We can adjust the final scales based on explosion radius
	pass 