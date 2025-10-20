extends BaseChunk

func _ready() -> void:
	chunk_type = "dungeon"  # Set this as a dungeon chunk
	print("[DungeonChunk] Setting chunk_type to: ", chunk_type)
	super._ready()  # Call parent _ready to initialize spawn manager

# Override to add special dungeon behavior
func start_spawning(interval: float = 5.0) -> void:
	if spawn_manager:
		# Dungeons might want more frequent spawning for challenge
		spawn_manager.start_all_spawning(interval * 0.8)  # 20% faster spawning
