extends Node2D

@onready var range_circle: Sprite2D = $RangeCircle
var fade_duration: float = 0.5
var initial_alpha: float = 0.3
var radius: float = 80.0

func _ready():
	# Create a circle texture for the range indicator
	_create_range_circle()
	
	# Start fade out animation
	var tween = create_tween()
	tween.tween_property(range_circle, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)

func _create_range_circle():
	if not range_circle:
		range_circle = Sprite2D.new()
		range_circle.name = "RangeCircle"
		add_child(range_circle)
	
	# Create a circle texture
	var size = int(radius * 2)  # Use the radius variable
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(size/2, size/2)
	var circle_radius = size/2 - 2  # Leave 2 pixel border
	
	# Draw circle outline and semi-transparent fill
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			
			if distance <= circle_radius:
				if distance >= circle_radius - 4:  # 4 pixel thick border
					image.set_pixel(x, y, Color(1.0, 0.2, 0.2, 0.8))  # Red border
				else:
					image.set_pixel(x, y, Color(1.0, 0.2, 0.2, 0.15))  # Semi-transparent red fill
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	range_circle.texture = texture
	range_circle.modulate.a = initial_alpha

func set_radius(new_radius: float) -> void:
	radius = new_radius
	# Recreate the circle with new radius
	_create_range_circle() 