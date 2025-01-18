@tool
extends BasePlatform
class_name OneWayPlatform

var dropping_bodies: Array[Node] = []

func _ready() -> void:
	super._ready()
	
	# Set up one-way collision
	collision_layer = 1  # Ground layer
	collision_mask = 0   # Don't collide with anything
	
	# Make platform semi-transparent
	platform_color.a = 0.7
	
	if collision_shape:
		collision_shape.one_way_collision = true
		collision_shape.one_way_collision_margin = 8.0  # Adjust this for better feel

func _initialize_platform() -> void:
	super._initialize_platform()
	
	# Additional one-way platform setup
	if collision_shape:
		collision_shape.one_way_collision = true
		collision_shape.one_way_collision_margin = 8.0

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Check for bodies on the platform
	for body in get_tree().get_nodes_in_group("player"):
		if body.is_on_floor() and body.get_floor_normal().y < -0.7:  # Check if player is on this platform
			if Input.is_action_just_pressed("down"):
				start_drop_through(body)
		elif body in dropping_bodies and not Input.is_action_pressed("down"):
			# If player releases down while dropping, stop the drop
			stop_drop_through(body)

func start_drop_through(body: Node) -> void:
	if body not in dropping_bodies:
		dropping_bodies.append(body)
		# Disable collision with this body
		collision_layer = 0
		# Start a timer to re-enable collision
		get_tree().create_timer(0.15).timeout.connect(
			func(): stop_drop_through(body)
		)

func stop_drop_through(body: Node) -> void:
	if body in dropping_bodies:
		dropping_bodies.erase(body)
		if dropping_bodies.is_empty():
			collision_layer = 1 
