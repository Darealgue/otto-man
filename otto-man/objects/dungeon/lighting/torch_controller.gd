extends Node2D
class_name TorchController

@export var light_intensity_min: float = 0.5
@export var light_intensity_max: float = 1.5
@export var flicker_speed: float = 0.8
@export var flicker_variation: float = 0.5
@export var range_variation: float = 0.15

var point_light: PointLight2D
var animated_sprite: AnimatedSprite2D
var base_energy: float
var base_texture_scale: float
var time: float = 0.0
var random_offset: float = 0.0
var noise: FastNoiseLite

func _ready():
	# Find the PointLight2D and AnimatedSprite2D nodes
	point_light = get_node_or_null("PointLight2D")
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	
	# Create random offset for each torch to avoid synchronization
	random_offset = randf() * 10.0  # Random offset between 0-10 seconds
	
	# Initialize Perlin noise for natural flickering
	noise = FastNoiseLite.new()
	noise.seed = randi()  # Random seed for each torch
	noise.frequency = 0.15  # How fast the noise changes (much slower)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	if point_light:
		base_energy = point_light.energy
		base_texture_scale = point_light.texture_scale
		print("[TorchController] Found PointLight2D with base energy: ", base_energy, " base scale: ", base_texture_scale)
	else:
		print("[TorchController] Warning: No PointLight2D found!")
	
	if animated_sprite:
		# Start the animation
		animated_sprite.play("idle")
		print("[TorchController] Started torch animation")
	else:
		print("[TorchController] Warning: No AnimatedSprite2D found!")

func _process(delta):
	time += delta
	
	# Create flickering light effect
	if point_light:
		# Use Perlin noise for more natural, random flickering
		var noise_value = noise.get_noise_1d(time * flicker_speed + random_offset)
		var flicker = noise_value * flicker_variation
		
		# Add some additional randomness for more chaotic effect (much slower)
		var random_variation = randf_range(-0.05, 0.05)
		
		# Calculate new energy with flickering
		var new_energy = base_energy + flicker + random_variation
		new_energy = clamp(new_energy, light_intensity_min, light_intensity_max)
		
		point_light.energy = new_energy
		
		# Vary the texture scale (range) with different noise pattern
		var range_noise = noise.get_noise_1d((time + random_offset * 1.7) * flicker_speed * 0.3)
		var range_variation_amount = range_noise * range_variation
		var range_random = randf_range(-0.03, 0.03)  # Add some random variation to range too (much smaller)
		var scale_variation = 1.0 + range_variation_amount + range_random
		point_light.texture_scale = base_texture_scale * scale_variation
