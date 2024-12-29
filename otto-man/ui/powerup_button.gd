extends Button

var powerup: PowerupResource

func _ready() -> void:
	# Make sure we can interact while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("DEBUG: PowerupButton ready")

func setup(p: PowerupResource) -> void:
	if !p:
		print("ERROR: Null powerup passed to button setup!")
		return
		
	print("DEBUG: Setting up powerup button for: " + p.name)
	powerup = p
	text = powerup.get_modified_description()
	
	# Set style based on rarity
	var style = get_theme_stylebox("normal").duplicate()
	if !style:
		print("ERROR: Could not get button style!")
		return
		
	# Use the new rarity color system
	style.bg_color = powerup.get_rarity_color()
	
	# Add a glow effect for Epic and Legendary items
	if powerup.rarity >= 2:  # Epic or Legendary
		var glow_color = style.bg_color
		glow_color.a = 0.3
		style.shadow_color = glow_color
		style.shadow_size = 5
	
	add_theme_stylebox_override("normal", style)
	print("DEBUG: Button style set for rarity: ", powerup.rarity)
	
	# Add hover effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	print("DEBUG: Button setup complete")

func _on_mouse_entered() -> void:
	# Bigger scale for higher rarities
	var scale_boost = 1.0 + (powerup.rarity * 0.02)  # 1.02 for rare, 1.04 for epic, 1.06 for legendary
	scale = Vector2(scale_boost, scale_boost)
	
func _on_mouse_exited() -> void:
	scale = Vector2.ONE 