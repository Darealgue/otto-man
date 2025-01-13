extends BaseRoom
class_name TestRoom

@export var enemy_scene: PackedScene
@export var enemies_per_wave: int = 3
@export var total_waves: int = 2

var current_wave := 0
var wave_completed := false
var spawn_timer := 0.0
const SPAWN_DELAY := 1.0  # Time between enemy spawns

@onready var trigger_area: Area2D = $TriggerArea
@onready var kill_zone: Area2D = $KillZone

func _ready() -> void:
	print("Test room ready!")
	# Get spawn points with explicit typing
	var nodes = $SpawnPoints.get_children()
	var spawn_points_array: Array[Node2D] = []
	for node in nodes:
		if node is SpawnPoint:
			spawn_points_array.append(node)
	spawn_points = spawn_points_array
	print("Found ", spawn_points.size(), " spawn points")
	
	entrance_position = $Positions/EntrancePosition
	exit_position = $Positions/ExitPosition
	
	super._ready()
	
	# Connect to our own signals to handle room progression
	room_started.connect(_on_room_started)
	room_completed.connect(_on_room_completed)
	enemy_defeated.connect(_on_enemy_defeated)
	
	# Connect trigger area
	if trigger_area:
		print("Connecting trigger area signals")
		trigger_area.body_entered.connect(_on_trigger_area_entered)
	else:
		push_error("No trigger area found!")
		
	# Connect kill zone
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)

func _on_trigger_area_entered(body: Node2D) -> void:
	print("Trigger area entered by: ", body.name)
	print("Body groups: ", body.get_groups())
	if not is_room_active and body.is_in_group("player"):
		print("Starting room!")
		start_room()
		
		spawn_initial_enemies()

func spawn_initial_enemies() -> void:
	current_wave = 0
	wave_completed = false
	spawn_next_wave()

func _process(delta: float) -> void:
	if is_room_active and spawn_timer > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()

func spawn_next_wave() -> void:
	if current_wave >= total_waves:
		wave_completed = true
		return
		
	current_wave += 1
	spawn_timer = SPAWN_DELAY
	
	# Emit some particles or play animation to indicate new wave
	print("Starting wave ", current_wave)

func spawn_enemy() -> void:
	if not enemy_scene or spawn_points.is_empty():
		push_error("Missing enemy scene or spawn points!")
		return
		
	# Get random spawn point that is clear
	var available_spawns = spawn_points.filter(func(spawn): return spawn.is_spawn_clear())
	if available_spawns.is_empty():
		# Try again next frame if no clear spawn points
		spawn_timer = 0.1
		return
		
	var spawn_point = available_spawns[randi() % available_spawns.size()]
	
	# Instance enemy
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_point.global_position
	add_child(enemy)
	
	# Check if we should spawn more enemies in this wave
	var enemies_in_wave = get_tree().get_nodes_in_group("enemies").size()
	if enemies_in_wave < enemies_per_wave:
		spawn_timer = SPAWN_DELAY
	else:
		spawn_timer = 0
		wave_completed = true

func _on_room_started() -> void:
	print("Room started!")
	# Play start animation or sound

func _on_room_completed() -> void:
	print("Room completed!")
	# Play victory animation or sound
	# Spawn powerup or rewards

func _on_enemy_defeated(_enemy: Node) -> void:
	# If wave is complete and no enemies left, start next wave
	if wave_completed and active_enemies.is_empty() and current_wave < total_waves:
		wave_completed = false
		spawn_next_wave() 

func _on_kill_zone_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		# Remove enemy from active enemies and queue free
		active_enemies.erase(body)
		body.queue_free()
		
		# If wave is complete and no enemies left, start next wave
		if wave_completed and active_enemies.is_empty() and current_wave < total_waves:
			wave_completed = false
			spawn_next_wave()
	elif body.is_in_group("player"):
		# Reset player to entrance position
		body.global_position = entrance_position.global_position
		# Optionally handle player death/damage here
		if body.has_method("take_damage"):
			body.take_damage(25.0)  # Apply fall damage
