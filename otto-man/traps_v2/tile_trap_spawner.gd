extends Node2D
class_name TileTrapSpawner

## Tile-based trap spawner. Created by the level generator at runtime.
## Each spawner occupies 1 tile and spawns 1 trap.
## The level generator groups adjacent spawners of the same type to form
## multi-tile trap clusters (e.g. 5 spikes in a row).

@export var trap_type: TrapConfigV2.TrapType = TrapConfigV2.TrapType.SPIKE
@export var surface_type: TrapConfigV2.SurfaceType = TrapConfigV2.SurfaceType.FLOOR
@export var current_level: int = 1
@export var auto_spawn: bool = true

var _spawned_trap: BaseTrapV2 = null
var _is_active: bool = false

const DEBUG_TRAP: bool = false

func _ready() -> void:
	add_to_group("TileTrapSpawner")
	if DEBUG_TRAP:
		print("[TileTrapSpawner] Ready at %s — type: %s, surface: %s" % [
			global_position,
			TrapConfigV2.TrapType.keys()[trap_type],
			TrapConfigV2.SurfaceType.keys()[surface_type]
		])

func activate() -> bool:
	_is_active = true
	if auto_spawn:
		return _spawn_trap()
	return true

func deactivate() -> void:
	_is_active = false
	clear_trap()

func _spawn_trap() -> bool:
	var scene_path := TrapConfigV2.get_scene_path(trap_type)
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("[TileTrapSpawner] Failed to load scene: %s" % scene_path)
		return false

	var trap := scene.instantiate() as BaseTrapV2
	if not trap:
		push_error("[TileTrapSpawner] Instantiated node is not BaseTrapV2: %s" % scene_path)
		return false

	trap.base_damage = TrapConfigV2.get_base_damage(trap_type)
	get_parent().add_child(trap)
	trap.global_position = global_position
	trap.initialize(current_level, surface_type)

	_spawned_trap = trap
	if DEBUG_TRAP:
		print("[TileTrapSpawner] Spawned %s at %s (surface: %s)" % [
			TrapConfigV2.TrapType.keys()[trap_type],
			global_position,
			TrapConfigV2.SurfaceType.keys()[surface_type]
		])
	return true

func clear_trap() -> void:
	if _spawned_trap and is_instance_valid(_spawned_trap):
		_spawned_trap.queue_free()
		_spawned_trap = null

func get_spawned_trap() -> BaseTrapV2:
	return _spawned_trap

func set_level(level: int) -> void:
	current_level = level
