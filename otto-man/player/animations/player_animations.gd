extends Resource

# Ground States
var idle_animation = {
	"name": "idle",
	"length": 1.0,
	"loop": true,
	"transitions": ["run", "jump", "fall", "attack", "block"]
}

var run_animation = {
	"name": "run",
	"length": 0.8,
	"loop": true,
	"transitions": ["idle", "jump", "fall", "attack", "block"]
}

# Air States
var jump_animation = {
	"name": "jump",
	"length": 0.5,
	"loop": false,
	"transitions": ["double_jump", "fall", "wall_slide", "attack", "block"]
}

var double_jump_animation = {
	"name": "double_jump",
	"length": 0.5,
	"loop": false,
	"transitions": ["fall", "wall_slide", "attack", "block"]
}

var fall_animation = {
	"name": "fall",
	"length": 0.5,
	"loop": true,
	"transitions": ["idle", "wall_slide", "attack", "block"]
}

# Wall States
var wall_slide_animation = {
	"name": "wall_slide",
	"length": 0.5,
	"loop": true,
	"transitions": ["idle", "jump", "fall", "attack"]
}

var wall_jump_animation = {
	"name": "wall_jump",
	"length": 0.5,
	"loop": false,
	"transitions": ["fall", "wall_slide", "attack", "block"]
}

# Combat States
var attack_animation = {
	"name": "attack",
	"length": 0.4,
	"loop": false,
	"transitions": ["idle", "run", "fall"]
}

var block_animation = {
	"name": "block",
	"length": 0.3,
	"loop": true,
	"transitions": ["block_impact", "idle", "run", "fall"]
}

var block_impact_animation = {
	"name": "block_impact",
	"length": 0.2,
	"loop": false,
	"transitions": ["block", "idle"]
}

# Special States
var dash_animation = {
	"name": "dash",
	"length": 0.3,
	"loop": false,
	"transitions": ["idle", "run", "fall"]
}

# Animation Groups
var ground_states = ["idle", "run"]
var air_states = ["jump", "double_jump", "fall"]
var wall_states = ["wall_slide", "wall_jump"]
var combat_states = ["attack", "block", "block_impact"]
var special_states = ["dash"]

# Transition Times
const INSTANT = 0.0
const FAST = 0.1
const NORMAL = 0.2
const SLOW = 0.3

# Get all animations
func get_all_animations() -> Array:
	return [
		idle_animation,
		run_animation,
		jump_animation,
		double_jump_animation,
		fall_animation,
		wall_slide_animation,
		wall_jump_animation,
		attack_animation,
		block_animation,
		block_impact_animation,
		dash_animation
	]

# Get animation by name
func get_animation(name: String) -> Dictionary:
	for anim in get_all_animations():
		if anim.name == name:
			return anim
	return {} 