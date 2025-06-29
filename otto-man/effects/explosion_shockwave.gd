extends Node2D

@onready var shockwave_sprite: Sprite2D = $ShockwaveSprite
var expansion_duration: float = 0.4
var fade_duration: float = 0.3

func _ready():
	# Create our own circular shockwave texture
	_create_shockwave_texture()
	
	if shockwave_sprite:
		# Start with small scale and fade in
		shockwave_sprite.scale = Vector2(0.2, 0.2)
		shockwave_sprite.modulate.a = 0.9
		
		# Create expansion animation
		var tween = create_tween()
		tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
		
		# Expand the shockwave
		tween.tween_property(shockwave_sprite, "scale", Vector2(3.0, 3.0), expansion_duration)
		
		# Fade out during expansion
		tween.tween_property(shockwave_sprite, "modulate:a", 0.0, fade_duration)
		
		# Clean up after animation
		tween.tween_callback(queue_free).set_delay(expansion_duration)

func set_explosion_radius(radius: float):
	if shockwave_sprite:
		# Adjust final scale based on explosion radius
		var base_radius = 50.0  # Base radius for our custom texture
		var scale_factor = radius / base_radius
		
		# Update the existing tween if it's running
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(shockwave_sprite, "scale", Vector2(scale_factor, scale_factor), expansion_duration)
		tween.tween_property(shockwave_sprite, "modulate:a", 0.0, fade_duration)

func _create_shockwave_texture():
	if not shockwave_sprite:
		shockwave_sprite = Sprite2D.new()
		shockwave_sprite.name = "ShockwaveSprite"
		add_child(shockwave_sprite)
	
	# Create a circular shockwave texture
	var size = 100
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(size/2, size/2)
	var outer_radius = size/2 - 2
	var inner_radius = outer_radius - 8  # 8 pixel thick ring
	
	# Draw circular shockwave ring
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			
			if distance <= outer_radius and distance >= inner_radius:
				# Create gradient effect on the ring
				var alpha = 1.0 - abs(distance - (inner_radius + outer_radius) / 2.0) / 4.0
				alpha = clamp(alpha, 0.3, 1.0)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	shockwave_sprite.texture = texture
	shockwave_sprite.modulate = Color(1.0, 0.8, 0.4, 0.9)  # Orange-ish color 