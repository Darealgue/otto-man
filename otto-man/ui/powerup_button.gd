extends Button

var powerup: PowerupResource
var base_style: StyleBoxFlat
var is_selected := false
var progress := 0.0  # Progress value for the radial indicator

func _ready() -> void:
	# Make sure we can interact while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE  # We'll handle focus manually
	print("DEBUG: PowerupButton ready")
	
	# Connect to button state changes
	toggled.connect(_on_toggled)
	
	# Enable custom drawing
	custom_minimum_size = Vector2(200, 60)  # Ensure enough space for the radial indicator

func _draw() -> void:
	if progress > 0.0:
		# Draw radial progress indicator
		var center = Vector2(size.x / 2, size.y / 2)
		var radius = (min(size.x, size.y) / 2) + 5  # Slightly larger than button
		var start_angle = -PI/2  # Start from top
		var end_angle = start_angle + (PI * 2 * progress)
		var color = powerup.get_rarity_color() if powerup else Color.WHITE
		color.a = 0.6  # More transparent
		
		# Draw background circle with thicker line
		draw_arc(center, radius, 0, PI * 2, 32, Color(color.r, color.g, color.b, 0.15), 8.0)  # Increased thickness to 8.0
		# Draw progress arc with thicker line
		if progress > 0:
			draw_arc(center, radius, start_angle, end_angle, 32, color, 8.0)  # Increased thickness to 8.0

func set_progress(value: float) -> void:
	progress = value
	queue_redraw()  # Request redraw when progress changes

func setup(p: PowerupResource) -> void:
	if !p:
		print("ERROR: Null powerup passed to button setup!")
		return
		
	print("DEBUG: Setting up powerup button for: " + p.name)
	powerup = p
	text = powerup.get_modified_description()
	
	# Set style based on rarity
	base_style = StyleBoxFlat.new()
	base_style.bg_color = powerup.get_rarity_color()
	base_style.corner_radius_top_left = 5
	base_style.corner_radius_top_right = 5
	base_style.corner_radius_bottom_left = 5
	base_style.corner_radius_bottom_right = 5
	
	# Add a glow effect for Epic and Legendary items
	if powerup.rarity >= 2:  # Epic or Legendary
		var glow_color = base_style.bg_color
		glow_color.a = 0.3
		base_style.shadow_color = glow_color
		base_style.shadow_size = 5
	
	# Set up all the button states
	add_theme_stylebox_override("normal", base_style)
	add_theme_stylebox_override("hover", base_style.duplicate())  # Start with base style for hover
	add_theme_stylebox_override("pressed", base_style.duplicate())  # And for pressed
	toggle_mode = true
	print("DEBUG: Button style set for rarity: ", powerup.rarity)
	
	# Add hover effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	print("DEBUG: Button setup complete")

func _on_mouse_entered() -> void:
	if !button_pressed:  # Only apply hover effect if not selected
		var hover_style = base_style.duplicate()
		hover_style.border_width_bottom = 4
		hover_style.border_width_top = 4
		hover_style.border_width_left = 4
		hover_style.border_width_right = 4
		hover_style.border_color = Color(1, 1, 1, 0.5)  # Semi-transparent white border
		hover_style.shadow_color = Color(1, 1, 1, 0.2)
		hover_style.shadow_size = 4
		add_theme_stylebox_override("hover", hover_style)
	
func _on_mouse_exited() -> void:
	if !button_pressed:  # Only reset if not selected
		add_theme_stylebox_override("hover", base_style.duplicate())

func _on_toggled(button_pressed: bool) -> void:
	if button_pressed:
		# Selected state - using border instead of darkening
		var selected_style = base_style.duplicate()
		selected_style.border_width_bottom = 6
		selected_style.border_width_top = 6
		selected_style.border_width_left = 6
		selected_style.border_width_right = 6
		selected_style.border_color = Color(1, 1, 1, 0.9)
		selected_style.shadow_color = Color(1, 1, 1, 0.3)
		selected_style.shadow_size = 8
		
		add_theme_stylebox_override("normal", selected_style)
		add_theme_stylebox_override("hover", selected_style.duplicate())
		add_theme_stylebox_override("pressed", selected_style.duplicate())
	else:
		# Normal state
		add_theme_stylebox_override("normal", base_style.duplicate())
		add_theme_stylebox_override("hover", base_style.duplicate())
		add_theme_stylebox_override("pressed", base_style.duplicate())
		queue_redraw()  # Ensure progress indicator is cleared
