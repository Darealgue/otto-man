extends Sprite2D

func _ready() -> void:
	# Create a blood splatter texture
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	
	# Create irregular blood splatter shape
	for x in range(16):
		for y in range(16):
			var center = Vector2(8, 8)
			var distance = Vector2(x, y).distance_to(center)
			
			# Create irregular shape with noise
			var noise_factor = sin(x * 0.5) * cos(y * 0.3) * 2.0
			var radius = 6.0 + noise_factor
			
			if distance <= radius:
				var alpha = 1.0 - (distance / radius) * 0.4
				# Add some randomness to color
				var color_variation = 0.8 + sin(x + y) * 0.2
				image.set_pixel(x, y, Color(color_variation, 0.1, 0.1, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	texture = texture
	
	# Set the texture
	set_texture(texture)
