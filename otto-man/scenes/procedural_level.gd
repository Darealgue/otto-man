extends Node2D

@onready var player = $Player

func _ready() -> void:
	# Wait one frame to ensure ChunkManager is ready
	await get_tree().process_frame
	
	print("[ProceduralLevel] Starting level generation")
	
	# Enable and start chunk generation
	ChunkManager.enable()
	ChunkManager.start_generation()
	
	# Position player at spawn point
	player.global_position = ChunkManager.get_spawn_position()
	
	# Connect to signals
	ChunkManager.difficulty_changed.connect(_on_difficulty_changed)
	ChunkManager.chunk_loaded.connect(_on_chunk_loaded)
	ChunkManager.chunk_unloaded.connect(_on_chunk_unloaded)

func _exit_tree() -> void:
	# Disable chunk generation when leaving the scene
	ChunkManager.disable()

func _on_difficulty_changed(new_difficulty: int) -> void:
	print("[ProceduralLevel] Difficulty increased to: ", new_difficulty)
	# You can add visual effects or UI updates here

func _on_chunk_loaded(chunk: BaseChunk) -> void:
	print("[ProceduralLevel] New chunk loaded: ", chunk.chunk_type.chunk_name)
	# You can add transition effects here

func _on_chunk_unloaded(chunk: BaseChunk) -> void:
	print("[ProceduralLevel] Chunk unloaded: ", chunk.chunk_type.chunk_name)
	# You can add cleanup or transition effects here 
