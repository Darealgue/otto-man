extends Node2D

const FADE_SPEED := 2.5  # Even slower fade for smoother transition
const DETECTION_RANGE := 300.0  # Increased range for earlier visibility
const MIN_ALPHA := 1.0  # Maximum opacity
const MAX_ALPHA := 1.0  # Maximum opacity
const GLOW_MARGIN := 2.0  # Tiny margin to prevent hard edges
const HIGHLIGHT_HEIGHT := 16.0  # Much smaller height for tighter binding
const HIGHLIGHT_EXTEND := 8.0  # Much smaller extension
const PRIMARY_COLOR := Color(0.0, 0.0, 0.0, 1.0)  # Black color
const SECONDARY_COLOR := Color(1.0, 0.9, 0.4, 1.0)  # Very soft yellow
const OUTLINE_WIDTH := 2.0  # Original thickness
const OUTLINE_OFFSET_TOP := 6.0  # Adjusted for better visibility
const OUTLINE_OFFSET_BOTTOM := 6.0  # Equal spacing top and bottom
const OUTLINE_END_MARGIN := 2.0  # Distance for vertical end lines
const VERTICAL_LINE_LENGTH := 2.0  # Length of connecting vertical lines

var platform_highlights: Dictionary = {}
var player: Node2D

func _ready() -> void:
	# Wait one frame to ensure all platforms are ready
	await get_tree().process_frame
	
	print("[PlatformHighlightManager] Starting initialization...")
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[PlatformHighlightManager] Player not found!")
		return
	else:
		print("[PlatformHighlightManager] Found player at:", player.global_position)
	
	# Find all one-way collision shapes in the scene
	_setup_platform_highlights()

func _setup_platform_highlights() -> void:
	# Start search from the chunk root (parent of this node)
	var chunk_root = get_parent()
	print("[PlatformHighlightManager] Searching for platforms in chunk:", chunk_root.name)
	
	# Find all CollisionShape2D nodes that might be platforms
	var platforms = _find_platform_collisions(chunk_root)
	print("[PlatformHighlightManager] Found", platforms.size(), "platforms in chunk")
	
	# Create highlights for each platform
	for platform in platforms:
		if platform.shape is SegmentShape2D:
			print("  Found line platform:", platform.shape.a, " to ", platform.shape.b)
		_create_highlight_for_platform(platform)

func _find_platform_collisions(node: Node) -> Array:
	var platforms = []
	
	# Check for CollisionShape2D nodes with one-way collision
	if node is CollisionShape2D:
		var parent = node.get_parent()
		if parent is StaticBody2D:
			print("  Found StaticBody2D:", parent.name)
			print("    Collision Layer:", parent.collision_layer)
			
			# For SegmentShape2D (collision lines), check one_way_collision property
			if node.shape is SegmentShape2D:
				# Get the one_way_collision property directly from the CollisionShape2D
				var is_one_way = node.one_way_collision
				
				print("    Found line segment from", node.shape.a, "to", node.shape.b)
				print("    Shape Type:", node.shape.get_class())
				print("    One Way Collision:", is_one_way)
				
				if is_one_way:
					print("    Added as platform!")
					platforms.append(node)
	
	# Recursively check all children
	for child in node.get_children():
		platforms.append_array(_find_platform_collisions(child))
	
	return platforms

func _get_rect_bounds(shape: Shape2D, platform: CollisionShape2D) -> Rect2:
	if shape is SegmentShape2D:
		# For segment shapes, we need to consider the platform's transform
		var global_a = platform.to_global(shape.a)
		var global_b = platform.to_global(shape.b)
		
		# Convert back to local coordinates for the highlight
		var local_a = to_local(global_a)
		var local_b = to_local(global_b)
		
		# Calculate rectangle bounds - much tighter to the platform
		var left_x = min(local_a.x, local_b.x) - HIGHLIGHT_EXTEND
		var right_x = max(local_a.x, local_b.x) + HIGHLIGHT_EXTEND
		var platform_y = min(local_a.y, local_b.y)
		var top_y = platform_y - HIGHLIGHT_HEIGHT
		var bottom_y = platform_y + HIGHLIGHT_HEIGHT * 0.5  # Less glow below platform
		
		return Rect2(
			Vector2(left_x, top_y),
			Vector2(right_x - left_x, bottom_y - top_y)
		)
	
	return Rect2()

func _create_highlight_for_platform(platform: CollisionShape2D) -> void:
	var shape = platform.shape
	if not shape is SegmentShape2D:
		return
		
	# Create a container for our highlight effect
	var container = Node2D.new()
	add_child(container)
	
	# Convert platform points to local coordinates
	var global_a = platform.to_global(shape.a)
	var global_b = platform.to_global(shape.b)
	var local_a = to_local(global_a)
	var local_b = to_local(global_b)
	
	# Calculate normal vector for offset
	var direction = (local_b - local_a).normalized()
	var normal = Vector2(-direction.y, direction.x)
	
	# Create horizontal lines
	var lines = []
	
	# Top line
	var top_line = Line2D.new()
	top_line.add_point(local_a + (normal * OUTLINE_OFFSET_TOP))
	top_line.add_point(local_b + (normal * OUTLINE_OFFSET_TOP))
	top_line.width = OUTLINE_WIDTH
	top_line.default_color = PRIMARY_COLOR
	top_line.default_color.a = MIN_ALPHA
	top_line.antialiased = true
	
	# Bottom line
	var bottom_line = Line2D.new()
	bottom_line.add_point(local_a - (normal * OUTLINE_OFFSET_BOTTOM))
	bottom_line.add_point(local_b - (normal * OUTLINE_OFFSET_BOTTOM))
	bottom_line.width = OUTLINE_WIDTH
	bottom_line.default_color = PRIMARY_COLOR
	bottom_line.default_color.a = MIN_ALPHA
	bottom_line.antialiased = true
	
	# Left connecting line
	var left_line = Line2D.new()
	left_line.add_point(local_a + (normal * OUTLINE_OFFSET_TOP))
	left_line.add_point(local_a - (normal * OUTLINE_OFFSET_BOTTOM))
	left_line.width = OUTLINE_WIDTH
	left_line.default_color = PRIMARY_COLOR
	left_line.default_color.a = MIN_ALPHA
	left_line.antialiased = true
	
	# Right connecting line
	var right_line = Line2D.new()
	right_line.add_point(local_b + (normal * OUTLINE_OFFSET_TOP))
	right_line.add_point(local_b - (normal * OUTLINE_OFFSET_BOTTOM))
	right_line.width = OUTLINE_WIDTH
	right_line.default_color = PRIMARY_COLOR
	right_line.default_color.a = MIN_ALPHA
	right_line.antialiased = true
	
	# Add blend mode for all lines
	for line in [top_line, bottom_line, left_line, right_line]:
		line.material = CanvasItemMaterial.new()
		line.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		container.add_child(line)
		lines.append(line)
	
	# Store effect
	platform_highlights[platform] = {
		"container": container,
		"lines": lines
	}

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	# Lines are always visible at constant alpha
	for platform in platform_highlights:
		var effects = platform_highlights[platform]
		for line in effects.lines:
			if line.default_color.a != MIN_ALPHA:  # Only update if needed
				var color = line.default_color
				color.a = MIN_ALPHA
				line.default_color = color

# Helper function for smoother transitions
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	# Scale, bias and saturate x to 0..1 range
	x = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	# Evaluate polynomial
	return x * x * (3 - 2 * x)

func _get_distance_to_platform(platform: CollisionShape2D, point: Vector2) -> float:
	# Convert point to local coordinates
	var local_point = platform.to_local(point)
	
	# Get closest point on platform
	var shape = platform.shape
	var closest_point = Vector2.ZERO
	
	if shape is RectangleShape2D:
		closest_point = local_point.clamp(-shape.size/2, shape.size/2)
	elif shape is SegmentShape2D:
		var segment_vector = shape.b - shape.a
		var point_vector = local_point - shape.a
		var t = point_vector.dot(segment_vector) / segment_vector.dot(segment_vector)
		t = clampf(t, 0.0, 1.0)
		closest_point = shape.a + segment_vector * t
	
	# Return distance to closest point
	return local_point.distance_to(closest_point) 
