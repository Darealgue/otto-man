extends BaseRoom

const BaseRoomScript = preload("res://rooms/base_room.gd")
@export var enemy_scene: PackedScene = preload("res://enemy/heavy/heavy_enemy.tscn")

var wave_configurations = [
	{
		"enemy_count": 1,
		"spawn_delay": 1.0,
		"enemy_types": ["heavy"]
	},
	{
		"enemy_count": 2,
		"spawn_delay": 0.8,
		"enemy_types": ["heavy"]
	}
]

var current_wave := 0
var enemies_spawned := 0
var spawn_timer := 0.0
var wave_completed := false

@onready var trigger_area: Area2D = $TriggerArea
@onready var kill_zone: Area2D = $KillZone

func _ready() -> void:
	super._ready()
	print("Combat challenge room ready!")
	
	# Initialize positions
	entrance_position = $Positions/EntrancePosition
	exit_position = $Positions/ExitPosition
	if not entrance_position:
		push_error("No entrance position found!")
	if not exit_position:
		push_error("No exit position found!")
	
	# Get spawn points
	var spawn_points_node = $SpawnPoints
	if not spawn_points_node:
		push_error("No SpawnPoints node found!")
		return
	
	var children = spawn_points_node.get_children()
	var typed_points: Array[Node2D] = []
	for child in children:
		if child is Node2D:
			typed_points.append(child)
			# Connect enemy detector signals
			if child.has_node("EnemyDetector"):
				var detector = child.get_node("EnemyDetector")
				detector.body_entered.connect(_on_enemy_detector_entered)
				detector.body_exited.connect(_on_enemy_detector_exited)
	spawn_points = typed_points
	print("Found ", spawn_points.size(), " spawn points")
	
	# Connect trigger area signal
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_area_entered)
		print("Connected trigger area signal")
	else:
		push_error("No trigger area found!")
		
	# Connect kill zone signal
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)
		print("Connected kill zone signal")
	else:
		push_error("No kill zone found!")

func _on_trigger_area_entered(body: Node) -> void:
	print("Body entered trigger area: ", body.name)
	if body.is_in_group("player") and not is_room_active:
		print("Player entered trigger area, starting room")
		start_room()
		spawn_initial_enemies()

func _process(delta: float) -> void:
	if not is_room_active:
		return
		
	if spawn_timer > 0:
		spawn_timer -= delta
		if spawn_timer <= 0 and current_wave < wave_configurations.size():
			spawn_enemy()

func spawn_initial_enemies() -> void:
	print("Spawning initial enemies for wave ", current_wave)
	if current_wave < wave_configurations.size():
		spawn_enemy()

func spawn_enemy() -> void:
	if not enemy_scene:
		push_error("No enemy scene set!")
		return
		
	var wave = wave_configurations[current_wave]
	if enemies_spawned >= wave.enemy_count:
		print("\n=== WAVE COMPLETION CHECK ===")
		print("Wave ", current_wave, " completed")
		wave_completed = true
		current_wave += 1
		enemies_spawned = 0
		if current_wave >= wave_configurations.size():
			print("All waves completed!")
			print("Active enemies: ", active_enemies.size())
			print("Wave completed: ", wave_completed)
			if active_enemies.is_empty():
				print("No active enemies - clearing room")
				is_room_cleared = true
				complete_room()
			return
		print("Starting wave ", current_wave)
		
	var available_points = spawn_points.filter(func(point): return point.is_spawn_clear())
	if available_points.is_empty():
		print("No clear spawn points available, retrying in 0.5 seconds")
		spawn_timer = 0.5
		return
		
	var spawn_point = available_points[randi() % available_points.size()]
	print("Spawning enemy at point: ", spawn_point.global_position)
	
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = spawn_point.global_position
	
	# Add enemy to active_enemies right when spawned
	active_enemies.append(enemy)
	print("Added enemy to active_enemies. Count now: ", active_enemies.size())
	
	# Connect to enemy death signal
	if enemy.has_signal("enemy_defeated"):
		print("Connecting to enemy_defeated signal")
		# Disconnect first to avoid duplicate connections
		if enemy.enemy_defeated.is_connected(_on_enemy_defeated):
			enemy.enemy_defeated.disconnect(_on_enemy_defeated)
		enemy.enemy_defeated.connect(_on_enemy_defeated.bind(enemy))
		print("Connected to enemy_defeated signal")
	else:
		print("WARNING: Enemy does not have enemy_defeated signal!")
	
	enemies_spawned += 1
	spawn_timer = wave.spawn_delay
	print("Enemy spawned, total in wave: ", enemies_spawned, "/", wave.enemy_count)

func _on_kill_zone_entered(body: Node2D) -> void:
	print("\n=== KILL ZONE ENTERED ===")
	print("Kill zone entered by: ", body.name)
	print("Current active enemies: ", active_enemies.size())
	print("Wave completed: ", wave_completed)
	print("Current wave: ", current_wave, "/", wave_configurations.size())
	
	if body.is_in_group("player"):
		print("Player fell into kill zone")
		# Reset player to entrance
		body.global_position = entrance_position.global_position
		# Optionally apply fall damage
		if body.has_method("take_damage"):
			body.take_damage(20.0)
	elif body.is_in_group("enemies"):
		print("Enemy fell into kill zone: ", body.name)
		print("Active enemies before removal: ", active_enemies.size())
		print("Was in active_enemies: ", body in active_enemies)
		
		# Call handle_death() on the enemy to ensure proper cleanup and signal emission
		if body.has_method("handle_death"):
			print("Calling handle_death() on enemy")
			body.handle_death()
		
		# Remove enemy from active enemies and queue for deletion
		if body in active_enemies:
			active_enemies.erase(body)
			print("Removed from active_enemies. Count now: ", active_enemies.size())
		
		# Check if room should be cleared
		if active_enemies.is_empty():
			print("\n=== CHECKING ROOM COMPLETION ===")
			print("No active enemies remaining")
			print("Wave completed: ", wave_completed)
			print("Current wave: ", current_wave)
			print("Total waves: ", wave_configurations.size())
			
			if wave_completed and current_wave >= wave_configurations.size():
				print("All conditions met - clearing room")
				is_room_cleared = true
				complete_room()
			else:
				print("Room not cleared - spawning next enemy")
				spawn_enemy()

func _on_enemy_detector_entered(body: Node) -> void:
	if body.is_in_group("enemies") and not active_enemies.has(body):
		print("Enemy detected: ", body.name)
		active_enemies.append(body)
		
		# Connect to enemy death signal if it exists
		if body.has_signal("enemy_defeated"):
			if not body.enemy_defeated.is_connected(_on_enemy_defeated):
				body.enemy_defeated.connect(_on_enemy_defeated)

func _on_enemy_detector_exited(body: Node) -> void:
	if body.is_in_group("enemies"):
		print("Enemy left detector: ", body.name)
		active_enemies.erase(body)

func start_room() -> void:
	if is_room_active:
		return
		
	print("=== STARTING ROOM ===")
	is_room_active = true
	is_room_cleared = false
	room_started.emit()
	
	# Seal the room
	_seal_room()
	
	# Start spawning enemies
	spawn_initial_enemies()

func complete_room() -> void:
	print("\n=== COMPLETE ROOM CALLED ===")
	print("is_room_cleared: ", is_room_cleared)
	print("is_room_active: ", is_room_active)
	print("active_enemies count: ", active_enemies.size())
	print("wave_completed: ", wave_completed)
	print("current_wave: ", current_wave)
	
	if is_room_cleared:
		print("Room already cleared, returning")
		return
		
	print("Room completion sequence started")
	is_room_cleared = true
	is_room_active = false
	
	# Remove barriers
	print("Calling _unseal_room()")
	_unseal_room()
	print("Room unsealed - barriers removed")
	
	# Emit completion signal
	room_completed.emit()
	print("Room completion signal emitted")
	
	# Mark room as completed in RoomManager
	RoomManager.mark_room_completed(scene_file_path)
	print("Room marked as completed in RoomManager")
	
	# Disconnect trigger area to prevent re-entry
	if trigger_area and trigger_area.body_entered.is_connected(_on_trigger_area_entered):
		trigger_area.body_entered.disconnect(_on_trigger_area_entered)
		print("Trigger area disconnected")
		
	# Enable exit area if it exists
	if exit_position and exit_position.has_node("ExitArea"):
		var exit_area = exit_position.get_node("ExitArea")
		exit_area.monitoring = true
		exit_area.monitorable = true
		print("Exit area enabled")

func _seal_room() -> void:
	print("Sealing room - enabling barriers")
	# Enable barriers
	var barriers = $Barriers
	if barriers:
		for barrier in barriers.get_children():
			barrier.visible = true
			if barrier.has_node("CollisionShape2D"):
				barrier.get_node("CollisionShape2D").set_deferred("disabled", false)
				print("Enabled barrier: ", barrier.name)
	else:
		push_error("No Barriers node found!")

func _unseal_room() -> void:
	print("Unsealing room - disabling barriers")
	# Disable barriers
	var barriers = $Barriers
	if barriers:
		for barrier in barriers.get_children():
			barrier.visible = false
			if barrier.has_node("CollisionShape2D"):
				barrier.get_node("CollisionShape2D").set_deferred("disabled", true)
				print("Disabled barrier: ", barrier.name)
	else:
		push_error("No Barriers node found!")

func _on_enemy_defeated(enemy: Node) -> void:
	print("\n=== ENEMY DEFEATED HANDLER ===")
	print("Enemy defeated: ", enemy.name)
	print("Active enemies before removal: ", active_enemies.size())
	print("Enemy in active_enemies: ", enemy in active_enemies)
	
	if enemy in active_enemies:
		active_enemies.erase(enemy)
		print("Enemy removed from active_enemies")
		print("Active enemies after removal: ", active_enemies.size())
		enemy_defeated.emit(enemy)
		
		# Check if room is cleared
		print("\n=== ROOM CLEAR CHECK ===")
		print("Active enemies: ", active_enemies.size())
		print("Wave completed: ", wave_completed)
		print("Current wave: ", current_wave, "/", wave_configurations.size())
		
		if active_enemies.is_empty() and wave_completed and current_wave >= wave_configurations.size():
			print("All conditions met for room completion:")
			print("- No active enemies")
			print("- Wave completed: ", wave_completed)
			print("- Current wave: ", current_wave, " >= Total waves: ", wave_configurations.size())
			print("Calling complete_room()")
			complete_room()
		elif active_enemies.is_empty():
			print("No more enemies, but room not cleared:")
			print("- Wave completed: ", wave_completed)
			print("- Current wave: ", current_wave, " / Total waves: ", wave_configurations.size())
	else:
		print("Enemy not found in active_enemies list!")
