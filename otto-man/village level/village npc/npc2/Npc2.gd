extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var action_label = $ActionLabel
@onready var nav_agent = $NavigationAgent2D

const SPEED = 50.0
const ARRIVAL_THRESHOLD = 10.0  # Distance to consider NPC has arrived at destination

var NPC_Info = {"Name":"Osman", "Occupation":"Farmer", "Mood":"Angry", 
"Gender":"Male", "Age":"45", "Health":"Healthy"}

# Define locations for different activities
var activity_zones = {
	"forest": {
		"area": null,  # Will hold reference to Area2D
		"center": Vector2.ZERO,  # Will store zone's center position
		"positions": [],  # Array of specific positions in the zone
		"current_spot": null  # Current target position
	},
	"well": {
		"area": null,
		"center": Vector2.ZERO,
		"positions": [],
		"current_spot": null
	},
	"house": {
		"area": null,
		"center": Vector2.ZERO,
		"positions": [],
		"current_spot": null
	},
	"girl_house": {
		"area": null,
		"center": Vector2.ZERO,
		"positions": [],
		"current_spot": null
	}
}

var current_schedule = {}  # Will store action:duration pairs
var current_action = ""
var current_duration = 0.0
var action_timer = 0.0
var target_position = Vector2.ZERO
var is_moving = false
var is_performing_action = false
var next_action = ""

# Navigation states
enum NavState { IDLE, MOVING_TO_ZONE, MOVING_TO_SPOT, AVOIDING_OBSTACLE }
var current_nav_state = NavState.IDLE

# Navigation settings
const OBSTACLE_CHECK_RADIUS = 50.0
const PATH_RECALCULATION_TIME = 0.5
const MIN_DISTANCE_TO_TARGET = 5.0

var path_update_timer = 0.0
var current_path = []
var current_path_index = 0

# Add these constants at the top
const WALL_CHECK_DISTANCE = 30.0
const WALL_AVOIDANCE_FORCE = 200.0

func _ready():
	# Wait one frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Initialize zone positions manually based on your scene
	activity_zones = {
		"forest": {
			"area": null,
			"center": Vector2(-998.25, 154.75),  # ForestZone CollisionShape2D position
			"positions": [],
			"current_spot": null
		},
		"well": {
			"area": null,
			"center": Vector2(279, -85),  # WellZone CollisionShape2D position
			"positions": [],
			"current_spot": null
		},
		"house": {
			"area": null,
			"center": Vector2(-114.5, 26.5),  # HouseZone CollisionShape2D position
			"positions": [],
			"current_spot": null
		},
		"girl_house": {
			"area": null,
			"center": Vector2(-112, 44),  # GirlHouseZone CollisionShape2D position
			"positions": [],
			"current_spot": null
		}
	}
	
	# Get the parent node (Village)
	var village = get_parent()
	if village:
		# We only need spots now
		var zones = village.get_node("Zones")
		
		if zones:
			# Register zones and their centers
			var zone_mappings = {
				"forest": "ForestZone",
				"well": "WellZone",
				"house": "HouseZone",
				"girl_house": "GirlHouseZone"
			}
			
			for zone_key in zone_mappings:
				var zone_node = zones.get_node_or_null(zone_mappings[zone_key])
				if zone_node:
					activity_zones[zone_key]["area"] = zone_node
					# Get position from CollisionShape2D
					var collision = zone_node.get_node("CollisionShape2D")
					if collision:
						activity_zones[zone_key]["center"] = collision.global_position
					else:
						print("ERROR: No CollisionShape2D found for zone: ", zone_key)
			
			print("Successfully registered all zones")
		else:
			print("ERROR: Could not find Zones node")
	else:
		print("ERROR: Could not find parent node")
	
	# Initialize navigation agent
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.radius = 16.0
	nav_agent.avoidance_enabled = true
	nav_agent.max_speed = SPEED
	
	# Connect navigation signals
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_on_navigation_finished)
	

	
	# Set up collision
	collision_layer = 128  # Layer 8 for NPCs
	collision_mask = 1    # Only collide with world/terrain

func update_action_label():
	var label_text = "Current: " + current_action
	
	# Add next action if available
	if !current_schedule.is_empty():
		var next_key = current_schedule.keys()[0]
		label_text += "\nNext: " + next_key
	else:
		label_text += "\nNext: None"
	
	# Add status
	if is_moving:
		label_text += "\nStatus: Moving to location"
	elif is_performing_action:
		label_text += "\nStatus: Performing action"
		# Add remaining time
		var time_left = current_duration - action_timer
		label_text += "\nTime left: " + str(int(time_left)) + " minutes"
	
	action_label.text = label_text

func parse_daily_schedule(daily_actions : Array):
	update_action_label()
	# This is an example of how to parse the Gemini response
	
	current_schedule.clear()
	
	for action_string in daily_actions:
		
		# First split to separate action and duration
		var main_parts = action_string.split("Duration:")
		if main_parts.size() < 2:
			continue
			
		# Get the action part (remove "Main action:" or "Custom action:")
		var action_part = main_parts[0].split(": ", true, 1)
		if action_part.size() < 2:
			continue
		var action_name = action_part[1].strip_edges()
		
		# Get the duration part
		var duration_str = main_parts[1].strip_edges()
		
		# Convert duration to game seconds (24 real seconds = 1 game hour)
		var duration = 0.0
		if "hour" in duration_str:
			# 1 hour = 24 seconds
			duration = float(duration_str.split(" ")[0]) * 24.0
		else:
			# 1 minute = 24/60 = 0.4 seconds
			duration = float(duration_str.split(" ")[0]) * 0.4
		
		current_schedule[action_name] = duration
	
	start_next_action()

func start_next_action():
	if current_schedule.is_empty():
		is_performing_action = false
		is_moving = false
		velocity = Vector2.ZERO
		return
	
	current_action = current_schedule.keys()[0]
	current_duration = current_schedule[current_action]  # Duration is already in seconds
	current_schedule.erase(current_action)
	action_timer = 0.0
	
	# Get target zone
	var target_zone = get_current_zone_name()

	
	if target_zone and activity_zones.has(target_zone):
		var zone_pos = activity_zones[target_zone]["center"]

		target_position = zone_pos
		nav_agent.target_position = zone_pos
		is_moving = true
		is_performing_action = false
	else:

		is_performing_action = true
	
	update_action_label()

func _physics_process(delta: float) -> void:
	if is_performing_action:
		handle_action(delta)
		return
	
	if is_moving:
		var next_path_position: Vector2 = nav_agent.get_next_path_position()
		var direction = (next_path_position - global_position).normalized()
		
		# Set velocity for navigation
		velocity = direction * SPEED
		
		# Update animations based on movement direction
		update_movement_animation(direction)
		
		# Check if we've arrived
		var distance_to_target = global_position.distance_to(target_position)
		if distance_to_target < ARRIVAL_THRESHOLD:
			handle_arrival()
			return
		
		move_and_slide()

func handle_arrival():

	is_moving = false
	is_performing_action = true
	velocity = Vector2.ZERO
	
	# Lock position
	global_position = target_position
	animated_sprite_2d.play("idle")
	action_timer = 0.0
	update_action_label()

func handle_action(delta: float) -> void:
	if !is_performing_action:
		return
	
	var duration = current_duration  # Duration is already in game seconds
	action_timer += delta
	
	# Print progress every second
	if int(action_timer) != int(action_timer - delta):
		var time_left = duration - action_timer

	
	# Check if action is complete
	if action_timer >= duration:

		
		# Reset all states
		is_performing_action = false
		is_moving = false
		velocity = Vector2.ZERO
		nav_agent.set_velocity(Vector2.ZERO)
		action_timer = 0.0
		
		# Start next action
		call_deferred("_start_next_action_internal")
		return
	
	update_action_label()

# New internal function to ensure clean state transition
func _start_next_action_internal():

	start_next_action()

func _on_velocity_computed(safe_velocity: Vector2):
	# Only update velocity if we're actually moving
	if is_moving:
		velocity = safe_velocity
		if safe_velocity.length() > 10:
			print("Moving with velocity: ", int(safe_velocity.length()))
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _on_navigation_finished():
	if current_nav_state == NavState.MOVING_TO_ZONE:
		# We've reached the zone, now find specific spot
		var zone_name = get_current_zone_name()
		if zone_name and activity_zones.has(zone_name) and !activity_zones[zone_name]["positions"].is_empty():
			var spot = find_nearest_activity_spot(zone_name)
			activity_zones[zone_name]["current_spot"] = spot
			navigate_to_target(spot)
			current_nav_state = NavState.MOVING_TO_SPOT
	elif current_nav_state == NavState.MOVING_TO_SPOT:
		handle_arrival()

func navigate_to_target(target_pos: Vector2):
	if target_pos == Vector2.ZERO:
		return
		

	target_position = target_pos
	nav_agent.target_position = target_pos
	current_nav_state = NavState.MOVING_TO_ZONE
	is_moving = true
	is_performing_action = false

func find_nearest_activity_spot(zone_name: String) -> Vector2:
	if !activity_zones.has(zone_name):
		return activity_zones[zone_name]["center"]  # Use zone center as fallback
		
	var nearest_pos = activity_zones[zone_name]["center"]  # Use zone center as default
	var shortest_dist = global_position.distance_squared_to(nearest_pos)
	
	# If there are specific positions in the zone, find the nearest one
	if !activity_zones[zone_name]["positions"].is_empty():
		for pos in activity_zones[zone_name]["positions"]:
			var dist = global_position.distance_squared_to(pos)
			if dist < shortest_dist:
				shortest_dist = dist
				nearest_pos = pos
	
	return nearest_pos

func set_daily_schedule(schedule_data: Array):
	# Call this function from your schedule manager script
	current_schedule.clear()
	
	for action_string in schedule_data:
		var parts = action_string.split(" / ")
		var action_part = parts[0].split(": ", true, 1)[1]
		var duration_part = parts[1].split(": ")[1]
		
		var duration = 0.0
		if "hour" in duration_part:
			duration = float(duration_part.split(" ")[0]) * 60
		else:
			duration = float(duration_part.split(" ")[0])
		
		current_schedule[action_part] = duration
	
	start_next_action()

func update_movement_animation(direction: Vector2) -> void:
	# Update animations based on movement direction
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite_2d.play("walk_right")
		else:
			animated_sprite_2d.play("walk_left")
	else:
		if direction.y < 0:
			animated_sprite_2d.play("walk_up")
		else:
			animated_sprite_2d.play("walk")  # Walking down

func get_current_zone_name() -> String:
	# Determine which zone we're in based on current action
	var action_lower = current_action.to_lower()
	
	if "water" in action_lower:
		return "well"
	elif "tree" in action_lower or "wood" in action_lower:
		return "forest"
	elif "girl" in action_lower or "watching" in action_lower:  # Added watching
		return "girl_house"
	elif "house" in action_lower and "girl" not in action_lower:  # Modified condition
		return "house"
	
	# Default to girl_house for specific actions
	if "visiting" in action_lower:
		return "girl_house"
	
	return ""

func is_in_zone(zone_name: String) -> bool:
	if !activity_zones.has(zone_name) or !activity_zones[zone_name]["area"]:
		return false
	
	var zone = activity_zones[zone_name]["area"]
	var overlapping_areas = zone.get_overlapping_bodies()
	return overlapping_areas.has(self)
