# perfect_guard.gd
# Powerup that slows down time after a successful parry
#
# Integration:
# - Connects to player's perfect_parry signal
# - Uses ScreenEffects singleton for time manipulation
# - Duration: Permanent (powerup itself)
# - Effect: Temporary (time slow)
#
# Implementation:
# 1. Stores references to player and ScreenEffects
# 2. Connects to perfect_parry signal with CONNECT_PERSIST flag
# 3. On parry: Calls ScreenEffects.slow_time()
#
# Important:
# - Signal connection must persist between scene changes
# - Time slow effect is handled entirely by ScreenEffects
# - Visual feedback should be synchronized with time effects

extends PowerupEffect

const TIME_SCALE = 0.2  # Slow to 20% speed
const SLOW_DURATION = 1.0  # Slow time for 1 second

var current_player: CharacterBody2D  # Store player reference
var screen_effects  # Store ScreenEffects reference

func _init() -> void:
	powerup_name = "Perfect Guard"
	description = "Perfect parries slow down time"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.UTILITY

func _ready() -> void:
	# Get ScreenEffects reference
	screen_effects = get_node("/root/ScreenEffects")
	if !screen_effects:
		push_error("[Perfect Guard] ScreenEffects singleton not found!")

func activate(player: CharacterBody2D) -> void:
	
	# Store player reference
	current_player = player
	# Get ScreenEffects reference if not already set
	if !screen_effects:
		screen_effects = get_node("/root/ScreenEffects")
	
	if !screen_effects:
		push_error("[Perfect Guard] ScreenEffects singleton not found!")
		return
	
	else:
		push_error("[Perfect Guard] Player missing perfect_parry signal!")
	
	super.activate(player)

func deactivate(player: CharacterBody2D) -> void:
	
	if is_instance_valid(player):
		if player.has_signal("perfect_parry"):
			
			if player.is_connected("perfect_parry", _on_perfect_parry):
				player.disconnect("perfect_parry", _on_perfect_parry)
	
	current_player = null
	screen_effects = null
	super.deactivate(player)

func _on_perfect_parry() -> void:
	
	if !is_instance_valid(current_player):
		push_error("[Perfect Guard] Invalid player reference!")
		return
	
	if !screen_effects:
		screen_effects = get_node("/root/ScreenEffects")
	
	if !screen_effects:
		push_error("[Perfect Guard] Invalid ScreenEffects reference!")
		return
	
	
	screen_effects.slow_time(TIME_SCALE, SLOW_DURATION)
	
	# Visual feedback
	if current_player.has_node("Sprite2D"):
		var sprite = current_player.get_node("Sprite2D")
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)  # Bright white
		
		var timer = get_tree().create_timer(0.2)
		await timer.timeout
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Reset to normal
	
	# Spawn parry effect
	if ResourceLoader.exists("res://effects/parry_effect.tscn"):
		var parry_effect = load("res://effects/parry_effect.tscn").instantiate()
		get_tree().get_root().add_child(parry_effect)
		if parry_effect is Node2D:
			parry_effect.global_position = current_player.global_position
