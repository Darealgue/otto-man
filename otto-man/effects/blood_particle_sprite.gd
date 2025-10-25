extends Sprite2D

func _ready() -> void:
	# Create a simple red circle texture
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	
	# Fill with red color
	for x in range(8):
		for y in range(8):
			var distance = Vector2(x - 4, y - 4).length()
			if distance <= 3.5:
				var alpha = 1.0 - (distance / 3.5) * 0.3  # Slight transparency at edges
				image.set_pixel(x, y, Color(0.8, 0.1, 0.1, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	texture = texture
	
	# Set the texture
	set_texture(texture)
