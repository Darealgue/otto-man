extends Node

signal powerup_activated(powerup: PowerupEffect)
signal powerup_deactivated(powerup: PowerupEffect)

var player: CharacterBody2D
var active_powerups: Array[PowerupEffect] = []

const PowerupSelection = preload("res://ui/powerup_selection.tscn")
const POWERUP_SCENES: Array[PackedScene] = [
	preload("res://resources/powerups/scenes/damage_boost.tscn"),
	preload("res://resources/powerups/scenes/health_boost.tscn"),
	preload("res://resources/powerups/scenes/speed_demon.tscn"),
	preload("res://resources/powerups/scenes/momentum_master.tscn"),
	preload("res://resources/powerups/scenes/perfect_guard.tscn"),
	preload("res://resources/powerups/scenes/berserker_gambit.tscn"),
	preload("res://resources/powerups/scenes/fire_trail.tscn")
]

func _ready() -> void:
	# Create a container node for our powerup instances
	var container = Node.new()
	container.name = "ActivePowerups"
	add_child(container)

func register_player(p: CharacterBody2D) -> void:
	player = p
	# Reactivate any existing powerups for the new player
	for powerup in active_powerups:
		powerup.activate(player)

func _process(delta: float) -> void:
	if !player:
		return
		
	# Update all active powerups
	for powerup in active_powerups:
		powerup.process(player, delta)

func show_powerup_selection() -> void:
	if !player:
		return
		
	var selection_ui = PowerupSelection.instantiate()
	get_tree().root.add_child(selection_ui)
	selection_ui.setup_powerups(POWERUP_SCENES)
	get_tree().paused = true

func activate_powerup(powerup_scene: PackedScene) -> void:
	if !player:
		return
		
	# Instance the powerup
	var powerup = powerup_scene.instantiate() as PowerupEffect
	if !powerup:
		push_error("Failed to instantiate powerup")
		return
		
	# Check for conflicts
	for active in active_powerups:
		if active.conflicts_with(powerup) or powerup.conflicts_with(active):
			powerup.queue_free()
			return
			
	# Add to scene tree and activate
	$ActivePowerups.add_child(powerup)
	active_powerups.append(powerup)
	powerup.activate(player)
	powerup_activated.emit(powerup)

func deactivate_powerup(powerup: PowerupEffect) -> void:
	if !player or !powerup:
		return
		
	powerup.deactivate(player)
	active_powerups.erase(powerup)
	powerup.queue_free()
	powerup_deactivated.emit(powerup)

func get_active_powerups() -> Array[PowerupEffect]:
	return active_powerups

func clear_all_powerups() -> void:
	if !player:
		return
		
	for powerup in active_powerups.duplicate():
		deactivate_powerup(powerup)
	active_powerups.clear()

# Helper function to check if a powerup is active by its scene path
func has_powerup(powerup_scene_path: String) -> bool:
	for powerup in active_powerups:
		if powerup.scene_file_path == powerup_scene_path:
			return true
	return false
